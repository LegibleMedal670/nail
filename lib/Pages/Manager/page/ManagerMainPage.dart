// lib/Pages/Manager/page/ManagerMainPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/page/ManagerTodoStatusPage.dart';
import 'package:nail/Pages/Manager/page/tabs/CurriculumManageTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MostProgressedMenteeTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MenteeManageTab.dart';
import 'package:nail/Pages/Manager/page/tabs/MentorManageTab.dart';

class ManagerMainPage extends StatefulWidget {
  const ManagerMainPage({super.key});

  @override
  State<ManagerMainPage> createState() => _ManagerMainPageState();
}

class _ManagerMainPageState extends State<ManagerMainPage> {
  int _currentIndex = 0;

  /// 교육 관리 탭의 이론/실습 전환 상태(앱바 토글 ↔ 하위 탭 동기화)
  final ValueNotifier<String> _manageKind = ValueNotifier<String>(kKindTheory);

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
    BottomNavigationBarItem(icon: Icon(Icons.support_agent_outlined), label: '멘토 관리'),
    BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: '멘티 관리'),
    BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_outlined), label: '교육 관리'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const MostProgressedMenteeTab(),
      const MentorManageTab(),
      const MenteeManageTab(),
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
            if (_currentIndex != 3) {
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
        // - 교육 관리(3)일 때는 기존 이론/실습 토글 노출(유지)
        actions: [
          if (_currentIndex != 3)
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
