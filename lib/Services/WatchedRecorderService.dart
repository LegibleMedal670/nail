// lib/Services/WatchedRecorderService.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:nail/Services/VideoProgressService.dart';

class WatchedRecorderService {
  final VideoPlayerController controller;
  final String moduleCode;
  final int durationSec;
  final int bucketSize;

  final Duration tickInterval;
  final Duration flushInterval;
  final int seekJumpThresholdSec;
  final int seekResumeGuardSec;

  final String loginKey;

  final void Function(VideoProgressResult result)? onServerAck;

  Timer? _tickTimer;
  Timer? _flushTimer;

  bool _running = false;

  int? _lastPosSec;
  int _seekCooldownTicks = 0;

  final Set<int> _sessionBuckets = <int>{};
  final Set<int> _pendingBuckets = <int>{};

  int? _lastFlushedPos;

  WatchedRecorderService({
    required this.controller,
    required this.moduleCode,
    required this.durationSec,
    this.bucketSize = 5,
    required this.loginKey, // ✅ 추가
    this.tickInterval = const Duration(seconds: 1),
    this.flushInterval = const Duration(seconds: 8),
    this.seekJumpThresholdSec = 8,
    this.seekResumeGuardSec = 2,
    this.onServerAck,
  });

  /// 현재 세션에서 아직 서버로 안 보낸 신규 버킷들(강제 업서트에 활용)
  Set<int> get pendingBuckets => Set.unmodifiable(_pendingBuckets);

  void start() {
    if (_running) return;
    _running = true;
    _tickTimer ??= Timer.periodic(tickInterval, (_) => _onTick());
    _flushTimer ??= Timer.periodic(flushInterval, (_) => _flush());
  }

  int _bucketIndex(int posSec) => (posSec / math.max(1, bucketSize)).floor();

  void _onTick() {
    if (!_running) return;
    final v = controller.value;
    if (!v.isInitialized) return;

    final playing = v.isPlaying;
    final buffering = v.isBuffering;
    final posSec = v.position.inSeconds;

    if (_lastPosSec != null) {
      final diff = (posSec - _lastPosSec!).abs();
      if (diff >= seekJumpThresholdSec) {
        _seekCooldownTicks = math.max(1, (seekResumeGuardSec / tickInterval.inSeconds).ceil());
        if (kDebugMode) {
          print('[WatchedRecorder] seek detected (+$diff s) → cooldown=$_seekCooldownTicks');
        }
      }
    }

    if (playing && !buffering) {
      if (_seekCooldownTicks > 0) {
        _seekCooldownTicks -= 1;
      } else {
        final b = _bucketIndex(posSec);
        if (_sessionBuckets.add(b)) {
          _pendingBuckets.add(b);
          if (kDebugMode) print('[WatchedRecorder] +bucket $b (pos=$posSec)');
        }
      }
    }

    _lastPosSec = posSec;
  }

  Future<void> _flush() async {
    if (!_running) return;

    final lastPos = _lastPosSec;
    final hasNew = _pendingBuckets.isNotEmpty;
    final posChanged = (lastPos != null && lastPos != _lastFlushedPos);

    if (!hasNew && !posChanged) return;

    if (loginKey.isEmpty) return;

    final payload = Set<int>.from(_pendingBuckets);
    _pendingBuckets.clear();

    try {
      // ✅ loginKey가 비었으면 호출하지 않음 (안전장치)
      if (loginKey.isEmpty) return;

      final ack = await VideoProgressService.instance.menteeUpsertProgress(
        loginKey: loginKey,            // ✅ 여기!
        moduleCode: moduleCode,
        durationSec: durationSec,
        bucketSize: bucketSize,
        newBuckets: payload,
        lastPosSec: lastPos,
        force: false,                  // 평시 flush는 false
      );
      _lastFlushedPos = lastPos;
      onServerAck?.call(ack);
    } catch (e) {
      if (kDebugMode) {
        print('[WatchedRecorder] flush error: $e');
      }
      _pendingBuckets.addAll(payload);
    }
  }

  Future<void> dispose() async {
    _running = false;
    try { await _flush(); } catch (_) {}
    _tickTimer?.cancel();
    _flushTimer?.cancel();
    _tickTimer = null;
    _flushTimer = null;
  }
}
