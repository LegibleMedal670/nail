import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 서명 메타데이터
class SignatureMetadata {
  final String phoneNumber;
  final String deviceId;
  final String deviceModel;
  final String deviceOs;
  final String deviceManufacturer;
  final String hashValue;

  const SignatureMetadata({
    required this.phoneNumber,
    required this.deviceId,
    required this.deviceModel,
    required this.deviceOs,
    required this.deviceManufacturer,
    required this.hashValue,
  });

  Map<String, dynamic> toDeviceInfoJson() => {
        'id': deviceId,
        'model': deviceModel,
        'os': deviceOs,
        'manufacturer': deviceManufacturer,
      };
}

/// 서명 서비스
class SignatureService {
  SignatureService._();
  static final instance = SignatureService._();

  final _sb = Supabase.instance.client;
  final _deviceInfo = DeviceInfoPlugin();

  /// 기기 정보 및 해시값 수집
  Future<SignatureMetadata> collectMetadata({
    required Uint8List signatureImage,
    required String phoneNumber,
  }) async {
    String deviceId = '';
    String model = '';
    String os = '';
    String manufacturer = '';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        model = androidInfo.model;
        os = 'Android ${androidInfo.version.release}';
        manufacturer = androidInfo.manufacturer;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? '';
        model = iosInfo.model;
        os = 'iOS ${iosInfo.systemVersion}';
        manufacturer = 'Apple';
      }
    } catch (e) {
      deviceId = 'unknown';
      model = 'unknown';
      os = 'unknown';
      manufacturer = 'unknown';
    }

    // SHA-256 해시 생성 (서명 이미지 + 전화번호 + 기기ID + 타임스탬프)
    final timestamp = DateTime.now().toIso8601String();
    final combinedData = [
      ...signatureImage,
      ...utf8.encode(phoneNumber),
      ...utf8.encode(deviceId),
      ...utf8.encode(timestamp),
    ];
    final hash = sha256.convert(combinedData).toString();

    return SignatureMetadata(
      phoneNumber: phoneNumber,
      deviceId: deviceId,
      deviceModel: model,
      deviceOs: os,
      deviceManufacturer: manufacturer,
      hashValue: hash,
    );
  }

  /// 서명 이미지 업로드 (압축 포함)
  Future<String> uploadSignatureImage({
    required Uint8List imageBytes,
    required String type, // 'theory', 'practice_mentor', etc
    required String userId,
  }) async {
    try {
      // 이미지 압축 (quality: 80, 가독성 유지)
      final compressed = await FlutterImageCompress.compressWithList(
        imageBytes,
        quality: 80,
        format: CompressFormat.png,
      );


      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$type/$userId/$timestamp.png';

      // 'signatures' 버킷 사용
      const bucketName = 'signatures';

      await _sb.storage.from(bucketName).uploadBinary(
            path,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true, // 덮어쓰기 허용
            ),
          );

      final url = _sb.storage.from(bucketName).getPublicUrl(path);

      return url;
    } catch (e) {
      rethrow;
    }
  }

  /// 이론 교육 서명
  Future<String> signTheoryModule({
    required String loginKey,
    required String moduleCode,
    required Uint8List signatureImage,
    required String phoneNumber,
  }) async {
    try {

      // 1. 이미지 업로드 (loginKey를 경로에 사용)
      final imageUrl = await uploadSignatureImage(
        imageBytes: signatureImage,
        type: 'theory',
        userId: loginKey, // Firebase UID를 경로에 사용
      );

      // 2. 메타데이터 수집
      final metadata = await collectMetadata(
        signatureImage: signatureImage,
        phoneNumber: phoneNumber,
      );

      // 3. RPC 호출
      final result = await _sb.rpc(
        'sign_theory_module',
        params: {
          'p_firebase_uid': loginKey,
          'p_module_code': moduleCode,
          'p_signature_url': imageUrl,
          'p_hash_value': metadata.hashValue,
          'p_phone_number': phoneNumber,
          'p_device_info': metadata.toDeviceInfoJson(),
        },
      );


      // RPC 결과 파싱 (UUID 반환)
      String signatureId;
      if (result is String) {
        signatureId = result;
      } else if (result is List && result.isNotEmpty) {
        signatureId = result.first.toString();
      } else if (result is Map && result.containsKey('id')) {
        signatureId = result['id'].toString();
      } else {
        signatureId = result.toString();
      }

      return signatureId;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  /// 실습 교육 서명 (선임 or 후임)
  Future<String> signPracticeAttempt({
    required String loginKey,
    required String attemptId,
    required bool isMentor,
    required Uint8List signatureImage,
    required String phoneNumber,
  }) async {
    try {

      // 1. 이미지 업로드 (loginKey를 경로에 사용)
      final type = isMentor ? 'practice_mentor' : 'practice_mentee';
      final imageUrl = await uploadSignatureImage(
        imageBytes: signatureImage,
        type: type,
        userId: loginKey, // Firebase UID를 경로에 사용
      );

      // 2. 메타데이터 수집
      final metadata = await collectMetadata(
        signatureImage: signatureImage,
        phoneNumber: phoneNumber,
      );

      // 3. RPC 호출
      final result = await _sb.rpc(
        'sign_practice_attempt',
        params: {
          'p_firebase_uid': loginKey,
          'p_attempt_id': attemptId,
          'p_is_mentor': isMentor,
          'p_signature_url': imageUrl,
          'p_hash_value': metadata.hashValue,
          'p_phone_number': phoneNumber,
          'p_device_info': metadata.toDeviceInfoJson(),
        },
      );


      // RPC 결과 파싱 (UUID 반환)
      String signatureId;
      if (result is String) {
        signatureId = result;
      } else if (result is List && result.isNotEmpty) {
        signatureId = result.first.toString();
      } else if (result is Map && result.containsKey('id')) {
        signatureId = result['id'].toString();
      } else {
        signatureId = result.toString();
      }

      return signatureId;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  /// 서명된 이론 모듈 목록 조회
  Future<Set<String>> getSignedTheoryModules({
    required String loginKey,
  }) async {
    try {
      final result = await _sb.rpc(
        'get_signed_theory_modules',
        params: {'p_firebase_uid': loginKey},
      );

      final List<dynamic> rows = result is List ? result : [result];
      final Set<String> signed = {};

      for (final row in rows) {
        if (row is Map && row['module_code'] != null) {
          signed.add(row['module_code'] as String);
        }
      }

      return signed;
    } catch (e) {
      return {};
    }
  }

  /// 서명된 실습 목록 조회
  Future<Map<String, Map<String, dynamic>>> getSignedPracticeAttempts({
    required String loginKey,
  }) async {
    try {
      final result = await _sb.rpc(
        'get_signed_practice_attempts',
        params: {'p_firebase_uid': loginKey},
      );

      final List<dynamic> rows = result is List ? result : [result];
      final Map<String, Map<String, dynamic>> signedMap = {};

      for (final row in rows) {
        if (row is Map && row['attempt_id'] != null) {
          final attemptId = row['attempt_id'] as String;
          signedMap[attemptId] = {
            'set_id': row['set_id'],
            'mentor_signed': row['mentor_signed'] == true,
            'mentee_signed': row['mentee_signed'] == true,
            'mentor_signed_at': row['mentor_signed_at'],
            'mentee_signed_at': row['mentee_signed_at'],
          };
        }
      }

      return signedMap;
    } catch (e) {
      return {};
    }
  }

  /// 수료 서명 (후임 or 선임)
  Future<String> signCompletion({
    required String loginKey,
    required String menteeId,
    required bool isMentor,
    required Uint8List signatureImage,
    required String phoneNumber,
  }) async {
    try {

      // 1. 이미지 업로드
      final type = isMentor ? 'completion_mentor' : 'completion_mentee';
      final imageUrl = await uploadSignatureImage(
        imageBytes: signatureImage,
        type: type,
        userId: loginKey,
      );

      // 2. 메타데이터 수집
      final metadata = await collectMetadata(
        signatureImage: signatureImage,
        phoneNumber: phoneNumber,
      );

      // 3. RPC 호출
      final result = await _sb.rpc(
        'sign_completion',
        params: {
          'p_firebase_uid': loginKey,
          'p_mentee_id': menteeId,
          'p_is_mentor': isMentor,
          'p_signature_url': imageUrl,
          'p_hash_value': metadata.hashValue,
          'p_phone_number': phoneNumber,
          'p_device_info': metadata.toDeviceInfoJson(),
        },
      );


      // RPC 결과 파싱 (UUID 반환)
      String signatureId;
      if (result is String) {
        signatureId = result;
      } else if (result is List && result.isNotEmpty) {
        signatureId = result.first.toString();
      } else if (result is Map && result.containsKey('id')) {
        signatureId = result['id'].toString();
      } else {
        signatureId = result.toString();
      }

      return signatureId;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  /// 수료 서명 상태 조회 (후임용)
  Future<Map<String, dynamic>?> getCompletionSignatureStatus({
    required String loginKey,
  }) async {
    try {
      final result = await _sb.rpc(
        'get_completion_signature_status',
        params: {'p_firebase_uid': loginKey},
      );

      if (result == null) return null;
      
      if (result is Map) {
        return {
          'mentee_signed': result['mentee_signed'] == true,
          'mentor_signed': result['mentor_signed'] == true,
          'mentee_signed_at': result['mentee_signed_at'],
          'mentor_signed_at': result['mentor_signed_at'],
        };
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 선임용: 수료 승인 대기 목록 조회
  Future<List<Map<String, dynamic>>> getCompletionPendingList({
    required String mentorLoginKey,
  }) async {
    try {
      final result = await _sb.rpc(
        'mentor_list_completion_pending',
        params: {'p_firebase_uid': mentorLoginKey},
      );

      final List<dynamic> rows = result is List ? result : [result];
      return rows.where((r) => r != null).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      return [];
    }
  }
}

