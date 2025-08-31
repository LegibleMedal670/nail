import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/models/mentor.dart';
import 'package:nail/Manager/widgets/MetricCard.dart';
import 'package:nail/Manager/widgets/mentor_tile.dart';
import 'package:nail/Manager/widgets/sort_bottom_sheet.dart';
import 'package:nail/Manager/page/mentor_edit_page.dart';

enum MentorSort { recentHire, name, menteeDesc, menteeAsc, fastGraduate, scoreDesc }

class MentorManageTab extends StatefulWidget {
  final List<int> menteesPerMentor;
  final List<int> pending7d;
  final List<int> pending28d;
  final List<Mentor> mentors; // 초기 리스트

  const MentorManageTab({
    super.key,
    required this.menteesPerMentor,
    required this.pending7d,
    required this.pending28d,
    required this.mentors,
  });

  @override
  State<MentorManageTab> createState() => _MentorManageTabState();
}

class _MentorManageTabState extends State<MentorManageTab> {
  // 내부에서 편집 반영할 수 있도록 상태 보유
  late List<Mentor> _mentors = List.of(widget.mentors);

  bool _use7days = true;
  MentorSort _sort = MentorSort.recentHire;

  // ===== KPI =====
  int get _totalMentors => widget.menteesPerMentor.length;
  int get _totalMentees => widget.menteesPerMentor.fold(0, (a, b) => a + b);
  double get _avgPerMentor => _totalMentors == 0 ? 0 : _totalMentees / _totalMentors;
  int get _minPerMentor => widget.menteesPerMentor.isEmpty
      ? 0
      : widget.menteesPerMentor.reduce((a, b) => a < b ? a : b);
  int get _maxPerMentor => widget.menteesPerMentor.isEmpty
      ? 0
      : widget.menteesPerMentor.reduce((a, b) => a > b ? a : b);

  List<int> get _series => _use7days ? widget.pending7d : widget.pending28d;

  double get _changeRate {
    final s = _series;
    if (s.length < 2) return 0;
    final half = (s.length / 2).floor();
    final prev = s.take(half).fold<int>(0, (a, b) => a + b);
    final curr = s.skip(half).fold<int>(0, (a, b) => a + b);
    if (prev == 0) return curr == 0 ? 0 : (curr > 0 ? 1.0 : 0);
    return (curr - prev) / prev;
  }

  // ===== 정렬 =====
  String _sortLabel(MentorSort s) => switch (s) {
    MentorSort.recentHire   => '최근 입사순',
    MentorSort.name         => '가나다순',
    MentorSort.menteeDesc   => '멘티수 많은순',
    MentorSort.menteeAsc    => '멘티수 적은순',
    MentorSort.fastGraduate => '평균 교육 기간 짧은순',
    MentorSort.scoreDesc    => '평균 점수 높은순',
  };

  List<Mentor> get _sortedMentors {
    final list = List<Mentor>.from(_mentors);
    int cmpNum(num a, num b) => a.compareTo(b);

    switch (_sort) {
      case MentorSort.recentHire:
        list.sort((a, b) => b.hiredAt.compareTo(a.hiredAt));
        break;
      case MentorSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case MentorSort.menteeDesc:
        list.sort((a, b) => cmpNum(b.menteeCount, a.menteeCount));
        break;
      case MentorSort.menteeAsc:
        list.sort((a, b) => cmpNum(a.menteeCount, b.menteeCount));
        break;
      case MentorSort.fastGraduate:
        list.sort((a, b) => cmpNum(a.avgGraduateDays, b.avgGraduateDays));
        break;
      case MentorSort.scoreDesc:
        list.sort((a, b) => cmpNum((b.avgScore ?? -1), (a.avgScore ?? -1)));
        break;
    }
    return list;
  }

  Future<void> _showSortSheet() async {
    final result = await showModalBottomSheet<MentorSort>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortBottomSheet<MentorSort>(
        title: '정렬 선택',
        current: _sort,
        options: const [
          SortOption(value: MentorSort.recentHire,   label: '최근 입사순',            icon: Icons.history_toggle_off),
          SortOption(value: MentorSort.name,         label: '가나다순',              icon: Icons.sort_by_alpha),
          SortOption(value: MentorSort.menteeDesc,   label: '멘티수 많은순',         icon: Icons.trending_up),
          SortOption(value: MentorSort.menteeAsc,    label: '멘티수 적은순',         icon: Icons.trending_down),
          SortOption(value: MentorSort.fastGraduate, label: '평균 교육 기간 짧은순', icon: Icons.speed_rounded),
          SortOption(value: MentorSort.scoreDesc,    label: '평균 점수 높은순',       icon: Icons.military_tech_rounded),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _sort = result);
  }

  // ===== 추가/편집/삭제 =====
  Future<void> _addMentor() async {
    final result = await Navigator.of(context).push<MentorEditResult>(
      MaterialPageRoute(builder: (_) => const MentorEditPage()),
    );
    if (result?.mentor != null) {
      setState(() => _mentors.add(result!.mentor!));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('멘토가 추가되었습니다.')));
    }
  }

  Future<void> _openEdit(Mentor m) async {
    final result = await Navigator.of(context).push<MentorEditResult>(
      MaterialPageRoute(builder: (_) => MentorEditPage(initial: m)),
    );
    if (result == null) return;

    if (result.deleted) {
      setState(() => _mentors.remove(m));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('멘토가 삭제되었습니다.')));
      return;
    }
    if (result.mentor != null) {
      final idx = _mentors.indexOf(m);
      if (idx != -1) setState(() => _mentors[idx] = result.mentor!);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = _changeRate >= 0 ? Colors.green.shade600 : Colors.red.shade600;
    final sign = _changeRate >= 0 ? '+' : '−';
    final cp = (_changeRate.abs() * 100).toStringAsFixed(0);

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_mentor_add',
        backgroundColor: UiTokens.primaryBlue,
        onPressed: _addMentor,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('추가'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI 2개
            SizedBox(
              height: 150,
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.3,
                children: [
                  MetricCard.simple(
                    icon: Icons.groups_2_outlined,
                    title: '총 멘토 수',
                    value: '$_totalMentors',
                    unit: '명',
                  ),
                  MetricCard.rich(
                    icon: Icons.account_tree_outlined,
                    title: '멘토 당 평균 멘티 수',
                    rich: TextSpan(
                      text: _avgPerMentor.toStringAsFixed(1),
                      style: const TextStyle(
                        color: UiTokens.title,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                      children: [
                        const TextSpan(
                          text: ' 명\n',
                          style: TextStyle(
                            color: UiTokens.primaryBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        TextSpan(
                          text: '(최소 $_minPerMentor · 최다 $_maxPerMentor)',
                          style: TextStyle(
                            color: UiTokens.title.withOpacity(0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 추세 카드
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: UiTokens.cardBorder),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [UiTokens.cardShadow],
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('평가 대기 멘티 (기간별)',
                            style: TextStyle(color: UiTokens.title, fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _use7days = !_use7days),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: UiTokens.actionIcon),
                        label: Text(_use7days ? '최근 7일' : '최근 4주',
                            style: const TextStyle(color: UiTokens.actionIcon, fontSize: 13, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(_changeRate >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: changeColor, size: 18),
                      const SizedBox(width: 6),
                      Text('$sign$cp%', style: TextStyle(color: changeColor, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final v in _series) ...[
                          Expanded(
                            child: Container(
                              height: (_series.isEmpty
                                  ? 0
                                  : (v / (_series.reduce((a, b) => a > b ? a : b))))
                                  * 40.0 +
                                  2,
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
            ),

            const SizedBox(height: 16),

            // 목록 헤더 + 정렬
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  const Text('멘토 목록',
                      style: TextStyle(color: UiTokens.title, fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showSortSheet,
                    icon: const Icon(Icons.keyboard_arrow_down_outlined, color: UiTokens.actionIcon, size: 18),
                    label: Text(_sortLabel(_sort),
                        style: const TextStyle(color: UiTokens.actionIcon, fontSize: 14, fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: const Size(0, 0),
                      foregroundColor: UiTokens.actionIcon,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            // 멘토 목록
            ListView.separated(
              itemCount: _sortedMentors.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final m = _sortedMentors[i];
                return MentorTile(mentor: m,);
              },
            ),
          ],
        ),
      ),
    );
  }
}

