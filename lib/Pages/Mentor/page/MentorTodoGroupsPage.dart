// lib/Pages/Mentor/page/MentorTodoGroupsPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Mentor/page/MentorTodoCreatePage.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/MentorProvider.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:nail/Pages/Mentor/page/MentorTodoGroupDetailPage.dart';

enum _ViewFilter { active, completed, inactive, all }
enum _Audience { all, mentor, mentee }

class MentorTodoGroupsPage extends StatefulWidget {
  const MentorTodoGroupsPage({super.key});

  @override
  State<MentorTodoGroupsPage> createState() => _MentorTodoGroupsPageState();
}

class _MentorTodoGroupsPageState extends State<MentorTodoGroupsPage> {
  _ViewFilter _filter = _ViewFilter.active;

  bool _loading = false;
  String? _error;

  /// 서버에서 받아온 전체 그룹(캐시)
  List<_GroupVm> _rowsAll = const [];

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
      final loginKey = context.read<MentorProvider>().mentorLoginKey.trim();
      if (loginKey.isEmpty) {
        setState(() {
          _loading = false;
          _error = '로그인이 필요합니다. (mentorLoginKey 없음)';
        });
        return;
      }

      // ✅ 항상 'all'로 받아 캐시, 화면에서만 필터 적용 (관리자 UI와 동일 전략)
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

  _GroupVm _mapRowToVm(Map<String, dynamic> m) {
    final audStr = (m['audience'] ?? 'mentee').toString();
    final aud = switch (audStr) {
      'all' => _Audience.all,
      'mentor' => _Audience.mentor,
      _ => _Audience.mentee,
    };

    DateTime createdAt;
    final ca = m['created_at'];
    if (ca is DateTime) {
      createdAt = ca;
    } else {
      createdAt = DateTime.tryParse(ca?.toString() ?? '') ?? DateTime.now();
    }

    return _GroupVm(
      id: (m['group_id'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      audience: aud,
      createdAt: createdAt,
      isArchived: m['is_archived'] == true,
      totalCount: int.tryParse('${m['total_count'] ?? 0}') ?? 0,
      doneCount: int.tryParse('${m['done_count'] ?? 0}') ?? 0,
      ackCount: int.tryParse('${m['ack_count'] ?? 0}') ?? 0,
    );
  }

  _Status _calcStatus(_GroupVm v) {
    final completed = (v.totalCount > 0) && (v.doneCount == v.totalCount);
    if (v.isArchived) return _Status.inactive;
    return completed ? _Status.completed : _Status.active;
  }

  bool _passByFilter(_GroupVm v) {
    final st = _calcStatus(v);
    switch (_filter) {
      case _ViewFilter.active:
        return st == _Status.active;
      case _ViewFilter.completed:
        return st == _Status.completed;
      case _ViewFilter.inactive:
        return st == _Status.inactive;
      case _ViewFilter.all:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rowsAll.where(_passByFilter).toList();
    final fa = rows.where((e) => e.audience == _Audience.all).toList();
    final fm = rows.where((e) => e.audience == _Audience.mentor).toList();
    final fe = rows.where((e) => e.audience == _Audience.mentee).toList();

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
          // ✅ TODO 생성 (Provider 함께 전달)
          IconButton(
            tooltip: 'TODO 생성',
            icon: const Icon(Icons.add_task_outlined, color: UiTokens.title),
            onPressed: () async {
              final mentorProv = context.read<MentorProvider>();
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider<MentorProvider>.value(
                    value: mentorProv,                // <- 현재 트리의 같은 인스턴스 주입
                    child: const MentorTodoCreatePage(),
                  ),
                ),
              );
              if (created == true && mounted) {
                await _fetch();                       // 생성 후 목록 새로고침
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _fetch)
          : RefreshIndicator(
        color: UiTokens.primaryBlue,
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _FilterChips(
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 12),
            if (fa.isEmpty && fm.isEmpty && fe.isEmpty)
              _NoResultBanner(filter: _filter),

            _AudienceSection(
              title: '멘티 공지',
              icon: Icons.people_outline,
              items: fe,
              emptyHint: '해당 상태의 멘티 공지가 없습니다.',
              statusOf: _calcStatus,
              onOpen: _openDetail,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(_GroupVm vm) async {
    final mentorProv = context.read<MentorProvider>(); // 현재 인스턴스 가져오기
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<MentorProvider>.value(
          value: mentorProv, // 같은 인스턴스 주입
          child: MentorTodoGroupDetailPage(
            groupId: vm.id,
            title: vm.title,
            audienceStr: switch (vm.audience) {
              _Audience.all => 'all',
              _Audience.mentor => 'mentor',
              _Audience.mentee => 'mentee',
            },
          ),
        ),
      ),
    );
    if (refreshed == true && mounted) {
      await _fetch();
    }
  }
}

// ---------- 상단 필터 칩 (관리자 UI와 동일 스타일) ----------
class _FilterChips extends StatelessWidget {
  final _ViewFilter value;
  final ValueChanged<_ViewFilter> onChanged;
  const _FilterChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    Widget chip({
      required _ViewFilter v,
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
        chip(v: _ViewFilter.active,    label: '활성',   icon: Icons.play_circle_outline,  color: UiTokens.primaryBlue),
        chip(v: _ViewFilter.completed, label: '완료',   icon: Icons.check_circle_outlined, color: Colors.teal),
        chip(v: _ViewFilter.inactive,  label: '비활성', icon: Icons.pause_circle_outline,  color: Colors.grey),
        chip(v: _ViewFilter.all,       label: '전체',   icon: Icons.all_inclusive,         color: c.primary),
      ],
    );
  }
}

// ---------- “결과 없음” 배너 ----------
class _NoResultBanner extends StatelessWidget {
  final _ViewFilter filter;
  const _NoResultBanner({required this.filter});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    String txt;
    switch (filter) {
      case _ViewFilter.active:    txt = '활성 상태의 공지가 없습니다.'; break;
      case _ViewFilter.completed: txt = '완료된 공지가 없습니다.'; break;
      case _ViewFilter.inactive:  txt = '비활성 공지가 없습니다.'; break;
      case _ViewFilter.all:       txt = '공지 목록이 비어 있습니다.'; break;
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

enum _Status { active, completed, inactive }

// ---------- 섹션 + 카드 ----------
class _AudienceSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_GroupVm> items;
  final String emptyHint;
  final _Status Function(_GroupVm) statusOf;
  final void Function(_GroupVm) onOpen;

  const _AudienceSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyHint,
    required this.statusOf,
    required this.onOpen,
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
            itemBuilder: (_, i) => _GroupCard(vm: items[i], status: statusOf(items[i]), onOpen: () => onOpen(items[i])),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
          ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final _GroupVm vm;
  final _Status status;
  final VoidCallback onOpen;
  const _GroupCard({required this.vm, required this.status, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final double doneRate = vm.totalCount == 0 ? 0 : vm.doneCount / vm.totalCount;
    final double ackRate = vm.totalCount == 0 ? 0 : vm.ackCount / vm.totalCount;

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
      onTap: onOpen,
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
                        vm.title.isEmpty ? '(제목 없음)' : vm.title,
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

class _GroupVm {
  final String id;
  final String title;
  final _Audience audience;
  final DateTime createdAt;
  final bool isArchived;
  final int totalCount;
  final int doneCount;
  final int ackCount;

  _GroupVm({
    required this.id,
    required this.title,
    required this.audience,
    required this.createdAt,
    required this.isArchived,
    required this.totalCount,
    required this.doneCount,
    required this.ackCount,
  });
}
