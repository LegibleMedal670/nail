// lib/Pages/Manager/page/todo/ManagerTodoGroupDetailPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/TodoTypes.dart';
import 'package:nail/Pages/Manager/page/ManagerTodoStatusPage.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Providers/UserProvider.dart';

class ManagerTodoGroupDetailPage extends StatefulWidget {
  final String groupId;
  final String title;          // 진입 시 전달된 제목(요약용) – 서버 요약에서 최신값 다시 씀
  final TodoAudience audience; // 진입 시 전달된 대상(요약용)

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

  // ------ 로딩/에러 ------
  bool _loadingSummary = false;
  bool _loadingMembers = false;
  String? _errSummary;
  String? _errMembers;

  // ------ 서버 데이터 ------
  _GroupSummaryVm? _summary; // 요약
  List<_AssigneeVm> _done = const [];
  List<_AssigneeVm> _notDone = const [];
  List<_AssigneeVm> _notAck = const [];

  // 현재 탭 인덱스 편의
  int get _tabIndex => _tab.index;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchSummary();
      // 최초에는 현재 탭(0=done) 말고, UX 상 미완료/미확인이 더 유용하므로 1 탭(미완료) 먼저 가져가도 됨.
      // 요구사항상 헤더/탭 숫자 정확도를 위해 전 탭을 즉시 로드하지 않고, Lazy Load로 처리.
      await _fetchMembers(_tabKeyByIndex(_tab.index));
      _tab.addListener(_onTabChanged);
    });
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  // ========================= 서버 연동 =========================

  Future<void> _fetchSummary() async {
    setState(() {
      _loadingSummary = true;
      _errSummary = null;
    });

    try {
      final loginKey = context.read<UserProvider>().adminKey?.trim() ?? '';
      if (loginKey.isEmpty) {
        setState(() {
          _loadingSummary = false;
          _errSummary = '로그인이 필요합니다. (adminKey 없음)';
        });
        return;
      }

      final m = await TodoService.instance.getTodoGroupSummary(
        loginKey: loginKey,
        groupId: widget.groupId,
      );

      setState(() {
        _summary = _mapSummary(m);
      });
    } catch (e) {
      print(e);
      setState(() => _errSummary = '요약 불러오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _fetchMembers(String tabKey) async {
    setState(() {
      _loadingMembers = true;
      _errMembers = null;
    });

    try {
      final loginKey = context.read<UserProvider>().adminKey?.trim() ?? '';
      if (loginKey.isEmpty) {
        setState(() {
          _loadingMembers = false;
          _errMembers = '로그인이 필요합니다. (adminKey 없음)';
        });
        return;
      }

      final rows = await TodoService.instance.getTodoGroupMembers(
        loginKey: loginKey,
        groupId: widget.groupId,
        tab: tabKey, // 'done' | 'not_done' | 'not_ack'
      );

      final mapped = rows.map(_mapAssignee).toList(growable: false);

      setState(() {
        switch (tabKey) {
          case 'done':
            _done = mapped;
            break;
          case 'not_done':
            _notDone = mapped;
            break;
          case 'not_ack':
            _notAck = mapped;
            break;
        }
      });
    } catch (e) {
      print(e);
      setState(() => _errMembers = '목록 불러오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _toggleArchive(bool toArchived) async {
    try {
      final loginKey = context.read<UserProvider>().adminKey?.trim() ?? '';
      if (loginKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다. (adminKey 없음)')),
        );
        return;
      }

      final res = await TodoService.instance.toggleGroupArchive(
        loginKey: loginKey,
        groupId: widget.groupId,
        toArchived: toArchived,
      );

      // 서버 결과 반영
      setState(() {
        _summary = _summary?.copyWith(
          isArchived: (res['is_archived'] == true),
          updatedAt: _tryParseDateTime(res['updated_at']),
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toArchived ? '비활성화되었습니다.' : '활성화되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 실패: $e')),
      );
    }
  }

  Future<void> _deleteGroup() async {
    try {
      final loginKey = context.read<UserProvider>().adminKey?.trim() ?? '';
      if (loginKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다. (adminKey 없음)')),
        );
        return;
      }

      await TodoService.instance.deleteTodoGroup(
        loginKey: loginKey,
        groupId: widget.groupId,
      );

      if (!mounted) return;
      Navigator.pop(context, 'deleted'); // 상위에서 재조회
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  // ========================= 맵퍼/유틸 =========================

  _GroupSummaryVm _mapSummary(Map<String, dynamic> m) {
    final audienceStr = (m['audience'] ?? 'mentee').toString();
    final audience = switch (audienceStr) {
      'all' => TodoAudience.all,
      'mentor' => TodoAudience.mentor,
      _ => TodoAudience.mentee,
    };
    final createdAt = _tryParseDateTime(m['created_at']);
    final updatedAt = _tryParseDateTime(m['updated_at']);
    return _GroupSummaryVm(
      title: (m['title'] ?? '').toString(),
      audience: audience,
      isArchived: m['is_archived'] == true,
      createdAt: createdAt,
      updatedAt: updatedAt,
      totalCount: int.tryParse('${m['total_count'] ?? 0}') ?? 0,
      doneCount: int.tryParse('${m['done_count'] ?? 0}') ?? 0,
      ackCount: int.tryParse('${m['ack_count'] ?? 0}') ?? 0,
      doneRate: _tryParseNum(m['done_rate']),
      ackRate: _tryParseNum(m['ack_rate']),
      description: (m['description'] ?? '').toString(),
    );
  }

  _AssigneeVm _mapAssignee(Map<String, dynamic> m) {
    final isMentor = (m['is_mentor'] == true);
    return _AssigneeVm(
      name: (m['nickname'] ?? '').toString(),
      role: isMentor ? '멘토' : '멘티',
      ackAt: _tryParseDateTime(m['ack_at']),
      doneAt: _tryParseDateTime(m['done_at']),
    );
  }

  DateTime? _tryParseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  double _tryParseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  // 탭 변경 시 Lazy Load
  void _onTabChanged() {
    if (!_tab.indexIsChanging) {
      final k = _tabKeyByIndex(_tab.index);
      // 이미 데이터가 있으면 패스, 없으면 로드
      final needLoad = switch (k) {
        'done' => _done.isEmpty,
        'not_done' => _notDone.isEmpty,
        'not_ack' => _notAck.isEmpty,
        _ => false,
      };
      if (needLoad) {
        _fetchMembers(k);
      }
    }
  }

  String _tabKeyByIndex(int idx) {
    switch (idx) {
      case 0:
        return 'done';
      case 1:
        return 'not_done';
      case 2:
      default:
        return 'not_ack';
    }
  }

  // ========================= UI =========================

  @override
  Widget build(BuildContext context) {
    final titleForAppBar = _summary?.title ?? widget.title;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _shorten(titleForAppBar),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700, fontSize: 20),
        ),
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
            tooltip: (_summary?.isArchived ?? false) ? '활성으로 전환' : '비활성으로 전환',
            icon: Icon((_summary?.isArchived ?? false)
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined, color: UiTokens.title),
            onPressed: _confirmToggle,
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
      body: _loadingSummary && _summary == null
          ? const Center(child: CircularProgressIndicator())
          : _errSummary != null
          ? _ErrorView(message: _errSummary!, onRetry: _fetchSummary)
          : Column(
        children: [
          // 헤더 요약
          _HeaderSummary(
            audience: _summary?.audience ?? widget.audience,
            total: _summary?.totalCount ?? 0,
            done: _summary?.doneCount ?? 0,
            notDone: (_summary?.totalCount ?? 0) - (_summary?.doneCount ?? 0),
            notAck: (_summary?.totalCount ?? 0) - (_summary?.ackCount ?? 0),
            isArchived: _summary?.isArchived ?? false,
            createdAt: _summary?.createdAt,
            description: _summary?.description,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _fetchSummary();
                await _fetchMembers(_tabKeyByIndex(_tab.index));
              },
              child: TabBarView(
                controller: _tab,
                children: [
                  _MembersPane(
                    loading: _loadingMembers && _tabIndex == 0 && _done.isEmpty,
                    error: _tabIndex == 0 ? _errMembers : null,
                    onRetry: () => _fetchMembers('done'),
                    items: _done,
                  ),
                  _MembersPane(
                    loading: _loadingMembers && _tabIndex == 1 && _notDone.isEmpty,
                    error: _tabIndex == 1 ? _errMembers : null,
                    onRetry: () => _fetchMembers('not_done'),
                    items: _notDone,
                  ),
                  _MembersPane(
                    loading: _loadingMembers && _tabIndex == 2 && _notAck.isEmpty,
                    error: _tabIndex == 2 ? _errMembers : null,
                    onRetry: () => _fetchMembers('not_ack'),
                    items: _notAck,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 확인/토글 모달
  Future<void> _confirmToggle() async {
    final toArchived = !(_summary?.isArchived ?? false);
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

    await _toggleArchive(toArchived);
  }

  Future<void> _confirmDelete() async {
    final ok = await _showConfirmDialog(
      context,
      title: '이 공지를 삭제할까요?',
      message: '모든 수신자 기록(확인/완료)이 함께 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '삭제',
    );
    if (!ok) return;

    await _deleteGroup();
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
  final DateTime? createdAt;
  final String? description;

  const _HeaderSummary({
    required this.audience,
    required this.total,
    required this.done,
    required this.notDone,
    required this.notAck,
    required this.isArchived,
    this.createdAt,
    this.description,
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
                const Spacer(),
                if (createdAt != null)
                  Text(_fmtDate(createdAt!),
                      style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
              ],
            ),
            if ((description ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: TextStyle(color: c.onSurface, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
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

class _MembersPane extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final List<_AssigneeVm> items;

  const _MembersPane({
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _ErrorView(message: error!, onRetry: onRetry);
    }
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
                it.doneAt != null ? Icons.check_circle : Icons.radio_button_unchecked,
                color: it.doneAt != null ? UiTokens.primaryBlue : c.onSurfaceVariant,
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
                          it.ackAt == null ? '미확인' : _fmtDateTime(it.ackAt!),
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
  final String role;     // '멘토' | '멘티'
  final DateTime? ackAt; // 열람(확인) 시각
  final DateTime? doneAt;

  _AssigneeVm({
    required this.name,
    required this.role,
    required this.ackAt,
    required this.doneAt,
  });
}

class _GroupSummaryVm {
  final String title;
  final TodoAudience audience;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int totalCount;
  final int doneCount;
  final int ackCount;
  final double doneRate; // % 값이 아닌 0~100 숫자를 보내지 않고, 소수 퍼센트를 서버에서 줬으니 그대로 표시는 하지 않고 내부 계산만 사용 가능
  final double ackRate;
  final String? description;

  _GroupSummaryVm({
    required this.title,
    required this.audience,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.totalCount,
    required this.doneCount,
    required this.ackCount,
    required this.doneRate,
    required this.ackRate,
    required this.description,
  });

  _GroupSummaryVm copyWith({
    String? title,
    TodoAudience? audience,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalCount,
    int? doneCount,
    int? ackCount,
    double? doneRate,
    double? ackRate,
    String? description,
  }) {
    return _GroupSummaryVm(
      title: title ?? this.title,
      audience: audience ?? this.audience,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalCount: totalCount ?? this.totalCount,
      doneCount: doneCount ?? this.doneCount,
      ackCount: ackCount ?? this.ackCount,
      doneRate: doneRate ?? this.doneRate,
      ackRate: ackRate ?? this.ackRate,
      description: description ?? this.description,
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
