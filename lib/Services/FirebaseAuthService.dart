import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase 전화번호 인증 서비스
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 인증 진행 중 상태 저장
  String? _verificationId;
  int? _resendToken;

  /// 현재 Firebase 사용자
  User? get currentUser => _auth.currentUser;

  /// 현재 사용자의 Firebase UID
  String? get currentUid => _auth.currentUser?.uid;

  /// 전화번호 인증 코드 전송
  /// 
  /// [phoneNumber] - 국가코드 포함 전화번호 (예: +821012345678)
  /// [onCodeSent] - 인증번호 전송 성공 콜백
  /// [onError] - 에러 발생 콜백
  /// [onAutoVerified] - 자동 인증 완료 콜백 (Android에서 SMS 자동 읽기)
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required VoidCallback onCodeSent,
    required Function(String errorMessage) onError,
    Function(UserCredential credential)? onAutoVerified,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),

        // 인증번호 전송 완료
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          debugPrint('[FirebaseAuth] 인증번호 전송 완료: $verificationId');
          onCodeSent();
        },

        // 자동 인증 완료 (Android SMS 자동 읽기)
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('[FirebaseAuth] 자동 인증 완료');
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            onAutoVerified?.call(userCredential);
          } catch (e) {
            onError('자동 인증 실패: $e');
          }
        },

        // 인증 실패
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('[FirebaseAuth] 인증 실패: ${e.code} - ${e.message}');
          String message;
          switch (e.code) {
            case 'invalid-phone-number':
              message = '유효하지 않은 전화번호입니다.';
              break;
            case 'too-many-requests':
              message = '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
              break;
            case 'quota-exceeded':
              message = '일일 인증 한도를 초과했습니다.';
              break;
            default:
              message = e.message ?? '인증에 실패했습니다.';
          }
          onError(message);
        },

        // 인증 코드 자동 검색 타임아웃
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          debugPrint('[FirebaseAuth] 자동 검색 타임아웃');
        },

        // 재전송 시 사용
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      debugPrint('[FirebaseAuth] verifyPhoneNumber 예외: $e');
      onError('인증 요청 중 오류가 발생했습니다.');
    }
  }

  /// 인증번호 확인 및 로그인
  /// 
  /// [smsCode] - 사용자가 입력한 6자리 인증번호
  /// Returns: 성공 시 UserCredential, 실패 시 null
  Future<UserCredential?> signInWithSmsCode({
    required String smsCode,
    required Function(String errorMessage) onError,
  }) async {
    if (_verificationId == null) {
      onError('인증번호를 먼저 요청해주세요.');
      return null;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('[FirebaseAuth] 로그인 성공: ${userCredential.user?.uid}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[FirebaseAuth] 로그인 실패: ${e.code} - ${e.message}');
      String message;
      switch (e.code) {
        case 'invalid-verification-code':
          message = '인증번호가 올바르지 않습니다.';
          break;
        case 'session-expired':
          message = '인증 세션이 만료되었습니다. 다시 시도해주세요.';
          break;
        default:
          message = e.message ?? '로그인에 실패했습니다.';
      }
      onError(message);
      return null;
    } catch (e) {
      debugPrint('[FirebaseAuth] signInWithSmsCode 예외: $e');
      onError('로그인 중 오류가 발생했습니다.');
      return null;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
    _verificationId = null;
    _resendToken = null;
    debugPrint('[FirebaseAuth] 로그아웃 완료');
  }

  /// 전화번호 포맷 변환 (한국)
  /// 01012345678 → +821012345678
  static String formatKoreanPhoneNumber(String phone) {
    // 공백, 하이픈 제거
    String cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');
    
    // 이미 +82로 시작하면 그대로 반환
    if (cleaned.startsWith('+82')) {
      return cleaned;
    }
    
    // 010으로 시작하면 0 제거하고 +82 추가
    if (cleaned.startsWith('0')) {
      return '+82${cleaned.substring(1)}';
    }
    
    // 그 외는 +82 추가
    return '+82$cleaned';
  }
}
