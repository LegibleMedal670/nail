import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/models/mentee.dart';

class MenteeExpandableTile extends StatelessWidget {
  final Mentee mentee;
  final bool expanded;
  final VoidCallback onToggle;

  const MenteeExpandableTile({
    super.key,
    required this.mentee,
    required this.expanded,
    required this.onToggle,
  });

  Color _progressColor(double p) {
    if (p >= 0.8) return Colors.green.shade600;
    if (p >= 0.5) return UiTokens.primaryBlue;
    return Colors.orange.shade600;
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final barColor = _progressColor(mentee.progress);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: UiTokens.cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF101828).withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            color: Colors.white,
          ),
          child: Column(
            children: [
              // 헤더
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[400],
                    backgroundImage: mentee.photoUrl != null ? NetworkImage(mentee.photoUrl!) : null,
                    child: mentee.photoUrl == null
                        ? Icon(Icons.person, color: cs.onSecondaryContainer)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mentee.name,
                          style: const TextStyle(
                            color: UiTokens.title,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mentee.mentor,
                          style: TextStyle(
                            color: UiTokens.title.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: mentee.progress,
                            backgroundColor: const Color(0xFFE7ECF3),
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 160),
                        child: const Icon(Icons.expand_more, color: UiTokens.actionIcon),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(mentee.progress * 100).round()}%',
                        style: TextStyle(
                          color: barColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Divider (expanded only)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(height: 1, color: const Color(0xFFEFF2F6)),
                ),
                crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 160),
              ),

              // 확장 내용
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _ExpandedDetail(
                  courseDone: mentee.courseDone ?? 0,
                  courseTotal: mentee.courseTotal ?? 0,
                  examDone: mentee.examDone ?? 0,
                  examTotal: mentee.examTotal ?? 0,
                  startDateText: _fmtDate(mentee.startedAt),
                  onDetail: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${mentee.name} 상세보기')),
                    );
                  },
                ),
                crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 160),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedDetail extends StatelessWidget {
  final int courseDone;
  final int courseTotal;
  final int examDone;
  final int examTotal;
  final String startDateText;
  final VoidCallback onDetail;

  const _ExpandedDetail({
    required this.courseDone,
    required this.courseTotal,
    required this.examDone,
    required this.examTotal,
    required this.startDateText,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final hasCourse = courseTotal > 0;
    final hasExam = examTotal > 0;

    final courseLabel = hasCourse ? '$courseDone/$courseTotal 완료' : '미정';
    final courseColor = hasCourse ? const Color(0xFF2F82F6) : const Color(0xFF8C96A1);

    final examLabel = hasExam ? '$examDone/$examTotal 완료' : '미정';
    final examColor = hasExam ? Colors.green.shade700 : const Color(0xFF8C96A1);

    const chipTextStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('교육 진행', style: chipTextStyle),
                    const SizedBox(height: 4),
                    Text(
                      courseLabel,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: courseColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('시험 결과', style: chipTextStyle),
                    const SizedBox(height: 4),
                    Text(
                      examLabel,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: examColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '시작일: $startDateText',
                style: const TextStyle(
                  color: Color(0xFF8C96A1),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              onPressed: onDetail,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                backgroundColor: const Color(0xFFE85D9C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text(
                '상세보기',
                style: TextStyle(
                  color: Color(0xFFFFFDFE),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
