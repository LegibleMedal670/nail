// lib/Pages/Manager/page/ManagerMainPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/page/tabs/CurriculumManageTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MostProgressedMenteeTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MenteeManageTab.dart';

class ManagerMainPage extends StatefulWidget {
  const ManagerMainPage({super.key});

  @override
  State<ManagerMainPage> createState() => _ManagerMainPageState();
}

class _ManagerMainPageState extends State<ManagerMainPage> {
  int _currentIndex = 0;

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
      MostProgressedMenteeTab(
        name: '김순돌',
        startedAt: DateTime.now(),
        // ← 대시보드 데모는 그대로 둡니다. (차후 서버 연동)
        curriculum: const [],
        completedIds: const {},
        progressRatio: const {},
      ),
      MenteeManageTab(),
      // ✅ 하드코딩 제거 → 탭 내부에서 CurriculumProvider 사용
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
