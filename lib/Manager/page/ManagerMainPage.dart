import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/models/mentee.dart';
import 'package:nail/Manager/models/mentor.dart';
import 'package:nail/Manager/page/tabs/manager_dashboard_tab.dart';
import 'package:nail/Manager/page/tabs/mentor_manage_tab.dart';

class ManagerMainPage extends StatefulWidget {
  const ManagerMainPage({super.key});

  @override
  State<ManagerMainPage> createState() => _ManagerMainPageState();
}

class _ManagerMainPageState extends State<ManagerMainPage> {
  int _currentIndex = 0;

  // ---- 더미 데이터 (실데이터로 교체) ----
  final int totalMentees = 120;
  final int completedMentees = 84;
  final double avgScore = 86.5;
  final int waitingFinalReview = 13;
  final int totalMentors = 18;

  final List<Mentee> _mentees = [
    Mentee(name: '김지은', mentor: '박선생', progress: 0.75, startedAt: DateTime(2024, 8, 1), courseDone: 1, courseTotal: 3, examDone: 1, examTotal: 2),
    Mentee(name: '이민지', mentor: '최선생', progress: 0.45, startedAt: DateTime(2024, 8, 14), courseDone: 1, courseTotal: 3, examDone: 0, examTotal: 2),
    Mentee(name: '박소영', mentor: '박선생', progress: 0.90, startedAt: DateTime(2024, 7, 20), courseDone: 3, courseTotal: 3, examDone: 1, examTotal: 2),
    Mentee(name: '정우혁', mentor: '김선생', progress: 0.32, startedAt: DateTime(2024, 9, 2)),
    Mentee(name: '문가영', mentor: '이선생', progress: 0.58, startedAt: DateTime(2024, 8, 22), courseDone: 2, courseTotal: 3, examDone: 0, examTotal: 2),
    Mentee(name: '한지민', mentor: '장선생', progress: 0.12, startedAt: DateTime(2024, 9, 10)),
    Mentee(name: '오세훈', mentor: '박선생', progress: 0.83, startedAt: DateTime(2024, 6, 30), courseDone: 3, courseTotal: 3, examDone: 1, examTotal: 2),
    Mentee(name: '윤성호', mentor: '김선생', progress: 0.67, startedAt: DateTime(2024, 8, 7), courseDone: 2, courseTotal: 3, examDone: 1, examTotal: 2),
  ];

  final List<int> menteesPerMentor = [8, 7, 5, 10, 6, 5, 9, 7, 6, 4, 8, 7, 5, 6, 9, 8, 6, 4];
  final List<int> pending7d  = [3, 5, 2, 4, 6, 3, 5];
  final List<int> pending28d = [1,2,3,2,4,3,2, 5,4,3,6,3,2,5, 4,4,5,6,3,2,3, 5,4,6,5,4,3];

  @override
  Widget build(BuildContext context) {
    final completionRate = totalMentees == 0 ? 0.0 : (completedMentees / totalMentees * 100);
    final menteesPerMentorAvg = totalMentors == 0 ? 0.0 : (totalMentees / totalMentors);

    final pages = <Widget>[
      // 대시보드 탭
      ManagerDashboardTab(
        completionRate: completionRate,
        avgScore: avgScore,
        waitingFinalReview: waitingFinalReview,
        menteesPerMentor: menteesPerMentorAvg,
        mentees: _mentees,
      ),
      // 멘토 관리 탭
      MentorManageTab(
        menteesPerMentor: menteesPerMentor,
        pending7d: pending7d,
        pending28d: pending28d,
        mentors: kDemoMentors,
      ),
      // 임시 탭들 (멘티관리/시험관리)
      const _PlaceholderTab(title: '멘티 관리'),
      const _PlaceholderTab(title: '시험 관리'),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        title:  Text(
          '관리자',
          style: TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.person_add_alt_rounded, color: UiTokens.actionIcon, size: 28),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: UiTokens.primaryBlue,
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

class _PlaceholderTab extends StatelessWidget {
  final String title;
  const _PlaceholderTab({required this.title});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: UiTokens.title,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
