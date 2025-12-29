import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// 서명 전 전화번호 재인증 페이지
class SignaturePhoneVerifyPage extends StatefulWidget {
  final String expectedPhone;

  const SignaturePhoneVerifyPage({
    super.key,
    required this.expectedPhone,
  });

  @override
  State<SignaturePhoneVerifyPage> createState() =>
      _SignaturePhoneVerifyPageState();
}

class _SignaturePhoneVerifyPageState extends State<SignaturePhoneVerifyPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    // ✅ 전화번호 자동 입력(자동 주입에도 포맷 적용)
    _phoneController.text = PhoneNumberUtils.format(widget.expectedPhone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    final phone = _phoneController.text.trim().replaceAll('-', '');
    if (phone.isEmpty || phone.length < 10) {
      _showSnack('올바른 전화번호를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone.startsWith('+82')
            ? phone
            : '+82${phone.substring(1)}', // 010 → +8210
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // 자동 인증 완료 (Android SMS 자동 읽기)
          if (mounted) {
            _showSnack('✅ 인증이 완료되었습니다.');
            Navigator.pop(context, true);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            _showSnack('인증 실패: ${e.message}');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _codeSent = true;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          _showSnack('인증번호가 발송되었습니다.');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      _showSnack('오류: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _codeSent = false;
      _codeController.clear();
    });
    await _sendVerificationCode();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showSnack('6자리 인증번호를 입력해주세요.');
      return;
    }

    if (_verificationId == null) {
      _showSnack('먼저 인증번호를 요청해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      // 재인증 시도 (기존 사용자)
      await _auth.currentUser?.reauthenticateWithCredential(credential);

      if (mounted) {
        _showSnack('✅ 인증이 완료되었습니다.');
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        _showSnack('잘못된 인증번호입니다.');
      } else {
        _showSnack('인증 실패: ${e.message}');
      }
    } catch (e) {
      _showSnack('오류: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isPhoneValid {
    final phone = _phoneController.text.replaceAll('-', '');
    return phone.length >= 10;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UiTokens.title),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // 타이틀
                  Text(
                    _codeSent ? '인증번호를\n입력해주세요' : '본인 인증을\n진행해주세요',
                    style: const TextStyle(
                      color: UiTokens.title,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 서브 타이틀
                  Text(
                    _codeSent
                        ? '${_phoneController.text}로 전송된 인증번호를 입력해주세요.'
                        : '서명 보안을 위해 등록된 전화번호로 인증번호를 발송합니다.',
                    style: TextStyle(
                      color: UiTokens.title.withOpacity(0.5),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 입력 폼
                  if (!_codeSent) _buildPhoneNumberForm() else _buildCodeForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 전화번호 입력 폼
  Widget _buildPhoneNumberForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨
        const Text(
          '휴대폰 번호',
          style: TextStyle(
            color: UiTokens.title,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // 전화번호 입력 필드
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.number,
          enabled: !_isLoading,
          inputFormatters: [
            // ✅ 숫자만 + 길이 제한(11) + 하이픈 포맷
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
            _PhoneNumberFormatter(),
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '010-0000-0000',
            hintStyle: TextStyle(
              color: UiTokens.title.withOpacity(0.3),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: UiTokens.primaryBlue, width: 1.5),
            ),
          ),
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 32),

        // 인증번호 전송 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed:
            (_isLoading || !_isPhoneValid) ? null : _sendVerificationCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: UiTokens.primaryBlue,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
                : Text(
              '인증번호 받기',
              style: TextStyle(
                color: _isPhoneValid
                    ? Colors.white
                    : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 인증번호 입력 폼
  Widget _buildCodeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨
        const Text(
          '인증번호',
          style: TextStyle(
            color: UiTokens.title,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // 인증번호 입력 필드
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          enabled: !_isLoading,
          autofocus: true,
          inputFormatters:  [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            counterText: '',
            hintText: '6자리 숫자 입력',
            hintStyle: TextStyle(
              color: UiTokens.title.withOpacity(0.3),
              fontWeight: FontWeight.w500,
              letterSpacing: 3.0,
            ),
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: UiTokens.primaryBlue, width: 1.5),
            ),
          ),
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w600,
            fontSize: 20,
            letterSpacing: 8.0,
          ),
        ),
        const SizedBox(height: 32),

        // 확인 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (_isLoading || _codeController.text.length != 6)
                ? null
                : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: UiTokens.primaryBlue,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
                : Text(
              '확인',
              style: TextStyle(
                color: _codeController.text.length == 6
                    ? Colors.white
                    : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 재전송 버튼
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _resendCode,
            child: Text(
              '인증번호가 오지 않나요?',
              style: TextStyle(
                color: UiTokens.title.withOpacity(0.5),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ✅ 포매터 로직을 함수로 재사용하기 위한 유틸
class PhoneNumberUtils {
  /// 입력값에서 숫자만 뽑아 010-0000-0000 형태로 변환
  static String format(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if ((i == 2 || i == 6) && i != digits.length - 1) {
        buffer.write('-');
      }
    }

    return buffer.toString();
  }
}

/// 전화번호 자동 포맷터 (010-0000-0000)
class _PhoneNumberFormatter extends TextInputFormatter {
  const _PhoneNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final formatted = PhoneNumberUtils.format(newValue.text);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
