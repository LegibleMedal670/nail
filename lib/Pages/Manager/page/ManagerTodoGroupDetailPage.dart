// lib/Pages/Manager/page/todo/ManagerTodoGroupDetailPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/TodoTypes.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Providers/UserProvider.dart';

class ManagerTodoGroupDetailPage extends StatefulWidget {
  final String groupId;
  final String title;           // 네비게이션 직후 즉시 표시용(서버 로드 전 임시)
  final TodoAudience audience;  // 네비게이션 직후 즉시 표시용(서버 로드 전 임시)

  const ManagerTodoGroupDetailPage({
    super.key,
    required this.groupId,
    required this.title,
    required this.audience,
  });

  @override
  State<ManagerTodoGroupDetailPage> createState() => _ManagerTodoGroupDetailPageState();
}

class _ManagerTodoGroupDetailPageState extends State<ManagerTodoGroupDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  bool _loading = false;
  String? _error;

  // ── 요약(서버) ───────────────────────────────────────────
  String _title = '';
  String _description = '';
  TodoAudience _audience = TodoAudience.mentee;
  bool _isArchived = false;
  int _total = 0;
  int _done = 0;
  int _notDone = 0;
  int _notAck = 0;

  // ── 탭 리스트(최초 진입 시 모두 로드) ─────────────────────
  List<_AssigneeVm> _doneItems = const [];
  List<_AssigneeVm> _notDoneItems = const [];
  List<_AssigneeVm> _notAckItems = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    // 서버 로드 전 임시 표시
    _title = widget.title;
    _audience = widget.audience;

    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAll());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
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

      // 요약 + 3탭 병렬 로드
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

      // ── 요약 바인딩 ──
      final audienceStr = (summary['audience'] ?? 'mentee').toString();
      final audience = switch (audienceStr) {
        'all' => TodoAudience.all,
        'mentor' => TodoAudience.mentor,
        _ => TodoAudience.mentee,
      };

      final total = int.tryParse('${summary['total_count'] ?? 0}') ?? 0;
      final done = int.tryParse('${summary['done_count'] ?? 0}') ?? 0;
      final ack  = int.tryParse('${summary['ack_count'] ?? 0}') ?? 0;

      // ── 리스트 매핑 ──
      List<_AssigneeVm> mapRows(List<Map<String, dynamic>> rows) {
        return rows.map((m) {
          final nick = (m['nickname'] ?? '').toString();
          final isMentor = m['is_mentor'] == true;

          DateTime? ackAt;
          final a = m['ack_at'];
          if (a is DateTime) {
            ackAt = a;
          } else if (a != null) {
            ackAt = DateTime.tryParse(a.toString());
          }
          final doneAt = m['done_at'];
          final isDone = doneAt != null;

          return _AssigneeVm(
            name: nick.isEmpty ? '(이름 없음)' : nick,
            role: isMentor ? '멘토' : '멘티',
            acknowledgedAt: ackAt,
            isDone: isDone,
          );
        }).toList(growable: false);
      }

      setState(() {
        _title = (summary['title'] ?? '').toString();
        _description = (summary['description'] ?? '').toString();
        _audience = audience;
        _isArchived = summary['is_archived'] == true;

        _total = total;
        _done = done;
        _notDone = total - done;
        _notAck = total - ack;

        _doneItems = mapRows(doneRows);
        _notDoneItems = mapRows(notDoneRows);
        _notAckItems = mapRows(notAckRows);
      });
    } catch (e) {
      setState(() => _error = '불러오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── 보관/해제 ──
  Future<void> _confirmToggle() async {
    final toArchived = !_isArchived;
    final title = toArchived ? '이 공지를 비활성화할까요?' : '이 공지를 활성화할까요?';
    final message = toArchived
        ? '현황의 “비활성” 필터에서만 보이게 됩니다.'
        : '현황의 “활성/완료” 필터에서 다시 보이게 됩니다.';
    final confirmText = toArchived ? '비활성화' : '활성화';

    final ok = await _showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
    );
    if (!ok) return;

    try {
      final loginKey = context.read<UserProvider>().adminKey?.trim() ?? '';
      await TodoService.instance.toggleGroupArchive(
        loginKey: loginKey,
        groupId: widget.groupId,
        toArchived: toArchived,
      );
      setState(() => _isArchived = toArchived);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toArchived ? '비활성화되었습니다.' : '활성화되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('변경 실패: $e')),
      );
    }
  }

  // ── 삭제 ──
  Future<void> _confirmDelete() async {
    final ok = await _showConfirmDialog(
      context,
      title: '이 공지를 삭제할까요?',
      message: '모든 수신자 기록(확인/완료)이 함께 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '삭제',
    );
    if (!ok) return;

    try {
      final loginKey = context.read<UserProvider>().adminKey?.trim() ?? '';
      await TodoService.instance.deleteTodoGroup(
        loginKey: loginKey,
        groupId: widget.groupId,
      );
      if (!mounted) return;
      Navigator.pop(context, 'deleted'); // 상위 목록에서 새로고침하도록
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final done = _done;
    final notDone = _notDone;
    final notAck = _notAck;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_shorten(_title), style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700, fontSize: 22),),
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
        onRefresh: _fetchAll,
        child: Column(
          children: [
            _HeaderSummary(
              title: _title,
              description: _description,
              audience: _audience,
              total: total,
              done: done,
              notDone: notDone,
              notAck: notAck,
              isArchived: _isArchived,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _AssigneeList(items: _doneItems),
                  _AssigneeList(items: _notDoneItems),
                  _AssigneeList(items: _notAckItems),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shorten(String s) => s.length > 22 ? '${s.substring(0, 22)}…' : s;
}

// =================== 헤더 요약 + 제목/설명 + 상태 뱃지 ===================

class _HeaderSummary extends StatelessWidget {
  final String title;
  final String description;
  final TodoAudience audience;
  final int total;
  final int done;
  final int notDone;
  final int notAck;
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
    final ackRate = total == 0 ? 0.0 : (total - notAck) / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE6EBF0)),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 제목 + 상태
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? '(제목 없음)' : title,
                    style: const TextStyle(
                      color: UiTokens.title,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(text: isArchived ? '비활성' : '활성', color: isArchived ? Colors.grey : UiTokens.primaryBlue),
              ],
            ),
            const SizedBox(height: 6),

            // 중간: 설명(있을 때만)
            if (description.trim().isNotEmpty)
              Container(
                width: double.infinity,
                // padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  description,
                  style: TextStyle(color: c.onSurface, height: 1.35),
                ),
              ),

            const SizedBox(height: 10),

            // 하단: 대상/요약 수치
            Row(
              children: [
                _SummaryPill(label: '총원', value: '$total'),
                const SizedBox(width: 8),
                _SummaryPill(label: '완료', value: '$done'),
                const SizedBox(width: 8),
                _SummaryPill(label: '미완료', value: '$notDone'),
                const SizedBox(width: 8),
                _SummaryPill(label: '미확인', value: '$notAck'),
              ],
            ),
            const SizedBox(height: 12),
            _LabeledBar(label: '완료율', value: doneRate, valueText: '${(doneRate * 100).round()}%'),
            const SizedBox(height: 6),
            _LabeledBar(label: '확인율', value: ackRate, valueText: '${(ackRate * 100).round()}%'),
          ],
        ),
      ),
    );
  }
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

// =================== 리스트/바 공용 위젯 ===================

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final hasValue = value.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
          if (hasValue) ...[
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

class _LabeledBar extends StatelessWidget {
  final String label;
  final double value;
  final String valueText;
  const _LabeledBar({required this.label, required this.value, required this.valueText});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      children: [
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
      ],
    );
  }
}

class _AssigneeList extends StatelessWidget {
  final List<_AssigneeVm> items;
  const _AssigneeList({required this.items});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Center(child: Text('해당되는 사용자가 없습니다.', style: TextStyle(color: c.onSurfaceVariant))),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemBuilder: (_, i) {
        final it = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE6EBF0)),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Icon(
                it.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: it.isDone ? UiTokens.primaryBlue : c.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.name, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _RoleChip(text: it.role),
                        const SizedBox(width: 8),
                        Icon(Icons.visibility_outlined, size: 14, color: c.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          it.acknowledgedAt == null ? '미확인' : _fmtDateTime(it.acknowledgedAt!),
                          style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: items.length,
    );
  }

  String _fmtDateTime(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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

class _AssigneeVm {
  final String name;
  final String role;
  final DateTime? acknowledgedAt;
  final bool isDone;

  _AssigneeVm({
    required this.name,
    required this.role,
    required this.acknowledgedAt,
    required this.isDone,
  });
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});

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

// =================== 확인 다이얼로그(파란톤) ===================

Future<bool> _showConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      required String confirmText,
    }) async {
  final cs = Theme.of(context).colorScheme;
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
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: badgeBg, shape: BoxShape.circle),
              child: const Icon(Icons.info_outline, size: 30, color: accent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: UiTokens.title,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: UiTokens.title.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: cs.outline.withOpacity(0.4)),
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
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}
