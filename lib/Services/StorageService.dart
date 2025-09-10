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

  // === 경로 표준화 ===
  String normalizeObjectPath(String raw) {
    var s = raw.trim();
    if (s.startsWith('/')) s = s.substring(1);
    if (s.startsWith('videos/')) s = s.substring('videos/'.length);
    return s;
  }

  // === 공통 경로 ===
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

  // === 비디오 업로드 ===
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
    final returned = await _sb.storage.from('videos').upload(
      key,
      file,
      fileOptions: FileOptions(cacheControl: '3600', upsert: upsert),
    );
    evictSignedUrl(key);
    evictSignedUrl(returned);
    return key; // 항상 버킷 상대 경로로 리턴
  }

  // === 썸네일 업로드(바이트) ===
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
    await _sb.storage.from('videos').uploadBinary(
      key,
      bytes,
      fileOptions: const FileOptions(cacheControl: '86400', upsert: true),
    );
    evictSignedUrl(key);
    return key;
  }

  // === 삭제 ===
  Future<void> deleteObject(String objectPath) async {
    final key = normalizeObjectPath(objectPath);
    await _sb.storage.from('videos').remove([key]);
    evictSignedUrl(key);
  }

  // === 서명 URL (비디오/이미지 공통) ===
  final Map<String, SignedUrlCacheEntry> _signedCache = {};

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
    final url = await _sb.storage.from('videos').createSignedUrl(key, expiresInSec);
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
}
