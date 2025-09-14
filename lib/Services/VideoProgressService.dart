// lib/Services/VideoProgressService.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class VideoProgressResult {
  final double watchedRatio;          // 0..1
  final int watchedSec;
  final int totalBuckets;
  final int lastPosSec;
  final int? nextUnwatchedStartSec;   // null or sec
  final int bucketSize;

  const VideoProgressResult({
    required this.watchedRatio,
    required this.watchedSec,
    required this.totalBuckets,
    required this.lastPosSec,
    required this.nextUnwatchedStartSec,
    required this.bucketSize,
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

    return VideoProgressResult(
      watchedRatio: _asDouble(row['watched_ratio']),
      watchedSec:   _asInt(row['watched_sec']),
      totalBuckets: _asInt(row['total_buckets']),
      lastPosSec:   _asInt(row['last_pos_sec']),
      nextUnwatchedStartSec: row['next_unwatched_start_sec'] == null
          ? null
          : _asInt(row['next_unwatched_start_sec']),
      bucketSize:   _asInt(row['bucket_size']),
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
    final res = await _sb.rpc('mentee_get_video_progress', params: {
      'p_login_key': loginKey,
      'p_module_code': moduleCode,
    });

    final list = _normalizeRpcResult(res);
    if (list.isEmpty) {
      return const VideoProgressResult(
        watchedRatio: 0, watchedSec: 0, totalBuckets: 0,
        lastPosSec: 0, nextUnwatchedStartSec: 0, bucketSize: 5,
      );
    }
    return VideoProgressResult.fromRow(Map<String, dynamic>.from(list.first as Map));
  }

  Future<VideoProgressResult> menteeUpsertProgress({
    required String loginKey,
    required String moduleCode,
    required int durationSec,
    required int bucketSize,
    required Set<int> newBuckets,
    required int? lastPosSec,
    bool force = false, // ← 추가
  }) async {

    print('menteeUpsert : $loginKey');

    final res = await _sb.rpc('mentee_upsert_video_progress', params: {
      'p_login_key': loginKey,
      'p_module_code': moduleCode,
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
        lastPosSec: 0, nextUnwatchedStartSec: 0, bucketSize: 5,
      );
    }
    return VideoProgressResult.fromRow(Map<String, dynamic>.from(list.first as Map));
  }
}
