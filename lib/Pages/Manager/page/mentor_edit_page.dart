import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/mentor.dart';

class MentorEditResult {
  final Mentor? mentor;  // 저장 결과(추가/수정)
  final bool deleted;    // 삭제 여부
  const MentorEditResult({this.mentor, this.deleted = false});
}

class MentorEditPage extends StatefulWidget {
  final Mentor? initial; // null이면 추가 모드
  const MentorEditPage({super.key, this.initial});

  @override
  State<MentorEditPage> createState() => _MentorEditPageState();
}

class _MentorEditPageState extends State<MentorEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name =
  TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _menteeCount =
  TextEditingController(text: (widget.initial?.menteeCount ?? 0).toString());
  late final TextEditingController _avgGradDays =
  TextEditingController(text: (widget.initial?.avgGraduateDays ?? 0).toString());
  late final TextEditingController _avgScore =
  TextEditingController(text: widget.initial?.avgScore?.toStringAsFixed(1) ?? '');
  late final TextEditingController _photoUrl =
  TextEditingController(text: widget.initial?.photoUrl ?? '');

  late DateTime _hiredAt = widget.initial?.hiredAt ?? DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    _menteeCount.dispose();
    _avgGradDays.dispose();
    _avgScore.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hiredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _hiredAt = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final mentees = int.parse(_menteeCount.text.trim());
    final gradDays = int.parse(_avgGradDays.text.trim());
    final double? score = _avgScore.text.trim().isEmpty
        ? null
        : double.tryParse(_avgScore.text.trim());

    final m = Mentor(
      name: _name.text.trim(),
      hiredAt: _hiredAt,
      menteeCount: mentees,
      avgGraduateDays: gradDays,
      photoUrl: _photoUrl.text.trim().isEmpty ? null : _photoUrl.text.trim(),
      avgScore: score,
    );

    Navigator.of(context).pop(MentorEditResult(mentor: m));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('멘토 삭제'),
        content: const Text('정말 삭제하시겠어요? 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      Navigator.of(context).pop(const MentorEditResult(deleted: true));
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: UiTokens.title),
        title: Text(isEdit ? '멘토 편집' : '멘토 추가',
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

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('입사일', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
                  subtitle: Text(_fmt(_hiredAt)),
                  trailing: const Icon(Icons.calendar_today_outlined, color: UiTokens.actionIcon),
                  onTap: _pickDate,
                ),
                const Divider(),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _menteeCount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '현재 멘티 수'),
                        validator: (v) => int.tryParse(v ?? '') == null ? '숫자를 입력하세요' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _avgGradDays,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '평균 교육 기간(일)'),
                        validator: (v) => int.tryParse(v ?? '') == null ? '숫자를 입력하세요' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _avgScore,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '멘티 평균 점수(옵션)'),
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
