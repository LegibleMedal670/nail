// lib/Manager/page/CheckPasswordPage.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nail/Pages/Manager/page/ManagerMainPage.dart';
import 'package:nail/Pages/Mentee/page/MenteeHomeScaffold.dart';
import 'package:nail/Pages/Mentee/page/MenteeMainPage.dart';
import 'package:nail/Pages/Mentor/page/MentorHomeScaffold.dart'; // ✅ 멘토 라우팅
import 'package:nail/Providers/UserProvider.dart';
import 'package:provider/provider.dart';

/// 진입 모드: 관리자 / 멘티 / 멘토
enum EntryMode { manager, mentee, mentor }

class CheckPasswordPage extends StatefulWidget {
  /// 기본은 관리자(비밀번호). 멘티/멘토 진입에는 EntryMode.mentee / EntryMode.mentor 로 호출하세요.
  const CheckPasswordPage({
    super.key,
    this.mode = EntryMode.manager,
  });

  final EntryMode mode;

  @override
  State<CheckPasswordPage> createState() => _CheckPasswordPageState();
}

class _CheckPasswordPageState extends State<CheckPasswordPage>
    with SingleTickerProviderStateMixin {
  // 스타일
  static const Color kTitleColor = Color.fromRGBO(34, 38, 49, 1);
  static const Color kPrimaryBlue = Color.fromRGBO(47, 130, 246, 1);
  static const Color kErrorRed = Color(0xFFE53935);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  bool _focusArmed = false;

  // Shake 애니메이션
  late final AnimationController _shakeCtl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  String get _code => _controller.text;
  bool get _isFilled => _code.length == 4;

  bool _isError = false;       // 현재 에러 상태(박스/점 색상 반영)
  bool _showErrorText = false; // 안내 문구 노출

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusArmed) return;
    _focusArmed = true;

    // 라우트 전환이 끝난 뒤 키보드 오픈
    final anim = ModalRoute.of(context)?.animation;
    if (anim != null) {
      anim.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          Future.delayed(const Duration(milliseconds: 80), () {
            if (mounted) _focus.requestFocus();
          });
        }
      });
    } else {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _shakeCtl.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _unfocusAll() => FocusScope.of(context).unfocus();

  Future<void> _failFeedback(String? errorText) async {
    setState(() {
      _isError = true;
      _showErrorText = true;
    });
    _shakeCtl.forward(from: 0); // 흔들림

    // 잠깐 유지 후 포커스
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    _focus.requestFocus();

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isError = false;
      _showErrorText = false;
    });
  }

  Future<void> _submit() async {
    if (!_isFilled) return;

    final user = context.read<UserProvider>();
    final code = _code;

    final ok = await user.signInWithCode(code); // 서버 검증 + (멘티/멘토) 캐시 저장
    if (!mounted) return;

    if (!ok) {
      await _failFeedback(
        (widget.mode == EntryMode.manager) ? '비밀번호가 올바르지 않습니다' : '코드가 올바르지 않습니다',
      );
      return;
    }

    // 역할/모드 일치 검증
    if (widget.mode == EntryMode.manager && !user.isAdmin) {
      await user.signOut();
      await _failFeedback('관리자 계정이 아닙니다');
      return;
    }
    if (widget.mode == EntryMode.mentee && (user.isAdmin || user.isMentor)) {
      await user.signOut();
      await _failFeedback('이 코드는 후임 전용입니다');
      return;
    }
    if (widget.mode == EntryMode.mentor && (!user.isMentor || user.isAdmin)) {
      await user.signOut();
      await _failFeedback('이 코드는 선임 전용입니다');
      return;
    }

    // 라우팅
    if (user.isAdmin) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ManagerMainPage()),
            (route) => false,
      );
      return;
    }

    try {
      if (user.isMentor) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MentorHomeScaffold()),
              (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MenteeHomeScaffold()),
              (route) => false,
        );
      }
    } catch (e) {
      await _failFeedback('사용자 정보 조회 실패: $e');
    }
  }

  // ====== UI 문자열(모드별) ======
  String get _titleText {
    switch (widget.mode) {
      case EntryMode.manager:
        return '비밀번호를 입력하세요';
      case EntryMode.mentee:
      case EntryMode.mentor:
        return '접속 코드를 입력하세요';
    }
  }

  String get _subtitleText {
    switch (widget.mode) {
      case EntryMode.manager:
        return '4자리 숫자';
      case EntryMode.mentee:
      case EntryMode.mentor:
        return '관리자에게 받은 4자리 코드';
    }
  }

  String get _errorText {
    switch (widget.mode) {
      case EntryMode.manager:
        return '비밀번호가 올바르지 않습니다';
      case EntryMode.mentee:
      case EntryMode.mentor:
        return '코드가 올바르지 않습니다';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isCodeMode = widget.mode != EntryMode.manager; // ✅ 멘티/멘토는 숫자 표시

    return GestureDetector(
      onTap: _unfocusAll,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: kTitleColor),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 28),
                Text(
                  _titleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: kTitleColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _subtitleText,
                  style: TextStyle(
                    color: kTitleColor.withOpacity(0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // 실제 입력용 히든 필드
                ExcludeSemantics(
                  child: Opacity(
                    opacity: 0.0,
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        autofocus: false,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        enableInteractiveSelection: false,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: [
                          if (widget.mode == EntryMode.manager)
                            AutofillHints.password
                          else
                            AutofillHints.oneTimeCode,
                        ],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),

                // 표시용 PIN 박스(탭 -> 히든 필드 포커스)
                AnimatedBuilder(
                  animation: _shakeCtl,
                  builder: (context, child) {
                    // -1..1 사이의 흔들림 값을 만들어 8px 진폭으로 횡이동
                    final dx = math.sin(_shakeCtl.value * math.pi * 6) * 8;
                    return Transform.translate(offset: Offset(dx, 0), child: child);
                  },
                  child: GestureDetector(
                    onTap: () => _focus.requestFocus(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final isActive = (_code.length == i && _focus.hasFocus) ||
                            (_code.isEmpty && i == 0 && _focus.hasFocus);
                        final isFilled = i < _code.length;

                        final borderColor = _isError
                            ? kErrorRed
                            : (isActive ? kPrimaryBlue : const Color(0xFFDEE4EE));
                        final fillColor = _isError
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFF5F7FB);
                        final textColor = _isError ? kErrorRed : kTitleColor;

                        return Padding(
                          padding: EdgeInsets.only(right: i == 3 ? 0 : 12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: fillColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: borderColor,
                                width: isActive && !_isError ? 2 : 1,
                              ),
                            ),
                            child: isFilled
                                ? (isCodeMode
                            // 멘티/멘토 모드: 숫자 표시
                                ? Text(
                              _code[i],
                              style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            )
                            // 관리자 모드: ● 마스킹
                                : Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: textColor,
                                shape: BoxShape.circle,
                              ),
                            ))
                                : const SizedBox.shrink(),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                // 에러 안내 텍스트
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showErrorText ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _errorText,
                      style: const TextStyle(
                        color: kErrorRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),
              ],
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
              height: 50,
              width: double.infinity,
              child: FilledButton(
                onPressed: _isFilled ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    color: Color.fromRGBO(253, 253, 255, 1),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
