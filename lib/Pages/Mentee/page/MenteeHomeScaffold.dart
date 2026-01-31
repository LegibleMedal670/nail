import 'package:flutter/material.dart';
import 'package:nail/Pages/Chat/widgets/ConfirmModal.dart';
import 'package:nail/Pages/Common/page/MyTodoPage.dart';
import 'package:nail/Pages/Common/widgets/WithdrawDialog.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:nail/Services/UserService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Mentee/page/MenteeMainPage.dart';
import 'package:nail/Pages/Mentee/page/MenteePracticePage.dart';
import 'package:nail/Pages/Welcome/PhoneLoginPage.dart';
import 'package:nail/Pages/Chat/page/ChatRoomListPage.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nail/Pages/Mentee/page/MenteeEducationPage.dart';
import 'package:nail/Pages/Mentee/page/MenteeJournalPage.dart';
import 'package:nail/Pages/Mentee/page/MenteeJournalHistoryPage.dart';

class MenteeHomeScaffold extends StatefulWidget {
  final int initialIndex;
  final bool showPractice; // 학습 탭에서 실습으로 전환
  const MenteeHomeScaffold({super.key, this.initialIndex = 0, this.showPractice = false});

  @override
  State<MenteeHomeScaffold> createState() => _MenteeHomeScaffoldState();
}

class _MenteeHomeScaffoldState extends State<MenteeHomeScaffold> {
  late int _currentIndex;

  bool _initialized = false;      // 첫 진입 1회 처리 (모달 + 배지 로딩)
  int _todoNotDoneCount = 0;      // 미완료 TODO 카운트 배지
  int _chatUnread = 0;            // 채팅 미읽음 배지
  int _journalPending = 0;        // 일일 일지(후임): 오늘 미제출 or 새 선임 피드백 시 점 표시
  final _chatSvc = ChatService.instance;
  RealtimeChannel? _chatRt;
  RealtimeChannel? _journalRt;
  // 탭 내 컨트롤을 위한 키/노티파이어
  final GlobalKey<MyTodoViewState> _todoKey = GlobalKey<MyTodoViewState>();
  final ValueNotifier<bool> _eduIsTheory = ValueNotifier<bool>(true);


  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    
    // 학습 탭에서 실습으로 전환
    if (widget.showPractice && widget.initialIndex == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _eduIsTheory.value = false; // 실습 탭으로 전환
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initTodosOnce();
      await _ensureChatRealtime();
      await _refreshChatBadge();
      await _ensureJournalRealtime();
      await _refreshJournalBadge();
    });
  }

  Future<void> _initTodosOnce() async {
    if (_initialized || !mounted) return;
    _initialized = true;

    // 배지용 "미완료 TODO" 카운트 1회 로딩
    await _refreshTodoBadge();

    // 배지용 "오늘 일지 제출 여부" 1회 로딩
    await _refreshJournalBadge();
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

  Future<void> _refreshJournalBadge() async {
    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    if (loginKey.isEmpty) return;
    try {
      // SupabaseService.loginKey와 UserProvider 동기화는 로그인 시점에 이미 처리됨
      SupabaseService.instance.loginKey = loginKey;
      final needDot =
          await SupabaseService.instance.menteeJournalNeedDot();
      if (!mounted) return;
      setState(() {
        _journalPending = needDot ? 1 : 0;
      });
    } catch (_) {
      // 조용히 무시
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
    // 후임/선임 세션은 login_with_key 재호출로 매핑 보장(가벼움)
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

    // loginKey를 SupabaseService에 반영 (RLS 매핑용)
    try {
      await SupabaseService.instance.loginWithKey(loginKey);
    } catch (_) {
      // ignore
    }

    final sb = Supabase.instance.client;
    final channelName = 'mentee_journals_${DateTime.now().microsecondsSinceEpoch}';
    final ch = sb.channel(channelName);

    void handler(PostgresChangePayload payload) {
      final rec = payload.newRecord ?? payload.oldRecord ?? <String, dynamic>{};
      final jId = (rec['journal_id'] ?? '').toString();
      // 저널 아이디가 비어 있어도, 내 계정에 보이는 메시지면 일단 배지를 다시 계산
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

  Future<void> _withdraw() async {
    final confirmed = await showWithdrawConfirmDialog(context);

    if (confirmed != true || !mounted) return;

    final up = context.read<UserProvider>();
    final userId = up.current?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await UserService.instance.withdrawUser(userId: userId);

      if (!mounted) return;

      // 로딩 닫기
      Navigator.of(context).pop();

      // Firebase Auth 로그아웃
      await up.signOut();

      if (!mounted) return;

      // 로그인 화면으로 이동
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      // 로딩 닫기
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원 탈퇴 실패: $e')),
      );
    }
  }

  @override
  void dispose() {
    _chatRt?.unsubscribe();
    _journalRt?.unsubscribe();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      MyTodoView(
        key: _todoKey,
        embedded: true,
        onBadgeChanged: _refreshTodoBadge, // TODO 상태 변경 시 배지 업데이트
      ), // 투두
      MenteeJournalPage(                       // 일일 일지
        embedded: true,
        onBadgeChanged: (needDot) {
          setState(() {
            _journalPending = needDot ? 1 : 0;
          });
        },
      ),
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
              tooltip: '히스토리(달력)',
              icon: const Icon(Icons.calendar_month_rounded, color: UiTokens.title),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MenteeJournalHistoryPage(),
                  ),
                );
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
            IconButton(
              tooltip: '회원 탈퇴',
              icon: const Icon(Icons.person_remove_outlined, color: UiTokens.title),
              onPressed: _withdraw,
            ),
          ],
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
            _refreshTodoBadge(); // ✅ 탭 전환 시 TODO 배지 동기화 (가벼운 호출)
            _refreshJournalBadge(); // ✅ 탭 전환 시 일지 배지도 동기화
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
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
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
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
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

/// 앱바용 이론/실습 토글(후임)
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
