// lib/Pages/Manager/page/todo/ManagerTodoGroupDetailPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/TodoTypes.dart';
import 'package:nail/Pages/Manager/page/ManagerTodoStatusPage.dart';

class ManagerTodoGroupDetailPage extends StatefulWidget {
  final String groupId;
  final String title;
  final TodoAudience audience;

  const ManagerTodoGroupDetailPage({
    super.key,
    required this.groupId,
    required this.title,
    required this.audience,
  });

  @override
  State<ManagerTodoGroupDetailPage> createState() => _ManagerTodoGroupDetailPageState();
}

class _ManagerTodoGroupDetailPageState extends State<ManagerTodoGroupDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // 데모 상태(서버 연동 시 제거/치환): false=활성, true=비활성(보관)
  bool _isArchived = false;

  // TODO: Service 연동으로 교체
  final List<_AssigneeVm> _done = [
    _AssigneeVm(name: '홍길동', role: '멘티', acknowledgedAt: DateTime.now().subtract(const Duration(hours: 3)), isDone: true),
    _AssigneeVm(name: '김멘토', role: '멘토', acknowledgedAt: DateTime.now().subtract(const Duration(hours: 5)), isDone: true),
  ];
  final List<_AssigneeVm> _notDone = [
    _AssigneeVm(name: '이아직', role: '멘티', acknowledgedAt: DateTime.now().subtract(const Duration(hours: 1)), isDone: false),
  ];
  final List<_AssigneeVm> _notAck = [
    _AssigneeVm(name: '박미열람', role: '멘티', acknowledgedAt: null, isDone: false),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _done.length + _notDone.length + _notAck.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _shorten(widget.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700, fontSize: 20),
        ),
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
            tooltip: _isArchived ? '활성으로 전환' : '비활성으로 전환',
            icon: Icon( _isArchived ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: UiTokens.title),
            onPressed: _confirmToggle, // ✔ 바로 모달
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: UiTokens.primaryBlue,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: UiTokens.primaryBlue,
          tabs: [
            Tab(text: '완료(${_done.length})'),
            Tab(text: '미완료(${_notDone.length})'),
            Tab(text: '미확인(${_notAck.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _HeaderSummary(
            audience: widget.audience,
            total: total,
            done: _done.length,
            notDone: _notDone.length,
            notAck: _notAck.length,
            isArchived: _isArchived,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _AssigneeList(items: _done),
                _AssigneeList(items: _notDone),
                _AssigneeList(items: _notAck),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ⋮ → 확인 모달 → 토글
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

    // TODO: 서버 연동
    // final success = await rpc.toggleArchive(groupId: widget.groupId, toArchived: toArchived);
    // if (!success) { 에러 스낵바; return; }

    setState(() => _isArchived = toArchived);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(toArchived ? '비활성화되었습니다.' : '활성화되었습니다.')),
    );
  }

  String _shorten(String s) => s.length > 22 ? '${s.substring(0, 22)}…' : s;
}

// =================== 헤더 요약 + 상태 뱃지 ===================

class _HeaderSummary extends StatelessWidget {
  final TodoAudience audience;
  final int total;
  final int done;
  final int notDone;
  final int notAck;
  final bool isArchived;

  const _HeaderSummary({
    required this.audience,
    required this.total,
    required this.done,
    required this.notDone,
    required this.notAck,
    required this.isArchived,
  });

  String get _audienceLabel {
    switch (audience) {
      case TodoAudience.all:
        return '전체 공지';
      case TodoAudience.mentor:
        return '멘토 공지';
      case TodoAudience.mentee:
        return '멘티 공지';
    }
  }

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
            Row(
              children: [
                Text(_audienceLabel, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                _StatusChip(text: isArchived ? '비활성' : '활성', color: isArchived ? Colors.grey : UiTokens.primaryBlue),
              ],
            ),
            const SizedBox(height: 8),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
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
      return Center(
        child: Text('해당되는 사용자가 없습니다.', style: TextStyle(color: c.onSurfaceVariant)),
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

// =================== 확인 다이얼로그(파란톤, 프로젝트 스타일) ===================

Future<bool> _showConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      required String confirmText,
    }) async {
  final cs = Theme.of(context).colorScheme;
  const Color accent = UiTokens.primaryBlue; // ✔ 항상 파란색
  const Color badgeBg = Color(0xFFEAF3FF);
  final IconData usedIcon = confirmText.contains('비활성') ? Icons.pause_circle_outline : Icons.play_circle_outline;

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
            // 상단 아이콘 배지
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: badgeBg, shape: BoxShape.circle),
              child: const Icon( // 색상만 파랑으로
                Icons.info_outline,
                size: 30,
                color: accent,
              ),
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
