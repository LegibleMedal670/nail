import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/MyTodoPage.dart';
import 'package:nail/Pages/Common/widgets/MyTodoModal.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Mentee/page/MenteeMainPage.dart';
import 'package:nail/Pages/Mentee/page/MenteePracticePage.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Pages/Chat/page/ChatRoomListPage.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nail/Pages/Mentee/page/MenteeEducationPage.dart';
import 'package:nail/Pages/Mentee/page/MenteeJournalPage.dart';

class MenteeHomeScaffold extends StatefulWidget {
  const MenteeHomeScaffold({super.key});

  @override
  State<MenteeHomeScaffold> createState() => _MenteeHomeScaffoldState();
}

class _MenteeHomeScaffoldState extends State<MenteeHomeScaffold> {
  int _currentIndex = 0;

  bool _initialized = false;      // 첫 진입 1회 처리 (모달 + 배지 로딩)
  int _todoNotDoneCount = 0;      // 미완료 TODO 카운트 배지
  int _chatUnread = 0;            // 채팅 미읽음 배지
  int _journalPending = 0;        // 일일 일지(멘티): 미제출 시 1 표시
  final _chatSvc = ChatService.instance;
  RealtimeChannel? _chatRt;
  // 탭 내 컨트롤을 위한 키/노티파이어
  final GlobalKey<MyTodoViewState> _todoKey = GlobalKey<MyTodoViewState>();
  final ValueNotifier<bool> _eduIsTheory = ValueNotifier<bool>(true);


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initTodosOnce();
      await _ensureChatRealtime();
      await _refreshChatBadge();
    });
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

  Future<void> _refreshChatBadge() async {
    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    if (loginKey.isEmpty) return;
    try {
      final rows = await _chatSvc.listRooms(loginKey: loginKey, limit: 200);
      final sum = rows.fold<int>(0, (acc, r) => acc + (int.tryParse((r['unread'] ?? '0').toString()) ?? 0));
      if (!mounted) return;
      setState(() => _chatUnread = sum);
    } catch (_) {
      // 조용히 무시
    }
  }

  Future<void> _ensureChatRealtime() async {
    _chatRt?.unsubscribe();
    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    if (loginKey.isEmpty) return;
    // 멘티/멘토 세션은 login_with_key 재호출로 매핑 보장(가벼움)
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
    final pages = <Widget>[
      MyTodoView(key: _todoKey, embedded: true), // 투두
      const MenteeJournalPage(embedded: true),   // 일일 일지
      const ChatRoomListPage(embedded: true),    // 채팅
      MenteeEducationPage(embedded: true, isTheoryNotifier: _eduIsTheory), // 학습(이론/실습)
    ];

    final titles = ['투두', '일일 일지', '채팅', '학습'];

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
            IconButton(
              tooltip: '히스토리(달력) - 데모',
              icon: const Icon(Icons.calendar_month_rounded, color: UiTokens.title),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데모: 히스토리는 후속 단계에서 구현됩니다.')));
              },
            ),
          ] else if (_currentIndex == 2) ...[
            // 채팅 탭: 별도 액션 없음 (로그아웃 공통)
          ] else if (_currentIndex == 3) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _eduIsTheory,
                  builder: (_, isTheory, __) => _EduKindSegment(
                    isTheory: isTheory,
                    onChanged: (v) => _eduIsTheory.value = v,
                  ),
                ),
              ),
            ),
          ],
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color.fromARGB(255, 240, 240, 240))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            _refreshTodoBadge(); // ✅ 탭 전환 시 배지 동기화 (가벼운 호출)
            if (i == 2) {
              _refreshChatBadge(); // 채팅 탭 전환 시 배지도 동기화
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: UiTokens.primaryBlue,
          unselectedItemColor: const Color(0xFFB0B9C1),
          showUnselectedLabels: true,
          items: [
            BottomNavigationBarItem(
              label: '투두',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.checklist_rounded),
                  if (_todoNotDoneCount > 0)
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
                          _todoNotDoneCount > 99 ? '99+' : '$_todoNotDoneCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.checklist_rounded),
                  if (_todoNotDoneCount > 0)
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
                          _todoNotDoneCount > 99 ? '99+' : '$_todoNotDoneCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            BottomNavigationBarItem(
              label: '일일 일지',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.menu_book_rounded),
                  if (_journalPending > 0)
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
                          _journalPending > 99 ? '99+' : '$_journalPending',
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
                  if (_journalPending > 0)
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
                          _journalPending > 99 ? '99+' : '$_journalPending',
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
              icon: Icon(Icons.menu_book_rounded),
              label: '학습',
            ),
          ],
        ),
      ),
    );
  }
}

/// 앱바용 이론/실습 토글(멘티)
class _EduKindSegment extends StatelessWidget {
  final bool isTheory;
  final ValueChanged<bool> onChanged;
  const _EduKindSegment({required this.isTheory, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6EBF0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentPill(
            selected: isTheory,
            label: '이론',
            onTap: () => onChanged(true),
          ),
          _SegmentPill(
            selected: !isTheory,
            label: '실습',
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  const _SegmentPill({required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? UiTokens.primaryBlue.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? UiTokens.primaryBlue : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
