// lib/Pages/Manager/page/ManagerMainPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Chat/page/ChatRoomListPage.dart';
import 'package:nail/Pages/Chat/page/CreateChatRoomPage.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/page/ManagerTodoStatusPage.dart';
import 'package:nail/Pages/Manager/page/tabs/CurriculumManageTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MostProgressedMenteeTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MenteeManageTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MentorManageTab.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerMainPage extends StatefulWidget {
  const ManagerMainPage({super.key});

  @override
  State<ManagerMainPage> createState() => _ManagerMainPageState();
}

class _ManagerMainPageState extends State<ManagerMainPage> {
  int _currentIndex = 0;
  final _svc = ChatService.instance;
  int _chatUnread = 0;
  RealtimeChannel? _chatRt;
  int _chatReloadToken = 0;

  /// 교육 관리 탭의 이론/실습 전환 상태(앱바 토글 ↔ 하위 탭 동기화)
  final ValueNotifier<String> _manageKind = ValueNotifier<String>(kKindTheory);

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
    // 최초 진입 및 구독
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureChatRealtime(loginKey);
    });
    _loadChatUnread(loginKey); // 가벼운 호출, 오류 시 무시

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
        // - 대시보드(0) / 멘토 관리(1) / 멘티 관리(2)일 때만 "TODO 현황" 아이콘 표시
        // - 채팅(3)일 때는 방 생성 + 버튼
        // - 교육 관리(4)일 때는 기존 이론/실습 토글 노출
        actions: [
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
    _chatRt?.unsubscribe();
    if (loginKey.isEmpty) return;
    _chatRt = _svc.subscribeListRefresh(onChanged: () => _loadChatUnread(loginKey));
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
