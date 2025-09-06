import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/Mentee.dart';
import 'package:nail/Pages/Manager/page/MenteeDetailPage.dart';
import 'package:nail/Pages/Manager/page/mentee_edit_page.dart';
import 'package:nail/Pages/Manager/widgets/MenteeSummaryTile.dart';
import 'package:nail/Pages/Manager/widgets/MetricCard.dart';
import 'package:nail/Pages/Manager/widgets/sort_bottom_sheet.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 정렬 옵션
enum MenteeSort { latest, name, progress, lowScore }

/// ===== 멘티 관리 탭 =====
class MenteeManageTab extends StatefulWidget {
  final List<Mentee> mentees;
  MenteeManageTab({super.key, List<Mentee>? mentees})
      : mentees = mentees ?? [];

  @override
  State<MenteeManageTab> createState() => _MenteeManageTabState();
}

class _MenteeManageTabState extends State<MenteeManageTab> {
  late List<Mentee> _data; // 내부 리스트 상태
  MenteeSort _sort = MenteeSort.latest;
  String? _expandedId;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = List.of(widget.mentees); // 초기엔 데모 보여주고
    _fetch(); // 서버 데이터로 교체
  }

  // ===== Supabase: 목록 가져오기 =====
  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.instance.listMentees();
      final list = rows.map(_menteeFromRow).toList();
      if (!mounted) return;
      setState(() {
        _data = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '불러오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Mentee _menteeFromRow(Map<String, dynamic> r) {
    return Mentee(
      id: r['id'] as String,
      name: r['nickname'] as String,
      mentor: (r['mentor'] as String?) ?? '미배정',
      startedAt: DateTime.parse(r['joined_at'] as String),
      photoUrl: r['photo_url'] as String?,
      accessCode: (r['login_key'] as String?) ?? '',
      // 아직 진행/시험 통계는 서버 미연동이므로 0으로 둔다
      progress: 0,
      courseDone: 0,
      courseTotal: 0,
      examDone: 0,
      examTotal: 0,
      score: null,
    );
  }

  Future<void> _onPullRefresh() => _fetch();

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

  List<Mentee> get _sorted {
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
      builder: (_) => SortBottomSheet<MenteeSort>(
        title: '정렬 선택',
        current: _sort,
        options: const [
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
    final existing = _data.map((m) => m.accessCode).where((s) => s.isNotEmpty).toSet();

    final res = await Navigator.of(context).push<MenteeEditResult>(
      MaterialPageRoute(builder: (_) => MenteeEditPage(existingCodes: existing)),
    );

    if (!mounted) return;
    if (res?.mentee != null) {
      await _fetch(); // 신뢰성 우선: 서버 재조회
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('멘티 "${res!.mentee!.name}" 추가됨')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : (_error != null
        ? Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!,
              style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _fetch,
            style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
            child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: _onPullRefresh,
      color: UiTokens.primaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                          color: UiTokens.title,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.0),
                      children: [
                        const TextSpan(
                          text: ' 명',
                          style: TextStyle(
                              color: UiTokens.primaryBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.2),
                        ),
                        TextSpan(
                          text: '\n미배정 $_unassignedCount명',
                          style: TextStyle(
                              color: UiTokens.title.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.2),
                        ),
                      ],
                    ),
                  ),
                  MetricCard.simple(
                      icon: Icons.grade_outlined,
                      title: '멘티 평균 점수',
                      value: _avgScore.toStringAsFixed(0),
                      unit: '점'),
                  MetricCard.simple(
                      icon: Icons.hourglass_bottom_outlined,
                      title: '최종 평가를 기다리는 멘티',
                      value: '18',
                      unit: '명'),
                  MetricCard.simple(
                      icon: Icons.priority_high_rounded,
                      title: '주요 인물',
                      value: '$_keyPeopleCount',
                      unit: '명'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ===== 목록 헤더 + 정렬 =====
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  const Text('멘티 목록',
                      style: TextStyle(
                          color: UiTokens.title,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showSortSheet,
                    icon: const Icon(Icons.filter_list_rounded,
                        color: UiTokens.actionIcon, size: 18),
                    label: Text(_sortLabel(_sort),
                        style: const TextStyle(
                            color: UiTokens.actionIcon,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

              // ⬇️ itemBuilder의 지역 context(아이템 컨텍스트)를 쓰지 않도록 변수명 변경
              itemBuilder: (itemCtx, i) {
                final m = _sorted[i];

                return MenteeSummaryTile(
                  mentee: m,
                  curriculum: const [],
                  watchRatio: {},
                  examMap: const {},

                  // ✅ 상세 페이지 결과 대기 후, 페이지의 context(this.context)만 사용
                  onDetail: () async {
                    final pageCtx = this.context; // State의 안정적인 컨텍스트

                    final res = await Navigator.of(pageCtx).push<MenteeEditResult?>(
                      MaterialPageRoute(builder: (_) => MenteeDetailPage.demoFromEntry(m)),
                    );

                    if (!mounted) return;

                    if (res?.deleted == true) {
                      await _fetch();
                      if (!mounted) return;
                      ScaffoldMessenger.of(pageCtx).showSnackBar(
                        const SnackBar(content: Text('멘티가 삭제되었습니다')),
                      );
                    } else if (res?.mentee != null) {
                      await _fetch();
                      if (!mounted) return;
                      // 필요하면 수정 완료 스낵바도 여기서 띄우면 됨
                      // ScaffoldMessenger.of(pageCtx).showSnackBar(
                      //   const SnackBar(content: Text('멘티 정보가 저장되었습니다')),
                      // );
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_mentee_add',
        backgroundColor: UiTokens.primaryBlue,
        onPressed: _addMentee,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('추가'),
      ),
      body: body,
    );
  }
}
