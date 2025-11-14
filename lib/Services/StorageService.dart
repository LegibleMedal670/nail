import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class SignedUrlCacheEntry {
  final String url;
  final DateTime expiresAt;
  const SignedUrlCacheEntry({required this.url, required this.expiresAt});
}

class StorageService {
  final SupabaseClient _sb = Supabase.instance.client;

  // === 서명 URL 캐시 ===
  final Map<String, SignedUrlCacheEntry> _signedCache = {};

  // === 버킷 명 ===
  static const String _videosBucket = 'videos';
  static const String _practiceBucket = 'practice';
  static const String _chatBucket = 'chat';

  // === 경로 표준화 ===
  String normalizeObjectPath(String raw) {
    var s = raw.trim();
    if (s.startsWith('/')) s = s.substring(1);
    if (s.startsWith('videos/')) s = s.substring('videos/'.length);
    if (s.startsWith('practice/')) s = s.substring('practice/'.length);
    return s;
  }

  // ---------------------------------------------------------------------------
  //                               비디오(학습) 섹션
  // ---------------------------------------------------------------------------

  String _objectPath({
    required String moduleCode,
    required int version,
    required int week,
    required String filename,
    required String kind, // "video" | "thumb" | "material"
  }) {
    final safe = filename.replaceAll(' ', '_');
    return 'modules/$moduleCode/v$version/week-$week/$kind/$safe';
  }

  Future<String> uploadVideo({
    required File file,
    required String moduleCode,
    required int version,
    required int week,
    bool upsert = false,
  }) async {
    final ext = p.extension(file.path);
    final name = 'video_${DateTime.now().millisecondsSinceEpoch}$ext';
    final key = _objectPath(
      moduleCode: moduleCode,
      version: version,
      week: week,
      filename: name,
      kind: 'video',
    );
    final returned = await _sb.storage.from(_videosBucket).upload(
      key,
      file,
      fileOptions: FileOptions(cacheControl: '3600', upsert: upsert),
    );
    evictSignedUrl(key);
    evictSignedUrl(returned);
    return key; // 항상 버킷 상대 경로로 리턴
  }

  Future<String> uploadThumbnailBytes({
    required Uint8List bytes,
    required String moduleCode,
    required int version,
    required int week,
    String filename = 'thumb.jpg',
    bool upsert = true,
  }) async {
    final key = _objectPath(
      moduleCode: moduleCode,
      version: version,
      week: week,
      filename: filename,
      kind: 'thumb',
    );
    await _sb.storage.from(_videosBucket).uploadBinary(
      key,
      bytes,
      fileOptions: const FileOptions(cacheControl: '86400', upsert: true),
    );
    evictSignedUrl(key);
    return key;
  }

  Future<void> deleteObject(String objectPath) async {
    final key = normalizeObjectPath(objectPath);
    await _sb.storage.from(_videosBucket).remove([key]);
    evictSignedUrl(key);
  }

  Future<String> getOrCreateSignedUrl(
      String objectPath, {
        int expiresInSec = 21600, // 6h
        int minTtlBufferSec = 300,
      }) async {
    final key = normalizeObjectPath(objectPath);
    final now = DateTime.now();
    final cached = _signedCache[key];
    if (cached != null &&
        now.isBefore(cached.expiresAt.subtract(Duration(seconds: minTtlBufferSec)))) {
      return cached.url;
    }
    final url = await _sb.storage.from(_videosBucket).createSignedUrl(key, expiresInSec);
    final exp = now.add(Duration(seconds: expiresInSec));
    _signedCache[key] = SignedUrlCacheEntry(url: url, expiresAt: exp);
    return url;
  }

  void evictSignedUrl(String? objectPath) {
    if (objectPath == null) return;
    final key = normalizeObjectPath(objectPath);
    _signedCache.remove(key);
  }

  void clearAllCaches() => _signedCache.clear();

  // ---------------------------------------------------------------------------
  //                               채팅(첨부) 섹션
  // ---------------------------------------------------------------------------

  /// rooms/{roomId}/{kind}/{filename}  kind: "images" | "files"
  String chatObjectPath({
    required String roomId,
    required String filename,
    required String kind,
  }) {
    final safe = filename.replaceAll(' ', '_');
    return 'rooms/$roomId/$kind/$safe';
  }

  /// 채팅 파일 업로드 → storage path 반환
  Future<String> uploadChatFile({
    required File file,
    required String roomId,
    required String kind, // "images" | "files"
    bool upsert = false,
    String? contentType,
  }) async {
    final rawName = _fileNameFromPath(file.path);
    final name = _uniqueSanitizedName(_sanitizeForStorage(rawName));
    final key = chatObjectPath(roomId: roomId, filename: name, kind: kind);
    await _sb.storage.from(_chatBucket).upload(
      key,
      file,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: upsert,
        contentType: contentType,
      ),
    );
    evictSignedUrl(key);
    return key;
  }

  Future<String> getOrCreateSignedUrlChat(
    String objectPath, {
    int expiresInSec = 21600,
    int minTtlBufferSec = 300,
  }) async {
    final key = normalizeObjectPath(objectPath);
    final now = DateTime.now();
    final cached = _signedCache[key];
    if (cached != null &&
        now.isBefore(cached.expiresAt.subtract(Duration(seconds: minTtlBufferSec)))) {
      return cached.url;
    }
    final url = await _sb.storage.from(_chatBucket).createSignedUrl(key, expiresInSec);
    final exp = now.add(Duration(seconds: expiresInSec));
    _signedCache[key] = SignedUrlCacheEntry(url: url, expiresAt: exp);
    return url;
  }

  String _fileNameFromPath(String path) {
    final idx = path.replaceAll('\\', '/').split('/').last;
    return idx;
  }

  /// Supabase Storage object key 제약을 고려해 파일명을 정규화
  /// - 공백/제어문자 제거
  /// - 허용: a-zA-Z0-9 . _ - (확장자는 유지)
  /// - 그 외 문자는 '_'로 치환
  /// - 모두 제거되면 timestamp 기반 기본 이름 생성
  String _sanitizeForStorage(String filename) {
    String base = filename.trim();
    if (base.isEmpty) {
      return 'file_${DateTime.now().millisecondsSinceEpoch}';
    }
    // 분리: 이름/확장자
    final dot = base.lastIndexOf('.');
    String namePart = dot > 0 ? base.substring(0, dot) : base;
    String extPart = dot > 0 ? base.substring(dot) : '';
    // 허용 문자만 남기기
    final reg = RegExp(r'[^a-zA-Z0-9._-]');
    namePart = namePart.replaceAll(reg, '_');
    // 연속 '_' 축약
    namePart = namePart.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (namePart.isEmpty) {
      namePart = 'file_${DateTime.now().millisecondsSinceEpoch}';
    }
    // 확장자도 허용 문자만
    extPart = extPart.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
    if (extPart.length > 20) {
      extPart = extPart.substring(0, 20);
    }
    return '$namePart$extPart';
  }

  /// 같은 이름을 여러 번 업로드해도 충돌하지 않도록 타임스탬프를 덧붙여 고유화
  String _uniqueSanitizedName(String sanitized) {
    final dot = sanitized.lastIndexOf('.');
    final namePart = dot > 0 ? sanitized.substring(0, dot) : sanitized;
    final extPart = dot > 0 ? sanitized.substring(dot) : '';
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${namePart}_$ts$extPart';
  }

  // ---------------------------------------------------------------------------
  //                      Practice(실습) - 세트 참고 이미지(관리자)
  // ---------------------------------------------------------------------------

  /// practice_sets/{code}/refs/{filename}
  String practiceObjectPath({
    required String code,
    required String filename,
  }) {
    final safe = filename.replaceAll(' ', '_');
    return 'practice_sets/$code/refs/$safe';
  }

  Future<String> uploadPracticeImageBytes({
    required Uint8List bytes,
    required String code,
    String? filename, // null이면 타임스탬프 기반 이름
    bool upsert = true,
  }) async {
    final name = filename ?? 'ref_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final key = practiceObjectPath(code: code, filename: name);

    await _sb.storage.from(_practiceBucket).uploadBinary(
      key,
      bytes,
      fileOptions: const FileOptions(
        cacheControl: '3600',
        upsert: true,
        contentType: 'image/jpeg',
      ),
    );

    evictSignedUrl(key);
    return key; // DB에는 이 키를 저장
  }

  Future<String> uploadPracticeImageFile({
    required File file,
    required String code,
    bool upsert = true,
  }) async {
    final ext = p.extension(file.path).toLowerCase();
    final name = 'ref_${DateTime.now().millisecondsSinceEpoch}$ext';
    final key = practiceObjectPath(code: code, filename: name);

    await _sb.storage.from(_practiceBucket).upload(
      key,
      file,
      fileOptions: FileOptions(cacheControl: '3600', upsert: upsert),
    );

    evictSignedUrl(key);
    return key;
  }

  Future<void> deletePracticeObject(String objectPath) async {
    final key = normalizeObjectPath(objectPath);
    await _sb.storage.from(_practiceBucket).remove([key]);
    evictSignedUrl(key);
  }

  Future<String> getOrCreateSignedUrlPractice(
      String objectPath, {
        int expiresInSec = 21600, // 6h
        int minTtlBufferSec = 300,
      }) async {
    final key = normalizeObjectPath(objectPath);
    final now = DateTime.now();
    final cached = _signedCache[key];
    if (cached != null &&
        now.isBefore(cached.expiresAt.subtract(Duration(seconds: minTtlBufferSec)))) {
      return cached.url;
    }

    final url = await _sb.storage.from(_practiceBucket).createSignedUrl(
      key,
      expiresInSec,
    );

    final exp = now.add(Duration(seconds: expiresInSec));
    _signedCache[key] = SignedUrlCacheEntry(url: url, expiresAt: exp);
    return url;
  }

  // ---------------------------------------------------------------------------
  //                  Practice(실습) - 멘티 제출 이미지(Attempt 단위)
  // ---------------------------------------------------------------------------

  /// attempts/{attempt_id}/{filename}
  String practiceAttemptObjectPath({
    required String attemptId,
    required String filename,
  }) {
    final safe = filename.replaceAll(' ', '_');
    return 'attempts/$attemptId/$safe';
  }

  /// 파일 한 장 업로드 → 키 반환
  Future<String> uploadPracticeAttemptImageFile({
    required File file,
    required String attemptId,
    bool upsert = false,
  }) async {
    final ext = p.extension(file.path).toLowerCase();
    final name = 'img_${DateTime.now().millisecondsSinceEpoch}$ext';
    final key = practiceAttemptObjectPath(attemptId: attemptId, filename: name);

    await _sb.storage.from(_practiceBucket).upload(
      key,
      file,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: upsert,
        // contentType는 생략해도 되지만 넣고 싶다면 아래처럼:
        // contentType: _inferImageContentTypeFromPath(file.path),
      ),
    );

    evictSignedUrl(key);
    return key;
  }

  /// 바이트 업로드 → 키 반환
  Future<String> uploadPracticeAttemptImageBytes({
    required Uint8List bytes,
    required String attemptId,
    String filename = 'img.jpg',
    bool upsert = false,
    String contentType = 'image/jpeg',
  }) async {
    final name = filename.isEmpty
        ? 'img_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : filename.replaceAll(' ', '_');
    final key = practiceAttemptObjectPath(attemptId: attemptId, filename: name);

    await _sb.storage.from(_practiceBucket).uploadBinary(
      key,
      bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: upsert,
        contentType: contentType,
      ),
    );

    evictSignedUrl(key);
    return key;
  }

  /// 파일 여러 장 배치 업로드 → 키 배열 반환
  Future<List<String>> uploadPracticeAttemptFilesBatch({
    required List<File> files,
    required String attemptId,
    bool upsert = false,
  }) async {
    final keys = <String>[];
    for (final f in files) {
      final k = await uploadPracticeAttemptImageFile(
        file: f,
        attemptId: attemptId,
        upsert: upsert,
      );
      keys.add(k);
    }
    return keys;
  }

  // (선택) path 확장자를 보고 content-type 추정
  String _inferImageContentTypeFromPath(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
      // Supabase가 heic 미지원일 수 있으니, 업로드 전 변환을 권장
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }
}
