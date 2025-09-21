import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/mentor.dart';
import 'package:nail/Pages/Manager/page/mentor_edit_page.dart';
import 'package:nail/Pages/Manager/widgets/MetricCard.dart';
import 'package:nail/Pages/Manager/widgets/mentor_tile.dart';
import 'package:nail/Pages/Manager/widgets/sort_bottom_sheet.dart';
import 'package:nail/Services/SupabaseService.dart';

enum MentorSort { recentHire, name, menteeDesc, menteeAsc, fastGraduate, scoreDesc }

class MentorManageTab extends StatefulWidget {
  const MentorManageTab({super.key});

  @override
  State<MentorManageTab> createState() => _MentorManageTabState();
}

class _MentorManageTabState extends State<MentorManageTab> {
  final _api = SupabaseService.instance;

  bool _loading = false;
  String? _error;
  List<Mentor> _mentors = [];

  MentorSort _sort = MentorSort.recentHire;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _api.adminListMentors(); // ✅ 새 API
      final list = rows.map(Mentor.fromRow).toList();
      setState(() { _mentors = list; _loading = false; });
    } catch (e) {
      setState(() { _error = '불러오기 실패: $e'; _loading = false; });
    }
  }

  // KPI 계산
  int get _totalMentors => _mentors.length;
  int get _totalMentees => _mentors.fold(0, (a, b) => a + b.menteeCount);
  double get _avgPerMentor => _totalMentors == 0 ? 0 : _totalMentees / _totalMentors;
  int get _minPerMentor => _mentors.isEmpty ? 0 : _mentors.map((m) => m.menteeCount).reduce((a, b) => a < b ? a : b);
  int get _maxPerMentor => _mentors.isEmpty ? 0 : _mentors.map((m) => m.menteeCount).reduce((a, b) => a > b ? a : b);


  // 정렬
  String _sortLabel(MentorSort s) => switch (s) {
    MentorSort.recentHire   => '최근 등록순',
    MentorSort.name         => '가나다순',
    MentorSort.menteeDesc   => '멘티수 많은순',
    MentorSort.menteeAsc    => '멘티수 적은순',
    MentorSort.fastGraduate => '평균 교육 기간 짧은순',
    MentorSort.scoreDesc    => '평균 점수 높은순',
  };

  List<Mentor> get _sorted {
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
        list.sort((a, b) => cmpNum(a.avgGraduateDays ?? 1<<30, b.avgGraduateDays ?? 1<<30));
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
          SortOption(value: MentorSort.recentHire,   label: '최근 등록순',          icon: Icons.history_toggle_off),
          SortOption(value: MentorSort.name,         label: '가나다순',            icon: Icons.sort_by_alpha),
          SortOption(value: MentorSort.menteeDesc,   label: '멘티수 많은순',       icon: Icons.trending_up),
          SortOption(value: MentorSort.menteeAsc,    label: '멘티수 적은순',       icon: Icons.trending_down),
          SortOption(value: MentorSort.fastGraduate, label: '평균 교육 기간 짧은순', icon: Icons.speed_rounded),
          SortOption(value: MentorSort.scoreDesc,    label: '평균 점수 높은순',     icon: Icons.military_tech_rounded),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _sort = result);
  }

  Future<void> _addMentor() async {
    final existing = _mentors.map((m) => m.accessCode).where((s) => s.isNotEmpty).toSet();
    final res = await Navigator.of(context).push<MentorEditResult>(
      MaterialPageRoute(builder: (_) => MentorEditPage(existingCodes: existing)),
    );
    if (res?.mentor != null) {
      setState(() => _mentors.add(res!.mentor!));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('멘토가 추가되었습니다')));
    }
  }

  Future<void> _openEdit(Mentor m) async {
    final existing = _mentors
        .where((x) => x.id != m.id)
        .map((x) => x.accessCode)
        .where((s) => s.isNotEmpty)
        .toSet();
    final res = await Navigator.of(context).push<MentorEditResult>(
      MaterialPageRoute(builder: (_) => MentorEditPage(initial: m, existingCodes: existing)),
    );
    if (res == null) return;
    if (res.deleted) {
      setState(() => _mentors.removeWhere((x) => x.id == m.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('멘토가 삭제되었습니다')));
      return;
    }
    if (res.mentor != null) {
      final idx = _mentors.indexWhere((x) => x.id == m.id);
      if (idx != -1) setState(() => _mentors[idx] = res.mentor!);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _mentors.isEmpty) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _mentors.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
              child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      );
    }

    final list = _sorted;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_mentor_add',
        backgroundColor: UiTokens.primaryBlue,
        onPressed: _addMentor,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('추가'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: UiTokens.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI
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
                            color: UiTokens.title, fontSize: 24, fontWeight: FontWeight.w800, height: 1.0),
                        children: [
                          const TextSpan(
                            text: ' 명\n',
                            style: TextStyle(color: UiTokens.primaryBlue, fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
                          ),
                          TextSpan(
                            text: '(최소 $_minPerMentor · 최다 $_maxPerMentor)',
                            style: TextStyle(color: UiTokens.title.withOpacity(0.55), fontSize: 12, fontWeight: FontWeight.w700, height: 1.2),
                          ),
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
                child: Row(children: [
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
                ]),
              ),

              // 멘토 목록
              ListView.separated(
                itemCount: list.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final m = list[i];
                  return GestureDetector(
                    onTap: () => _openEdit(m),
                    child: MentorTile(mentor: m),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
