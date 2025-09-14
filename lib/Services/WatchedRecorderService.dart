// lib/Services/WatchedRecorderService.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:nail/Services/VideoProgressService.dart';

/// Records watched buckets and periodically flushes them to the server.
/// - Buckets are recorded while playing (not buffering).
/// - Large seek jumps start a short cooldown to avoid bogus buckets.
/// - Flush sends only *new* buckets since last ack to the RPC.
class WatchedRecorderService {
  final VideoPlayerController controller;
  final String moduleCode;

  /// Initial duration snapshot (seconds). May be 0 on iOS/streaming right after initialize().
  /// We compute an effective duration at flush time using the controller's *current* duration.
  final int durationSec;

  final int bucketSize;

  final Duration tickInterval;
  final Duration flushInterval;
  final int seekJumpThresholdSec; // treat as seek if |Δpos| >= this
  final int seekResumeGuardSec;   // after a seek, pause recording for N seconds

  final String loginKey;

  final void Function(VideoProgressResult result)? onServerAck;

  Timer? _tickTimer;
  Timer? _flushTimer;

  bool _running = false;

  int? _lastPosSec;
  int _seekCooldownTicks = 0;

  /// Buckets seen during this page session (for stats/force-full-cover on exit, if needed)
  final Set<int> _sessionBuckets = <int>{};

  /// Buckets pending to be flushed to the server
  final Set<int> _pendingBuckets = <int>{};

  int? _lastFlushedPos;

  WatchedRecorderService({
    required this.controller,
    required this.moduleCode,
    required this.durationSec,
    required this.loginKey,
    this.bucketSize = 5,
    this.tickInterval = const Duration(seconds: 1),
    this.flushInterval = const Duration(seconds: 8),
    this.seekJumpThresholdSec = 8,
    this.seekResumeGuardSec = 2,
    this.onServerAck,
  });

  /// Expose pending buckets for a final force-upsert when leaving the page
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

    // Seek detection → small cooldown to avoid false buckets
    if (_lastPosSec != null) {
      final diff = (posSec - _lastPosSec!).abs();
      if (diff >= seekJumpThresholdSec) {
        _seekCooldownTicks = math.max(1, (seekResumeGuardSec / tickInterval.inSeconds).ceil());
        if (kDebugMode) {
          print('[WatchedRecorder] seek detected: Δ$diff s → cooldown ticks: $_seekCooldownTicks');
        }
      }
    }

    final canRecord = playing && !buffering && _seekCooldownTicks <= 0;

    if (canRecord) {
      final idx = _bucketIndex(posSec);
      if (!_sessionBuckets.contains(idx)) {
        _sessionBuckets.add(idx);
        _pendingBuckets.add(idx);
        if (kDebugMode) {
          print('[WatchedRecorder] +bucket $idx (pos=$posSec)');
        }
      }
    } else {
      if (kDebugMode && (playing || buffering) && _seekCooldownTicks > 0) {
        print('[WatchedRecorder] cooldown… ($_seekCooldownTicks)');
      }
    }

    _lastPosSec = posSec;
    if (_seekCooldownTicks > 0) _seekCooldownTicks -= 1;
  }

  int _effectiveDurationSec() {
    // Prefer the controller's latest duration if known (>0), else fall back to the initial snapshot.
    final d = controller.value.duration.inSeconds;
    if (d > 0) return d;
    return math.max(0, durationSec);
  }

  Future<void> _flush() async {
    if (!_running) return;

    final v = controller.value;
    if (!v.isInitialized) return;

    final currentPos = v.position.inSeconds;
    final posChanged = _lastFlushedPos == null || _lastFlushedPos != currentPos;
    final hasNew = _pendingBuckets.isNotEmpty;

    // Nothing to send
    if (!hasNew && !posChanged) return;

    if (loginKey.isEmpty) return;

    // Copy payload and clear local buffer for at-least-once delivery semantics
    final payload = Set<int>.from(_pendingBuckets);
    _pendingBuckets.clear();

    // Compute robust duration/lastPos
    var effDuration = _effectiveDurationSec();

    var lastPos = currentPos;
    if (effDuration > 0 && lastPos >= effDuration) {
      lastPos = effDuration - 1; // keep last_pos within [0, duration-1]
    }

    // Guard: if we are sending only a position update (no buckets) and position changed,
    // include the current bucket so server always has ≥1 bucket when duration becomes known.
    if (payload.isEmpty && posChanged) {
      final idx = _bucketIndex(lastPos);
      payload.add(idx);
      if (kDebugMode) {
        print('[WatchedRecorder] (guard) adding current bucket $idx because payload was empty');
      }
    }

    try {
      if (kDebugMode) {
        print('[WatchedRecorder] flush → buckets=${payload.length} '
            'effDuration=$effDuration lastPos=$lastPos loginKey=${loginKey.isNotEmpty}');
      }

      final ack = await VideoProgressService.instance.menteeUpsertProgress(
        loginKey: loginKey,
        moduleCode: moduleCode,
        durationSec: effDuration,
        bucketSize: bucketSize,
        newBuckets: payload,
        lastPosSec: lastPos,
        force: false,
      );

      _lastFlushedPos = lastPos;
      onServerAck?.call(ack);
    } catch (e) {
      if (kDebugMode) {
        print('[WatchedRecorder] flush error: $e');
      }
      // re-queue payload to try again later
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
