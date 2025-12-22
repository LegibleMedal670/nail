import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Welcome/SelectRolePage.dart';
import 'package:nail/Services/FirebaseAuthService.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _authService = FirebaseAuthService();
  
  // 상태 변수
  bool _isCodeSent = false;
  bool _isLoading = false;

  // 입력 필드 컨트롤러
  final _phoneNumberController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// 전화번호 유효성 검사 (010 + 8자리)
  bool get _isPhoneValid {
    final digits = _phoneNumberController.text.replaceAll('-', '');
    return digits.length == 11 && digits.startsWith('010');
  }

  /// 인증번호 전송
  Future<void> _sendVerificationCode() async {
    if (!_isPhoneValid) {
      _showError('올바른 전화번호를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    final phone = _phoneNumberController.text.replaceAll('-', '');
    final formattedPhone = FirebaseAuthService.formatKoreanPhoneNumber(phone);
    debugPrint('인증 요청: $formattedPhone');

    await _authService.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      onCodeSent: () {
        if (mounted) {
          setState(() {
            _isCodeSent = true;
            _isLoading = false;
          });
          _showSnackBar('인증번호가 전송되었습니다.');
        }
      },
      onError: (message) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError(message);
        }
      },
      onAutoVerified: (credential) {
        if (mounted) {
          setState(() => _isLoading = false);
          _onLoginSuccess();
        }
      },
    );
  }

  /// 인증번호 확인 및 로그인
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      _showError('인증번호 6자리를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.signInWithSmsCode(
      smsCode: code,
      onError: (message) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError(message);
        }
      },
    );

    if (result != null && mounted) {
      setState(() => _isLoading = false);
      _onLoginSuccess();
    }
  }

  /// 로그인 성공 처리
  void _onLoginSuccess() {
    final uid = _authService.currentUid;
    debugPrint('Firebase 로그인 성공! UID: $uid');
    
    // TODO: Supabase와 연동 - Firebase UID로 사용자 조회/생성
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SelectRolePage()),
      (route) => false,
    );
  }

  /// 인증번호 재전송
  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    
    final phone = _phoneNumberController.text.replaceAll('-', '');
    final formattedPhone = FirebaseAuthService.formatKoreanPhoneNumber(phone);

    await _authService.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      onCodeSent: () {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('인증번호가 재전송되었습니다.');
        }
      },
      onError: (message) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError(message);
        }
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                    _isCodeSent ? '인증번호를\n입력해주세요' : '휴대폰 번호를\n입력해주세요',
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
                    _isCodeSent 
                        ? '${_phoneNumberController.text}로 전송된 인증번호를 입력해주세요.'
                        : '본인 확인을 위해 휴대폰 번호를 입력해주세요.',
                    style: TextStyle(
                      color: UiTokens.title.withOpacity(0.5),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 입력 폼
                  if (!_isCodeSent) _buildPhoneNumberForm() else _buildCodeForm(),
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
          controller: _phoneNumberController,
          keyboardType: TextInputType.number,
          enabled: !_isLoading,
          inputFormatters: [
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
              borderSide: const BorderSide(color: UiTokens.primaryBlue, width: 1.5),
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
            onPressed: (_isLoading || !_isPhoneValid) ? null : _sendVerificationCode,
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
                      color: _isPhoneValid ? Colors.white : const Color(0xFF94A3B8),
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
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            counterText: '',
            hintText: '6자리 숫자 입력',
            hintStyle: TextStyle(
              color: UiTokens.title.withOpacity(0.3),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
              borderSide: const BorderSide(color: UiTokens.primaryBlue, width: 1.5),
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
            onPressed: (_isLoading || _codeController.text.length != 6) ? null : _verifyCode,
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

/// 전화번호 자동 포맷터 (010-0000-0000)
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('-', '');
    
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 7) {
        buffer.write('-');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
