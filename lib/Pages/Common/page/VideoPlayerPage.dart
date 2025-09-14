// lib/Pages/Common/page/VideoPlayerPage.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:provider/provider.dart';

import 'package:nail/Services/StorageService.dart';
import 'package:nail/Services/WatchedRecorderService.dart';
import 'package:nail/Services/VideoProgressService.dart';
import 'package:nail/Services/ModuleKey.dart';
import 'package:nail/Providers/UserProvider.dart';

class VideoPlayerPage extends StatefulWidget {
  final String storageObjectPath; // e.g. modules/ABC/v1/week-1/video/xxx.mp4
  final String moduleCode;        // 진행도 저장 키(정규화하여 서버와 일치시킴)
  final String? title;
  final int signedUrlTtlSec;
  final int minTtlBufferSec;

  final int bucketSize;       // 기본 5초
  final int flushIntervalSec; // 기본 8초

  const VideoPlayerPage({
    super.key,
    required this.storageObjectPath,
    required this.moduleCode,
    this.title,
    this.signedUrlTtlSec = 21600,
    this.minTtlBufferSec = 300,
    this.bucketSize = 5,
    this.flushIntervalSec = 8,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  final StorageService _storage = StorageService();

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  WatchedRecorderService? _recorder;
  VideoProgressResult? _lastProgress;

  bool _loading = true;
  bool _error = false;
  bool _enteredFsOnce = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      // 1) 서명 URL 준비
      final url = await _storage.getOrCreateSignedUrl(
        widget.storageObjectPath,
        expiresInSec: widget.signedUrlTtlSec,
        minTtlBufferSec: widget.minTtlBufferSec,
      );

      // 2) 비디오 컨트롤러 초기화
      final vc = VideoPlayerController.networkUrl(Uri.parse(url));
      await vc.initialize();
      await vc.setLooping(false);

      // 3) 로그인 키 & 서버 진행도 조회 → 이어보기 시점 계산
      final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
      final normCode = ModuleKey.norm(widget.moduleCode);

      int resumeSec = 0;
      VideoProgressResult? initialPr;

      if (loginKey.isNotEmpty) {
        try {
          initialPr = await VideoProgressService.instance.menteeGetProgress(
            loginKey: loginKey,
            moduleCode: normCode, // 정규화된 모듈 코드 사용
          );

          final d = vc.value.duration.inSeconds;

          if (kDebugMode) {
            print('[Prepare] video duration = $d sec');
            print('[Prepare] server initial: last=${initialPr.lastPosSec} '
                'next=${initialPr.nextUnwatchedStartSec} bucket=${initialPr.bucketSize}');
          }

          // 이어보기 정책: 미시청 구간이 있으면 그 시작, 없으면 last_pos
          final candidate =
          (initialPr.nextUnwatchedStartSec ?? initialPr.lastPosSec);
          resumeSec = candidate.clamp(0, (d > 0 ? d - 1 : 0));
        } catch (e) {
          debugPrint('prefetch progress error: $e');
        }
      }

      // 4) 먼저 해당 위치로 이동
      if (resumeSec > 0) {
        await vc.seekTo(Duration(seconds: resumeSec));
      }

      // 5) Chewie 컨트롤러 (초기엔 autoPlay=false → seek 완료 후 play)
      final cc = ChewieController(
        videoPlayerController: vc,
        autoInitialize: false,
        autoPlay: false, // 중요: seek 이후 수동 재생
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControlsOnInitialize: true,
        deviceOrientationsOnEnterFullScreen: const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
        systemOverlaysOnEnterFullScreen: const [SystemUiOverlay.bottom],
        systemOverlaysAfterFullScreen: SystemUiOverlay.values,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.black87,
          handleColor: Colors.black,
          backgroundColor: Colors.black26,
          bufferedColor: Colors.black38,
        ),
        errorBuilder: (context, message) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(height: 8),
              Text('재생 오류: $message'),
              const SizedBox(height: 8),
              FilledButton(onPressed: _reload, child: const Text('다시 시도')),
            ],
          ),
        ),
      );

      // 6) 진행도 레코더 시작(초기 seek 이후 시작)
      final totalSec = vc.value.duration.inSeconds;
      final durationSec = totalSec > 0 ? totalSec : 0;

      final rec = WatchedRecorderService(
        controller: vc,
        moduleCode: normCode, // 정규화된 모듈 코드 사용
        durationSec: durationSec,
        loginKey: loginKey,
        bucketSize: widget.bucketSize,
        tickInterval: const Duration(seconds: 1),
        flushInterval: Duration(seconds: widget.flushIntervalSec),
        seekJumpThresholdSec: 8,
        seekResumeGuardSec: 2,
        onServerAck: (r) {
          if (!mounted) return;
          setState(() => _lastProgress = r);
          if (kDebugMode) {
            final pct = (r.watchedRatio * 100).toStringAsFixed(2);
            print('[VideoPlayerPage] progress ack: $pct% '
                'watched=${r.watchedSec}s '
                'bucket=${r.bucketSize} '
                'totalBuckets=${r.totalBuckets} '
                'last=${r.lastPosSec} next=${r.nextUnwatchedStartSec}');
          }
        },
      );
      rec.start();

      // 7) 상태 반영 + (있다면) 초기 진행도 오버레이에 즉시 반영
      setState(() {
        _videoController = vc;
        _chewieController = cc;
        _recorder = rec;
        _lastProgress = initialPr ?? _lastProgress;
        _loading = false;
      });

      // 8) 최종 재생 시작
      await vc.play();

      // 9) 최초 1회 자동 풀스크린 진입 (옵션)
      if (!_enteredFsOnce) {
        _enteredFsOnce = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          if (!mounted) return;
          try {
            _chewieController?.enterFullScreen();
          } catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('Chewie prepare error: $e');
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _reload() async {
    await _disposeAll();
    await _prepare();
  }

  Future<void> _disposeAll() async {
    try {
      await _recorder?.dispose(); // 내부에서 마지막 flush 시도
    } catch (_) {}
    try {
      _chewieController?.pause();
    } catch (_) {}
    _chewieController?.dispose();
    if (_videoController != null) {
      await _videoController!.dispose();
    }
    _recorder = null;
    _chewieController = null;
    _videoController = null;
  }

  @override
  void dispose() {
    try {
      if ((_chewieController?.isFullScreen ?? false) == true) {
        _chewieController?.exitFullScreen();
      }
    } catch (_) {}
    _disposeAll();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if ((_chewieController?.isFullScreen ?? false) == true) {
      try {
        _chewieController?.exitFullScreen();
      } catch (_) {}
      return false;
    }

    // ★★★ 완료 직전 강제 업서트: 끝 보고 바로 나가도 즉시 100%
    try {
      final vc = _videoController;
      if (vc != null && vc.value.isInitialized) {
        final total = vc.value.duration.inSeconds;
        final pos = vc.value.position.inSeconds;
        final durationSec = total > 0 ? total : 0;

        if (durationSec > 0) {
          final tailPos = (pos >= durationSec) ? durationSec - 1 : pos;
          final bucketSize = widget.bucketSize;
          final lastBucket =
          (tailPos / (bucketSize > 0 ? bucketSize : 5)).floor();

          // 0..lastBucket을 모두 커버하여 즉시 100% 달성
          final fullCover = lastBucket >= 0
              ? Set<int>.from(List<int>.generate(lastBucket + 1, (i) => i))
              : <int>{};

          final loginKey =
              context.read<UserProvider>().current?.loginKey ?? '';
          if (loginKey.isNotEmpty) {
            await VideoProgressService.instance.menteeUpsertProgress(
              loginKey: loginKey,
              moduleCode: ModuleKey.norm(widget.moduleCode),
              durationSec: durationSec,
              bucketSize: bucketSize,
              newBuckets: fullCover,
              lastPosSec: tailPos,
              force: true, // 증가량 클램프 해제
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[VideoPlayerPage] force upsert error: $e');
      }
    }

    try {
      await _recorder?.dispose();
    } catch (_) {}

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? '동영상';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final allow = await _onWillPop();
        if (allow && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          titleSpacing: 0,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            tooltip: '닫기',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final allow = await _onWillPop();
              if (allow && mounted) Navigator.pop(context);
            },
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(height: 8),
                const Text('영상을 불러오지 못했습니다.'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _reload,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          )
              : Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  child: AspectRatio(
                    aspectRatio:
                    _videoController!.value.aspectRatio == 0
                        ? 16 / 9
                        : _videoController!.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  ),
                ),
              ),
              if (kDebugMode && _lastProgress != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _lastProgress?.isCompleted == true
                          ? 'Watched ${((_lastProgress!.watchedRatio * 100).clamp(0, 100)).toStringAsFixed(1)}%  ✓ 완료'
                          : 'Watched ${((_lastProgress!.watchedRatio * 100).clamp(0, 100)).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
