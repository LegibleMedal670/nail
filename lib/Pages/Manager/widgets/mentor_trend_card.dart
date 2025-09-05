import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class MentorTrendCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<int> series; // 길이에 비례하여 막대 렌더
  final bool positive;
  final double changePercent;
  final VoidCallback onToggleRange;

  const MentorTrendCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.series,
    required this.positive,
    required this.changePercent,
    required this.onToggleRange,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = (series.isEmpty) ? 1 : series.reduce((a, b) => a > b ? a : b);
    final color = positive ? Colors.green.shade600 : Colors.red.shade600;
    final sign = positive ? '+' : '−';
    final cp = changePercent.abs().toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: UiTokens.title,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onToggleRange,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: UiTokens.actionIcon),
                label: Text(
                  subtitle,
                  style: const TextStyle(
                    color: UiTokens.actionIcon,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            ],
          ),
          const SizedBox(height: 8),

          // 변화율
          Row(
            children: [
              Icon(
                positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '$sign$cp%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 미니 스파크라인(막대)
          SizedBox(
            height: 42,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in series) ...[
                  Expanded(
                    child: Container(
                      height: (v / maxV) * 40.0 + 2,
                      decoration: BoxDecoration(
                        color: UiTokens.primaryBlue.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
