import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// 공용 메트릭 카드: 아이콘/제목/값(혹은 RichText)을 표기하는 카드
class MetricCard extends StatelessWidget {
  final String title;

  /// 아이콘을 쓰지 않고 완전 커스텀 리딩을 주고 싶으면 [leading]을 사용
  final IconData? icon;
  final Widget? leading;
  final Color iconColor;
  final double iconSize;

  /// 값 표기 방식 1: 단일 값 + 단위
  final String? value;
  final String? unit;

  /// 값 표기 방식 2: RichText (줄바꿈, 스타일 혼합 등)
  final InlineSpan? rich;

  final EdgeInsetsGeometry padding;

  const MetricCard._({
    required this.title,
    required this.icon,
    required this.leading,
    required this.iconColor,
    required this.iconSize,
    required this.value,
    required this.unit,
    required this.rich,
    required this.padding,
  });

  /// 값 + 단위 형태
  const MetricCard.simple({
    Key? key,
    required String title,
    IconData? icon,
    Color iconColor = UiTokens.primaryBlue,
    double iconSize = 24,
    Widget? leading,
    String? value,
    String? unit,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  }) : this._(
    title: title,
    icon: icon,
    leading: leading,
    iconColor: iconColor,
    iconSize: iconSize,
    value: value,
    unit: unit,
    rich: null,
    padding: padding,
  );

  /// RichText 형태
  const MetricCard.rich({
    Key? key,
    required String title,
    IconData? icon,
    Color iconColor = UiTokens.primaryBlue,
    double iconSize = 24,
    Widget? leading,
    required InlineSpan rich,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  }) : this._(
    title: title,
    icon: icon,
    leading: leading,
    iconColor: iconColor,
    iconSize: iconSize,
    value: null,
    unit: null,
    rich: rich,
    padding: padding,
  );

  @override
  Widget build(BuildContext context) {
    final lead = leading ??
        (icon != null ? Icon(icon, color: iconColor, size: iconSize) : null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [UiTokens.cardShadow], // <- const 붙이지 마세요(Opacity 등 포함 가능성)
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lead != null) ...[
            const SizedBox(height: 2),
            lead,
            const SizedBox(height: 8),
          ],
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: UiTokens.title,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const Spacer(),
          if (rich != null)
            RichText(text: rich!, textAlign: TextAlign.left)
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
                    letterSpacing: 0.2,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      unit!,
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
