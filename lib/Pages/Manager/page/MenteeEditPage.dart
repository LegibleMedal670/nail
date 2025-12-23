import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/Mentee.dart';
import 'package:nail/Pages/Manager/models/MenteeEdtitResult.dart';
import 'package:nail/Pages/Manager/widgets/DiscardConfirmSheet.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 드롭다운 소스용 경량 멘토 모델
class _MentorLite {
  final String id;
  final String name;
  final String? photoUrl;
  const _MentorLite({required this.id, required this.name, this.photoUrl});

  factory _MentorLite.fromRow(Map<String, dynamic> r) {
    return _MentorLite(
      id: (r['id'] ?? '').toString(),
      name: (r['nickname'] ?? '').toString(),
      photoUrl: (r['photo_url'] as String?),
    );
  }
}

class MenteeEditPage extends StatefulWidget {
  /// 편집이면 initial 전달, 추가면 null
  final Mentee? initial;

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
  // ✅ mentor 텍스트 입력 제거 → 드롭다운으로 전환
  late final TextEditingController _photoUrl =
  TextEditingController(text: widget.initial?.photoUrl ?? '');
  late final TextEditingController _accessCode =
  TextEditingController(text: widget.initial?.accessCode ?? '');

  late DateTime _startedAt = widget.initial?.startedAt ?? DateTime.now();

  // --- Mentor dropdown state ---
  final List<_MentorLite> _mentors = [];
  final Map<String, String> _mentorNameById = {};
  bool _loadingMentors = false;
  String? _selectedMentorId; // null=미배정

  @override
  void initState() {
    super.initState();
    _selectedMentorId = (widget.initial?.mentorId?.isNotEmpty == true)
        ? widget.initial!.mentorId
        : null;
    _loadMentors();
  }


  Future<void> _loadMentors() async {
    setState(() => _loadingMentors = true);
    try {
      final rows = await SupabaseService.instance.adminListMentors();
      _mentors
        ..clear()
        ..addAll(rows.map((e) => _MentorLite.fromRow(Map<String, dynamic>.from(e))));
      _mentorNameById
        ..clear()
        ..addEntries(_mentors.map((m) => MapEntry(m.id, m.name)));

      // ✅ 현재 선택이 목록에 없다면 미배정(null)로
      if (_selectedMentorId != null && !_mentors.any((m) => m.id == _selectedMentorId)) {
        _selectedMentorId = null;
      }

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('멘토 목록 불러오기 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingMentors = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
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

  // --- 접속 코드 유틸(랜덤 생성 기능 유지) ---
  String _generate4DigitsUnique() {
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

  void _fillRandomCode() {
    setState(() => _accessCode.text = _generate4DigitsUnique());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('랜덤 코드를 생성했어요')),
    );
  }

  // --- 삭제 (서버 연동) ---
  Future<void> _delete() async {
    if (widget.initial == null) return;

    final ok = await showDiscardChangesDialog(
      context,
      title: '멘티 삭제',
      message: '정말 “${widget.initial!.name}” 멘티를 삭제하시겠어요?\n되돌릴 수 없어요.',
      stayText: '취소',
      leaveText: '삭제',
      isDanger: true,                 // 🔴 위험 작업 스타일
      barrierDismissible: true,       // (원하면 false로 변경해도 됨)
    );

    if (!ok) return;

    try {
      await SupabaseService.instance.deleteUser(id: widget.initial!.id);
      if (!mounted) return;
      Navigator.of(context).pop(const MenteeEditResult(deleted: true));
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
    final mentorId = _selectedMentorId; // null이면 미배정

    try {
      Map<String, dynamic> row;
      if (widget.initial == null) {
        // 현재 UI 플로우에서는 신규 멘티 추가를 사용하지 않음 (FAB 제거됨).
        // 혹시 호출되더라도 안전하게 막아둔다.
        throw Exception('신규 멘티 추가는 현재 지원하지 않습니다.');
      } else {
        // 편집
        row = await SupabaseService.instance.updateUserMin(
          id: widget.initial!.id,
          nickname: nickname,
          mentorId: mentorId,      // ✅ uuid 전달(미배정은 null)
        );
        // ---- 여기부터 추가: 멘토 변경 시 관리자 RPC로 배정/해제 수행 ----
        final prevMentorId = widget.initial!.mentorId;   // 예전 배정
        final nextMentorId = mentorId;                   // 드롭다운 선택값(null=미배정)

        if (prevMentorId != nextMentorId) {
          if (nextMentorId == null && prevMentorId != null) {
            // 미배정으로 변경 → 해제
            await SupabaseService.instance.adminUnassignMentees(
              menteeIds: [widget.initial!.id],
            );
          } else if (nextMentorId != null) {
            // 새 멘토로 배정/변경
            await SupabaseService.instance.adminAssignMenteesToMentor(
              mentorId: nextMentorId,
              menteeIds: [widget.initial!.id],
            );
          }
        }
      }

      // 반환 row에는 mentor_name이 없을 수도 있으니, 드롭다운에서 보던 이름으로 보정
      final merged = Map<String, dynamic>.from(row);
      merged['mentor_name'] ??= (mentorId == null ? null : _mentorNameById[mentorId]);

      final entry = Mentee.fromRow(merged);

      if (!mounted) return;
      Navigator.of(context).pop(MenteeEditResult(mentee: entry));
    } catch (e) {
      print(e);
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


    // build() 내부, DropdownButton 만들기 직전
    final String? dropdownValue =
    (_selectedMentorId != null && _mentors.any((m) => m.id == _selectedMentorId))
        ? _selectedMentorId
        : null;

    return GestureDetector(
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
            child: Form(
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

                  // ✅ 담당 멘토 (드롭다운)
                  InputDecorator(
                    decoration: _dec('담당 멘토(없으면 미배정)', Icons.school_outlined),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: dropdownValue,
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('미배정')),
                                ..._mentors.map((m) => DropdownMenuItem<String?>(
                                  value: m.id,
                                  child: Text(m.name, overflow: TextOverflow.ellipsis),
                                )),
                              ],
                              onChanged: (v) => setState(() => _selectedMentorId = v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '목록 새로고침',
                          onPressed: _loadingMentors ? null : _loadMentors,
                          icon: _loadingMentors
                              ? const SizedBox(
                              width: 18, height: 18, child: CupertinoActivityIndicator())
                              : const Icon(Icons.refresh_rounded, color: UiTokens.actionIcon),
                        ),
                        if (_selectedMentorId != null)
                          IconButton(
                            tooltip: '미배정으로 변경',
                            onPressed: () => setState(() => _selectedMentorId = null),
                            icon: const Icon(Icons.clear_rounded, color: UiTokens.actionIcon),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // // 시작일
                  // InkWell(
                  //   onTap: _pickDate,
                  //   borderRadius: BorderRadius.circular(14),
                  //   child: InputDecorator(
                  //     decoration: _dec('시작일', Icons.event_outlined),
                  //     child: Row(
                  //       children: [
                  //         Text(
                  //           _fmtDate(_startedAt),
                  //           style: const TextStyle(
                  //             color: UiTokens.title,
                  //             fontWeight: FontWeight.w800,
                  //           ),
                  //         ),
                  //         const Spacer(),
                  //         const Icon(Icons.calendar_today_outlined, color: UiTokens.actionIcon),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                  //
                  // // 사진 URL (옵션)
                  // TextFormField(
                  //   controller: _photoUrl,
                  //   decoration: _dec('사진 URL(옵션)', Icons.link_outlined),
                  // ),
                  // const SizedBox(height: 16),
                  //
                  // // 접속 코드(필수, 중복 체크는 서버 + 폼에서 1차 체크)
                  // TextFormField(
                  //   controller: _accessCode,
                  //   keyboardType: TextInputType.number,
                  //   inputFormatters: [
                  //     FilteringTextInputFormatter.digitsOnly,
                  //     LengthLimitingTextInputFormatter(4),
                  //   ],
                  //   decoration: _dec('접속 코드 (4자리 숫자)', Icons.vpn_key_outlined).copyWith(
                  //     suffixIcon: IconButton(
                  //       tooltip: '랜덤 생성',
                  //       onPressed: _fillRandomCode,
                  //       icon: const Icon(Icons.casino_rounded),
                  //     ),
                  //   ),
                  //   validator: (v) {
                  //     final s = (v ?? '').trim();
                  //     if (s.isEmpty) return '접속 코드를 입력하세요';
                  //     if (s.length != 4) return '4자리 숫자를 입력하세요';
                  //     if (int.tryParse(s) == null) return '숫자만 입력하세요';
                  //
                  //     final isSameAsInitial =
                  //         (widget.initial?.accessCode.isNotEmpty ?? false) &&
                  //             widget.initial!.accessCode == s;
                  //     if (!isSameAsInitial && widget.existingCodes.contains(s)) {
                  //       return '이미 존재하는 코드입니다';
                  //     }
                  //     return null;
                  //   },
                  // ),
                ],
              ),
            ),
          ),
        ),

        // 하단 버튼(키보드와 함께 상승)
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
}
