import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';

class MentorKpiCard extends StatelessWidget {
  final IconData icon;
  final String title;

  // 단순 숫자
  final String? value;
  final String? valueAccent;

  // RichText
  final InlineSpan? rich;

  const MentorKpiCard({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.valueAccent,
  }) : rich = null;

  const MentorKpiCard.rich({
    super.key,
    required this.icon,
    required this.title,
    required this.rich,
  })  : value = null,
        valueAccent = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UiTokens.cardBorder),
        boxShadow: const [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Icon(icon, color: UiTokens.primaryBlue, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: UiTokens.title,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (rich != null)
            RichText(
              text: rich!,
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value ?? '',
                  style: const TextStyle(
                    color: UiTokens.title,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (valueAccent != null) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      valueAccent!,
                      style: const TextStyle(
                        color: UiTokens.primaryBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
