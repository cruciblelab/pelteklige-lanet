import 'package:flutter/material.dart';

import 'articulation_motion.dart';
import 'articulations.dart';
import 'front_painter.dart';
import 'sagittal_painter.dart';

export 'articulation_motion.dart' show stepAt;
export 'sagittal_painter.dart' show ArticulationPainter;

enum CompareMode { correct, error, both }

/// Ağız yan kesiti animasyonu: dil, damak, dişler, dudaklar, hava akışı,
/// ses telleri ve temas anı. İsteğe bağlı olarak kişinin hatası doğrusunun
/// üstüne "hayalet" olarak çizilir.
class ArticulationView extends StatefulWidget {
  final String correct;
  final String? error;
  final String? errorTitle;
  final bool labels;
  final bool controls;

  const ArticulationView({
    super.key,
    required this.correct,
    this.error,
    this.errorTitle,
    this.labels = true,
    this.controls = true,
  });

  @override
  State<ArticulationView> createState() => _ArticulationViewState();
}

class _ArticulationViewState extends State<ArticulationView>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 3200);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _cycle,
  )..repeat();
  bool _slow = false;

  /// Önden (ayna) görünüm: kişi aynada kendi ağzıyla karşılaştırabilir.
  bool _front = false;
  late bool _labels = widget.labels;
  late CompareMode _mode = widget.error == null
      ? CompareMode.correct
      : CompareMode.both;

  @override
  void didUpdateWidget(ArticulationView old) {
    super.didUpdateWidget(old);
    if (old.error != widget.error) {
      _mode = widget.error == null ? CompareMode.correct : CompareMode.both;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _togglePlay() => setState(() {
    if (_c.isAnimating) {
      _c.stop();
    } else {
      _c.repeat();
    }
  });

  void _toggleSlow() => setState(() {
    _slow = !_slow;
    _c.duration = _slow ? _cycle * 2.5 : _cycle;
    if (_c.isAnimating) _c.repeat();
  });

  Articulation get _main =>
      articulations[_mode == CompareMode.error
          ? widget.error!
          : widget.correct]!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: articulationPainter(
                    front: _front,
                    t: _c.value,
                    main: _main,
                    ghost: _mode == CompareMode.both && hasError
                        ? articulations[widget.error!]
                        : null,
                    mainIsError: _mode == CompareMode.error,
                    labels: _labels,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final step = stepAt(_main.motion, _c.value);
            return _StepCaption(
              step: step,
              text: _main.steps[step],
              color: _mode == CompareMode.error
                  ? const Color(0xFFD84343)
                  : theme.colorScheme.primary,
            );
          },
        ),
        if (widget.controls) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: _c.isAnimating ? 'Durdur' : 'Oynat',
                onPressed: _togglePlay,
                icon: Icon(_c.isAnimating ? Icons.pause : Icons.play_arrow),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: false, label: Text('Yandan')),
                  ButtonSegment(value: true, label: Text('Önden')),
                ],
                selected: {_front},
                onSelectionChanged: (v) => setState(() => _front = v.first),
              ),
              FilterChip(
                label: const Text('Yavaş'),
                selected: _slow,
                onSelected: (_) => _toggleSlow(),
              ),
              FilterChip(
                label: const Text('Adlar'),
                selected: _labels,
                onSelected: (v) => setState(() => _labels = v),
              ),
            ],
          ),
          if (_front)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Aynada kendi ağzınla karşılaştır: dil ucunun nereye gittiğini '
                've dudaklarını görebilirsin.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (hasError) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<CompareMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: CompareMode.correct,
                    label: Text('Doğrusu'),
                  ),
                  ButtonSegment(value: CompareMode.error, label: Text('Senin')),
                  ButtonSegment(
                    value: CompareMode.both,
                    label: Text('Üst üste'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
            ),
          ],
          if (hasError && _mode == CompareMode.both)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  _legendDot(theme.colorScheme.primary),
                  const Text(' doğrusu   '),
                  _legendDot(const Color(0xFFD84343), dashed: true),
                  Flexible(
                    child: Text(
                      ' senin (${widget.errorTitle ?? 'hata'})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _legendDot(Color c, {bool dashed = false}) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: dashed ? Colors.transparent : c,
      border: Border.all(color: c, width: 2),
    ),
  );
}

class _StepCaption extends StatelessWidget {
  final int step;
  final String text;
  final Color color;

  const _StepCaption({
    required this.step,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 4),
            width: i == step ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == step ? color : color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
            child: Text(
              '${step + 1}. $text',
              key: ValueKey(text),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
      ],
    );
  }
}

/// Animasyonun tek bir karesi (küçük önizlemeler ve görsel testler için).
class ArticulationStill extends StatelessWidget {
  final String correct;
  final String? error;
  final double t;
  final bool labels;
  final bool showError;

  /// Yan kesit yerine önden (ayna) görünüm.
  final bool front;

  const ArticulationStill({
    super.key,
    required this.correct,
    this.error,
    required this.t,
    this.labels = false,
    this.showError = false,
    this.front = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          painter: articulationPainter(
            front: front,
            t: t,
            main: articulations[showError ? error! : correct]!,
            ghost: !showError && error != null ? articulations[error!] : null,
            mainIsError: showError,
            labels: labels,
          ),
        ),
      ),
    );
  }
}

/// Seçilen görünüme göre çizici.
CustomPainter articulationPainter({
  required bool front,
  required double t,
  required Articulation main,
  required Articulation? ghost,
  required bool mainIsError,
  required bool labels,
}) => front
    ? MouthFrontPainter(
        t: t,
        main: main,
        ghost: ghost,
        mainIsError: mainIsError,
        labels: labels,
      )
    : ArticulationPainter(
        t: t,
        main: main,
        ghost: ghost,
        mainIsError: mainIsError,
        labels: labels,
      );
