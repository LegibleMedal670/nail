// lib/Pages/Manager/page/todo/ManagerTodoCreatePage.dart
import 'package:flutter/material.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/UserProvider.dart';

class ManagerTodoCreatePage extends StatefulWidget {
  const ManagerTodoCreatePage({super.key});

  @override
  State<ManagerTodoCreatePage> createState() => _ManagerTodoCreatePageState();
}

class _ManagerTodoCreatePageState extends State<ManagerTodoCreatePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // ---- Drafts (여러 TODO 동시 생성) ----
  final List<_TodoDraft> _drafts = [_TodoDraft()];

  // ---- 대상 선택 상태 ----
  final _searchCtrl = TextEditingController();
  String _q = '';
  final Set<String> _selectedMentors = {};
  final Set<String> _selectedMentees = {};

  // ---- 로드 상태 ----
  bool _loadingLists = false;
  String? _loadError;
  String _adminWarn = '';

  // ---- 실제 데이터 (RPC 연동) ----
  List<_UserVm> _mentors = const [];
  List<_UserVm> _mentees = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() => _q = _searchCtrl.text.trim()));

    // 첫 진입 시 목록 로드
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAssigneeLists());
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---- 헬퍼 ----
  int get _assigneeCount =>
      _selectedMentors.length + _selectedMentees.length;
  int get _validDraftCount =>
      _drafts.where((d) => d.titleCtrl.text.trim().isNotEmpty).length;
  bool get _canSubmit => _assigneeCount > 0 && _validDraftCount > 0;

  Future<void> _loadAssigneeLists() async {
    setState(() {
      _loadingLists = true;
      _loadError = null;
      _adminWarn = '';
    });

    try {
      final loginKey =
          context.read<UserProvider>().adminKey?.trim() ?? '';

      // 1) 멘티 목록: 공개 RPC(list_mentees)
      final menteeMaps = await TodoService.instance.listMenteesForSelect();
      final mentees = menteeMaps.map((m) {
        final mentorName = (m['mentor_name'] ?? '').toString();
        return _UserVm(
          id: (m['id'] ?? '').toString(),
          name: (m['name'] ?? '').toString(),
          role: 'mentee',
          subtitle: mentorName.isNotEmpty ? '담당 멘토: $mentorName' : null,
          photoUrl: (m['photo_url'] ?? '').toString(),
        );
      }).toList(growable: false);

      // 2) 멘토 목록: 관리자 전용 RPC(list_mentors_for_select)
      List<_UserVm> mentors = const [];
      if (loginKey.isEmpty) {
        _adminWarn =
        '로그인 정보가 없어 멘토 목록을 불러오지 못했습니다. (관리자 권한 확인 불가)';
      } else {
        try {
          final mentorMaps = await TodoService.instance
              .listMentorsForSelect(adminLoginKey: loginKey);
          mentors = mentorMaps
              .map((m) => _UserVm(
            id: (m['id'] ?? '').toString(),
            name: (m['name'] ?? '').toString(),
            role: 'mentor',
            subtitle: null, // 요구사항: 멘토 밑에는 아무 텍스트 없음
            photoUrl: (m['photo_url'] ?? '').toString(),
          ))
              .toList(growable: false);
        } catch (e) {
          _adminWarn = '멘토 목록을 불러오지 못했습니다. 관리자 권한을 확인하세요.';
        }
      }

      setState(() {
        _mentees = mentees;
        _mentors = mentors;
      });
    } catch (e) {
      setState(() => _loadError = '목록 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingLists = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'TODO 추가',
            style: TextStyle(
                color: UiTokens.title,
                fontWeight: FontWeight.w700,
                fontSize: 22),
          ),
          backgroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: UiTokens.title),
            tooltip: '뒤로가기',
            onPressed: () => Navigator.maybePop(context),
          ),
          bottom: TabBar(
            controller: _tab,
            labelColor: UiTokens.primaryBlue,
            unselectedLabelColor: c.onSurfaceVariant,
            indicatorColor: UiTokens.primaryBlue,
            tabs: const [Tab(text: '내용'), Tab(text: '대상 선택')],
          ),
        ),
        body: _loadingLists
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? _ErrorView(
          message: _loadError!,
          onRetry: _loadAssigneeLists,
        )
            : TabBarView(
          controller: _tab,
          children: [
            _buildContentTab(context),
            _buildAssigneeTab(context),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: const Color(0xFFE6EBF0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addDraft,
                    icon: const Icon(Icons.add),
                    label: const Text('새 TODO 추가'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _canSubmit ? _onSubmit : null,
                    style: FilledButton.styleFrom(
                        backgroundColor: UiTokens.primaryBlue),
                    icon: const Icon(Icons.send),
                    label: Text('저장하기 (${_assigneeCount}명)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== 내용 탭 =====================
  Widget _buildContentTab(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    final mentorAllSelected =
        _mentors.isNotEmpty && _selectedMentors.length == _mentors.length;
    final menteeAllSelected =
        _mentees.isNotEmpty && _selectedMentees.length == _mentees.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        if (_adminWarn.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _WarnBanner(text: _adminWarn),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _quickChip(
              context,
              icon: Icons.support_agent_outlined,
              label: '멘토 전체',
              selected: mentorAllSelected,
              onTap: () => _toggleMentor(!mentorAllSelected),
            ),
            _quickChip(
              context,
              icon: Icons.people_outline,
              label: '멘티 전체',
              selected: menteeAllSelected,
              onTap: () => _toggleMentee(!menteeAllSelected),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _drafts.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final d = _drafts.removeAt(oldIndex);
              _drafts.insert(newIndex, d);
            });
          },
          itemBuilder: (_, i) {
            final d = _drafts[i];
            final key = ValueKey(d.id);

            return Container(
              key: key,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE6EBF0)),
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                children: [
                  // 헤더
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.drag_indicator, color: c.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('TODO #${i + 1}',
                            style: const TextStyle(
                                color: UiTokens.title,
                                fontWeight: FontWeight.w800)),
                        const Spacer(),
                        IconButton(
                          tooltip: '삭제',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _drafts.length == 1
                              ? null
                              : () => _removeDraft(i),
                        ),
                      ],
                    ),
                  ),
                  // 본문
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: d.titleCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: '제목',
                            hintText: '예) 전사 공지: 금일 교육일지 업로드',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: d.descCtrl,
                          minLines: 2,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: '설명(선택)',
                            hintText: '수행 방법/양식/주의사항 등을 적어주세요',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _addDraft() => setState(() => _drafts.add(_TodoDraft()));
  void _removeDraft(int i) {
    final d = _drafts.removeAt(i);
    d.dispose();
    setState(() {});
  }

  // ===================== 대상 선택 탭 =====================
  Widget _buildAssigneeTab(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    final fMentors = _filterByName(_mentors, _q);
    final fMentees = _filterByName(_mentees, _q);

    final mentorAllSelected =
        _mentors.isNotEmpty && _selectedMentors.length == _mentors.length;
    final menteeAllSelected =
        _mentees.isNotEmpty && _selectedMentees.length == _mentees.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '이름으로 검색',
              border: const OutlineInputBorder(),
              suffixIcon: _q.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _searchCtrl.clear(),
              ),
            ),
          ),
        ),
        if (_adminWarn.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _WarnBanner(text: _adminWarn),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _assigneeSection(
                title: '멘토',
                total: _mentors.length,
                selected: _selectedMentors.length,
                onToggleAll: () => _toggleMentor(!mentorAllSelected),
                child: _AssigneeList(
                  items: fMentors,
                  selected: _selectedMentors,
                  onChange: (id, v) =>
                      setState(() => v ? _selectedMentors.add(id) : _selectedMentors.remove(id)),
                ),
              ),
              const SizedBox(height: 16),
              _assigneeSection(
                title: '멘티',
                total: _mentees.length,
                selected: _selectedMentees.length,
                onToggleAll: () => _toggleMentee(!menteeAllSelected),
                child: _AssigneeList(
                  items: fMentees,
                  selected: _selectedMentees,
                  onChange: (id, v) =>
                      setState(() => v ? _selectedMentees.add(id) : _selectedMentees.remove(id)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- 선택 토글 ----
  void _toggleMentor(bool select) {
    setState(() {
      if (select) {
        _selectedMentors
          ..clear()
          ..addAll(_mentors.map((e) => e.id));
      } else {
        _selectedMentors.clear();
      }
    });
  }

  void _toggleMentee(bool select) {
    setState(() {
      if (select) {
        _selectedMentees
          ..clear()
          ..addAll(_mentees.map((e) => e.id));
      } else {
        _selectedMentees.clear();
      }
    });
  }

  List<_UserVm> _filterByName(List<_UserVm> src, String q) {
    if (q.isEmpty) return src;
    final lq = q.toLowerCase();
    return src.where((e) => e.name.toLowerCase().contains(lq)).toList();
    // 요구사항: 이메일은 스키마에 없으므로 이름만 검색
  }

  bool _submitting = false;

  // ---- 제출 ----
  Future<void> _onSubmit() async {

    if (_submitting) return;

    setState(() => _submitting = true);

    final validDrafts =
    _drafts.where((d) => d.titleCtrl.text.trim().isNotEmpty).toList();
    if (validDrafts.isEmpty) {
      _tab.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('제목을 한 개 이상 입력하세요.')));
      return;
    }
    if (_assigneeCount == 0) {
      _tab.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('대상을 한 명 이상 선택하세요.')));
      return;
    }

    final loginKey =
        context.read<UserProvider>().adminKey?.trim() ?? '';
    if (loginKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다. (loginKey 없음)')),
      );
      return;
    }

    try {
      // 서버에서 기대하는 p_items의 포맷에 맞춰 구성
      // 예: [{ title, description, assignees: [uuid, ...] }, ...]
      final assignees = <String>[
        ..._selectedMentors,
        ..._selectedMentees,
      ];
      final items = validDrafts
          .map<Map<String, dynamic>>((d) => {
        'title': d.titleCtrl.text.trim(),
        'description': d.descCtrl.text.trim().isEmpty
            ? null
            : d.descCtrl.text.trim(),
        'assignee_ids': assignees,
        // (선택) 명시: 'all' | 'mentor' | 'mentee' (미지정 시 서버 기본값 'mentee')
        'audience': _selectedMentors.isNotEmpty ? _selectedMentees.isNotEmpty ? 'all' : 'mentor' : 'mentee',
      })
          .toList(growable: false);

      await TodoService.instance.createTodoGroups(
        loginKey: loginKey,
        items: items,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('TODO ${validDrafts.length}개를 $_assigneeCount명에게 부여했습니다.')));
      Navigator.of(context).pop();
    } catch (e) {
      print(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---- UI helpers ----
  Widget _quickChip(BuildContext context,
      {required IconData icon,
        required String label,
        required bool selected,
        required VoidCallback onTap}) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? UiTokens.primaryBlue.withOpacity(0.12) : c.surface,
          border: Border.all(
              color: selected ? UiTokens.primaryBlue : const Color(0xFFE6EBF0)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? UiTokens.primaryBlue : c.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? UiTokens.primaryBlue
                        : c.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _assigneeSection({
    required String title,
    required int total,
    required int selected,
    required VoidCallback onToggleAll,
    required Widget child,
  }) {
    final c = Theme.of(context).colorScheme;
    final allSelected = total > 0 && total == selected;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE6EBF0)),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
                color: c.surface,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        color: UiTokens.title, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                _Badge(text: '$selected/$total'),
                const Spacer(),
                TextButton.icon(
                  onPressed: onToggleAll,
                  icon: Icon(allSelected ? Icons.remove_done : Icons.done_all,
                      size: 18),
                  label: Text(allSelected ? '전체 해제' : '전체 선택'),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ====== Draft & List Widgets ======
class _TodoDraft {
  final String id = UniqueKey().toString();
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;

  _TodoDraft({String? initialTitle, String? initialDesc})
      : titleCtrl = TextEditingController(text: initialTitle ?? ''),
        descCtrl = TextEditingController(text: initialDesc ?? '');

  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
  }
}

class _AssigneeList extends StatelessWidget {
  final List<_UserVm> items;
  final Set<String> selected;
  final void Function(String id, bool checked) onChange;

  const _AssigneeList({
    super.key,
    required this.items,
    required this.selected,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child:
            Text('결과 없음', style: TextStyle(color: c.onSurfaceVariant))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, i) {
        final u = items[i];
        final checked = selected.contains(u.id);
        return CheckboxListTile(
          value: checked,
          onChanged: (v) => onChange(u.id, v ?? false),
          title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: (u.subtitle == null || u.subtitle!.isEmpty)
              ? null
              : Text(u.subtitle!),
          secondary: CircleAvatar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black54,
            child: Icon(
              u.role == 'mentor'
                  ? Icons.support_agent_outlined
                  : Icons.person_outline,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          controlAffinity: ListTileControlAffinity.leading,
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: items.length,
    );
  }
}

class _WarnBanner extends StatelessWidget {
  final String text;
  const _WarnBanner({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        border: Border.all(color: const Color(0xFFFFE4B3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFB26A00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFB26A00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry, super.key});

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

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: c.surfaceVariant, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(
              color: c.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _UserVm {
  final String id;
  final String name;
  final String role; // 'mentor' | 'mentee'
  final String? subtitle; // 멘토: null, 멘티: '담당 멘토: OOO'
  final String? photoUrl;

  const _UserVm({
    required this.id,
    required this.name,
    required this.role,
    this.subtitle,
    this.photoUrl,
  });
}
