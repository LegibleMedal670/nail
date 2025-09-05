import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/curriculum_item.dart';
import 'package:nail/Pages/Manager/models/mentee.dart';
import 'package:nail/Pages/Manager/page/tabs/CurriculumManageTab.dart';
import 'package:nail/Pages/Manager/page/tabs/manager_dashboard_tab.dart';
import 'package:nail/Pages/Manager/page/tabs/mentee_manage_tab.dart';

class ManagerMainPage extends StatefulWidget {
  const ManagerMainPage({super.key});

  @override
  State<ManagerMainPage> createState() => _ManagerMainPageState();
}

class _ManagerMainPageState extends State<ManagerMainPage> {
  int _currentIndex = 0;

  // 🔽 바텀내비 항목을 한 곳에서 관리
  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
    // BottomNavigationBarItem(icon: Icon(Icons.supervisor_account_outlined), label: '멘토 관리'),
    BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: '멘티 관리'),
    BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_outlined), label: '교육 관리'),
  ];

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
      // ManagerDashboardTab(
      //   completionRate: completionRate,
      //   avgScore: avgScore,
      //   waitingFinalReview: waitingFinalReview,
      //   menteesPerMentor: menteesPerMentorAvg,
      //   mentees: _mentees,
      // ),
      MostProgressedMenteeTab(
        name: '김순돌',
        startedAt: DateTime.now(),
        curriculum: [
          CurriculumItem(id: 'w01', week: 1, title: '네일아트 기초 교육', summary: '도구 소개, 위생, 손톱 구조 이해', durationMinutes: 60, hasVideo: true,  requiresExam: false),
          CurriculumItem(id: 'w02', week: 2, title: '케어 기본', summary: '큐티클 정리, 파일링, 샌딩', durationMinutes: 75, hasVideo: true,  requiresExam: false),
          CurriculumItem(id: 'w03', week: 3, title: '베이스 코트 & 컬러 올리기', summary: '균일한 도포, 번짐 방지 요령', durationMinutes: 90, hasVideo: true,  requiresExam: true),
          CurriculumItem(id: 'w04', week: 4, title: '마감재 사용법', summary: '탑젤/매트탑, 경화 시간', durationMinutes: 60, hasVideo: true,  requiresExam: false),
          CurriculumItem(id: 'w05', week: 5, title: '간단 아트 1', summary: '도트, 스트라이프, 그라데이션', durationMinutes: 80, hasVideo: true,  requiresExam: false),
          CurriculumItem(id: 'w06', week: 6, title: '간단 아트 2', summary: '프렌치, 마블 기초', durationMinutes: 80, hasVideo: true,  requiresExam: true),
          CurriculumItem(id: 'w07', week: 7, title: '젤 오프 & 재시술', summary: '안전한 오프, 손상 최소화', durationMinutes: 50, hasVideo: true,  requiresExam: false),
          CurriculumItem(id: 'w08', week: 8, title: '손 위생/살롱 위생 표준', summary: '소독 루틴, 위생 체크리스트', durationMinutes: 45, hasVideo: false, requiresExam: false),
          CurriculumItem(id: 'w09', week: 9, title: '고객 응대 매뉴얼', summary: '예약/상담/클레임 응대', durationMinutes: 60, hasVideo: false, requiresExam: true),
          CurriculumItem(id: 'w10', week:10, title: '트러블 케이스', summary: '리프트/파손/알러지 예방과 대응', durationMinutes: 70, hasVideo: true,  requiresExam: false),
          CurriculumItem(id: 'w11', week:11, title: '젤 연장 기초', summary: '폼, 팁, 쉐입 만들기', durationMinutes: 90, hasVideo: true,  requiresExam: true),
          CurriculumItem(id: 'w12', week:12, title: '아트 심화', summary: '스톤, 파츠, 믹스미디어', durationMinutes: 95, hasVideo: true,  requiresExam: false),
          CurriculumItem(id: 'w13', week:13, title: '시술 시간 단축 팁', summary: '동선/세팅 최적화, 체크리스트', durationMinutes: 40, hasVideo: false, requiresExam: false),
          CurriculumItem(id: 'w14', week:14, title: '종합 점검 & 모의평가', summary: '전 과정 복습, 취약 파트 점검', durationMinutes: 120, hasVideo: true, requiresExam: true),
        ],
        completedIds: {'w01', 'w02',}, // 임의 완료
        progressRatio: {
          'w03': 0.2, // 20% 시청 중
        },
      ),
      // 멘토 관리 탭
      // MentorManageTab(
      //   menteesPerMentor: menteesPerMentor,
      //   pending7d: pending7d,
      //   pending28d: pending28d,
      //   mentors: kDemoMentors,
      // ),
      MenteeManageTab(),
      CurriculumManageTab(
        items: [
          CurriculumItem(
            id: 'w01',
            week: 1,
            title: '네일아트 기초 교육',
            summary: '도구 소개, 위생, 손톱 구조 이해',
            durationMinutes: 60,
            hasVideo: true,
            requiresExam: false,
          ),
          CurriculumItem(
            id: 'w02',
            week: 2,
            title: '케어 기본',
            summary: '큐티클 정리, 파일링, 샌딩',
            durationMinutes: 75,
            hasVideo: true,
            requiresExam: false,
          ),
          CurriculumItem(
            id: 'w03',
            week: 3,
            title: '베이스 코트 & 컬러 올리기',
            summary: '균일한 도포, 번짐 방지 요령',
            durationMinutes: 90,
            hasVideo: true,
            requiresExam: true,
          ),
          CurriculumItem(
            id: 'w04',
            week: 4,
            title: '마감재 사용법',
            summary: '탑젤/매트탑, 경화 시간',
            durationMinutes: 60,
            hasVideo: true,
            requiresExam: false,
          ),
          CurriculumItem(
            id: 'w05',
            week: 5,
            title: '간단 아트 1',
            summary: '도트, 스트라이프, 그라데이션',
            durationMinutes: 80,
            hasVideo: true,
            requiresExam: false,
          ),
          CurriculumItem(
            id: 'w06',
            week: 6,
            title: '간단 아트 2',
            summary: '프렌치, 마블 기초',
            durationMinutes: 80,
            hasVideo: true,
            requiresExam: true,
          ),
          CurriculumItem(
            id: 'w07',
            week: 7,
            title: '젤 오프 & 재시술',
            summary: '안전한 오프, 손상 최소화',
            durationMinutes: 50,
            hasVideo: true,
            requiresExam: false,
          ),
          CurriculumItem(
            id: 'w08',
            week: 8,
            title: '손 위생/살롱 위생 표준',
            summary: '소독 루틴, 위생 체크리스트',
            durationMinutes: 45,
            hasVideo: false,
            requiresExam: false,
          ),
          CurriculumItem(
            id: 'w09',
            week: 9,
            title: '고객 응대 매뉴얼',
            summary: '예약/상담/클레임 응대',
            durationMinutes: 60,
            hasVideo: false,
            requiresExam: true,
          ),
          CurriculumItem(
            id: 'w10',
            week: 10,
            title: '트러블 케이스',
            summary: '리프트/파손/알러지 예방과 대응',
            durationMinutes: 70,
            hasVideo: true,
            requiresExam: false,
          ),
          CurriculumItem(
            id: 'w11',
            week: 11,
            title: '젤 연장 기초',
            summary: '폼, 팁, 쉐입 만들기',
            durationMinutes: 90,
            hasVideo: true,
            requiresExam: true,
          ),
          CurriculumItem(
            id: 'w12',
            week: 12,
            title: '아트 심화',
            summary: '스톤, 파츠, 믹스미디어',
            durationMinutes: 95,
            hasVideo: true,
            requiresExam: false,
          ),
          CurriculumItem(
            id: 'w13',
            week: 13,
            title: '시술 시간 단축 팁',
            summary: '동선/세팅 최적화, 체크리스트',
            durationMinutes: 40,
            hasVideo: false,
            requiresExam: false,
          ),
          CurriculumItem(
            id: 'w14',
            week: 14,
            title: '종합 점검 & 모의평가',
            summary: '전 과정 복습, 취약 파트 점검',
            durationMinutes: 120,
            hasVideo: true,
            requiresExam: true,
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        title: Text(
          (_currentIndex == 0) ? '가장 진도가 빠른 신입' :_navItems[_currentIndex].label!,
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
        // actions: const [
        //   Padding(
        //     padding: EdgeInsets.only(right: 10),
        //     child: Icon(Icons.person_add_alt_rounded, color: UiTokens.actionIcon, size: 28),
        //   ),
        // ],
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
