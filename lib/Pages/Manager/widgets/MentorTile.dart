import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/mentor.dart';

/// 선임 목록 타일 (프로필, 이름, 입사일, 후임수, 평균 졸업기간, 평균점수 뱃지)
class MentorTile extends StatelessWidget {
  final Mentor mentor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const MentorTile({
    super.key,
    required this.mentor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: UiTokens.cardBorder, width: 1),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [UiTokens.cardShadow],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey[400],
                backgroundImage:
                mentor.photoUrl != null ? NetworkImage(mentor.photoUrl!) : null,
                child: mentor.photoUrl == null
                    ? Icon(Icons.person, color: cs.onSecondaryContainer)
                    : null,
              ),
              const SizedBox(width: 12),

              // 본문
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 + 평균점수 배지(옵션)
                    Text(
                      mentor.name,
                      style: const TextStyle(
                        color: UiTokens.title,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 1행: 입사일 / 후임 수
                    Row(
                      children: [
                        _kv('입사일', _fmtDate(mentor.hiredAt)),
                        const SizedBox(width: 12),
                        _kv('후임', '${mentor.menteeCount}명'),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 2행: 평균 졸업기간 뱃지
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip(
                          label: '평균 교육 기간 ${mentor.avgGraduateDays ?? '-'}',
                          bg: const Color(0xFFE9F2FF),
                          fg: UiTokens.primaryBlue,
                        ),
                        // if (mentor.avgScore != null)
                        //   _chip(
                        //     label: '후임 평균 ${mentor.avgScore!.toStringAsFixed(0)}점',
                        //     bg: const Color(0xFFE9F2FF),
                        //     fg: UiTokens.primaryBlue,
                        //   ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // 우측 화살표(기본) 또는 외부에서 주입
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: UiTokens.actionIcon,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$k: ',
          style: TextStyle(
            color: UiTokens.title.withOpacity(0.55),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          v,
          style: const TextStyle(
            color: UiTokens.title,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
