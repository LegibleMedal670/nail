import 'package:flutter/material.dart';
import 'package:nail/Pages/Chat/page/ChatRoomListPage.dart';
import 'package:nail/Pages/Mentor/page/MentorMainPage.dart';
import 'package:nail/Pages/Mentor/page/MentorTodoGroupsPage.dart';
import 'package:nail/Pages/Common/page/MyTodoPage.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nail/Providers/MentorProvider.dart';

class MentorHomeScaffold extends StatefulWidget {
  const MentorHomeScaffold({super.key});

  @override
  State<MentorHomeScaffold> createState() => _MentorHomeScaffoldState();
}

class _MentorHomeScaffoldState extends State<MentorHomeScaffold> {
  int _currentIndex = 0;

  // 채팅 배지
  int _chatUnread = 0;
  int _todoNotDoneCount = 0;
  final _chatSvc = ChatService.instance;
  RealtimeChannel? _chatRt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureChatRealtime();
      await _refreshChatBadge();
      await _refreshTodoBadge();
    });
  }

  Future<void> _refreshChatBadge() async {
    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    if (loginKey.isEmpty) return;
    try {
      final rows = await _chatSvc.listRooms(loginKey: loginKey, limit: 200);
      final sum = rows.fold<int>(0, (acc, r) => acc + (int.tryParse((r['unread'] ?? '0').toString()) ?? 0));
      if (!mounted) return;
      setState(() => _chatUnread = sum);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refreshTodoBadge() async {
    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    if (loginKey.isEmpty) return;
    try {
      // 멘티와 동일 API: 미완료 TODO 카운트를 뱃지로
      final rows = await TodoService.instance.listMyTodos(loginKey: loginKey, filter: 'not_done');
      if (!mounted) return;
      setState(() => _todoNotDoneCount = rows.length);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _ensureChatRealtime() async {
    _chatRt?.unsubscribe();
    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    if (loginKey.isEmpty) return;
    try {
      await SupabaseService.instance.loginWithKey(loginKey);
    } catch (_) {
      // ignore
    }
    _chatRt = _chatSvc.subscribeListRefresh(onChanged: _refreshChatBadge);
  }

  @override
  void dispose() {
    _chatRt?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final loginKey = up.current?.loginKey ?? '';

    // 멘토 대시보드용 Provider 1회 구성
    final dashboard = ChangeNotifierProvider(
      create: (_) => MentorProvider(mentorLoginKey: loginKey)..ensureLoaded(),
      child: const MentorDashboardBody(),
    );

    final pages = <Widget>[
      dashboard,
      const ChatRoomListPage(embedded: true),
    ];

    final titles = ['대시보드', '채팅'];

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
          if (_currentIndex == 0) ...[
            // 내 TODO + 배지
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Stack(
                children: [
                  IconButton(
                    tooltip: '내 TODO',
                    icon: const Icon(Icons.checklist_rounded, color: UiTokens.title),
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTodoPage()));
                      if (!mounted) return;
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
            ),
            // TODO 현황
            IconButton(
              tooltip: 'TODO 현황',
              icon: const Icon(Icons.fact_check_outlined, color: UiTokens.title),
              onPressed: () async {
                // 별도 Provider로 라우팅
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider(
                      create: (_) => MentorProvider(mentorLoginKey: loginKey)..ensureLoaded(),
                      child: const MentorTodoGroupsPage(),
                    ),
                  ),
                );
                await _refreshTodoBadge();
              },
            ),
            // 로그아웃
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
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color.fromARGB(255, 240, 240, 240))),
        ),
        child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 1) {
            _refreshChatBadge();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: UiTokens.primaryBlue,
        unselectedItemColor: const Color(0xFFB0B9C1),
        showUnselectedLabels: true,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: '대시보드',
          ),
          BottomNavigationBarItem(
            label: '채팅',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline),
                if (_chatUnread > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _chatUnread > 99 ? '99+' : '$_chatUnread',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline),
                if (_chatUnread > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _chatUnread > 99 ? '99+' : '$_chatUnread',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}


