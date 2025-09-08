import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import '../models/CurriculumItem.dart';

class CurriculumTile extends StatelessWidget {
  final CurriculumItem item;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const CurriculumTile({
    super.key,
    required this.item,
    this.onTap,
    this.onEdit,
  });

  String _mins(int m) => '${m}분';

  @override
  Widget build(BuildContext context) {
    final titleColor = UiTokens.title;

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
                    // 제목 (주차 + 제목)
                    Text(
                      'W${item.week}. ${item.title}',
                      style: const TextStyle(
                        color: UiTokens.title,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 요약
                    Text(
                      item.summary,
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
                    // 하단 메타: 시간, 뱃지들
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 16, color: UiTokens.actionIcon),
                        const SizedBox(width: 6),
                        // Text(
                        //   _mins(item.durationMinutes),
                        //   style: const TextStyle(
                        //     color: UiTokens.title,
                        //     fontSize: 13,
                        //     fontWeight: FontWeight.w700,
                        //   ),
                        // ),
                        const SizedBox(width: 10),
                        if (item.hasVideo) _chip('영상'),
                        if (item.requiresExam) ...[
                          const SizedBox(width: 6),
                          _chip('시험'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // // 오른쪽: 편집 아이콘
              // IconButton(
              //   onPressed: onEdit,
              //   icon: const Icon(Icons.edit_outlined, color: UiTokens.actionIcon),
              //   tooltip: '편집',
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label) {
    final pink = const Color(0xFFE85D9C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == '영상' ? Icons.videocam_outlined : Icons.task_alt_rounded,
            size: 14,
            color: pink,
          ),
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
