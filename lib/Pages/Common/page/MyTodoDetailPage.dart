import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Providers/UserProvider.dart';

/// 내 TODO 상세 페이지
/// - 제목, 본문, 발행 주체, 완료 여부, 생성일자 표시
/// - 완료하기/완료 취소 버튼
class MyTodoDetailPage extends StatefulWidget {
  final Map<String, dynamic> todoData;

  const MyTodoDetailPage({super.key, required this.todoData});

  @override
  State<MyTodoDetailPage> createState() => _MyTodoDetailPageState();
}

class _MyTodoDetailPageState extends State<MyTodoDetailPage> {
  late Map<String, dynamic> _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.todoData);
  }

  String get _title => (_data['title'] ?? '').toString();
  String get _description => (_data['description'] ?? '').toString();
  String get _role => (_data['created_by_role'] ?? 'admin').toString();
  bool get _isDone => _data['done_at'] != null;
  bool get _isAcked => _data['ack_at'] != null;
  String get _groupId => '${_data['group_id']}';

  DateTime? get _createdAt {
    final raw = _data['created_at'];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    return DateFormat('yyyy.MM.dd HH:mm').format(local);
  }

  Future<void> _toggleDone() async {
    if (_loading) return;
    setState(() => _loading = true);

    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    final toDone = !_isDone;

    try {
      await TodoService.instance.setMyTodoDone(
        loginKey: loginKey,
        groupId: _groupId,
        done: toDone,
      );

      setState(() {
        _data['done_at'] = toDone ? DateTime.now().toIso8601String() : null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toDone ? '완료 처리되었습니다.' : '완료가 취소되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('변경 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _acknowledgeIfNeeded() async {
    if (_isAcked) return;

    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    try {
      await TodoService.instance.acknowledgeTodo(
        loginKey: loginKey,
        groupId: _groupId,
      );
      setState(() {
        _data['ack_at'] = DateTime.now().toIso8601String();
      });
    } catch (_) {
      // 확인 실패는 무시 (다음에 다시 시도)
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 페이지 진입 시 자동 확인 처리
    WidgetsBinding.instance.addPostFrameCallback((_) => _acknowledgeIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'TODO 상세',
          style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UiTokens.title),
          tooltip: '뒤로가기',
          onPressed: () => Navigator.pop(context, _data),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── 상태 배지 영역 ───
                    Row(
                      children: [
                        _RoleBadge(role: _role),
                        const SizedBox(width: 8),
                        _StateBadge(isDone: _isDone, isAcked: _isAcked),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ─── 제목 ───
                    Text(
                      _title.isEmpty ? '(제목 없음)' : _title,
                      style: const TextStyle(
                        color: UiTokens.title,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── 본문 카드 ───
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('본문'),
                          const SizedBox(height: 10),
                          Text(
                            _description.isEmpty ? '내용이 없습니다.' : _description,
                            style: TextStyle(
                              color: _description.isEmpty
                                  ? UiTokens.title.withOpacity(0.5)
                                  : UiTokens.title.withOpacity(0.85),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── 정보 카드 ───
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('정보'),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: '생성일',
                            value: _formatDateTime(_createdAt),
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: _role == 'admin'
                                ? Icons.shield_outlined
                                : Icons.school_outlined,
                            label: '발행 주체',
                            value: _role == 'admin' ? '관리자' : '담당 멘토',
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: _isDone
                                ? Icons.check_circle_outline
                                : Icons.hourglass_bottom_outlined,
                            label: '상태',
                            value: _isDone
                                ? '완료'
                                : (_isAcked ? '확인됨 (미완료)' : '미확인'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── 하단 버튼 ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _toggleDone,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _isDone ? const Color(0xFFF1F5F9) : UiTokens.primaryBlue,
                    foregroundColor: _isDone ? UiTokens.title : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isDone ? '완료 취소' : '완료하기',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 내부 위젯들
// ═══════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [UiTokens.cardShadow],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: UiTokens.title,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: UiTokens.actionIcon),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: UiTokens.title.withOpacity(0.6),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: UiTokens.title,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    final bg = isAdmin ? const Color(0xFFEEF2FF) : const Color(0xFFECFDF5);
    final border = isAdmin ? const Color(0xFFCBD5FE) : const Color(0xFFA7F3D0);
    final fg = isAdmin ? const Color(0xFF4338CA) : const Color(0xFF059669);
    final label = isAdmin ? '관리자' : '담당 멘토';
    final icon = isAdmin ? Icons.shield_outlined : Icons.school_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  final bool isDone;
  final bool isAcked;

  const _StateBadge({required this.isDone, required this.isAcked});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color, bg, border;

    if (isDone) {
      label = '완료';
      color = const Color(0xFF059669);
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
    } else if (isAcked) {
      label = '확인';
      color = const Color(0xFF2563EB);
      bg = const Color(0xFFEFF6FF);
      border = const Color(0xFFBFDBFE);
    } else {
      label = '미확인';
      color = const Color(0xFFB45309);
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFEF3C7);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
