import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/widgets/SortBottomSheet.dart';
import 'package:nail/Providers/MentorProvider.dart';
import 'package:nail/Services/TodoService.dart';

enum _MembersTab { done, notDone, notAck }

class MentorTodoGroupDetailPage extends StatefulWidget {
  final String groupId;
  final String title;       // 네비게이션 즉시 표시용(서버 로드 전)
  final String audienceStr; // 'all'|'mentor'|'mentee'

  const MentorTodoGroupDetailPage({
    super.key,
    required this.groupId,
    required this.title,
    required this.audienceStr,
  });

  @override
  State<MentorTodoGroupDetailPage> createState() => _MentorTodoGroupDetailPageState();
}

class _MentorTodoGroupDetailPageState extends State<MentorTodoGroupDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  bool _loading = false;
  String? _error;

  bool _dirty = false;

  // 요약
  String _title = '';
  String _description = '';
  String _audience = 'mentee';
  bool _isArchived = false;
  int _total = 0, _done = 0, _notDone = 0, _notAck = 0;

  // 탭 리스트
  List<_MemberVm> _doneItems = const [];
  List<_MemberVm> _notDoneItems = const [];
  List<_MemberVm> _notAckItems = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _title = widget.title;
    _audience = widget.audienceStr;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAll());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final loginKey = context.read<MentorProvider>().mentorLoginKey;

      final results = await Future.wait([
        TodoService.instance.getTodoGroupSummary(loginKey: loginKey, groupId: widget.groupId),
        TodoService.instance.getTodoGroupMembers(loginKey: loginKey, groupId: widget.groupId, tab: 'done'),
        TodoService.instance.getTodoGroupMembers(loginKey: loginKey, groupId: widget.groupId, tab: 'not_done'),
        TodoService.instance.getTodoGroupMembers(loginKey: loginKey, groupId: widget.groupId, tab: 'not_ack'),
      ]);

      final summary = (results[0] as Map).cast<String, dynamic>();
      final doneRows = (results[1] as List).cast<Map<String, dynamic>>();
      final notDoneRows = (results[2] as List).cast<Map<String, dynamic>>();
      final notAckRows = (results[3] as List).cast<Map<String, dynamic>>();

      List<_MemberVm> map(List<Map<String, dynamic>> rows) {
        return rows.map((m) {
          DateTime? ackAt;
          final ack = m['ack_at'];
          if (ack is DateTime) ackAt = ack; else if (ack != null) ackAt = DateTime.tryParse('$ack');
          return _MemberVm(
            name: '${m['nickname'] ?? '(이름 없음)'}',
            role: m['is_mentor'] == true ? '멘토' : '멘티',
            ackAt: ackAt,
            isDone: m['done_at'] != null,
          );
        }).toList(growable: false);
      }

      final audience = (summary['audience'] ?? 'mentee').toString();
      final total = int.tryParse('${summary['total_count'] ?? 0}') ?? 0;
      final done  = int.tryParse('${summary['done_count']  ?? 0}') ?? 0;
      final ack   = int.tryParse('${summary['ack_count']   ?? 0}') ?? 0;

      setState(() {
        _title = (summary['title'] ?? '').toString();
        _description = (summary['description'] ?? '').toString();
        _audience = audience;
        _isArchived = summary['is_archived'] == true;

        _total = total;
        _done = done;
        _notDone = total - done;
        _notAck = total - ack;

        _doneItems    = map(doneRows);
        _notDoneItems = map(notDoneRows);
        _notAckItems  = map(notAckRows);
      });
    } catch (e) {
      print(e);
      setState(() { _error = '불러오기 실패: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _confirmToggle() async {
    final toArchived = !_isArchived;
    final ok = await _showConfirmDialog(
      context,
      title: toArchived ? '이 공지를 비활성화할까요?' : '이 공지를 활성화할까요?',
      message: toArchived ? '현황의 “비활성” 필터에서만 보이게 됩니다.' : '현황의 “활성/완료” 필터에서 다시 보이게 됩니다.',
      confirmText: toArchived ? '비활성화' : '활성화',
    );
    if (!ok) return;

    try {
      final loginKey = context.read<MentorProvider>().mentorLoginKey;
      await TodoService.instance.toggleGroupArchive(
        loginKey: loginKey,
        groupId: widget.groupId,
        toArchived: toArchived,
      );
      setState(() {
        _isArchived = toArchived;
        _dirty = true;            // ✅ 변경됨 표시
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toArchived ? '비활성화되었습니다.' : '활성화되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('변경 실패: $e')));
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await _showConfirmDialog(
      context,
      title: '이 공지를 삭제할까요?',
      message: '모든 수신자 기록(확인/완료)이 함께 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '삭제',
    );
    if (!ok) return;

    try {
      final loginKey = context.read<MentorProvider>().mentorLoginKey;
      await TodoService.instance.deleteTodoGroup(
        loginKey: loginKey,
        groupId: widget.groupId,
      );
      if (!mounted) return;
      Navigator.pop(context, true); // 리스트에서 새로고침
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _done; final notDone = _notDone; final notAck = _notAck;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _dirty);      // 변경 여부 반환
        return false;                        // 우리가 pop 처리했으니 false
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_shorten(_title), style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700, fontSize: 22)),
          backgroundColor: Colors.white, elevation: 0, centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: UiTokens.title),
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            IconButton(
              tooltip: '그룹 삭제',
              icon: const Icon(Icons.delete_outline, color: UiTokens.title),
              onPressed: _confirmDelete,
            ),
            IconButton(
              tooltip: _isArchived ? '활성으로 전환' : '비활성으로 전환',
              icon: Icon(_isArchived ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: UiTokens.title),
              onPressed: _confirmToggle,
            ),
          ],
          bottom: TabBar(
            controller: _tab,
            labelColor: UiTokens.primaryBlue,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: UiTokens.primaryBlue,
            tabs: [
              Tab(text: '완료($done)'),
              Tab(text: '미완료($notDone)'),
              Tab(text: '미확인($notAck)'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _Error(message: _error!, onRetry: _fetchAll)
            : RefreshIndicator(
          color: UiTokens.primaryBlue,
          onRefresh: _fetchAll,
          child: Column(
            children: [
              _HeaderSummary(
                title: _title,
                description: _description,
                audience: _audience,
                total: _total,
                done: _done,
                notDone: _notDone,
                notAck: _notAck,
                isArchived: _isArchived,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _MemberList(items: _doneItems),
                    _MemberList(items: _notDoneItems),
                    _MemberList(items: _notAckItems),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shorten(String s) => s.length > 22 ? '${s.substring(0, 22)}…' : s;
}

// ===== 헤더 요약 =====

class _HeaderSummary extends StatelessWidget {
  final String title;
  final String description;
  final String audience;
  final int total, done, notDone, notAck;
  final bool isArchived;

  const _HeaderSummary({
    required this.title,
    required this.description,
    required this.audience,
    required this.total,
    required this.done,
    required this.notDone,
    required this.notAck,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final doneRate = total == 0 ? 0.0 : done / total;
    final ackRate  = total == 0 ? 0.0 : (total - notAck) / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE6EBF0)),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 제목 + 상태
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(
                title.isEmpty ? '(제목 없음)' : title,
                style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800, fontSize: 18, height: 1.25),
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(text: isArchived ? '비활성' : '활성',
                color: isArchived ? Colors.grey : UiTokens.primaryBlue),
          ]),
          const SizedBox(height: 6),

          if (description.trim().isNotEmpty)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
              child: Text(description, style: TextStyle(color: c.onSurface, height: 1.35)),
            ),

          const SizedBox(height: 10),
          Row(
            children: [
              _MiniPill(label: '총원', value: '$total'),
              const SizedBox(width: 8),
              _MiniPill(label: '완료', value: '$done'),
              const SizedBox(width: 8),
              _MiniPill(label: '미완료', value: '$notDone'),
              const SizedBox(width: 8),
              _MiniPill(label: '미확인', value: '$notAck'),
            ],
          ),
          const SizedBox(height: 12),
          _LabeledBar(label: '완료율', value: doneRate, valueText: '${(doneRate * 100).round()}%'),
          const SizedBox(height: 6),
          _LabeledBar(label: '확인율', value: ackRate, valueText: '${(ackRate * 100).round()}%'),
        ]),
      ),
    );
  }
}

// ===== 리스트(멤버) =====

class _MemberVm {
  final String name;
  final String role;
  final DateTime? ackAt;
  final bool isDone;
  _MemberVm({required this.name, required this.role, required this.ackAt, required this.isDone});
}

class _MemberList extends StatelessWidget {
  final List<_MemberVm> items;
  const _MemberList({required this.items});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [Center(child: Text('해당되는 사용자가 없습니다.', style: TextStyle(color: c.onSurfaceVariant)))],
      );
    }

    String fmt(DateTime d) =>
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final it = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE6EBF0)),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(children: [
            Icon(it.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: it.isDone ? UiTokens.primaryBlue : c.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.name, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(children: [
                  _RoleChip(text: it.role),
                  const SizedBox(width: 8),
                  Icon(Icons.visibility_outlined, size: 14, color: c.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(it.ackAt == null ? '미확인' : fmt(it.ackAt!),
                      style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ===== 공용 작은 위젯 =====

class _MiniPill extends StatelessWidget {
  final String label; final String value;
  const _MiniPill({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _LabeledBar extends StatelessWidget {
  final String label; final double value; final String valueText;
  const _LabeledBar({required this.label, required this.value, required this.valueText});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(children: [
      SizedBox(width: 48, child: Text(label, style: TextStyle(color: c.onSurfaceVariant, fontSize: 12))),
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
      SizedBox(width: 56, child: Text(valueText, textAlign: TextAlign.right, style: TextStyle(color: c.onSurfaceVariant, fontSize: 12))),
    ]);
  }
}

class _RoleChip extends StatelessWidget {
  final String text;
  const _RoleChip({required this.text});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: c.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}


class _StatusChip extends StatelessWidget {
  final String text; final Color color;
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    );
  }
}

class _Error extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
          child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

// 파란톤 확인 다이얼로그(관리자 버전 재사용)
Future<bool> _showConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      required String confirmText,
    }) async {
  const Color accent = UiTokens.primaryBlue;
  const Color badgeBg = Color(0xFFEAF3FF);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 56, height: 56, decoration: const BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                child: const Icon(Icons.info_outline, size: 30, color: accent)),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center,
                style: const TextStyle(color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800, height: 1.25)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: TextStyle(color: UiTokens.title.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.4)),
                    backgroundColor: const Color(0xFFF5F7FA),
                  ),
                  child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w800, color: UiTokens.title)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
  return result == true;
}
