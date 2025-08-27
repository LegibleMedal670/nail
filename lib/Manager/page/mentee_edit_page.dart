// lib/Manager/pages/mentee_edit_page.dart
import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/page/tabs/mentee_manage_tab.dart';

class MenteeEditResult {
  final MenteeEntry? mentee;
  final bool deleted; // (편집 모드일 때) 삭제 여부
  const MenteeEditResult({this.mentee, this.deleted = false});
}

class MenteeEditPage extends StatefulWidget {
  final MenteeEntry? initial; // null이면 추가 모드
  const MenteeEditPage({super.key, this.initial});

  @override
  State<MenteeEditPage> createState() => _MenteeEditPageState();
}

class _MenteeEditPageState extends State<MenteeEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name =
  TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _mentor =
  TextEditingController(text: widget.initial?.mentor ?? '');
  late final TextEditingController _progress =
  TextEditingController(text: ((widget.initial?.progress ?? 0) * 100).round().toString());
  late final TextEditingController _courseDone =
  TextEditingController(text: (widget.initial?.courseDone ?? 0).toString());
  late final TextEditingController _courseTotal =
  TextEditingController(text: (widget.initial?.courseTotal ?? 0).toString());
  late final TextEditingController _examDone =
  TextEditingController(text: (widget.initial?.examDone ?? 0).toString());
  late final TextEditingController _examTotal =
  TextEditingController(text: (widget.initial?.examTotal ?? 0).toString());
  late final TextEditingController _score =
  TextEditingController(text: widget.initial?.score?.toStringAsFixed(1) ?? '');
  late final TextEditingController _photoUrl =
  TextEditingController(text: widget.initial?.photoUrl ?? '');

  late DateTime _startedAt = widget.initial?.startedAt ?? DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    _mentor.dispose();
    _progress.dispose();
    _courseDone.dispose();
    _courseTotal.dispose();
    _examDone.dispose();
    _examTotal.dispose();
    _score.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startedAt = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final p = int.parse(_progress.text.trim());
    final cDone = int.tryParse(_courseDone.text.trim()) ?? 0;
    final cTot  = int.tryParse(_courseTotal.text.trim()) ?? 0;
    final eDone = int.tryParse(_examDone.text.trim()) ?? 0;
    final eTot  = int.tryParse(_examTotal.text.trim()) ?? 0;
    final double? s = _score.text.trim().isEmpty ? null : double.tryParse(_score.text.trim());

    final entry = MenteeEntry(
      id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      mentor: _mentor.text.trim().isEmpty ? '미배정' : _mentor.text.trim(),
      progress: (p.clamp(0, 100)) / 100.0,
      startedAt: _startedAt,
      courseDone: cDone,
      courseTotal: cTot,
      examDone: eDone,
      examTotal: eTot,
      photoUrl: _photoUrl.text.trim().isEmpty ? null : _photoUrl.text.trim(),
      score: s,
    );

    Navigator.of(context).pop(MenteeEditResult(mentee: entry));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('멘티 삭제'),
        content: const Text('정말 삭제하시겠어요? 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      Navigator.of(context).pop(const MenteeEditResult(deleted: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: UiTokens.title),
        title: Text(isEdit ? '멘티 편집' : '멘티 추가',
            style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: UiTokens.actionIcon),
              tooltip: '삭제',
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '이름'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _mentor,
                  decoration: const InputDecoration(labelText: '담당 멘토(없으면 비워두기)'),
                ),
                const SizedBox(height: 12),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('시작일', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
                  subtitle: Text(_fmt(_startedAt)),
                  trailing: const Icon(Icons.calendar_today_outlined, color: UiTokens.actionIcon),
                  onTap: _pickDate,
                ),
                const Divider(),

                const SizedBox(height: 12),
                TextFormField(
                  controller: _progress,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '진행률(%)'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return '숫자를 입력하세요';
                    if (n < 0 || n > 100) return '0~100 범위';
                    return null;
                  },
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _courseDone,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '교육 완료 수'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _courseTotal,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '교육 전체 수'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _examDone,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '시험 완료 수'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _examTotal,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '시험 전체 수'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _score,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '평가 점수(옵션)'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final d = double.tryParse(v.trim());
                          if (d == null) return '숫자를 입력하세요';
                          if (d < 0 || d > 100) return '0~100 범위';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _photoUrl,
                        decoration: const InputDecoration(labelText: '사진 URL(옵션)'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: UiTokens.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
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
