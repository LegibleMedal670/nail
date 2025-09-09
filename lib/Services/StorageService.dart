// lib/Services/StorageService.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _sb = Supabase.instance.client;

  String _objectPath({
    required String moduleCode,
    required int version,
    required int week,
    required String filename,
    required String kind, // "video" | "material"
  }) {
    final safe = filename.replaceAll(' ', '_');
    return 'modules/$moduleCode/v$version/week-$week/$kind/$safe';
  }

  Future<String> uploadVideo({
    required File file,
    required String moduleCode,
    required int version,
    required int week,
    bool upsert = false, // ★ 추가
  }) async {
    final ext = p.extension(file.path);
    final name = 'video_${DateTime.now().millisecondsSinceEpoch}$ext';
    final path = _objectPath(
      moduleCode: moduleCode,
      version: version,
      week: week,
      filename: name,
      kind: 'video',
    );

    // upsert 옵션은 동일 경로 재업로드 시 유용
    final fullPath = await _sb.storage.from('videos').upload(
      path,
      file,
      fileOptions: FileOptions(cacheControl: '3600', upsert: upsert),
    );
    return fullPath; // == path
  }

  Future<void> deleteVideo(String objectPath) async {
    await _sb.storage.from('videos').remove([objectPath]);
  }

  // (참고) 스테이징 후 확정하려면 move 사용 가능
  Future<void> moveVideo(String fromPath, String toPath) async {
    await _sb.storage.from('videos').move(fromPath, toPath);
  }
}
