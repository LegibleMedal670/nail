import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/MyTodoPage.dart';
import 'package:nail/Pages/Common/widgets/MyTodoModal.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Mentee/page/MenteeMainPage.dart';
import 'package:nail/Pages/Mentee/page/MenteePracticePage.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Pages/Chat/page/ChatRoomListPage.dart';
import 'package:nail/Providers/UserProvider.dart';

class MenteeHomeScaffold extends StatefulWidget {
  const MenteeHomeScaffold({super.key});

  @override
  State<MenteeHomeScaffold> createState() => _MenteeHomeScaffoldState();
}

class _MenteeHomeScaffoldState extends State<MenteeHomeScaffold> {
  int _currentIndex = 0;

  bool _initialized = false;      // 첫 진입 1회 처리 (모달 + 배지 로딩)
  int _todoNotDoneCount = 0;      // 미완료 TODO 카운트 배지


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTodosOnce());
  }

  Future<void> _initTodosOnce() async {
    if (_initialized || !mounted) return;
    _initialized = true;

    // 1) 로그인 직후 미확인 활성 TODO 모달 강제 노출
    await showMyTodosModalIfNeeded(context);

    // 2) 배지용 "미완료 TODO" 카운트 1회 로딩
    await _refreshTodoBadge();
  }

  Future<void> _refreshTodoBadge() async {
    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    if (loginKey.isEmpty) return;
    try {
      final rows = await TodoService.instance
          .listMyTodos(loginKey: loginKey, filter: 'not_done'); // ✅ 미완료만
      if (!mounted) return;
      setState(() => _todoNotDoneCount = rows.length);
    } catch (_) {
      // 실패는 조용히 무시 (UI 영향 최소화)
    }
  }


  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const MenteeMainPage(embedded: true),      // 이론
      const MenteePracticePage(embedded: true),  // 실습
      const ChatRoomListPage(embedded: true),    // 채팅
    ];

    final titles = ['이론', '실습', '채팅'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                tooltip: '내 TODO',
                icon: const Icon(Icons.checklist_rounded, color: UiTokens.title),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyTodoPage()),
                  );
                  if (!mounted) return;
                  // 페이지에서 돌아오면 배지 카운트 동기화
                  await _refreshTodoBadge();
                },
              ),
              if (_todoNotDoneCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [UiTokens.cardShadow],
                    ),
                    child: Text(
                      _todoNotDoneCount > 99 ? '99+' : '$_todoNotDoneCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout_rounded, color: UiTokens.title),
            onPressed: () async {
              await context.read<UserProvider>().signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                    (route) => false,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          _refreshTodoBadge(); // ✅ 탭 전환 시 배지 동기화 (가벼운 호출)
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: UiTokens.primaryBlue,
        unselectedItemColor: const Color(0xFFB0B9C1),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: '이론',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.brush_rounded),
            label: '실습',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '채팅',
          ),
        ],
      ),
    );
  }
}
