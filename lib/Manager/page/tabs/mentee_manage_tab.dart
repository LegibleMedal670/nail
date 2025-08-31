import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/page/mentee_edit_page.dart';
import 'package:nail/Manager/widgets/MetricCard.dart';
import 'package:nail/Manager/widgets/sort_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/widgets/sort_bottom_sheet.dart';

/// 정렬 옵션
enum MenteeSort { latest, name, progress, lowScore }

/// 간단한 멘티 모델
class MenteeEntry {
  final String id;
  final String name;
  final String mentor; // '미배정' 또는 빈 문자열이면 미배정으로 간주
  final double progress; // 0.0 ~ 1.0
  final DateTime startedAt;
  final int? courseDone;
  final int? courseTotal;
  final int? examDone;
  final int? examTotal;
  final String? photoUrl;
  final double? score; // 평균/최신 평가 점수

  const MenteeEntry({
    required this.id,
    required this.name,
    required this.mentor,
    required this.progress,
    required this.startedAt,
    this.courseDone,
    this.courseTotal,
    this.examDone,
    this.examTotal,
    this.photoUrl,
    this.score,
  });

  MenteeEntry copyWith({
    String? id,
    String? name,
    String? mentor,
    double? progress,
    DateTime? startedAt,
    int? courseDone,
    int? courseTotal,
    int? examDone,
    int? examTotal,
    String? photoUrl,
    double? score,
  }) {
    return MenteeEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      mentor: mentor ?? this.mentor,
      progress: progress ?? this.progress,
      startedAt: startedAt ?? this.startedAt,
      courseDone: courseDone ?? this.courseDone,
      courseTotal: courseTotal ?? this.courseTotal,
      examDone: examDone ?? this.examDone,
      examTotal: examTotal ?? this.examTotal,
      photoUrl: photoUrl ?? this.photoUrl,
      score: score ?? this.score,
    );
  }
}

/// 데모 데이터
final List<MenteeEntry> kDemoMentees = [
  MenteeEntry(
    id: 'm001',
    name: '김지은',
    mentor: '박선생',
    progress: 0.75,
    startedAt: DateTime(2024, 8, 1),
    courseDone: 1, courseTotal: 3,
    examDone: 1, examTotal: 2,
    score: 82,
  ),
  MenteeEntry(
    id: 'm002',
    name: '이민지',
    mentor: '미배정',
    progress: 0.45,
    startedAt: DateTime(2024, 8, 14),
    courseDone: 1, courseTotal: 3,
    examDone: 0, examTotal: 2,
    score: 58,
  ),
  MenteeEntry(
    id: 'm003',
    name: '박소영',
    mentor: '박선생',
    progress: 0.90,
    startedAt: DateTime(2024, 7, 20),
    courseDone: 3, courseTotal: 3,
    examDone: 1, examTotal: 2,
    score: 93,
  ),
  MenteeEntry(
    id: 'm004',
    name: '정우혁',
    mentor: '김선생',
    progress: 0.32,
    startedAt: DateTime(2024, 9, 2),
    score: 64,
  ),
  MenteeEntry(
    id: 'm005',
    name: '문가영',
    mentor: '이선생',
    progress: 0.58,
    startedAt: DateTime(2024, 8, 22),
    courseDone: 2, courseTotal: 3,
    examDone: 0, examTotal: 2,
  ),
  MenteeEntry(
    id: 'm006',
    name: '한지민',
    mentor: '미배정',
    progress: 0.12,
    startedAt: DateTime(2024, 9, 10),
    score: 45,
  ),
  MenteeEntry(
    id: 'm007',
    name: '오세훈',
    mentor: '박선생',
    progress: 0.83,
    startedAt: DateTime(2024, 6, 30),
    courseDone: 3, courseTotal: 3,
    examDone: 1, examTotal: 2,
    score: 88,
  ),
  MenteeEntry(
    id: 'm008',
    name: '윤성호',
    mentor: '김선생',
    progress: 0.67,
    startedAt: DateTime(2024, 8, 7),
    courseDone: 2, courseTotal: 3,
    examDone: 1, examTotal: 2,
  ),
];

/// ===== 멘티 관리 탭 =====
class MenteeManageTab extends StatefulWidget {
  final List<MenteeEntry> mentees;
  MenteeManageTab({super.key, List<MenteeEntry>? mentees})
      : mentees = mentees ?? kDemoMentees;

  @override
  State<MenteeManageTab> createState() => _MenteeManageTabState();
}

class _MenteeManageTabState extends State<MenteeManageTab> {
  late List<MenteeEntry> _data; // ← 내부 상태로 보관 (추가 반영)
  MenteeSort _sort = MenteeSort.latest;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _data = List.of(widget.mentees);
  }

  // ===== KPI 계산 (_data 기준) =====
  int get _totalMentees => _data.length;

  int get _unassignedCount =>
      _data.where((m) => m.mentor.trim().isEmpty || m.mentor.trim() == '미배정').length;

  double get _avgScore {
    final scores = _data.map((m) => m.score).whereType<double>().toList();
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  double get _avgEducationDays {
    if (_data.isEmpty) return 0;
    final now = DateTime.now();
    final days = _data.map((m) => now.difference(m.startedAt).inDays).toList();
    return days.reduce((a, b) => a + b) / _data.length;
  }

  int get _keyPeopleCount {
    final now = DateTime.now();
    return _data.where((m) {
      final lowScore = (m.score ?? 101) < 60;
      final slow = now.difference(m.startedAt).inDays >= 21 && m.progress < 0.4;
      return lowScore || slow;
    }).length;
  }

  // ===== 정렬 =====
  String _sortLabel(MenteeSort s) => switch (s) {
    MenteeSort.latest => '최신 시작순',
    MenteeSort.name => '가나다순',
    MenteeSort.progress => '진척도순',
    MenteeSort.lowScore => '낮은 점수순',
  };

  List<MenteeEntry> get _sorted {
    final list = [..._data];
    int cmpNum(num a, num b) => a.compareTo(b);
    switch (_sort) {
      case MenteeSort.latest:
        list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        break;
      case MenteeSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case MenteeSort.progress:
        list.sort((a, b) => cmpNum(b.progress, a.progress));
        break;
      case MenteeSort.lowScore:
        list.sort((a, b) => cmpNum((a.score ?? 101), (b.score ?? 101)));
        break;
    }
    return list;
  }

  Future<void> _showSortSheet() async {
    final result = await showModalBottomSheet<MenteeSort>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SortBottomSheet<MenteeSort>(
        title: '정렬 선택',
        current: MenteeSort.latest, // dummy, 아래 onChanged로 덮어씀
        options: [
          SortOption(value: MenteeSort.latest, label: '최신 시작순', icon: Icons.history_toggle_off),
          SortOption(value: MenteeSort.name, label: '가나다순', icon: Icons.sort_by_alpha),
          SortOption(value: MenteeSort.progress, label: '진척도순', icon: Icons.trending_up),
          SortOption(value: MenteeSort.lowScore, label: '낮은 점수순', icon: Icons.sentiment_dissatisfied_outlined),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _sort = result);
  }

  // ===== 추가 버튼 처리 =====
  Future<void> _addMentee() async {
    final res = await Navigator.of(context).push<MenteeEditResult>(
      MaterialPageRoute(builder: (_) => const MenteeEditPage()),
    );
    if (res?.mentee != null) {
      setState(() {
        _data.insert(0, res!.mentee!);
        _expandedId = res.mentee!.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('멘티 "${res!.mentee!.name}" 추가됨')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_mentee_add',
        backgroundColor: UiTokens.primaryBlue,
        onPressed: _addMentee,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('추가'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 2×2 KPI 카드 =====
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.33,
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  MetricCard.rich(
                    icon: Icons.people_alt_outlined,
                    title: '총 멘티 수',
                    rich: TextSpan(
                      text: '$_totalMentees',
                      style: const TextStyle(
                          color: UiTokens.title, fontSize: 24, fontWeight: FontWeight.w800, height: 1.0),
                      children: [
                        const TextSpan(
                          text: ' 명',
                          style: TextStyle(
                              color: UiTokens.primaryBlue, fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
                        ),
                        TextSpan(
                          text: '\n미배정 $_unassignedCount명',
                          style: TextStyle(
                              color: UiTokens.title.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w700, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                  MetricCard.simple(icon: Icons.grade_outlined, title: '멘티 평균 점수', value: _avgScore.toStringAsFixed(0), unit: '점'),
                  MetricCard.simple(icon: Icons.hourglass_bottom_outlined, title: '최종 평가를 기다리는 멘티', value: '18', unit: '명'),
                  MetricCard.simple(icon: Icons.priority_high_rounded, title: '주요 인물', value: '$_keyPeopleCount', unit: '명'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ===== 목록 헤더 + 정렬 =====
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  const Text('멘티 목록', style: TextStyle(color: UiTokens.title, fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showSortSheet,
                    icon: const Icon(Icons.keyboard_arrow_down_outlined, color: UiTokens.actionIcon, size: 18),
                    label: Text(_sortLabel(_sort),
                        style: const TextStyle(color: UiTokens.actionIcon, fontSize: 14, fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      foregroundColor: UiTokens.actionIcon,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            // ===== 멘티 목록 =====
            ListView.separated(
              itemCount: _sorted.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final m = _sorted[i];
                final expanded = _expandedId == m.id;
                return MenteeExpandableTile(
                  mentee: m,
                  expanded: expanded,
                  onToggle: () {
                    setState(() => _expandedId = expanded ? null : m.id);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}




/// ===== (재활용 버전) 멘티 확장 타일 =====
/// 프로젝트에 동일 위젯이 이미 있다면 이 클래스를 제거하고 기존 위젯을 import 하세요.
class MenteeExpandableTile extends StatelessWidget {
  final MenteeEntry mentee;
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: UiTokens.cardBorder, width: 1),
            boxShadow: [UiTokens.cardShadow],
          ),
          child: Column(
            children: [
              // 헤더
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[400],
                    backgroundImage:
                    mentee.photoUrl != null ? NetworkImage(mentee.photoUrl!) : null,
                    child: mentee.photoUrl == null
                        ? Icon(Icons.person, color: cs.onSecondaryContainer)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // 이름/멘토/프로그레스
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
                          mentee.mentor.isEmpty ? '미배정' : mentee.mentor,
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
                  // 퍼센트 + 화살표
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

              // 구분선
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(height: 1, color: const Color(0xFFEFF2F6)),
                ),
                crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
                crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
    final courseColor = hasCourse ? UiTokens.primaryBlue : const Color(0xFF8C96A1);

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
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('교육 진행', style: chipTextStyle),
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
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('시험 결과', style: chipTextStyle),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '교육 진행: $courseLabel   •   시험 결과: $examLabel',
                style: const TextStyle(
                  color: Color(0xFF8C96A1),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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
