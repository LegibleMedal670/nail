import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/page/tabs/mentee_manage_tab.dart';
import 'package:nail/Services/SupabaseService.dart';

class MenteeEditResult {
  final MenteeEntry? mentee;
  final bool deleted; // (편집 모드일 때) 삭제 여부
  const MenteeEditResult({this.mentee, this.deleted = false});
}

class MenteeEditPage extends StatefulWidget {
  /// 편집이면 initial 전달, 추가면 null
  final MenteeEntry? initial;

  /// 접속 코드 중복 방지용 (이미 존재하는 4자리 코드 목록)
  final Set<String> existingCodes;

  const MenteeEditPage({
    super.key,
    this.initial,
    this.existingCodes = const {},
  });

  @override
  State<MenteeEditPage> createState() => _MenteeEditPageState();
}

class _MenteeEditPageState extends State<MenteeEditPage> {
  final _formKey = GlobalKey<FormState>();

  // --- Controllers ---
  late final TextEditingController _name =
  TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _mentor =
  TextEditingController(text: widget.initial?.mentor == '미배정' ? '' : (widget.initial?.mentor ?? ''));
  late final TextEditingController _photoUrl =
  TextEditingController(text: widget.initial?.photoUrl ?? '');
  late final TextEditingController _accessCode =
  TextEditingController(text: widget.initial?.accessCode ?? '');

  late DateTime _startedAt = widget.initial?.startedAt ?? DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    _mentor.dispose();
    _photoUrl.dispose();
    _accessCode.dispose();
    super.dispose();
  }

  // --- UI helpers ---
  void _unfocusAll() => FocusScope.of(context).unfocus();

  String _fmtDate(DateTime d) =>
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

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: UiTokens.actionIcon),
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
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

  // --- 접속 코드 유틸 (중복 방지) ---
  String _generate4DigitsUnique() {
    final rng = Random();
    final taken = {...widget.existingCodes};
    // 편집 중이면 본인 기존 코드는 허용
    if (widget.initial?.accessCode.isNotEmpty ?? false) {
      taken.remove(widget.initial!.accessCode);
    }

    // 1000~9999에서 중복 피해서 추첨
    for (int i = 0; i < 100; i++) {
      final c = (1000 + rng.nextInt(9000)).toString();
      if (!taken.contains(c)) return c;
    }
    // 이론상 거의 불가능하지만, 100회 모두 실패 시 예외 케이스
    return '9999';
  }

  void _fillRandomCode() {
    setState(() => _accessCode.text = _generate4DigitsUnique());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('랜덤 코드를 생성했어요')),
    );
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
    if (ok == true && mounted) {
      Navigator.of(context).pop(const MenteeEditResult(deleted: true));
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final nickname = _name.text.trim();
    final mentor = _mentor.text.trim().isEmpty ? null : _mentor.text.trim();
    final photo  = _photoUrl.text.trim().isEmpty ? null : _photoUrl.text.trim();
    final code = _accessCode.text.trim();

    try {
      Map<String, dynamic> row;
      if (widget.initial == null) {
        // 추가: 코드가 null이면 서버가 자동 생성
        row = await SupabaseService.instance.createMentee(
          nickname: nickname,
          joinedAt: _startedAt,
          mentor: mentor,
          photoUrl: photo,
          loginKey: code,
        );
      } else {
        // 편집
        row = await SupabaseService.instance.updateUserMin(
          id: widget.initial!.id,
          nickname: nickname,
          joinedAt: _startedAt,
          mentor: mentor,
          photoUrl: photo,
          loginKey: code, // 비워두면 기존 유지
        );
      }

      // 로컬 리스트 모델로 변환
      final entry = MenteeEntry(
        id: row['id'] as String,
        name: row['nickname'] as String,
        mentor: (row['mentor'] as String?) ?? '미배정',
        startedAt: DateTime.parse(row['joined_at'] as String),
        progress: widget.initial?.progress ?? 0,
        courseDone: widget.initial?.courseDone ?? 0,
        courseTotal: widget.initial?.courseTotal ?? 0,
        examDone: widget.initial?.examDone ?? 0,
        examTotal: widget.initial?.examTotal ?? 0,
        score: widget.initial?.score,
        photoUrl: row['photo_url'] as String?,
        accessCode: (row['login_key'] as String?) ?? (code ?? ''), // 필요 시 표시
      );

      if (!mounted) return;
      Navigator.of(context).pop(MenteeEditResult(mentee: entry));
    } catch (e) {
      // 서버가 'DUPLICATE_LOGIN_KEY' 던지면 메시지 치환
      final msg = e.toString().contains('DUPLICATE_LOGIN_KEY')
          ? '이미 존재하는 접속 코드입니다'
          : '저장 실패: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      // 화면 아무 곳이나 탭 → 키보드 닫힘
      onTap: _unfocusAll,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Form( // ✅ Form 추가
              key: _formKey,
              child: Column(
                children: [
                  // 이름
                  TextFormField(
                    controller: _name,
                    decoration: _dec('이름', Icons.person_outline),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
                  ),
                  const SizedBox(height: 16),

                  // 담당 멘토 (옵션)
                  TextFormField(
                    controller: _mentor,
                    decoration: _dec('담당 멘토(없으면 비워두기)', Icons.school_outlined),
                  ),
                  const SizedBox(height: 16),

                  // 시작일 (카드형 선택)
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: _dec('시작일', Icons.event_outlined),
                      child: Row(
                        children: [
                          Text(
                            _fmtDate(_startedAt),
                            style: const TextStyle(
                              color: UiTokens.title,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.calendar_today_outlined, color: UiTokens.actionIcon),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 사진 URL (옵션)
                  TextFormField(
                    controller: _photoUrl,
                    decoration: _dec('사진 URL(옵션)', Icons.link_outlined),
                  ),
                  const SizedBox(height: 16),

                  // 접속 코드 + 랜덤생성(중복 방지)
                  TextFormField(
                    controller: _accessCode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: _dec('접속 코드 (4자리 숫자)', Icons.vpn_key_outlined).copyWith(
                      suffixIcon: IconButton(
                        tooltip: '랜덤 생성',
                        onPressed: _fillRandomCode,
                        icon: const Icon(Icons.casino_rounded),
                      ),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return '접속 코드는 필수입니다';
                      if (s.length != 4) return '4자리 숫자를 입력하세요';
                      if (int.tryParse(s) == null) return '숫자만 입력하세요';

                      // 중복 검사 (편집 중이면 본인 기존 코드는 허용)
                      final isSameAsInitial =
                          (widget.initial?.accessCode.isNotEmpty ?? false) &&
                              widget.initial!.accessCode == s;
                      if (!isSameAsInitial && widget.existingCodes.contains(s)) {
                        return '이미 존재하는 코드입니다';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // 하단 버튼: 키보드 높이에 맞춰 자연스럽게 상승
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
                  _unfocusAll();
                  if (_formKey.currentState?.validate() ?? false) {
                    _save();
                  }
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
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
  }
}
