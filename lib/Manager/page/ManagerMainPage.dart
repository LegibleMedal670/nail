import 'package:flutter/material.dart';

class ManagerMainPage extends StatefulWidget {
  const ManagerMainPage({super.key});

  @override
  State<ManagerMainPage> createState() => _ManagerMainPageState();
}

class _ManagerMainPageState extends State<ManagerMainPage> {
  // 공통 톤
  static const Color kTitleColor = Color.fromRGBO(34, 38, 49, 1);
  static const Color kPrimaryBlue = Color.fromRGBO(47, 130, 246, 1);
  static const Color kActionIconColor = Color.fromRGBO(176, 185, 193, 1); // AppBar action & 정렬 버튼

  // TODO: 실제 데이터로 치환
  final int totalMentees = 120;
  final int completedMentees = 84;
  final double avgScore = 86.5;       // 평가 완료 멘티 평균 점수
  final int waitingFinalReview = 13;  // 최종 관리자 평가 대기
  final int totalMentors = 18;

  int _currentIndex = 0;

  // ===== 멘티 현황 더미 데이터 ===== (null 허용)
  final List<_Mentee> _mentees = [
    _Mentee(
      name: '김지은',
      mentor: '박선생',
      progress: 0.75,
      startedAt: DateTime(2024, 8, 1),
      courseDone: 1,
      courseTotal: 3,
      examDone: 1,
      examTotal: 2,
    ),
    _Mentee(
      name: '이민지',
      mentor: '최선생',
      progress: 0.45,
      startedAt: DateTime(2024, 8, 14),
      courseDone: 1,
      courseTotal: 3,
      examDone: 0,
      examTotal: 2,
    ),
    _Mentee(
      name: '박소영',
      mentor: '박선생',
      progress: 0.90,
      startedAt: DateTime(2024, 7, 20),
      courseDone: 3,
      courseTotal: 3,
      examDone: 1,
      examTotal: 2,
    ),
    _Mentee(
      name: '정우혁',
      mentor: '김선생',
      progress: 0.32,
      startedAt: DateTime(2024, 9, 2),
    ),
    _Mentee(
      name: '문가영',
      mentor: '이선생',
      progress: 0.58,
      startedAt: DateTime(2024, 8, 22),
      courseDone: 2,
      courseTotal: 3,
      examDone: 0,
      examTotal: 2,
    ),
    _Mentee(
      name: '한지민',
      mentor: '장선생',
      progress: 0.12,
      startedAt: DateTime(2024, 9, 10),
    ),
    _Mentee(
      name: '오세훈',
      mentor: '박선생',
      progress: 0.83,
      startedAt: DateTime(2024, 6, 30),
      courseDone: 3,
      courseTotal: 3,
      examDone: 1,
      examTotal: 2,
    ),
    _Mentee(
      name: '윤성호',
      mentor: '김선생',
      progress: 0.67,
      startedAt: DateTime(2024, 8, 7),
      courseDone: 2,
      courseTotal: 3,
      examDone: 1,
      examTotal: 2,
    ),
  ];

  // 정렬
  _MenteeSort _sort = _MenteeSort.latest;

  // 확장: 하나만 열리도록 현재 열린 멘티 참조 저장
  _Mentee? _expandedMentee;

  // ===== 멘토 관리 탭용 더미 데이터 =====
  final List<int> _menteesPerMentor = [8, 7, 5, 10, 6, 5, 9, 7, 6, 4, 8, 7, 5, 6, 9, 8, 6, 4];
  final List<int> _pending7d  = [3, 5, 2, 4, 6, 3, 5]; // 최근 7일 “평가 대기” 수
  final List<int> _pending28d = [1,2,3,2,4,3,2, 5,4,3,6,3,2,5, 4,4,5,6,3,2,3, 5,4,6,5,4,3];
  bool _use7days = true;

  // ====== 계산 ======
  List<_Mentee> get _sortedMentees {
    final list = List<_Mentee>.from(_mentees);
    switch (_sort) {
      case _MenteeSort.latest:
        list.sort((a, b) => b.startedAt.compareTo(a.startedAt)); // 최근 시작일 우선
        break;
      case _MenteeSort.name:
        list.sort((a, b) => a.name.compareTo(b.name)); // 가나다
        break;
      case _MenteeSort.progress:
        list.sort((a, b) => b.progress.compareTo(a.progress)); // 진척도 높은 순
        break;
    }
    return list;
  }

  String _sortLabel(_MenteeSort s) {
    switch (s) {
      case _MenteeSort.latest:
        return '최신순';
      case _MenteeSort.name:
        return '가나다순';
      case _MenteeSort.progress:
        return '진척도순';
    }
  }

  // 멘토 관리 KPI 계산
  int get _totalMentors => _menteesPerMentor.length;
  int get _totalMenteesForMentorTab => _menteesPerMentor.fold(0, (a, b) => a + b);
  double get _avgPerMentor =>
      _totalMentors == 0 ? 0 : _totalMenteesForMentorTab / _totalMentors;
  int get _minPerMentor =>
      _menteesPerMentor.isEmpty ? 0 : _menteesPerMentor.reduce((a, b) => a < b ? a : b);
  int get _maxPerMentor =>
      _menteesPerMentor.isEmpty ? 0 : _menteesPerMentor.reduce((a, b) => a > b ? a : b);

  List<int> get _pendingSeries => _use7days ? _pending7d : _pending28d;

  double get _pendingChangeRate {
    final s = _pendingSeries;
    if (s.length < 2) return 0;
    final half = (s.length / 2).floor();
    final prev = s.take(half).fold<int>(0, (a, b) => a + b);
    final curr = s.skip(half).fold<int>(0, (a, b) => a + b);
    if (prev == 0) return curr == 0 ? 0 : 1.0;
    return (curr - prev) / prev;
  }

  Future<void> _showSortSheet() async {
    final result = await showModalBottomSheet<_MenteeSort>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SortBottomSheet(
        current: _sort,
        primaryBlue: kPrimaryBlue,
        titleColor: kTitleColor,
        actionIconColor: kActionIconColor,
      ),
    );
    if (result != null && mounted) {
      setState(() => _sort = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // (관리자 대시보드 상단 4 카드) 계산 값
    final completionRate = totalMentees == 0 ? 0.0 : (completedMentees / totalMentees * 100);
    final menteesPerMentor = totalMentors == 0 ? 0.0 : (totalMentees / totalMentors);

    // 각 탭 본문
    final pages = <Widget>[
      // 0. 관리자 대시보드
      SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ---- 상단 4 카드 ----
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.3,
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      _DashboardCard(
                        icon: Icons.school_outlined,
                        iconColor: kPrimaryBlue,
                        title: '교육 완료율',
                        value: '${completionRate.toStringAsFixed(0)}',
                        unit: '%',
                      ),
                      _DashboardCard(
                        icon: Icons.star_rate_rounded,
                        iconColor: kPrimaryBlue,
                        title: '평가 평균 점수',
                        value: '${avgScore.toStringAsFixed(0)}',
                        unit: '점',
                      ),
                      _DashboardCard(
                        icon: Icons.hourglass_bottom_rounded,
                        iconColor: kPrimaryBlue,
                        title: '최종 평가를 기다리는 멘티',
                        value: '$waitingFinalReview',
                        unit: '명',
                      ),
                      _DashboardCard(
                        icon: Icons.group_outlined,
                        iconColor: kPrimaryBlue,
                        title: '멘토 당 평균 멘티 수',
                        value: menteesPerMentor.toStringAsFixed(1),
                        unit: '명',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ---- 멘티 현황 헤더 + 정렬 버튼(바텀시트 호출) ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Text(
                      '멘티 현황',
                      style: TextStyle(
                        color: kTitleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showSortSheet,
                      icon: const Icon(Icons.keyboard_arrow_down_outlined, color: kActionIconColor, size: 18),
                      label: Text(
                        _sortLabel(_sort),
                        style: const TextStyle(
                          color: kActionIconColor, // AppBar 액션 아이콘과 동일
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        foregroundColor: kActionIconColor,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),

              // ---- 멘티 현황 리스트 (확장 타일) ----
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: ListView.separated(
                  itemCount: _sortedMentees.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = _sortedMentees[i];
                    final expanded = identical(_expandedMentee, m);
                    return _MenteeExpandableTile(
                      mentee: m,
                      expanded: expanded,
                      onToggle: () {
                        setState(() {
                          if (expanded) {
                            _expandedMentee = null;
                          } else {
                            _expandedMentee = m; // 단 하나만 열림
                          }
                        });
                      },
                      actionIconColor: kActionIconColor,
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),

      // 1. 멘토 관리 탭 (요약 2 + 트렌드 1)
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- 1행: KPI 2개 (그리드) ----
              SizedBox(
                height: 140,
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.3,
                  children: [
                    _MentorKpiCard(
                      icon: Icons.groups_2_outlined,
                      title: '총 멘토 수',
                      value: '$_totalMentors',
                      valueAccent: '명',
                    ),
                    _MentorKpiCard.rich(
                      icon: Icons.account_tree_outlined,
                      title: '멘토 당 평균 멘티 수',
                      rich: TextSpan(
                        text: _avgPerMentor.toStringAsFixed(1),
                        style: const TextStyle(
                          color: _ManagerMainPageState.kTitleColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.0, // 첫 줄 라인 높이
                        ),
                        children: [
                          const TextSpan(
                            text: ' 명\n', // ← 줄바꿈!
                            style: TextStyle(
                              color: _ManagerMainPageState.kPrimaryBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          TextSpan(
                            text: '(최소 $_minPerMentor · 최다 $_maxPerMentor)',
                            style: TextStyle(
                              color: _ManagerMainPageState.kTitleColor.withOpacity(0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.2, // 두 번째 줄 라인 높이
                            ),
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
              ),

              // ---- 2행: 전체폭 트렌드 카드 ----
              _MentorTrendCard(
                title: '평가 대기 멘티 (기간별)',
                subtitle: _use7days ? '최근 7일' : '최근 4주',
                series: _pendingSeries,
                positive: _pendingChangeRate >= 0,
                changePercent: (_pendingChangeRate * 100),
                onToggleRange: () => setState(() => _use7days = !_use7days),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Text(
                      '멘토 현황',
                      style: TextStyle(
                        color: kTitleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showSortSheet,
                      icon: const Icon(Icons.keyboard_arrow_down_outlined, color: kActionIconColor, size: 18),
                      label: Text(
                        _sortLabel(_sort),
                        style: const TextStyle(
                          color: kActionIconColor, // AppBar 액션 아이콘과 동일
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        foregroundColor: kActionIconColor,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // TODO: 여기 아래에 멘토 리스트/추가/삭제 UI 배치
            ],
          ),
        ),
      ),

      // 2. 멘티 관리 (플레이스홀더)
      const _PlaceholderTab(title: '멘티 관리'),

      // 3. 시험 관리 (플레이스홀더)
      const _PlaceholderTab(title: '시험 관리'),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        title: const Text(
          '관리자',
          style: TextStyle(
            color: kTitleColor,
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(
              Icons.person_add_alt_rounded,
              color: kActionIconColor,
              size: 28,
            ),
          ),
        ],
      ),

      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kPrimaryBlue,
        unselectedItemColor: const Color(0xFFB0B9C1),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
          BottomNavigationBarItem(icon: Icon(Icons.supervisor_account_outlined), label: '멘토 관리'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: '멘티 관리'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_outlined), label: '시험 관리'),
        ],
      ),
    );
  }
}

// ===== 정렬/모델 =====
enum _MenteeSort { latest, name, progress }

class _Mentee {
  final String name;
  final String mentor;
  final double progress; // 0.0 ~ 1.0
  final DateTime startedAt;
  final int? courseDone;   // null 허용
  final int? courseTotal;  // null 허용
  final int? examDone;     // null 허용
  final int? examTotal;    // null 허용
  final String? photoUrl;

  _Mentee({
    required this.name,
    required this.mentor,
    required this.progress,
    required this.startedAt,
    this.courseDone,
    this.courseTotal,
    this.examDone,
    this.examTotal,
    this.photoUrl,
  });
}

// ===== 바텀시트 (정렬 선택) =====
class _SortBottomSheet extends StatelessWidget {
  final _MenteeSort current;
  final Color primaryBlue;
  final Color titleColor;
  final Color actionIconColor;

  const _SortBottomSheet({
    required this.current,
    required this.primaryBlue,
    required this.titleColor,
    required this.actionIconColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget _item(_MenteeSort v, String label) {
      final selected = v == current;
      return InkWell(
        onTap: () => Navigator.of(context).pop<_MenteeSort>(v),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.check_rounded,
                size: 22,
                color: selected ? primaryBlue : const Color(0xFFD6DADF),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // 드래그 핸들
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE6EAF0),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          // 제목
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '정렬 선택',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 항목들
          _item(_MenteeSort.latest, '최신순'),
          _item(_MenteeSort.name, '가나다순'),
          _item(_MenteeSort.progress, '진척도순'),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ===== 공용 대시보드 카드 =====
class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? unit;

  const _DashboardCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    const titleColor = Color.fromRGBO(34, 38, 49, 1);
    const valueColor = Color.fromRGBO(34, 38, 49, 1);
    const unitBlue = Color.fromRGBO(47, 130, 246, 1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE6EAF0), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: valueColor,
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
                      color: unitBlue,
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

// ===== 멘토 관리: KPI 카드 =====
class _MentorKpiCard extends StatelessWidget {
  final IconData icon;
  final String title;

  // 단순 숫자 표기
  final String? value;
  final String? valueAccent;

  // RichText 표기
  final InlineSpan? rich;

  const _MentorKpiCard({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.valueAccent,
  }) : rich = null;

  const _MentorKpiCard.rich({
    super.key,
    required this.icon,
    required this.title,
    required this.rich,
  })  : value = null,
        valueAccent = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Icon(icon, color: _ManagerMainPageState.kPrimaryBlue, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: _ManagerMainPageState.kTitleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (rich != null)
            RichText(
              text: rich!,
              textAlign: TextAlign.left,
              maxLines: 2,           // 필요하면 2~3으로
              overflow: TextOverflow.ellipsis,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value ?? '',
                  style: const TextStyle(
                    color: _ManagerMainPageState.kTitleColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (valueAccent != null) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      valueAccent!,
                      style: const TextStyle(
                        color: _ManagerMainPageState.kPrimaryBlue,
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

// ===== 멘토 관리: 트렌드 카드 =====
class _MentorTrendCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<int> series; // 길이에 비례하여 막대 렌더
  final bool positive;
  final double changePercent;
  final VoidCallback onToggleRange;

  const _MentorTrendCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.series,
    required this.positive,
    required this.changePercent,
    required this.onToggleRange,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = (series.isEmpty) ? 1 : series.reduce((a, b) => a > b ? a : b);
    final color = positive ? Colors.green.shade600 : Colors.red.shade600;
    final sign = positive ? '+' : '−';
    final cp = changePercent.abs().toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6EAF0)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _ManagerMainPageState.kTitleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onToggleRange,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: _ManagerMainPageState.kActionIconColor),
                label: Text(
                  subtitle,
                  style: const TextStyle(
                    color: _ManagerMainPageState.kActionIconColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            ],
          ),
          const SizedBox(height: 8),

          // 변화율
          Row(
            children: [
              Icon(
                positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '$sign$cp%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 미니 스파크라인(막대)
          SizedBox(
            height: 42,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in series) ...[
                  Expanded(
                    child: Container(
                      height: (v / maxV) * 40.0 + 2, // 최소 2
                      decoration: BoxDecoration(
                        color: _ManagerMainPageState.kPrimaryBlue.withOpacity(0.85),
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
    );
  }
}

// ===== 멘티 확장 타일 =====
class _MenteeExpandableTile extends StatelessWidget {
  final _Mentee mentee;
  final bool expanded;
  final VoidCallback onToggle;
  final Color actionIconColor;

  const _MenteeExpandableTile({
    required this.mentee,
    required this.expanded,
    required this.onToggle,
    required this.actionIconColor,
  });

  Color _progressColor(double p) {
    if (p >= 0.8) return Colors.green.shade600;
    if (p >= 0.5) return const Color.fromRGBO(47, 130, 246, 1);
    return Colors.orange.shade600;
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
            border: Border.all(color: const Color(0xFFE6EAF0), width: 1),
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
              // ----- 헤더 행 -----
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
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

                  // 이름/멘토 + 진행바
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mentee.name,
                          style: const TextStyle(
                            color: _ManagerMainPageState.kTitleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mentee.mentor,
                          style: TextStyle(
                            color: _ManagerMainPageState.kTitleColor.withOpacity(0.6),
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
                        turns: expanded ? 0.5 : 0.0, // 180도 회전
                        duration: const Duration(milliseconds: 160),
                        child: Icon(Icons.expand_more, color: actionIconColor),
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

              // 구분선 (확장 시)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(height: 1, color: const Color(0xFFEFF2F6)),
                ),
                crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 160),
              ),

              // ----- 확장 내용 -----
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: courseColor,
                      ),
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: examColor,
                      ),
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

// ===== 플레이스홀더 탭 =====
class _PlaceholderTab extends StatelessWidget {
  final String title;
  const _PlaceholderTab({required this.title});

  @override
  Widget build(BuildContext context) {
    const Color kTitleColor = Color.fromRGBO(34, 38, 49, 1);
    return SafeArea(
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: kTitleColor,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
