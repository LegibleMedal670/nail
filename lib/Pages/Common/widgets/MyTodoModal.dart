import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/MyTodoPage.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/UserProvider.dart';

/// 로그인 직후 호출: 읽지 않은 활성 TODO가 있으면 리스트형 모달을 띄움.
/// - barrierDismissible=false
/// - “자세히 보기” → (전체 ACK) 모달 닫고 페이지 이동
/// - “모두 확인”   → (전체 ACK) 모달 닫기
Future<void> showMyTodosModalIfNeeded(BuildContext context) async {
  final user = context.read<UserProvider>().current;
  final loginKey = user?.loginKey ?? '';
  if (loginKey.isEmpty) return;

  List<Map<String, dynamic>> items = [];
  try {
    items = await TodoService.instance.listMyUnreadActiveTodos(loginKey: loginKey);
  } catch (_) {
    return; // 조용히 실패
  }
  if (items.isEmpty) return;

  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TodoModal(
      initialItems: items,
      onOpenPageAfterAckAll: () {
        Navigator.pop(context); // 모달 닫고
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyTodoPage()));
      },
    ),
  );
}

class _TodoModal extends StatefulWidget {
  final List<Map<String, dynamic>> initialItems;
  final VoidCallback onOpenPageAfterAckAll;
  const _TodoModal({required this.initialItems, required this.onOpenPageAfterAckAll});

  @override
  State<_TodoModal> createState() => _TodoModalState();
}

class _TodoModalState extends State<_TodoModal> {
  late List<Map<String, dynamic>> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(widget.initialItems);
  }

  Future<void> _ackAllAndClose({required bool goToPage}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
      // 일괄 ACK (실패 항목이 있어도 계속 진행)
      for (final m in List<Map<String, dynamic>>.from(_items)) {
        try {
          await TodoService.instance.acknowledgeTodo(
            loginKey: loginKey,
            groupId: '${m['group_id']}',
          );
        } catch (_) {
          // 항목 단건 실패는 스킵(일괄 처리 성격상 전체 플로우 중단하지 않음)
        }
      }
      if (!mounted) return;
      if (goToPage) {
        widget.onOpenPageAfterAckAll();
      } else {
        Navigator.pop(context); // 모달만 닫기
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _items.length;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            const SizedBox(height: 16),
            const _ModalHeader(),
            const SizedBox(height: 8),
            // Sub-title with count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '읽지 않은 항목 $itemCount건',
                    style: TextStyle(
                      color: UiTokens.title.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _items.isEmpty
                    ? const Center(child: Text('표시할 항목이 없습니다.'))
                    : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = _items[i];
                    final title = (m['title'] ?? '').toString();
                    final createdBy = (m['created_by_role'] ?? 'admin').toString();
                    final audience = (m['audience'] ?? 'mentee').toString();

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE6EBF0)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              _RoleBadge(role: createdBy),
                              const SizedBox(width: 8),
                              _AudienceChip(audience: audience),
                            ]),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                color: UiTokens.title,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Bottom action bar
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _ackAllAndClose(goToPage: true),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('자세히 보기', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _ackAllAndClose(goToPage: false),
                      style: FilledButton.styleFrom(
                        backgroundColor: UiTokens.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('모두 확인', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 56, height: 56,
          decoration: const BoxDecoration(color: Color(0xFFEAF3FF), shape: BoxShape.circle),
          child: const Icon(Icons.info_outline, color: UiTokens.primaryBlue, size: 30),
        ),
        const SizedBox(height: 10),
        const Text(
          '새로운 안내가 있습니다',
          style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 10),
        Text(
          '아래 항목을 확인하세요',
          style: TextStyle(color: UiTokens.title.withOpacity(0.7), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role; // 'admin'|'mentor'
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
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  final String audience; // 'all'|'mentor'|'mentee'
  const _AudienceChip({required this.audience});

  @override
  Widget build(BuildContext context) {
    final label = audience == 'all' ? '전체' : (audience == 'mentor' ? '멘토' : '멘티');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
      child: Text('$label 공지', style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}
