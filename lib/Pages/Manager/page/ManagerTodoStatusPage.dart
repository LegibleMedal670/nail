// lib/Pages/Manager/page/todo/ManagerTodoStatusPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/TodoTypes.dart';
import 'package:nail/Pages/Manager/page/ManagerTodoCreatePage.dart';
import 'package:nail/Pages/Manager/page/ManagerTodoGroupDetailPage.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Providers/UserProvider.dart';

class ManagerTodoStatusPage extends StatefulWidget {
  const ManagerTodoStatusPage({super.key});

  @override
  State<ManagerTodoStatusPage> createState() => _ManagerTodoStatusPageState();
}

class _ManagerTodoStatusPageState extends State<ManagerTodoStatusPage> {
  TodoViewFilter _filter = TodoViewFilter.active;

  bool _loading = false;
  String? _error;

  /// 서버에서 받아온 전체 그룹(캐시)
  List<_TodoGroupVm> _rowsAll = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final loginKey = context.read<UserProvider>().adminKey?.trim() ?? '';
      if (loginKey.isEmpty) {
        setState(() {
          _loading = false;
          _error = '로그인이 필요합니다. (adminKey 없음)';
        });
        return;
      }

      // ✅ 최초/새로고침 시에는 항상 'all' 로 전체를 받아 캐시
      final list = await TodoService.instance.listTodoGroups(
        loginKey: loginKey,
        filter: 'all',
      );

      final mapped = list.map(_mapRowToVm).toList(growable: false);
      setState(() => _rowsAll = mapped);
    } catch (e) {
      setState(() => _error = '목록 불러오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _TodoGroupVm _mapRowToVm(Map<String, dynamic> m) {
    final audienceStr = (m['audience'] ?? 'mentee').toString();
    final audience = switch (audienceStr) {
      'all' => TodoAudience.all,
      'mentor' => TodoAudience.mentor,
      _ => TodoAudience.mentee,
    };

    DateTime createdAt;
    final ca = m['created_at'];
    if (ca is DateTime) {
      createdAt = ca;
    } else {
      createdAt = DateTime.tryParse(ca?.toString() ?? '') ?? DateTime.now();
    }

    return _TodoGroupVm(
      id: (m['group_id'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      createdAt: createdAt,
      audience: audience,
      doneCount: int.tryParse('${m['done_count'] ?? 0}') ?? 0,
      ackCount: int.tryParse('${m['ack_count'] ?? 0}') ?? 0,
      totalCount: int.tryParse('${m['total_count'] ?? 0}') ?? 0,
      isArchived: m['is_archived'] == true,
    );
  }

  // 상태 계산(서버는 all로 받고, 화면에서 필터)
  _Status _calcStatus(_TodoGroupVm v) {
    final completed = (v.totalCount > 0) && (v.doneCount == v.totalCount);
    if (v.isArchived) return _Status.inactive; // 보관됨
    return completed ? _Status.completed : _Status.active;
  }

  bool _passByFilter(_TodoGroupVm v) {
    final st = _calcStatus(v);
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

  @override
  Widget build(BuildContext context) {
    final rows = _rowsAll.where(_passByFilter).toList();
    final fa = rows.where((e) => e.audience == TodoAudience.all).toList();
    final fm = rows.where((e) => e.audience == TodoAudience.mentor).toList();
    final fe = rows.where((e) => e.audience == TodoAudience.mentee).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('TODO 현황',
            style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700, fontSize: 22)),
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UiTokens.title),
          tooltip: '뒤로가기',
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'TODO 추가',
            icon: const Icon(Icons.add_task_outlined, color: UiTokens.title),
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ManagerTodoCreatePage()))
                  .then((_) => _fetch()); // 생성 후 자동 새로고침
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _fetch)
          : RefreshIndicator(
        onRefresh: _fetch, // 당겨서 새로고침은 서버 호출
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _FilterChips(
              value: _filter,
              onChanged: (v) {
                // ✅ 클라이언트 사이드 필터만 변경 (서버 호출 X)
                setState(() => _filter = v);
              },
            ),
            const SizedBox(height: 12),

            // 전체가 비었을 때도 칩 아래에 안내만 노출 (칩은 항상 보임)
            if (fa.isEmpty && fm.isEmpty && fe.isEmpty)
              _NoResultBanner(filter: _filter),

            _AudienceSection(
              title: '전체 공지',
              icon: Icons.campaign_outlined,
              items: fa,
              emptyHint: '해당 상태의 전체 공지가 없습니다.',
              statusOf: _calcStatus,
            ),
            const SizedBox(height: 16),
            _AudienceSection(
              title: '멘토 공지',
              icon: Icons.support_agent_outlined,
              items: fm,
              emptyHint: '해당 상태의 멘토 공지가 없습니다.',
              statusOf: _calcStatus,
            ),
            const SizedBox(height: 16),
            _AudienceSection(
              title: '멘티 공지',
              icon: Icons.people_outline,
              items: fe,
              emptyHint: '해당 상태의 멘티 공지가 없습니다.',
              statusOf: _calcStatus,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 상단 필터 칩 ----------
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
          duration: const Duration(milliseconds: 120),
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

// ---------- “결과 없음” 배너 ----------
class _NoResultBanner extends StatelessWidget {
  final TodoViewFilter filter;
  const _NoResultBanner({required this.filter});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    String txt;
    switch (filter) {
      case TodoViewFilter.active:    txt = '활성 상태의 공지가 없습니다.'; break;
      case TodoViewFilter.completed: txt = '완료된 공지가 없습니다.'; break;
      case TodoViewFilter.inactive:  txt = '비활성 공지가 없습니다.'; break;
      case TodoViewFilter.all:       txt = '공지 목록이 비어 있습니다.'; break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        border: Border.all(color: const Color(0xFFE6EBF0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: c.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(txt, style: TextStyle(color: c.onSurfaceVariant))),
        ],
      ),
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
        )
        // 상세에서 완료/보관 등 변경했을 수도 있으므로 복귀 시 새로고침하고 싶다면 주석 해제
        .then((_) => (context.mounted) ? context.findAncestorStateOfType<_ManagerTodoStatusPageState>()?._fetch() : null)
            ;
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

  String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {

    print(message);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
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
  final bool isArchived;

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
