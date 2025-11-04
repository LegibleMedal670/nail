import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/MentorProvider.dart';
import 'package:nail/Services/TodoService.dart';

class MentorTodoCreatePage extends StatefulWidget {
  const MentorTodoCreatePage({super.key});

  @override
  State<MentorTodoCreatePage> createState() => _MentorTodoCreatePageState();
}

class _MentorTodoCreatePageState extends State<MentorTodoCreatePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _titleCtrls = <TextEditingController>[TextEditingController()];
  final _descCtrls  = <TextEditingController>[TextEditingController()];
  final _searchCtrl = TextEditingController();
  String _q = '';
  final Set<String> _selectedMentees = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() => _q = _searchCtrl.text.trim()));
    // 내 멘티 목록 보장 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<MentorProvider>();
      if (p.mentees.isEmpty) {
        p.refreshMentees(onlyPending: p.onlyPendingMentees);
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in _titleCtrls) { c.dispose(); }
    for (final c in _descCtrls) { c.dispose(); }
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _validDraftCount =>
      _titleCtrls.where((c) => c.text.trim().isNotEmpty).length;

  bool get _canSubmit =>
      _validDraftCount > 0 && _selectedMentees.isNotEmpty && !_submitting;

  void _addDraft() {
    setState(() {
      _titleCtrls.add(TextEditingController());
      _descCtrls.add(TextEditingController());
    });
  }

  void _removeDraft(int i) {
    if (_titleCtrls.length == 1) return;
    setState(() {
      _titleCtrls.removeAt(i).dispose();
      _descCtrls.removeAt(i).dispose();
    });
  }

  List<Map<String, dynamic>> _filteredMentees(List<Map<String, dynamic>> src) {
    if (_q.isEmpty) return src;
    final lq = _q.toLowerCase();
    return src.where((m) => ('${m['nickname'] ?? ''}').toLowerCase().contains(lq)).toList();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    try {
      final p = context.read<MentorProvider>();
      final menteeIds = _selectedMentees.toList(growable: false);

      // 여러 드래프트 → 여러 그룹 생성
      for (var i = 0; i < _titleCtrls.length; i++) {
        final title = _titleCtrls[i].text.trim();
        if (title.isEmpty) continue;
        final desc  = _descCtrls[i].text.trim();
        await TodoService.instance.createTodoForMentees(
          mentorLoginKey: p.mentorLoginKey,
          title: title,
          description: desc.isEmpty ? null : desc,
          menteeIds: menteeIds,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TODO ${_validDraftCount}개를 ${_selectedMentees.length}명에게 부여했어요.')),
      );

      // 돌아가며 KPI/멘티 목록 갱신
      await p.refreshKpi();
      await p.refreshMentees(onlyPending: p.onlyPendingMentees);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MentorProvider>();
    final mentees = _filteredMentees(p.mentees);
    final menteeAllSelected = p.mentees.isNotEmpty && _selectedMentees.length == p.mentees.length;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('TODO 부여', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700, fontSize: 22)),
          backgroundColor: Colors.white, elevation: 0, centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: UiTokens.title),
            onPressed: () => Navigator.maybePop(context),
          ),
          bottom: TabBar(
            controller: _tab,
            labelColor: UiTokens.primaryBlue,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: UiTokens.primaryBlue,
            tabs: const [Tab(text: '내용'), Tab(text: '대상 선택')],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            // ===== 내용 탭 =====
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _QuickChip(
                      icon: Icons.people_outline,
                      label: '담당 멘티 전체',
                      selected: menteeAllSelected,
                      onTap: () {
                        setState(() {
                          if (menteeAllSelected) {
                            _selectedMentees.clear();
                          } else {
                            _selectedMentees
                              ..clear()
                              ..addAll(p.mentees.map((m) => '${m['id']}'));
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _titleCtrls.length,
                  onReorder: (o, n) {
                    setState(() {
                      if (n > o) n -= 1;
                      final t = _titleCtrls.removeAt(o);
                      final d = _descCtrls.removeAt(o);
                      _titleCtrls.insert(n, t);
                      _descCtrls.insert(n, d);
                    });
                  },
                  itemBuilder: (_, i) {
                    return Container(
                      key: ValueKey('draft-$i'),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE6EBF0)),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0,2))],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.drag_indicator, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text('TODO #${i+1}', style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
                                const Spacer(),
                                IconButton(
                                  tooltip: '삭제',
                                  onPressed: _titleCtrls.length==1 ? null : () => _removeDraft(i),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                            child: Column(children: [
                              TextField(
                                controller: _titleCtrls[i],
                                onChanged: (_) => setState((){}),
                                decoration: const InputDecoration(
                                  labelText: '제목', hintText: '예) 이번 주 실습 공지', border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _descCtrls[i],
                                minLines: 2, maxLines: 6,
                                decoration: const InputDecoration(
                                  labelText: '설명(선택)', hintText: '수행 방법/마감/주의사항 등을 적어주세요', border: OutlineInputBorder(),
                                ),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),

            // ===== 대상 선택 탭 =====
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '멘티 이름 검색',
                      border: const OutlineInputBorder(),
                      suffixIcon: _q.isEmpty ? null : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [
                      _AssigneeSection(
                        title: '담당 멘티',
                        total: p.mentees.length,
                        selected: _selectedMentees.length,
                        onToggleAll: () {
                          setState(() {
                            if (menteeAllSelected) {
                              _selectedMentees.clear();
                            } else {
                              _selectedMentees
                                ..clear()
                                ..addAll(p.mentees.map((m) => '${m['id']}'));
                            }
                          });
                        },
                        child: _MenteeList(
                          items: mentees,
                          selected: _selectedMentees,
                          onChange: (id, v) => setState(() {
                            if (v) _selectedMentees.add(id); else _selectedMentees.remove(id);
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
                    onPressed: _canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
                    icon: const Icon(Icons.send),
                    label: Text('저장하기 (${_selectedMentees.length}명)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ======= 작은 구성요소들 =======

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _QuickChip({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? UiTokens.primaryBlue.withOpacity(0.12) : c.surface,
          border: Border.all(color: selected ? UiTokens.primaryBlue : const Color(0xFFE6EBF0)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: selected ? UiTokens.primaryBlue : c.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? UiTokens.primaryBlue : c.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _AssigneeSection extends StatelessWidget {
  final String title;
  final int total;
  final int selected;
  final VoidCallback onToggleAll;
  final Widget child;
  const _AssigneeSection({
    required this.title, required this.total, required this.selected,
    required this.onToggleAll, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final allSelected = total > 0 && total == selected;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE6EBF0)),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0,2))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            Text(title, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            _Badge(text: '$selected/$total'),
            const Spacer(),
            TextButton.icon(
              onPressed: onToggleAll,
              icon: Icon(allSelected ? Icons.remove_done : Icons.done_all, size: 18),
              label: Text(allSelected ? '전체 해제' : '전체 선택'),
            ),
          ]),
        ),
        child,
      ]),
    );
  }
}

class _MenteeList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Set<String> selected;
  final void Function(String id, bool checked) onChange;

  const _MenteeList({required this.items, required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('멘티가 없습니다.', style: TextStyle(color: c.onSurfaceVariant))),
      );
    }
    return ListView.separated(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final m = items[i];
        final id = '${m['id']}';
        final name = '${m['nickname'] ?? '멘티'}';
        final checked = selected.contains(id);
        final subtitle = m['joined_at'] != null
            ? '가입일: ${('${m['joined_at']}'.split(' ').first)}'
            : null;
        return CheckboxListTile(
          value: checked,
          onChanged: (v) => onChange(id, v ?? false),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: subtitle==null?null:Text(subtitle, style: TextStyle(color: c.onSurfaceVariant)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          secondary: const CircleAvatar(child: Icon(Icons.person_outline)),
        );
      },
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
