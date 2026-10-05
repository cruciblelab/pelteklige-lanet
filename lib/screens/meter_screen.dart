import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sibilant_analyzer.dart';
import '../services/recordings.dart';
import '../services/settings.dart';
import '../services/stt.dart';

/// Tıslama ölçer: S / Ş / Z seslerinin "tizliğini" canlı gösterir.
class MeterScreen extends StatefulWidget {
  final String? initialTarget;
  const MeterScreen({super.key, this.initialTarget});

  @override
  State<MeterScreen> createState() => _MeterScreenState();
}

class _Point {
  final double hz;
  final SibilantZone zone;
  const _Point(this.hz, this.zone);
}

class _MeterScreenState extends State<MeterScreen> {
  static const _sampleRate = 44100;
  static const _historyLen = 170; // yaklaşık 4 saniye

  late SibilantAnalyzer _an;
  StreamSubscription? _sub;
  bool _running = false;
  late String _target = widget.initialTarget == 'Ş' ? 'Ş' : 'S';
  double _smoothHz = 0;
  double _level = -90;
  SibilantZone _zone = SibilantZone.silence;
  final List<_Point?> _history = [];
  int _fricFrames = 0, _hitFrames = 0;

  SibilantZone get _targetZone =>
      _target == 'Ş' ? SibilantZone.sh : SibilantZone.s;

  @override
  void initState() {
    super.initState();
    _applyProfile();
  }

  void _applyProfile() {
    final p = Settings.instance.voiceProfile;
    _an = SibilantAnalyzer(
      sampleRate: _sampleRate,
      shMinHz: p.shMinHz,
      sMinHz: p.sMinHz,
    );
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  Future<void> _start() async {
    if (Stt.instance.isListening) await Stt.instance.cancel();
    final store = RecordingStore.instance;
    if (!await store.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mikrofon izni gerekli.')));
      }
      return;
    }
    _an.reset();
    final stream = await store.startPcmStream(sampleRate: _sampleRate);
    _sub = stream.listen((bytes) {
      final frames = _an.addPcm16(bytes);
      if (frames.isEmpty || !mounted) return;
      for (final f in frames) {
        final z = _an.zoneOf(f);
        if (z == SibilantZone.silence) {
          _history.add(null);
        } else {
          _smoothHz = _smoothHz == 0
              ? f.centroidHz
              : _smoothHz * 0.7 + f.centroidHz * 0.3;
          _history.add(_Point(f.centroidHz, z));
          _fricFrames++;
          if (z == _targetZone) _hitFrames++;
        }
        _zone = z;
        _level = f.levelDb;
      }
      while (_history.length > _historyLen) {
        _history.removeAt(0);
      }
      setState(() {});
    });
    setState(() => _running = true);
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    if (_running) await RecordingStore.instance.stopPcmStream();
    if (mounted) setState(() => _running = false);
  }

  void _resetScore() => setState(() {
    _fricFrames = 0;
    _hitFrames = 0;
    _history.clear();
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Settings.instance.voiceProfile;
    final secondsInTarget = _hitFrames * (_an.frameSize / 2) / _sampleRate;
    final ratio = _fricFrames == 0
        ? 0
        : (100 * _hitFrames / _fricFrames).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Tıslama ölçer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hedef sesi tek nefeste uzatarak söyle: “${_target == 'S' ? 'ssssss' : 'şşşşşş'}”. '
            'İbre renkli bölgede kalmaya çalışsın.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Hedef: '),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'S', label: Text('S / Z')),
                  ButtonSegment(value: 'Ş', label: Text('Ş')),
                ],
                selected: {_target},
                onSelectionChanged: (v) {
                  _target = v.first;
                  _resetScore();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<VoiceProfile>(
            initialValue: p,
            decoration: const InputDecoration(
              labelText: 'Ses profili',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final v in VoiceProfile.values)
                DropdownMenuItem(value: v, child: Text(v.label)),
            ],
            onChanged: (v) {
              if (v == null) return;
              Settings.instance.voiceProfile = v;
              setState(_applyProfile);
              _resetScore();
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 90,
            child: CustomPaint(
              painter: _GaugePainter(
                hz: _zone == SibilantZone.silence ? null : _smoothHz,
                shMin: _an.shMinHz,
                sMin: _an.sMinHz,
                target: _targetZone,
                textColor: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _HistoryPainter(
                history: List.of(_history),
                maxLen: _historyLen,
                shMin: _an.shMinHz,
                sMin: _an.sMinHz,
                grid: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.volume_down, size: 18),
              Expanded(
                child: LinearProgressIndicator(
                  value: ((_level + 70) / 70).clamp(0.0, 1.0),
                ),
              ),
              const Icon(Icons.volume_up, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat('Hedefte', '${secondsInTarget.toStringAsFixed(1)} sn'),
                  _Stat('İsabet', '%$ratio'),
                  _Stat('Şu an', switch (_zone) {
                    SibilantZone.silence => '—',
                    SibilantZone.low => 'kalın',
                    SibilantZone.sh => 'Ş',
                    SibilantZone.s => 'S',
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _running ? _stop : _start,
                  icon: Icon(_running ? Icons.stop : Icons.mic),
                  label: Text(_running ? 'Durdur' : 'Başlat'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _resetScore,
                child: const Text('Sıfırla'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Bu ölçer neyi gösterir, neyi göstermez?'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: const [
              Text(
                '• S sesinin enerjisi tiz frekanslarda (yaklaşık 5–9 kHz), Ş sesininki '
                'daha alçakta (yaklaşık 2,5–4,5 kHz) toplanır. Ölçer bu enerjinin '
                'ağırlık merkezini gösterir.\n'
                '• Yanal S (hava yanlardan kaçınca) çoğu zaman Ş bölgesine kayar; ölçer bunu iyi yakalar.\n'
                '• Dişler arası (peltek) S kısık ve yayvan çıkar ama her zaman düşük '
                'frekansta görünmez. Ölçer “S” dese bile kaydını dinlemeyi ve aynaya bakmayı unutma.\n'
                '• Telefonun mikrofonu, uzaklık ve ortam gürültüsü değerleri kaydırır. '
                'Ölçeri kendi en iyi denemenle kıyaslamak için kullan, not vermek için değil.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

const _maxHz = 10000.0;
const _lowColor = Color(0xFF9E9E9E);
const _shColor = Color(0xFF8E24AA);
const _sColor = Color(0xFF00897B);

Color _zoneColor(SibilantZone z) => switch (z) {
  SibilantZone.s => _sColor,
  SibilantZone.sh => _shColor,
  _ => _lowColor,
};

class _GaugePainter extends CustomPainter {
  final double? hz;
  final double shMin, sMin;
  final SibilantZone target;
  final Color textColor;

  _GaugePainter({
    required this.hz,
    required this.shMin,
    required this.sMin,
    required this.target,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double x(double f) => (f / _maxHz).clamp(0.0, 1.0) * size.width;
    const top = 24.0, h = 34.0;
    final zones = [
      (0.0, shMin, SibilantZone.low, 'kalın / yayvan'),
      (shMin, sMin, SibilantZone.sh, 'Ş'),
      (sMin, _maxHz, SibilantZone.s, 'S'),
    ];
    for (final z in zones) {
      final rect = Rect.fromLTRB(x(z.$1), top, x(z.$2), top + h);
      final isTarget = z.$3 == target;
      canvas.drawRect(
        rect,
        Paint()
          ..color = _zoneColor(z.$3).withValues(alpha: isTarget ? 0.85 : 0.3),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: z.$4,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isTarget ? 16 : 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
    for (final k in [0, 2, 4, 6, 8, 10]) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$k kHz',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: textColor,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final px = x(k * 1000.0);
      tp.paint(
        canvas,
        Offset(
          (px - tp.width / 2).clamp(0, size.width - tp.width),
          top + h + 4,
        ),
      );
    }
    if (hz != null) {
      final px = x(hz!);
      final needle = Paint()
        ..color = textColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(px, top - 14), Offset(px, top + h + 2), needle);
      canvas.drawCircle(Offset(px, top - 16), 6, Paint()..color = textColor);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.hz != hz || old.target != target || old.sMin != sMin;
}

class _HistoryPainter extends CustomPainter {
  final List<_Point?> history;
  final int maxLen;
  final double shMin, sMin;
  final Color grid;

  _HistoryPainter({
    required this.history,
    required this.maxLen,
    required this.shMin,
    required this.sMin,
    required this.grid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double y(double f) =>
        size.height - (f / _maxHz).clamp(0.0, 1.0) * size.height;
    canvas.drawRect(
      Rect.fromLTRB(0, y(_maxHz), size.width, y(sMin)),
      Paint()..color = _sColor.withValues(alpha: 0.08),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, y(sMin), size.width, y(shMin)),
      Paint()..color = _shColor.withValues(alpha: 0.08),
    );
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [shMin, sMin]) {
      canvas.drawLine(Offset(0, y(f)), Offset(size.width, y(f)), gridPaint);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = grid,
    );
    final dx = size.width / maxLen;
    final offset = maxLen - history.length;
    for (var i = 0; i < history.length; i++) {
      final p = history[i];
      if (p == null) continue;
      canvas.drawCircle(
        Offset((offset + i) * dx, y(p.hz)),
        2.5,
        Paint()..color = _zoneColor(p.zone),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
