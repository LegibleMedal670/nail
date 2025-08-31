import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nail/Manager/page/ManagerMainPage.dart';

class CheckPasswordPage extends StatefulWidget {
  const CheckPasswordPage({super.key});

  @override
  State<CheckPasswordPage> createState() => _CheckPasswordPageState();
}

class _CheckPasswordPageState extends State<CheckPasswordPage>
    with SingleTickerProviderStateMixin {
  // 역할 선택 페이지 스타일
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

  final String password = '1234';

  bool _isError = false;       // 현재 에러 상태(박스/점 색상 반영)
  bool _showErrorText = false; // 안내 문구 노출

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) _focus.requestFocus();
    // });
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
      // 애니메이션이 없다면 약간 지연 후 포커스
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

  Future<void> _failFeedback() async {
    setState(() {
      _isError = true;
      _showErrorText = true;
    });
    _shakeCtl.forward(from: 0); // 흔들림 시작

    // 잠깐 보여주고 입력 리셋
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    _focus.requestFocus();

    // 에러 하이라이트는 조금 더 유지했다가 해제
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isError = false;
      _showErrorText = false;
    });
  }

  void _submit() {
    if (!_isFilled) return;
    final code = _code;
    if (code == password) {
      // TODO: 성공 시 이동/처리
      // Navigator.of(context).push(...);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => ManagerMainPage()),
            (Route<dynamic> route) => false,
      );
    } else {
      _failFeedback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
                const Text(
                  '비밀번호를 입력하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kTitleColor,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '4자리 숫자',
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
                        autofillHints: const [AutofillHints.password],
                        inputFormatters:  [
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
                        final dotColor = _isError ? kErrorRed : kTitleColor;
                        final fillColor = _isError
                            ? const Color(0xFFFFEBEE) // 옅은 레드 배경
                            : const Color(0xFFF5F7FB);

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
                                ? Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            )
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
                      '비밀번호가 올바르지 않습니다',
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
