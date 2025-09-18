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
  String? _errorTop;

  String _topName = '-';
  DateTime _topStartedAt = DateTime.now();
  String? _topPhotoUrl;

  List<CurriculumItem> _topCurriculum = const [];
  Set<String> _topCompleted = {};
  Map<String, double> _topProgressRatio = {};

  // Future<void> _loadTopMenteeAndCourse() async {
  //   setState(() {
  //     _loadingTop = true;
  //     _errorTop = null;
  //   });
  //
  //   try {
  //     // 1) 상위 멘티 1명 (admin RPC)
  //     final row = await AdminMenteeService.instance.fetchTopMenteeRow();
  //     if (row == null) {
  //       throw '랭킹 데이터가 없습니다';
  //     }
  //
  //     final String loginKey = (row['login_key'] ?? '').toString();
  //     if (loginKey.isEmpty) {
  //       throw '해당 멘티의 로그인 키가 없습니다';
  //     }
  //
  //     // 표시용 기본 정보
  //     final String nickname = (row['nickname'] ?? '이름없음').toString();
  //     final DateTime startedAt = DateTime.tryParse((row['joined_at'] ?? '').toString()) ?? DateTime.now();
  //     final String? photoUrl = row['photo_url'] as String?;
  //
  //     // 2) 모듈별 진행 (기존 mentee_course_progress RPC 사용)
  //     final data = await AdminMenteeService.instance.fetchMenteeCourseData(loginKey);
  //
  //     if (!mounted) return;
  //     setState(() {
  //       _topName = nickname;
  //       _topStartedAt = startedAt;
  //       _topPhotoUrl = photoUrl;
  //
  //       _topCurriculum = data.curriculum;
  //       _topCompleted = data.completedIds;
  //       _topProgressRatio = data.progressRatio;
  //
  //       _loadingTop = false;
  //       _errorTop = null;
  //     });
  //   } catch (e) {
  //     if (!mounted) return;
  //     setState(() {
  //       _loadingTop = false;
  //       _errorTop = '$e';
  //     });
  //   }
  // }

  @override
  void initState() {
    super.initState();
    // _loadTopMenteeAndCourse();
  }

  // Widget _buildTopMenteeTab() {
  //   if (_loadingTop) {
  //     return const Center(child: CircularProgressIndicator());
  //   }
  //   if (_errorTop != null) {
  //     return Center(
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Text('불러오기 실패: $_errorTop',
  //               style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
  //           const SizedBox(height: 8),
  //           FilledButton(
  //             onPressed: _loadTopMenteeAndCourse,
  //             style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
  //             child: const Text('다시 시도'),
  //           ),
  //         ],
  //       ),
  //     );
  //   }
  //
  //   return MostProgressedMenteeTab(
  //     name: _topName,
  //     startedAt: _topStartedAt,
  //     photoUrl: _topPhotoUrl,
  //     curriculum: _topCurriculum,
  //     completedIds: _topCompleted,
  //     progressRatio: _topProgressRatio,
  //     onRefresh: _loadTopMenteeAndCourse, // ✅ 여기 연결!
  //   );
  // }

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
    BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: '멘티 관리'),
    BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_outlined), label: '교육 관리'),
  ];

  @override
  Widget build(BuildContext context) {

    final pages = <Widget>[
      // _buildTopMenteeTab(),     // <- 기존 더미 대신 서버 데이터 주입
      MostProgressedMenteeTab(),
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
