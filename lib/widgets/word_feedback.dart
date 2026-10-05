import 'package:flutter/material.dart';

import '../utils/text_align.dart';

Color statusColor(WordStatus s) => switch (s) {
  WordStatus.correct => const Color(0xFF2E7D32),
  WordStatus.close => const Color(0xFFEF8F00),
  WordStatus.wrong => const Color(0xFFC62828),
  WordStatus.missed => const Color(0xFF9E9E9E),
};

/// Tanınan metnin hedef metinle karşılaştırmasını renkli gösterir.
class WordFeedback extends StatelessWidget {
  final AlignmentResult result;
  final String heard;

  const WordFeedback({super.key, required this.result, required this.heard});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortened = result.words.where((w) => w.shortened).toList();
    final subs = result.substitutions.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final w in result.words)
              Tooltip(
                message: w.status == WordStatus.missed
                    ? 'Duyulmadı'
                    : 'Duyulan: ${w.heard}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor(w.status).withValues(alpha: 0.12),
                    border: Border.all(color: statusColor(w.status)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    w.status == WordStatus.correct || w.heard == null
                        ? w.display
                        : '${w.display} → ${w.heard}',
                    style: TextStyle(
                      color: statusColor(w.status),
                      fontWeight: FontWeight.w600,
                      decoration: w.status == WordStatus.missed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Duyulan: “${heard.isEmpty ? '—' : heard}”',
          style: theme.textTheme.bodySmall,
        ),
        if (result.missedCount > 0)
          _hint(
            context,
            Icons.remove_circle_outline,
            '${result.missedCount} kelime duyulmadı (yutulmuş ya da çok hızlı/kısık söylenmiş olabilir).',
          ),
        for (final w in shortened)
          _hint(
            context,
            Icons.content_cut,
            '“${w.target}” kısa duyuldu: “${w.heard}”. Bir hece ya da ses yutulmuş olabilir.',
          ),
        if (subs.isNotEmpty)
          _hint(
            context,
            Icons.swap_horiz,
            'Harf farkları: ${subs.map((e) => e.value > 1 ? '${e.key} (${e.value})' : e.key).join(', ')}',
          ),
        if (result.accuracy == 1 && result.words.isNotEmpty)
          _hint(context, Icons.check_circle, 'Tüm kelimeler doğru duyuldu.'),
      ],
    );
  }

  Widget _hint(BuildContext context, IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// Dinleme sırasında gösterilen küçük ses düzeyi göstergesi.
class ListeningIndicator extends StatelessWidget {
  final double level;
  final String partial;

  const ListeningIndicator({
    super.key,
    required this.level,
    required this.partial,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.graphic_eq, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: level.clamp(0.0, 1.0)),
              const SizedBox(height: 4),
              Text(
                partial.isEmpty ? 'Dinliyorum…' : partial,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
