import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:nail/Services/StorageService.dart';

/// Supabase Storage의 objectPath(버킷 상대 경로)를 받아
/// 서명 URL을 생성해 Chewie로 재생하는 페이지.
/// - 풀스크린 내장
/// - 재생/일시정지/탐색/배속 등 기본 컨트롤
class VideoPlayerPage extends StatefulWidget {
  final String storageObjectPath; // e.g. modules/ABC/v1/week-1/video/xxx.mp4
  final String? title;
  final int signedUrlTtlSec;
  final int minTtlBufferSec;

  const VideoPlayerPage({
    super.key,
    required this.storageObjectPath,
    this.title,
    this.signedUrlTtlSec = 21600, // 6h
    this.minTtlBufferSec = 300,   // 5m
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  final StorageService _storage = StorageService();

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  bool _loading = true;
  bool _error = false;

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
      // 1) Supabase 서명 URL(캐시 사용)
      final url = await _storage.getOrCreateSignedUrl(
        widget.storageObjectPath,
        expiresInSec: widget.signedUrlTtlSec,
        minTtlBufferSec: widget.minTtlBufferSec,
      );

      // 2) VideoPlayerController 초기화
      final vc = VideoPlayerController.networkUrl(Uri.parse(url));
      await vc.initialize(); // Chewie autoInitialize를 쓸 수도 있지만, 명시 초기화가 안전
      await vc.setLooping(false);

      // 3) ChewieController 구성
      final cc = ChewieController(
        videoPlayerController: vc,
        autoInitialize: false,     // 우리가 위에서 initialize() 완료
        autoPlay: true,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControlsOnInitialize: true,
        // 풀스크린 입/출 시 시스템 오버레이 & 방향 제어
        deviceOrientationsOnEnterFullScreen: const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: const [
          DeviceOrientation.portraitUp,
        ],
        systemOverlaysOnEnterFullScreen: const [SystemUiOverlay.bottom],
        systemOverlaysAfterFullScreen: SystemUiOverlay.values,
        // 진행바 색상(선택): 앱 톤에 맞게 살짝 강화
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.black87,
          handleColor: Colors.black,
          backgroundColor: Colors.black26,
          bufferedColor: Colors.black38,
        ),
        // 오류 위젯
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

      setState(() {
        _videoController = vc;
        _chewieController = cc;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Chewie prepare error: $e');
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _reload() async {
    await disposeControllers();
    await _prepare();
  }

  Future<void> disposeControllers() async {
    try {
      await _chewieController?.pause();
    } catch (_) {}
    // await _chewieController?.dispose();
    await _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? '동영상';
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_chewieController != null)
            IconButton(
              tooltip: '전체화면',
              onPressed: () => _chewieController!.enterFullScreen(),
              icon: const Icon(Icons.fullscreen),
            ),
        ],
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
              FilledButton(onPressed: _reload, child: const Text('다시 시도')),
            ],
          ),
        )
            : Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio == 0
                    ? 16 / 9
                    : _videoController!.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              ),
            ),
      ),
    );
  }
}
