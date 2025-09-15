// lib/Pages/Manager/page/ManagerMainPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Common/model/CurriculumProgress.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/page/tabs/CurriculumManageTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MostProgressedMenteeTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MenteeManageTab.dart';
import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:nail/Services/AdminMenteeService.dart';
import 'package:provider/provider.dart';

class ManagerMainPage extends StatefulWidget {
  const ManagerMainPage({super.key});

  @override
  State<ManagerMainPage> createState() => _ManagerMainPageState();
}

class _ManagerMainPageState extends State<ManagerMainPage> {
  int _currentIndex = 0;

  bool _loadingTop = true;
  String? _errTop;
  Map<String, dynamic>? _topRow;

  List<CurriculumItem> _curriculum = const [];
  Set<String> _completed = const {};
  Map<String, double> _ratios = const {};
  Map<String, CurriculumProgress> _progressMap = const {};

  @override
  void initState() {
    super.initState();
    _loadTopMentee();
  }

  Future<void> _loadTopMentee() async {
    try {
      // 1) 상위 멘티 한 명
      final row = await AdminMenteeService.instance.fetchTopMenteeRow();
      if (row == null) {
        setState(() { _errTop = '데이터가 없습니다'; _loadingTop = false; });
        return;
      }

      // 2) 커리큘럼: 전역 Provider에서 (최신 보장)
      final cp = context.read<CurriculumProvider>();
      await cp.ensureLoaded();                 // 캐시→SWR
      if (cp.items.isEmpty) {
        await cp.refresh(force: true);         // 정말 없으면 강제 페치
      }
      final items = cp.items;                  // 정렬은 Provider가 week ASC로 이미 보장

      // 3) 진행도: RPC에서
      final loginKey = (row['login_key'] ?? '') as String;
      final prog = await AdminMenteeService.instance.fetchMenteeCourseData(loginKey);

      setState(() {
        _topRow = row;
        _curriculum = items;
        _completed = prog.completedIds;
        _ratios = prog.progressRatio;
        _progressMap = prog.progressMap;
        _loadingTop = false;
      });
    } catch (e) {
      setState(() { _errTop = e.toString(); _loadingTop = false; });
    }
  }


  Widget _buildTopMenteePage() {
    if (_loadingTop) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errTop != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('불러오기 실패: $_errTop'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loadTopMentee,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    final r = _topRow!;
    return MostProgressedMenteeTab(
      name: (r['nickname'] ?? '이름없음') as String,
      mentor: (r['mentor'] ?? '미배정') as String,
      startedAt: DateTime.tryParse((r['joined_at'] ?? '').toString()) ?? DateTime.now(),
      photoUrl: r['photo_url'] as String?,
      menteeUserId: (r['id'] ?? '') as String?,
      curriculum: _curriculum,          // ✅ Provider에서 온 “진짜” 커리큘럼
      completedIds: _completed,         // ✅ RPC 진행도/완료
      progressRatio: _ratios,           // ✅ RPC 진행도
      progressMap: _progressMap,
    );
  }

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
    BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: '멘티 관리'),
    BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_outlined), label: '교육 관리'),
  ];

  // 아래 더미 통계/대시보드는 그대로 두고, 커리큘럼 탭만 서버연동으로 바꿔요.
  final int totalMentees = 120;
  final int completedMentees = 84;
  final double avgScore = 86.5;
  final int waitingFinalReview = 13;
  final int totalMentors = 18;

  final List<int> menteesPerMentor = [8, 7, 5, 10, 6, 5, 9, 7, 6, 4, 8, 7, 5, 6, 9, 8, 6, 4];
  final List<int> pending7d  = [3, 5, 2, 4, 6, 3, 5];
  final List<int> pending28d = [1,2,3,2,4,3,2, 5,4,3,6,3,2,5, 4,4,5,6,3,2,3, 5,4,6,5,4,3];

  @override
  Widget build(BuildContext context) {
    final completionRate = totalMentees == 0 ? 0.0 : (completedMentees / totalMentees * 100);
    final menteesPerMentorAvg = totalMentors == 0 ? 0.0 : (totalMentees / totalMentors);

    final pages = <Widget>[
      _buildTopMenteePage(),     // <- 기존 더미 대신 서버 데이터 주입
      MenteeManageTab(),
      const CurriculumManageTab(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        title: Text(
          (_currentIndex == 0) ? '가장 진도가 빠른 신입' : _navItems[_currentIndex].label!,
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: UiTokens.primaryBlue,
        unselectedItemColor: const Color(0xFFB0B9C1),
        showUnselectedLabels: true,
        items: _navItems,
      ),
    );
  }
}
