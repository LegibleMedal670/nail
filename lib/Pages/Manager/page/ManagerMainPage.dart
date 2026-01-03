// lib/Pages/Manager/page/ManagerMainPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Chat/page/ChatRoomListPage.dart';
import 'package:nail/Pages/Chat/page/CreateChatRoomPage.dart';
import 'package:nail/Pages/Chat/widgets/ConfirmModal.dart';
import 'package:nail/Pages/Common/widgets/WithdrawDialog.dart';
import 'package:nail/Pages/Manager/page/PendingUsersPage.dart';
import 'package:nail/Pages/Welcome/PhoneLoginPage.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:nail/Services/UserService.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/page/ManagerTodoStatusPage.dart';
import 'package:nail/Pages/Manager/page/tabs/CurriculumManageTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MostProgressedMenteeTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MenteeManageTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MentorManageTab.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerMainPage extends StatefulWidget {
  final int initialIndex;
  const ManagerMainPage({super.key, this.initialIndex = 0});

  @override
  State<ManagerMainPage> createState() => _ManagerMainPageState();
}

class _ManagerMainPageState extends State<ManagerMainPage> {
  late int _currentIndex;
  final _svc = ChatService.instance;
  final _sb = Supabase.instance.client;
  int _chatUnread = 0;
  int _pendingCount = 0; // 가입 대기 사용자 수
  RealtimeChannel? _chatRt;
  String? _rtLoginKeyBound; // 현재 구독이 묶여 있는 loginKey
  int _chatReloadToken = 0;

  /// 교육 관리 탭의 이론/실습 전환 상태(앱바 토글 ↔ 하위 탭 동기화)
  final ValueNotifier<String> _manageKind = ValueNotifier<String>(kKindTheory);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    try {
      final res = await _sb.rpc('rpc_list_pending_users');
      if (mounted) {
        setState(() {
          _pendingCount = (res as List?)?.length ?? 0;
        });
      }
    } catch (_) {
      // 무시
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

      // 성공 메시지는 Splash에서 처리하도록 (현재 화면은 이미 dispose됨)
    } catch (e) {
      if (!mounted) return;

      // 로딩 닫기
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원 탈퇴 실패: $e')),
      );
    }
  }

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
    BottomNavigationBarItem(icon: Icon(Icons.support_agent_outlined), label: '멘토 관리'),
    BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: '멘티 관리'),
    BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: '채팅'),
    BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_outlined), label: '교육 관리'),
  ];

  @override
  Widget build(BuildContext context) {
    // 로그인 키는 화면 갱신 때마다 최신값을 사용
    final up = context.watch<UserProvider>();
    final loginKey = up.isAdmin ? (up.adminKey ?? '') : (up.current?.loginKey ?? '');
    // 최초 진입 및 loginKey 변경 시에만 구독 보장
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureChatRealtime(loginKey));

    final pages = <Widget>[
      const MostProgressedMenteeTab(),
      const MentorManageTab(),
      const MenteeManageTab(),
      ChatRoomListPage(embedded: true, externalReloadToken: _chatReloadToken),
      CurriculumManageTab(kindNotifier: _manageKind),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        title: ValueListenableBuilder<String>(
          valueListenable: _manageKind,
          builder: (_, kind, __) {
            final base = (_currentIndex == 0) ? '가장 진도가 빠른 신입' : _navItems[_currentIndex].label!;
            if (_currentIndex != 4) {
              return Text(
                base,
                style: const TextStyle(
                  color: UiTokens.title,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                ),
              );
            }
            final isTheory = kind == kKindTheory;
            final title = isTheory ? '$base(이론)' : '$base(실습)';
            return Text(
              title,
              style: const TextStyle(
                color: UiTokens.title,
                fontWeight: FontWeight.w700,
                fontSize: 26,
              ),
            );
          },
        ),
        // ✅ 앱바 우측 액션:
        // - 대시보드(0)일 때: 가입 승인 + TODO 현황
        // - 멘토 관리(1) / 멘티 관리(2)일 때: TODO 현황
        // - 채팅(3)일 때는 방 생성 + 버튼
        // - 교육 관리(4)일 때는 기존 이론/실습 토글 노출
        actions: [
          // 대시보드(0)일 때 가입 승인 버튼
          if (_currentIndex == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: '가입 승인',
                    icon: const Icon(Icons.switch_account, color: UiTokens.title),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PendingUsersPage()),
                      );
                      _loadPendingCount(); // 돌아왔을 때 갱신
                    },
                  ),
                  if (_pendingCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _pendingCount > 99 ? '99+' : '$_pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_currentIndex < 3)
            IconButton(
              tooltip: 'TODO 현황',
              icon: const Icon(Icons.fact_check_outlined, color: UiTokens.title),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManagerTodoStatusPage()),
                );
              },
            ),
          // 대시보드(0)일 때 로그아웃 버튼
          if (_currentIndex == 0)
            IconButton(
              tooltip: '로그아웃',
              icon: const Icon(Icons.logout, color: UiTokens.title),
              onPressed: _logout,
            ),
          if (_currentIndex == 3)
            IconButton(
              tooltip: '방 생성',
              icon: const Icon(Icons.add, color: UiTokens.title),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateChatRoomPage()),
                );
                if (!mounted) return;
                setState(() {
                  _currentIndex = 3; // 채팅 탭 유지
                  _chatReloadToken++; // 목록 강제 새로고침
                });
                await _loadChatUnread(loginKey);
              },
            ),
          if (_currentIndex == 4)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ValueListenableBuilder<String>(
                  valueListenable: _manageKind,
                  builder: (_, kind, __) => _ManageKindSegment(
                    value: kind,
                    onChanged: (v) => _manageKind.value = v,
                  ),
                ),
              ),
            ),
          if (_currentIndex == 4)
            IconButton(
              tooltip: '회원 탈퇴',
              icon: const Icon(Icons.person_remove_outlined, color: UiTokens.title),
              onPressed: _withdraw,
            ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color.fromARGB(255, 240, 240, 240))),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: UiTokens.primaryBlue,
          unselectedItemColor: const Color(0xFFB0B9C1),
          showUnselectedLabels: true,
          items: [
            _navItems[0],
            _navItems[1],
            _navItems[2],
            BottomNavigationBarItem(
              label: _navItems[3].label,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat_bubble_outline),
                  if (_chatUnread > 0)
                    Positioned(
                      right: -10,
                      top: -3,
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
                      top: -3,
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
            _navItems[4],
          ],
        ),
      ),
    );
  }

  Future<void> _loadChatUnread(String loginKey) async {
    if (loginKey.isEmpty) return;
    try {
      final rows = await _svc.listRooms(loginKey: loginKey, limit: 200);
      final sum = rows.fold<int>(0, (acc, r) => acc + (int.tryParse((r['unread'] ?? '0').toString()) ?? 0));
      if (mounted) setState(() => _chatUnread = sum);
    } catch (_) {
      // 무시
    }
  }

  void _ensureChatRealtime(String loginKey) {
    if (loginKey.isEmpty) return;
    if (_rtLoginKeyBound == loginKey && _chatRt != null) {
      // 이미 동일 키로 구독됨
      return;
    }
    // 다른 키로 바인딩되어 있거나 최초 → 재바인딩
    _chatRt?.unsubscribe();
    _rtLoginKeyBound = loginKey;
    // 관리자 세션은 Realtime RLS 매핑을 먼저 보장
    SupabaseService.instance.ensureAdminSessionLinked().catchError((_) {}).whenComplete(() {
      _chatRt = _svc.subscribeListRefresh(onChanged: () => _loadChatUnread(loginKey));
      // 초기 1회 배지 동기화
      _loadChatUnread(loginKey);
    });
  }
}

/// 앱바용 이론/실습 토글(세련된 필 세그먼트)
class _ManageKindSegment extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ManageKindSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final isTheory = value == kKindTheory;

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
            onTap: () => onChanged(kKindTheory),
          ),
          _SegmentPill(
            selected: !isTheory,
            label: '실습',
            onTap: () => onChanged(kKindPractice),
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

  const _SegmentPill({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

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
              color: selected ? UiTokens.primaryBlue : c.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
