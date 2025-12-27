import 'package:flutter/material.dart';
import 'package:nail/Pages/Chat/page/ChatRoomListPage.dart';
import 'package:nail/Pages/Chat/widgets/ConfirmModal.dart';
import 'package:nail/Pages/Mentor/page/MentorMainPage.dart';
import 'package:nail/Pages/Mentor/page/MentorTodoGroupsPage.dart';
import 'package:nail/Pages/Mentor/page/MentorTodoGroupsView.dart';
import 'package:nail/Pages/Mentor/page/MentorTodoCreatePage.dart';
import 'package:nail/Pages/Mentor/page/MentorJournalPage.dart';
import 'package:nail/Pages/Common/page/MyTodoPage.dart';
import 'package:nail/Pages/Welcome/PhoneLoginPage.dart';
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
  int _journalPendingCount = 0; // 일일 일지(멘토) 미응답 배지
  final _chatSvc = ChatService.instance;
  RealtimeChannel? _chatRt;
  RealtimeChannel? _journalRt;
  // 탭 컨트롤용 키
  final GlobalKey<MyTodoViewState> _todoKey = GlobalKey<MyTodoViewState>();
  final GlobalKey<MentorTodoGroupsViewState> _groupsKey = GlobalKey<MentorTodoGroupsViewState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureChatRealtime();
      await _refreshChatBadge();
      await _refreshTodoBadge();
      await _refreshJournalBadge();
      await _ensureJournalRealtime();
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

  Future<void> _refreshJournalBadge() async {
    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    if (loginKey.isEmpty) return;
    try {
      SupabaseService.instance.loginKey = loginKey;
      final rows =
          await SupabaseService.instance.mentorListDailyJournals(date: null, statusFilter: 'pending');
      if (!mounted) return;
      setState(() => _journalPendingCount = rows.length);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '로그아웃 하시겠습니까?',
      message: '다시 로그인하려면 전화번호 인증이 필요합니다.',
      confirmText: '로그아웃',
      isDanger: true,
      icon: Icons.logout_rounded,
    );

    if (!confirmed || !mounted) return;

    await context.read<UserProvider>().signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneLoginPage()),
      (route) => false,
    );
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

  Future<void> _ensureJournalRealtime() async {
    _journalRt?.unsubscribe();
    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    if (loginKey.isEmpty) return;
    try {
      await SupabaseService.instance.loginWithKey(loginKey);
    } catch (_) {
      // ignore
    }

    final sb = Supabase.instance.client;
    final channelName = 'mentor_journals_${DateTime.now().microsecondsSinceEpoch}';
    final ch = sb.channel(channelName);

    void handler(PostgresChangePayload payload) {
      _refreshJournalBadge();
    }

    ch
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'daily_journal_messages',
        callback: handler,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'daily_journal_messages',
        callback: handler,
      )
      ..subscribe();

    _journalRt = ch;
  }

  @override
  void dispose() {
    _chatRt?.unsubscribe();
    _journalRt?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final loginKey = up.current?.loginKey ?? '';

    // 페이지 구성: 받은TODO / TODO 현황 / 일일 일지 / 채팅 / 대시보드
    final pages = <Widget>[
      MyTodoView(
        key: _todoKey,
        embedded: true,
        onBadgeChanged: _refreshTodoBadge, // TODO 상태 변경 시 배지 업데이트
      ),
      MentorTodoGroupsView(key: _groupsKey, embedded: true),
      MentorJournalPage(
        embedded: true,
        onPendingChanged: _refreshJournalBadge,
      ),
      const ChatRoomListPage(embedded: true),
      const MentorDashboardBody(),
    ];

    final titles = ['받은TODO', 'TODO 현황', '일일 일지', '채팅', '대시보드'];

    // 스캐폴드 전체를 MentorProvider로 감싸 AppBar/탭/라우팅 전역에서 접근 가능하게 함
    return ChangeNotifierProvider(
      create: (_) => MentorProvider(mentorLoginKey: loginKey)..ensureLoaded(),
      child: Scaffold(
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
            IconButton(
              tooltip: '필터',
              icon: const Icon(Icons.filter_list_rounded, color: UiTokens.title),
              onPressed: () => _todoKey.currentState?.openFilterSheet(),
            ),
            IconButton(
              tooltip: '새로고침',
              icon: const Icon(Icons.refresh_rounded, color: UiTokens.title),
              onPressed: () => _todoKey.currentState?.reload(),
            ),
          ] else if (_currentIndex == 1) ...[
            Builder(
              builder: (ctx) => IconButton(
                tooltip: 'TODO 생성',
                icon: const Icon(Icons.add_task_outlined, color: UiTokens.title),
                onPressed: () async {
                  final mp = ctx.read<MentorProvider>();
                  final created = await Navigator.push<bool>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider<MentorProvider>.value(
                        value: mp,
                        child: const MentorTodoCreatePage(),
                      ),
                    ),
                  );
                  if (created == true) {
                    await _groupsKey.currentState?.reload();
                  }
                },
              ),
            ),
          ],
          // 공통 로그아웃 버튼
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout_rounded, color: UiTokens.title),
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
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
          if (i == 3) {
            _refreshChatBadge();
          }
          if (i == 2) {
            _refreshJournalBadge();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: UiTokens.primaryBlue,
        unselectedItemColor: const Color(0xFFB0B9C1),
        showUnselectedLabels: true,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.checklist_rounded),
            label: '받은TODO',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            label: 'TODO 현황',
          ),
          BottomNavigationBarItem(
            label: '일일 일지',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.menu_book_rounded),
                if (_journalPendingCount > 0)
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
                        _journalPendingCount > 99 ? '99+' : '$_journalPendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.menu_book_rounded),
                if (_journalPendingCount > 0)
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
                        _journalPendingCount > 99 ? '99+' : '$_journalPendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: '대시보드',
          ),
        ],
      ),
      ),
    ));
  }
}




