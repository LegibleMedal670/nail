// lib/Pages/Manager/page/todo/ManagerTodoCreatePage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class ManagerTodoCreatePage extends StatefulWidget {
  const ManagerTodoCreatePage({super.key});

  @override
  State<ManagerTodoCreatePage> createState() => _ManagerTodoCreatePageState();
}

class _ManagerTodoCreatePageState extends State<ManagerTodoCreatePage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // ---- Drafts (여러 TODO 동시 생성) ----
  final List<_TodoDraft> _drafts = [ _TodoDraft() ];

  // ---- 대상 선택 ----
  final _searchCtrl = TextEditingController();
  String _q = '';
  final Set<String> _selectedMentors = {};
  final Set<String> _selectedMentees = {};

  // 더미 데이터(→ Service 연동으로 교체)
  final List<_UserVm> _mentors = List.generate(10, (i) => _UserVm(id: 'm$i', name: '멘토$i', role: 'mentor', email: 'mentor$i@example.com'));
  final List<_UserVm> _mentees = List.generate(24, (i) => _UserVm(id: 'e$i', name: '멘티$i', role: 'mentee', email: 'mentee$i@example.com'));

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() => _q = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final d in _drafts) { d.dispose(); }
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---- State helpers ----
  int get _assigneeCount => _selectedMentors.length + _selectedMentees.length;
  int get _validDraftCount => _drafts.where((d) => d.titleCtrl.text.trim().isNotEmpty).length;
  bool get _canSubmit => _assigneeCount > 0 && _validDraftCount > 0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    // 화면 아무 곳이나 탭하면 포커스 해제(키보드 닫힘)
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('TODO 추가', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700, fontSize: 22)),
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
          bottom: TabBar(
            controller: _tab,
            labelColor: UiTokens.primaryBlue,
            unselectedLabelColor: c.onSurfaceVariant,
            indicatorColor: UiTokens.primaryBlue,
            tabs: const [ Tab(text: '내용'), Tab(text: '대상 선택') ],
          ),
        ),
        body: TabBarView(
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
                    style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
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

    final mentorAllSelected = _mentors.isNotEmpty && _selectedMentors.length == _mentors.length;
    final menteeAllSelected = _mentees.isNotEmpty && _selectedMentees.length == _mentees.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        // ✅ 빠른 선택 칩(내용 탭 상단): 멘토 전체 / 멘티 전체
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

        // 드래프트 카드 리스트(리오더 가능)
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
                boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)) ],
              ),
              child: Column(
                children: [
                  // 헤더
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.drag_indicator, color: c.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('TODO #${i+1}', style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        IconButton(
                          tooltip: '삭제',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _drafts.length == 1 ? null : () => _removeDraft(i),
                        ),
                      ],
                    ),
                  ),
                  // 본문
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
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

    final fMentors = _filter(_mentors, _q);
    final fMentees = _filter(_mentees, _q);

    final mentorAllSelected = _mentors.isNotEmpty && _selectedMentors.length == _mentors.length;
    final menteeAllSelected = _mentees.isNotEmpty && _selectedMentees.length == _mentees.length;

    return Column(
      children: [
        // 검색창
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '이름/이메일로 검색',
              border: const OutlineInputBorder(),
              suffixIcon: _q.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchCtrl.clear()),
            ),
          ),
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
                  onChange: (id, v) => setState(() => v ? _selectedMentors.add(id) : _selectedMentors.remove(id)),
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
                  onChange: (id, v) => setState(() => v ? _selectedMentees.add(id) : _selectedMentees.remove(id)),
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
        _selectedMentors..clear()..addAll(_mentors.map((e) => e.id));
      } else {
        _selectedMentors.clear();
      }
    });
  }
  void _toggleMentee(bool select) {
    setState(() {
      if (select) {
        _selectedMentees..clear()..addAll(_mentees.map((e) => e.id));
      } else {
        _selectedMentees.clear();
      }
    });
  }

  List<_UserVm> _filter(List<_UserVm> src, String q) {
    if (q.isEmpty) return src;
    final lq = q.toLowerCase();
    return src.where((e) => e.name.toLowerCase().contains(lq) || e.email.toLowerCase().contains(lq)).toList();
  }

  // ---- 제출 ----
  void _onSubmit() {
    final validDrafts = _drafts.where((d) => d.titleCtrl.text.trim().isNotEmpty).toList();
    if (validDrafts.isEmpty) {
      _tab.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목을 한 개 이상 입력하세요.')));
      return;
    }
    if (_assigneeCount == 0) {
      _tab.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('대상을 한 명 이상 선택하세요.')));
      return;
    }

    // TODO: Service 연동
    // for (final d in validDrafts) {
    //   final todoId = await createTodo(title: d.titleCtrl.text.trim(), desc: d.descCtrl.text.trim());
    //   await assignTodo(todoId, [..._selectedMentors, ..._selectedMentees]);
    // }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('TODO ${validDrafts.length}개를 ${_assigneeCount}명에게 부여했습니다. (Service 연동 예정)')),
    );
    Navigator.of(context).pop();
  }

  // ---- UI helpers ----
  Widget _quickChip(BuildContext context, {required IconData icon, required String label, required bool selected, required VoidCallback onTap}) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? UiTokens.primaryBlue.withOpacity(0.12) : c.surface,
          border: Border.all(color: selected ? UiTokens.primaryBlue : const Color(0xFFE6EBF0)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? UiTokens.primaryBlue : c.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? UiTokens.primaryBlue : c.onSurfaceVariant)),
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
        boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)) ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              children: [
                Text(title, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                _Badge(text: '$selected/$total'),
                const Spacer(),
                TextButton.icon(
                  onPressed: onToggleAll,
                  icon: Icon(allSelected ? Icons.remove_done : Icons.done_all, size: 18),
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
  void dispose() { titleCtrl.dispose(); descCtrl.dispose(); }
}

class _AssigneeList extends StatelessWidget {
  final List<_UserVm> items;
  final Set<String> selected;
  final void Function(String id, bool checked) onChange;

  const _AssigneeList({required this.items, required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('결과 없음', style: TextStyle(color: c.onSurfaceVariant))),
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
          subtitle: Text(u.email),
          secondary: Icon(u.role == 'mentor' ? Icons.support_agent_outlined : Icons.person_outline),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          controlAffinity: ListTileControlAffinity.leading,
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: items.length,
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
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _UserVm {
  final String id;
  final String name;
  final String role; // mentor|mentee
  final String email;
  _UserVm({required this.id, required this.name, required this.role, required this.email});
}
