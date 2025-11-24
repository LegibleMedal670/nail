import 'package:flutter/material.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/UserProvider.dart';

enum MyTodoFilter { notDone, all, done }

extension _F on MyTodoFilter {
  String get label {
    switch (this) {
      case MyTodoFilter.notDone:
        return '미완료';
      case MyTodoFilter.all:
        return '전체'; // = active
      case MyTodoFilter.done:
        return '완료';
    }
  }

  String get param {
    switch (this) {
      case MyTodoFilter.notDone:
        return 'not_done';
      case MyTodoFilter.all:
        return 'active'; // ✅ 전체는 활성 목록과 동일
      case MyTodoFilter.done:
        return 'done';
    }
  }
}

class MyTodoPage extends StatelessWidget {
  const MyTodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '내 TODO',
          style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UiTokens.title),
          tooltip: '뒤로가기',
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: const [
          _MyTodoActionBar(),
          SizedBox(width: 4),
        ],
      ),
      body: const MyTodoView(embedded: false),
    );
  }
}

/// 임베디드/단독 모두에서 재사용 가능한 TODO 본문 뷰
class MyTodoView extends StatefulWidget {
  final bool embedded; // true면 AppBar 외부에서 포함되는 탭 본문 용도
  const MyTodoView({super.key, required this.embedded});

  @override
  State<MyTodoView> createState() => MyTodoViewState();
}

class MyTodoViewState extends State<MyTodoView> {
  bool _loading = true;
  String? _error;
  MyTodoFilter _filter = MyTodoFilter.notDone;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
      final rows = await TodoService.instance.listMyTodos(
        loginKey: loginKey,
        filter: _filter.param,
      );
      setState(() => _items = rows);
    } catch (e) {
      setState(() => _error = '불러오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleDone(Map<String, dynamic> m) async {
    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    final groupId = '${m['group_id']}';
    final bool toDone = m['done_at'] == null;
    try {
      await TodoService.instance.setMyTodoDone(
        loginKey: loginKey,
        groupId: groupId,
        done: toDone,
      );
      await _load(); // 간단하게 전체 재조회
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('변경 실패: $e')));
    }
  }

  Future<void> _ackNow(Map<String, dynamic> m) async {
    if (m['ack_at'] != null) return;
    final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
    final groupId = '${m['group_id']}';
    try {
      await TodoService.instance.acknowledgeTodo(
        loginKey: loginKey,
        groupId: groupId,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('확인 실패: $e')));
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<MyTodoFilter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FilterSheet(current: _filter),
    );
    if (result != null && result != _filter) {
      setState(() => _filter = result);
      await _load();
    }
  }

  // ===== 외부 제어용 공개 메서드 =====
  void reload() => _load();
  void openFilterSheet() => _openFilterSheet();

  @override
  Widget build(BuildContext context) {
    final listView =
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _Error(message: _error!, onRetry: _load)
            : RefreshIndicator(
              onRefresh: _load,
              child:
                  _items.isEmpty
                      ? const _Empty(message: '표시할 항목이 없습니다.')
                      : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemBuilder: (_, i) {
                          final m = _items[i];
                          final title = (m['title'] ?? '').toString();
                          final desc = (m['description'] ?? '').toString();
                          final role =
                              (m['created_by_role'] ?? 'admin')
                                  .toString(); // 'admin'|'mentor'
                          final audience =
                              (m['audience'] ?? 'mentee').toString();
                          final bool done = m['done_at'] != null;
                          final bool acked = m['ack_at'] != null;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: UiTokens.cardBorder),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [UiTokens.cardShadow],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _RoleBadge(role: role),
                                      const SizedBox(width: 8),
                                      _AudienceChip(audience: audience),
                                      const Spacer(),
                                      if (done)
                                        const _StateBadge(
                                          label: '완료',
                                          color: Color(0xFF059669),
                                          bg: Color(0xFFECFDF5),
                                          border: Color(0xFFA7F3D0),
                                        )
                                      else if (acked)
                                        const _StateBadge(
                                          label: '확인',
                                          color: Color(0xFF2563EB),
                                          bg: Color(0xFFEFF6FF),
                                          border: Color(0xFFBFDBFE),
                                        )
                                      else
                                        const _StateBadge(
                                          label: '미확인',
                                          color: Color(0xFFB45309),
                                          bg: Color(0xFFFFFBEB),
                                          border: Color(0xFFFEF3C7),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: UiTokens.title,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (desc.isNotEmpty)
                                    Text(
                                      desc,
                                      style: TextStyle(
                                        color: UiTokens.title.withOpacity(
                                          0.75,
                                        ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed:
                                              acked ? null : () => _ackNow(m),
                                          child: const Text(
                                            '확인',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () => _toggleDone(m),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                done
                                                    ? const Color(0xFF64748B)
                                                    : UiTokens.primaryBlue,
                                          ),
                                          child: Text(
                                            done ? '완료 해제' : '완료',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder:
                            (_, __) => const SizedBox(height: 10),
                        itemCount: _items.length,
                      ),
            );

    // if (widget.embedded) {
    //   return Column(
    //     children: [
    //       // 내장 상단 필터/새로고침 바
    //       Padding(
    //         padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    //         child: Row(
    //           children: [
    //             TextButton.icon(
    //               onPressed: _openFilterSheet,
    //               icon: const Icon(Icons.filter_list_rounded, color: UiTokens.actionIcon, size: 18),
    //               label: Text(
    //                 _filter.label,
    //                 style: const TextStyle(color: UiTokens.actionIcon, fontWeight: FontWeight.w700),
    //               ),
    //             ),
    //             const Spacer(),
    //             IconButton(
    //               icon: const Icon(Icons.refresh_rounded, color: UiTokens.actionIcon),
    //               tooltip: '새로고침',
    //               onPressed: _load,
    //             ),
    //           ],
    //         ),
    //       ),
    //       Expanded(child: listView),
    //     ],
    //   );
    // }

    // 단독 모드에서는 상단 AppBar를 페이지에서 소유
    return listView;
  }
}

/// 단독 페이지 AppBar 액션 영역
class _MyTodoActionBar extends StatelessWidget {
  const _MyTodoActionBar();

  @override
  Widget build(BuildContext context) {
    // 단독 페이지에서만 사용: 필터/새로고침
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.filter_list_rounded, color: UiTokens.title),
          onPressed: () {
            final state = context.findAncestorStateOfType<MyTodoViewState>();
            state?.openFilterSheet();
          },
          tooltip: '필터',
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: UiTokens.title),
          onPressed: () {
            final state = context.findAncestorStateOfType<MyTodoViewState>();
            state?.reload();
          },
          tooltip: '새로고침',
        ),
      ],
    );
  }
}

class _FilterSheet extends StatelessWidget {
  final MyTodoFilter current;

  const _FilterSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final options = MyTodoFilter.values;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '필터',
              style: TextStyle(
                color: UiTokens.title,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            ...options.map(
              (f) => ListTile(
                leading: Icon(
                  f == MyTodoFilter.done
                      ? Icons.done_all_rounded
                      : (f == MyTodoFilter.notDone
                          ? Icons.hourglass_bottom_rounded
                          : Icons
                              .visibility_rounded // '전체' = active
                              ),
                  color: UiTokens.actionIcon,
                ),
                title: Text(
                  f.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing:
                    (f == current)
                        ? const Icon(Icons.check, color: UiTokens.primaryBlue)
                        : const SizedBox.shrink(),
                onTap: () => Navigator.pop(context, f),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final Color border;

  const _StateBadge({
    required this.label,
    required this.color,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
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

class _AudienceChip extends StatelessWidget {
  final String audience; // 'all'|'mentor'|'mentee'
  const _AudienceChip({required this.audience});

  @override
  Widget build(BuildContext context) {
    final label =
        audience == 'all' ? '전체' : (audience == 'mentor' ? '멘토' : '멘티');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label 공지',
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;

  const _Empty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Text(
          message,
          style: TextStyle(
            color: UiTokens.title.withOpacity(0.6),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
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
