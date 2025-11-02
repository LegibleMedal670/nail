// lib/Pages/Manager/page/todo/ManagerTodoStatusPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/TodoTypes.dart';
import 'package:nail/Pages/Manager/page/ManagerTodoCreatePage.dart';
import 'package:nail/Pages/Manager/page/ManagerTodoGroupDetailPage.dart';



class ManagerTodoStatusPage extends StatefulWidget {
  const ManagerTodoStatusPage({super.key});

  @override
  State<ManagerTodoStatusPage> createState() => _ManagerTodoStatusPageState();
}

class _ManagerTodoStatusPageState extends State<ManagerTodoStatusPage> {
  TodoViewFilter _filter = TodoViewFilter.active;

  // 데모 데이터 (isArchived 포함)
  final List<_TodoGroupVm> _allAudience = [
    _TodoGroupVm(
      id: 'g-all-1',
      title: '전사 공지: 이번 주 안전 교육 리마인드',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      audience: TodoAudience.all,
      doneCount: 18,
      ackCount: 24,
      totalCount: 30,
      isArchived: false,
    ),
    _TodoGroupVm(
      id: 'g-all-2',
      title: '전사 공지: 지난 주 설비 점검 결과 공유',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      audience: TodoAudience.all,
      doneCount: 30,
      ackCount: 30,
      totalCount: 30,
      isArchived: true, // 비활성(보관)
    ),
  ];
  final List<_TodoGroupVm> _mentorAudience = [
    _TodoGroupVm(
      id: 'g-men-1',
      title: '멘토 대상: 신규 멘티 OT 준비',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      audience: TodoAudience.mentor,
      doneCount: 7,
      ackCount: 10,
      totalCount: 12,
      isArchived: false,
    ),
  ];
  final List<_TodoGroupVm> _menteeAudience = [
    _TodoGroupVm(
      id: 'g-mee-1',
      title: '멘티 대상: 금일 교육일지 업로드',
      createdAt: DateTime.now(),
      audience: TodoAudience.mentee,
      doneCount: 9,
      ackCount: 15,
      totalCount: 25,
      isArchived: false,
    ),
    _TodoGroupVm(
      id: 'g-mee-2',
      title: '멘티 대상: 1강 수강 확인',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      audience: TodoAudience.mentee,
      doneCount: 30,
      ackCount: 30,
      totalCount: 30,
      isArchived: false, // 완료
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final hasAny = _allAudience.isNotEmpty || _mentorAudience.isNotEmpty || _menteeAudience.isNotEmpty;

    // 상태 계산
    _Status calcStatus(_TodoGroupVm v) {
      final completed = (v.totalCount > 0) && (v.doneCount == v.totalCount);
      if (v.isArchived) return _Status.inactive; // 비활성(보관)
      return completed ? _Status.completed : _Status.active; // 완료 or 활성
    }

    // 필터링
    bool pass(_TodoGroupVm v) {
      final st = calcStatus(v);
      switch (_filter) {
        case TodoViewFilter.active:
          return st == _Status.active;
        case TodoViewFilter.completed:
          return st == _Status.completed;
        case TodoViewFilter.inactive:
          return st == _Status.inactive;
        case TodoViewFilter.all:
          return true;
      }
    }

    final fa = _allAudience.where(pass).toList();
    final fm = _mentorAudience.where(pass).toList();
    final fe = _menteeAudience.where(pass).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('TODO 현황', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700, fontSize: 22)),
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: UiTokens.title,
          ),
          tooltip: '뒤로가기',
          onPressed: () {
            Navigator.maybePop(context); // 평소엔 곧바로 뒤로
          },
        ),
        actions: [
          IconButton(
            tooltip: 'TODO 추가',
            icon: const Icon(Icons.add_task_outlined, color: UiTokens.title),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManagerTodoCreatePage()));
            },
          ),
        ],
      ),
      body: hasAny
          ? ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _FilterChips(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 12),
          _AudienceSection(
            title: '전체 공지',
            icon: Icons.campaign_outlined,
            items: fa,
            emptyHint: '해당 상태의 전체 공지가 없습니다.',
            statusOf: calcStatus,
          ),
          const SizedBox(height: 16),
          _AudienceSection(
            title: '멘토 공지',
            icon: Icons.support_agent_outlined,
            items: fm,
            emptyHint: '해당 상태의 멘토 공지가 없습니다.',
            statusOf: calcStatus,
          ),
          const SizedBox(height: 16),
          _AudienceSection(
            title: '멘티 공지',
            icon: Icons.people_outline,
            items: fe,
            emptyHint: '해당 상태의 멘티 공지가 없습니다.',
            statusOf: calcStatus,
          ),
        ],
      )
          : const _EmptyView(),
    );
  }
}

// ---------- 상단 필터 칩(예쁘게) ----------
class _FilterChips extends StatelessWidget {
  final TodoViewFilter value;
  final ValueChanged<TodoViewFilter> onChanged;
  const _FilterChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    Widget chip({
      required TodoViewFilter v,
      required String label,
      required IconData icon,
      required Color color,
    }) {
      final selected = value == v;
      return InkWell(
        onTap: () => onChanged(v),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : c.surface,
            border: Border.all(color: selected ? color : const Color(0xFFE6EBF0)),
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? color : c.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? color : c.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(v: TodoViewFilter.active,    label: '활성',   icon: Icons.play_circle_outline,  color: UiTokens.primaryBlue),
        chip(v: TodoViewFilter.completed, label: '완료',   icon: Icons.check_circle_outlined, color: Colors.teal),
        chip(v: TodoViewFilter.inactive,  label: '비활성', icon: Icons.pause_circle_outline,  color: Colors.grey),
        chip(v: TodoViewFilter.all,       label: '전체',   icon: Icons.all_inclusive,         color: c.primary),
      ],
    );
  }
}

// ---------- 섹션 + 카드 ----------
class _AudienceSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_TodoGroupVm> items;
  final String emptyHint;
  final _Status Function(_TodoGroupVm) statusOf;

  const _AudienceSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyHint,
    required this.statusOf,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: UiTokens.primaryBlue),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE6EBF0)), borderRadius: BorderRadius.circular(12)),
            child: Text(emptyHint, style: TextStyle(color: c.onSurfaceVariant)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, i) => _TodoGroupCard(vm: items[i], status: statusOf(items[i])),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
          ),
      ],
    );
  }
}

enum _Status { active, completed, inactive }

class _TodoGroupCard extends StatelessWidget {
  final _TodoGroupVm vm;
  final _Status status;
  const _TodoGroupCard({required this.vm, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final double doneRate = vm.totalCount == 0 ? 0 : vm.doneCount / vm.totalCount;
    final double ackRate = vm.totalCount == 0 ? 0 : vm.ackCount / vm.totalCount;

    // 상태 칩 스타일
    late final Color chipColor;
    late final IconData chipIcon;
    late final String chipText;

    switch (status) {
      case _Status.active:
        chipColor = UiTokens.primaryBlue;
        chipIcon = Icons.play_circle_outline;
        chipText = '활성';
        break;
      case _Status.completed:
        chipColor = Colors.teal;
        chipIcon = Icons.check_circle_outlined;
        chipText = '완료';
        break;
      case _Status.inactive:
        chipColor = Colors.grey;
        chipIcon = Icons.pause_circle_outline;
        chipText = '비활성';
        break;
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ManagerTodoGroupDetailPage(
              groupId: vm.id,
              title: vm.title,
              audience: vm.audience,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE6EBF0)),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: chipColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(chipIcon, color: chipColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        vm.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(text: chipText, color: chipColor),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_fmtDate(vm.createdAt), style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 10),
                _LabeledProgress(label: '완료', value: doneRate, valueText: '${vm.doneCount}/${vm.totalCount}'),
                const SizedBox(height: 6),
                _LabeledProgress(label: '확인', value: ackRate, valueText: '${vm.ackCount}/${vm.totalCount}'),
              ]),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right, color: c.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LabeledProgress extends StatelessWidget {
  final String label;
  final double value;
  final String valueText;
  const _LabeledProgress({required this.label, required this.value, required this.valueText});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(width: 28, child: Text(label, style: TextStyle(color: c.onSurfaceVariant, fontSize: 12))),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 8,
              backgroundColor: const Color(0xFFF3F6F9),
              color: UiTokens.primaryBlue,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(valueText, textAlign: TextAlign.right, style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fact_check_outlined, size: 56, color: c.outline),
            const SizedBox(height: 12),
            const Text('아직 만든 공지가 없습니다', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 6),
            Text('우측 상단의 [TODO 추가] 버튼으로 공지를 생성하세요.', style: TextStyle(color: c.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _TodoGroupVm {
  final String id;
  final String title;
  final DateTime createdAt;
  final TodoAudience audience;
  final int doneCount;
  final int ackCount;
  final int totalCount;
  final bool isArchived; // 비활성 플래그

  _TodoGroupVm({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.audience,
    required this.doneCount,
    required this.ackCount,
    required this.totalCount,
    required this.isArchived,
  });
}
