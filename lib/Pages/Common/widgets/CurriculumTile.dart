import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';

/// 기존 디자인/호출을 100% 유지하면서,
/// - titleOverride / summaryOverride / badgesOverride / hideWeek
///   를 추가해 실습(Practice)도 같은 타일로 그릴 수 있게 확장.
/// - 실습 전용 팩토리: CurriculumTile.practice(...)
class CurriculumTile extends StatelessWidget {
  /// 기존 호출을 위한 본래 아이템 (이론 커리큘럼)
  /// *주의*: 실습 전용 팩토리로 만들 경우 null이어도 됨.
  final CurriculumItem? item;

  final VoidCallback? onTap;

  /// 실습 등 외부 데이터로 렌더링할 때 덮어쓸 수 있는 값들
  final String? titleOverride;
  final String? summaryOverride;
  final List<String>? badgesOverride;
  final bool hideWeek;

  const CurriculumTile({
    super.key,
    required this.item,
    this.onTap,
    this.titleOverride,
    this.summaryOverride,
    this.badgesOverride,
    this.hideWeek = false,
  });

  /// 실습 전용 팩토리
  factory CurriculumTile.practice({
    Key? key,
    required String title,
    String? summary,
    List<String>? badges,
    VoidCallback? onTap,
  }) {
    return CurriculumTile(
      key: key,
      item: null,
      onTap: onTap,
      titleOverride: title,
      summaryOverride: summary,
      badgesOverride: badges ?? const ['실습'],
      hideWeek: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = UiTokens.title;

    // 제목/요약/뱃지 계산 (override 우선)
    final String titleText = titleOverride ??
        (hideWeek ? (item?.title ?? '')
            : 'W${item?.week}. ${item?.title ?? ''}');

    final String summaryText = summaryOverride ?? (item?.summary ?? '');

    final List<String> badges = badgesOverride ??
        <String>[
          if (item?.hasVideo == true) '영상',
          if (item?.requiresExam == true) '시험',
        ];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: UiTokens.cardBorder, width: 1),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [UiTokens.cardShadow],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽: 본문
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: UiTokens.title,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 요약
                    if (summaryText.isNotEmpty) ...[
                      Text(
                        summaryText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else
                      const SizedBox(height: 10),

                    // 하단 메타: 뱃지들
                    Row(
                      children: [
                        for (final b in badges) ...[
                          _chip(b),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label) {
    final pink = const Color(0xFFE85D9C);
    IconData icon;
    switch (label) {
      case '영상':
        icon = Icons.videocam_outlined;
        break;
      case '시험':
        icon = Icons.task_alt_rounded;
        break;
      default:
        icon = Icons.local_offer_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: pink),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: pink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
