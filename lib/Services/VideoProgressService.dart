// lib/Services/VideoProgressService.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ModuleKey.dart';

class VideoProgressResult {
  final double watchedRatio;          // 0..1
  final int watchedSec;
  final int totalBuckets;
  final int lastPosSec;
  final int? nextUnwatchedStartSec;   // null or sec
  final int bucketSize;
  final bool isCompleted;             // Soft 기준: true/false

  const VideoProgressResult({
    required this.watchedRatio,
    required this.watchedSec,
    required this.totalBuckets,
    required this.lastPosSec,
    required this.nextUnwatchedStartSec,
    required this.bucketSize,
    required this.isCompleted,
  });

  factory VideoProgressResult.fromRow(Map row) {
    double _asDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int _asInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    bool _asBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().toLowerCase();
      return s == 't' || s == 'true' || s == '1';
    }

    return VideoProgressResult(
      watchedRatio: _asDouble(row['watched_ratio']),
      watchedSec:   _asInt(row['watched_sec']),
      totalBuckets: _asInt(row['total_buckets']),
      lastPosSec:   _asInt(row['last_pos_sec']),
      nextUnwatchedStartSec: row['next_unwatched_start_sec'] == null
          ? null
          : _asInt(row['next_unwatched_start_sec']),
      bucketSize:   _asInt(row['bucket_size']),
      isCompleted:  _asBool(row['is_completed']),
    );
  }
}

class VideoProgressService {
  VideoProgressService._();
  static final instance = VideoProgressService._();
  final _sb = Supabase.instance.client;

  List _normalizeRpcResult(dynamic raw) {
    if (raw is PostgrestResponse) return raw.data is List ? raw.data : <dynamic>[raw.data];
    if (raw is List) return raw;
    if (raw is Map) return [raw];
    return const <dynamic>[];
  }

  Future<VideoProgressResult> menteeGetProgress({
    required String loginKey,
    required String moduleCode,
  }) async {
    final code = ModuleKey.norm(moduleCode);
    final res = await _sb.rpc('mentee_get_video_progress', params: {
      'p_firebase_uid': loginKey,
      'p_module_code': code,
    });

    final list = _normalizeRpcResult(res);
    if (list.isEmpty) {
      return const VideoProgressResult(
        watchedRatio: 0, watchedSec: 0, totalBuckets: 0,
        lastPosSec: 0, nextUnwatchedStartSec: null, bucketSize: 5,
        isCompleted: false,
      );
    }
    final row = Map<String, dynamic>.from(list.first as Map);
    final pr = VideoProgressResult.fromRow(row);
    if (kDebugMode) {
      print('[VideoProgressService] get: '
          'ratio=${(pr.watchedRatio*100).toStringAsFixed(2)}% '
          'watched=${pr.watchedSec} total=${pr.totalBuckets} '
          'last=${pr.lastPosSec} next=${pr.nextUnwatchedStartSec} '
          'bucket=${pr.bucketSize} done=${pr.isCompleted}');
    }
    return pr;
  }

  Future<VideoProgressResult> menteeUpsertProgress({
    required String loginKey,
    required String moduleCode,
    required int durationSec,
    required int bucketSize,
    required Set<int> newBuckets,
    required int? lastPosSec,
    bool force = false, // 서버 증가량 클램프 해제 스위치
  }) async {
    final code = ModuleKey.norm(moduleCode);

    if (kDebugMode) {
      print('menteeUpsert : $loginKey '
          '(code=$code, d=$durationSec, bsz=$bucketSize, nb=${newBuckets.length}, last=$lastPosSec, force=$force)');
    }

    final res = await _sb.rpc('mentee_upsert_video_progress', params: {
      'p_firebase_uid': loginKey,
      'p_module_code': code,
      'p_duration_sec': durationSec,
      'p_bucket_size': bucketSize,
      'p_new_buckets': newBuckets.toList(),
      'p_last_pos_sec': lastPosSec,
      'p_force': force,
    });

    final list = _normalizeRpcResult(res);
    if (list.isEmpty) {
      return const VideoProgressResult(
        watchedRatio: 0, watchedSec: 0, totalBuckets: 0,
        lastPosSec: 0, nextUnwatchedStartSec: null, bucketSize: 5,
        isCompleted: false,
      );
    }
    final row = Map<String, dynamic>.from(list.first as Map);
    final pr = VideoProgressResult.fromRow(row);
    if (kDebugMode) {
      print('[VideoProgressService] upsert ack: '
          'ratio=${(pr.watchedRatio*100).toStringAsFixed(2)}% '
          'watched=${pr.watchedSec} total=${pr.totalBuckets} '
          'last=${pr.lastPosSec} next=${pr.nextUnwatchedStartSec} '
          'bucket=${pr.bucketSize} done=${pr.isCompleted}');
    }
    return pr;
  }
}
