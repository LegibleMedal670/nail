import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/mentor.dart';
import 'package:nail/Pages/Manager/widgets/DiscardConfirmSheet.dart';
import 'package:nail/Services/SupabaseService.dart';

class MentorEditResult {
  final Mentor? mentor;
  final bool deleted;
  const MentorEditResult({this.mentor, this.deleted = false});
}

class MentorEditPage extends StatefulWidget {
  final Mentor? initial;
  final Set<String> existingCodes;
  const MentorEditPage({super.key, this.initial, this.existingCodes = const {}});
  @override
  State<MentorEditPage> createState() => _MentorEditPageState();
}

class _MentorEditPageState extends State<MentorEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
  TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _photo =
  TextEditingController(text: widget.initial?.photoUrl ?? '');
  late final TextEditingController _code =
  TextEditingController(text: widget.initial?.accessCode ?? '');
  late DateTime _hiredAt = widget.initial?.hiredAt ?? DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    _photo.dispose();
    _code.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hiredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _hiredAt = picked);
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: UiTokens.actionIcon),
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE6ECF3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: UiTokens.primaryBlue, width: 2),
      ),
    );
  }

  String _genUnique4() {
    final rng = Random();
    final taken = {...widget.existingCodes};
    if (widget.initial?.accessCode.isNotEmpty ?? false) {
      taken.remove(widget.initial!.accessCode);
    }
    for (int i = 0; i < 100; i++) {
      final c = (1000 + rng.nextInt(9000)).toString();
      if (!taken.contains(c)) return c;
    }
    return '9999';
  }

  Future<void> _delete() async {
    if (widget.initial == null) return;

    final ok = await showDiscardChangesDialog(
      context,
      title: '선임 삭제',
      message: '정말 “${widget.initial!.name}” 선임를 삭제하시겠어요?\n되돌릴 수 없어요.',
      stayText: '취소',
      leaveText: '삭제',
      isDanger: true,                 // 🔴 위험 작업 스타일
      barrierDismissible: true,
    );

    if (!ok) return;

    try {
      await SupabaseService.instance.deleteUser(id: widget.initial!.id);
      if (!mounted) return;
      Navigator.of(context).pop(const MentorEditResult(deleted: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }


  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final nickname = _name.text.trim();
    final photoUrl = _photo.text.trim().isEmpty ? null : _photo.text.trim();
    final loginKey = _code.text.trim();

    try {
      Map<String, dynamic> row;
      if (widget.initial == null) {
        row = await SupabaseService.instance.adminCreateMentor(
          nickname: nickname,
          hiredAt: _hiredAt,
          photoUrl: photoUrl,
          loginKey: loginKey,
        );
      } else {
        row = await SupabaseService.instance.updateUserMin(
          id: widget.initial!.id,
          nickname: nickname,
          // joinedAt: _hiredAt,
          // mentorId: null,           // 선임 자신 편집이라 mentor(uuid) 사용 안 함
          // photoUrl: photoUrl,
          // loginKey: loginKey.isEmpty ? null : loginKey,
        );
      }

      final m = Mentor(
        id: row['id'] as String,
        name: row['nickname'] as String,
        hiredAt: DateTime.parse(row['joined_at'] as String),
        menteeCount: widget.initial?.menteeCount ?? 0,
        avgScore: widget.initial?.avgScore,
        avgGraduateDays: widget.initial?.avgGraduateDays,
        photoUrl: row['photo_url'] as String?,
        accessCode: (row['login_key'] as String?) ?? loginKey,
      );

      if (!mounted) return;
      Navigator.of(context).pop(MentorEditResult(mentor: m));
    } catch (e) {
      final msg = e.toString().contains('DUPLICATE_LOGIN_KEY')
          ? '이미 존재하는 접속 코드입니다'
          : '저장 실패: $e';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: UiTokens.title),
        title: Text(isEdit ? '선임 편집' : '선임 추가',
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _name,
                decoration: _dec('이름', Icons.person_outline),
                validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
              ),
              const SizedBox(height: 16),

              // InkWell(
              //   onTap: _pickDate,
              //   borderRadius: BorderRadius.circular(14),
              //   child: InputDecorator(
              //     decoration: _dec('등록일', Icons.event_outlined),
              //     child: Row(
              //       children: [
              //         Text(_fmtDate(_hiredAt),
              //             style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
              //         const Spacer(),
              //         const Icon(Icons.calendar_today_outlined, color: UiTokens.actionIcon),
              //       ],
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 16),
              //
              // TextFormField(
              //   controller: _photo,
              //   decoration: _dec('사진 URL(옵션)', Icons.link_outlined),
              // ),
              // const SizedBox(height: 16),
              //
              // TextFormField(
              //   controller: _code,
              //   keyboardType: TextInputType.number,
              //   inputFormatters: [
              //     FilteringTextInputFormatter.digitsOnly,
              //     LengthLimitingTextInputFormatter(4),
              //   ],
              //   decoration: _dec('접속 코드 (4자리 숫자)', Icons.vpn_key_outlined).copyWith(
              //     suffixIcon: IconButton(
              //       tooltip: '랜덤 생성',
              //       onPressed: () async {
              //         // 서버에서 고유 코드 생성 API가 있으므로 그것도 사용 가능
              //         try {
              //           final gen = await SupabaseService.instance.generateUniqueLoginCode(digits: 4);
              //           _code.text = gen;
              //         } catch (_) {
              //           _code.text = _genUnique4();
              //         }
              //         if (!mounted) return;
              //         ScaffoldMessenger.of(context).showSnackBar(
              //           const SnackBar(content: Text('랜덤 코드를 생성했어요')),
              //         );
              //       },
              //       icon: const Icon(Icons.casino_rounded),
              //     ),
              //   ),
              //   validator: (v) {
              //     final s = (v ?? '').trim();
              //     if (s.isEmpty) return '접속 코드를 입력하세요';
              //     if (s.length != 4) return '4자리 숫자를 입력하세요';
              //     if (int.tryParse(s) == null) return '숫자만 입력하세요';
              //
              //     final exists = widget.existingCodes.contains(s);
              //     final sameAsInitial = (widget.initial?.accessCode == s);
              //     if (exists && !sameAsInitial) return '이미 존재하는 코드입니다';
              //     return null;
              //   },
              // ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) _save();
              },
              style: FilledButton.styleFrom(
                backgroundColor: UiTokens.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }
}
