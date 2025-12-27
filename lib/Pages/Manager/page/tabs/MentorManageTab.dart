// lib/Pages/Manager/page/tabs/MentorManageTab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/mentor.dart';
import 'package:nail/Pages/Manager/page/MentorEditPage.dart';
import 'package:nail/Pages/Manager/widgets/MetricCard.dart';
import 'package:nail/Pages/Manager/widgets/MentorTile.dart';
import 'package:nail/Pages/Common/widgets/SortBottomSheet.dart';
import 'package:nail/Services/SupabaseService.dart';

// ✅ 관리자 세션 키를 읽기 위함
import 'package:nail/Providers/UserProvider.dart';

// ✅ 멘토 상세 Provider + Page
import 'package:nail/Providers/AdminMentorDetailProvider.dart';
import 'package:nail/Pages/Manager/page/MentorDetailPage.dart';

enum MentorSort { recentHire, name, menteeDesc, menteeAsc, fastGraduate }

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.adminListMentors(); // ✅ 서버 RPC
      final list = rows.map(Mentor.fromRow).toList();
      setState(() {
        _mentors = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '불러오기 실패: $e';
        _loading = false;
      });
    }
  }

  // KPI 계산
  int get _totalMentors => _mentors.length;

  int get _totalMentees => _mentors.fold(0, (a, b) => a + b.menteeCount);

  double get _avgPerMentor =>
      _totalMentors == 0 ? 0 : _totalMentees / _totalMentors;

  int get _minPerMentor =>
      _mentors.isEmpty
          ? 0
          : _mentors.map((m) => m.menteeCount).reduce((a, b) => a < b ? a : b);

  int get _maxPerMentor =>
      _mentors.isEmpty
          ? 0
          : _mentors.map((m) => m.menteeCount).reduce((a, b) => a > b ? a : b);

  // 정렬
  String _sortLabel(MentorSort s) => switch (s) {
    MentorSort.recentHire => '최근 등록순',
    MentorSort.name => '가나다순',
    MentorSort.menteeDesc => '멘티수 많은순',
    MentorSort.menteeAsc => '멘티수 적은순',
    MentorSort.fastGraduate => '평균 교육 기간 짧은순',
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
        list.sort(
              (a, b) => cmpNum(
            a.avgGraduateDays ?? (1 << 30),
            b.avgGraduateDays ?? (1 << 30),
          ),
        );
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
          SortOption(
            value: MentorSort.recentHire,
            label: '최근 등록순',
            icon: Icons.history_toggle_off,
          ),
          SortOption(
            value: MentorSort.name,
            label: '가나다순',
            icon: Icons.sort_by_alpha,
          ),
          SortOption(
            value: MentorSort.menteeDesc,
            label: '멘티수 많은순',
            icon: Icons.trending_up,
          ),
          SortOption(
            value: MentorSort.menteeAsc,
            label: '멘티수 적은순',
            icon: Icons.trending_down,
          ),
          SortOption(
            value: MentorSort.fastGraduate,
            label: '평균 교육 기간 짧은순',
            icon: Icons.speed_rounded,
          ),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _sort = result);
  }

  Future<void> _addMentor() async {
    final existing =
    _mentors.map((m) => m.accessCode).where((s) => s.isNotEmpty).toSet();
    final res = await Navigator.of(context).push<MentorEditResult>(
      MaterialPageRoute(
        builder: (_) => MentorEditPage(existingCodes: existing),
      ),
    );
    if (res?.mentor != null) {
      setState(() => _mentors.add(res!.mentor!));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('멘토가 추가되었습니다')));
    }
  }

  Future<void> _openDetail(Mentor m) async {
    final adminKey = context.read<UserProvider>().adminKey;
    if (adminKey == null || adminKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 인증이 필요합니다. 다시 로그인해 주세요.')),
      );
      return;
    }

    final ret = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => MentorDetailProvider(mentorId: m.id)..ensureLoaded(),
          child: MentorDetailPage(mentor: m),
        ),
      ),
    );

    // 삭제: bool true
    if (ret == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('멘토가 삭제되었습니다')));
      }
      return;
    }

    // 수정: Mentor 객체
    if (ret is Mentor) {
      final idx = _mentors.indexWhere((x) => x.id == ret.id);
      if (idx != -1) {
        setState(() => _mentors[idx] = ret); // ✅ 즉시 반영 (네트워크 호출 없음)
      }
      return;
    }

    // ret == null → 멘티 배정 등 변경이 있었을 수 있으므로 목록 갱신
    await _load();
  }

  // (기존) 편집 페이지 — 필요 시 유지
  Future<void> _openEdit(Mentor m) async {
    final existing = _mentors
        .where((x) => x.id != m.id)
        .map((x) => x.accessCode)
        .where((s) => s.isNotEmpty)
        .toSet();
    final res = await Navigator.of(context).push<MentorEditResult>(
      MaterialPageRoute(
        builder: (_) => MentorEditPage(initial: m, existingCodes: existing),
      ),
    );
    if (res == null) return;
    if (res.deleted) {
      setState(() => _mentors.removeWhere((x) => x.id == m.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('멘토가 삭제되었습니다')));
      return;
    }
    if (res.mentor != null) {
      final idx = _mentors.indexWhere((x) => x.id == m.id);
      if (idx != -1) setState(() => _mentors[idx] = res.mentor!);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('저장되었습니다')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _mentors.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _mentors.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: const TextStyle(
                  color: UiTokens.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(
                  backgroundColor: UiTokens.primaryBlue,
                ),
                child: const Text(
                  '다시 시도',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final list = _sorted;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: UiTokens.primaryBlue,
        // 당길 때 인디케이터 위치/감각 약간 개선
        displacement: 36,
        child: CustomScrollView(
          // ✅ 핵심: 단일 스크롤러 + AlwaysScrollable (리스트가 짧아도 당겨짐)
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                    // 섹션 구성:
                    // 0: KPI
                    // 1: spacer
                    // 2: header(멘토 목록 + 정렬)
                    // 3.. : empty or list items
                    // 마지막: tail spacer (pull 시 아래 잘림 체감 완화)
                    const headerCount = 3;

                    final bool isEmpty = list.isEmpty;
                    final int contentCount =
                    isEmpty ? 1 : (list.length * 2 - 1); // 타일+구분자
                    const int tailCount = 1;

                    final int totalCount = headerCount + contentCount + tailCount;

                    // ✅ 맨 마지막 Tail Spacer
                    if (index == totalCount - 1) {
                      return const SizedBox(height: 120);
                    }

                    if (index == 0) {
                      return _buildKpiGrid(ctx);
                    }
                    if (index == 1) {
                      return const SizedBox(height: 8);
                    }
                    if (index == 2) {
                      return _buildListHeader();
                    }

                    final int contentIndex = index - headerCount;

                    if (isEmpty) {
                      // contentCount == 1 이므로 contentIndex는 0만 들어옴
                      return _buildEmptyState();
                    }

                    // 리스트: 짝수=타일, 홀수=간격
                    if (contentIndex.isOdd) {
                      return const SizedBox(height: 10);
                    }

                    final int itemIndex = contentIndex ~/ 2;
                    final m = list[itemIndex];

                    return GestureDetector(
                      onTap: () => _openDetail(m), // ✅ 상세로 이동 (A안)
                      onLongPress: () => _openEdit(m), // (옵션) 롱프레스 시 편집
                      child: MentorTile(mentor: m),
                    );
                  },
                  // 전체 아이템 개수 지정
                  childCount: () {
                    const headerCount = 3;
                    final bool isEmpty = list.isEmpty;
                    final int contentCount =
                    isEmpty ? 1 : (list.length * 2 - 1);
                    const int tailCount = 1;
                    return headerCount + contentCount + tailCount;
                  }(),
                ),
              ),
            ),
          ],
        ),
      ),
      // 필요하면 다시 띄우세요 (현재는 기존 코드에 없어서 주석)
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _addMentor,
      //   backgroundColor: UiTokens.primaryBlue,
      //   child: const Icon(Icons.add),
      // ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          const Text(
            '멘토 목록',
            style: TextStyle(
              color: UiTokens.title,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _showSortSheet,
            icon: const Icon(
              Icons.filter_list_rounded,
              color: UiTokens.actionIcon,
              size: 18,
            ),
            label: Text(
              _sortLabel(_sort),
              style: const TextStyle(
                color: UiTokens.actionIcon,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 0),
              foregroundColor: UiTokens.actionIcon,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 빈 목록 상태 =====
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: UiTokens.title.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            '등록된 멘토가 없습니다',
            style: TextStyle(
              color: UiTokens.title.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '아래 버튼을 눌러 멘토를 추가해보세요',
            style: TextStyle(
              color: UiTokens.title.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ===== KPI Grid (내용 기반 높이 + 반응형 칼럼수) =====
  Widget _buildKpiGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;

        // 화면 폭에 따라 칼럼 수 조정
        final int crossAxisCount = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

        // ✅ 최신 API: TextScaler 기반 (textScaleFactor deprecated 회피)
        final scaler = MediaQuery.textScalerOf(ctx);
        final textScale = scaler.scale(1.0).clamp(1.0, 1.6);

        const baseTileHeight = 140.0;
        final tileHeight = baseTileHeight * textScale;

        return GridView(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(), // 바깥 스크롤에 위임
          shrinkWrap: true, // 내용만큼만 차지
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            mainAxisExtent: tileHeight, // 고정 높이로 안정화
          ),
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
        );
      },
    );
  }
}
