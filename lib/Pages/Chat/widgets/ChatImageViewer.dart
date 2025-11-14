// lib/Pages/Chat/widgets/ChatImageViewer.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class ChatImageViewer extends StatefulWidget {
  final List<String> images;      // 지금은 [단일]로 전달
  final int initialIndex;         // 보통 0
  final String heroTagPrefix;
  final List<String>? titles;     // 보낸 사람 닉네임 등

  const ChatImageViewer({
    Key? key,
    required this.images,
    required this.initialIndex,
    this.heroTagPrefix = 'chat_img_',
    this.titles,
  }) : super(key: key);

  @override
  State<ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends State<ChatImageViewer> {
  late final PageController _pc;
  late int _index;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pc = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _downloadCurrent() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final src = widget.images[_index];
    try {
      late Uint8List bytes;
      if (src.startsWith('http')) {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse(src));
        final res = await req.close();
        bytes = await consolidateHttpClientResponseBytes(res);
      } else {
        bytes = await File(src).readAsBytes();
      }
      // 갤러리에 저장
      await ImageGallerySaver.saveImage(bytes, quality: 90, name: 'chat_${DateTime.now().millisecondsSinceEpoch}');
      if (!mounted) return;

      // TODO: 갤러리 저장/공유 원하면 아래처럼 확장
      // - image_gallery_saver 로 갤러리에 저장
      // - share_plus 로 공유 시트 열기
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('다운로드 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    final tagPrefix = widget.heroTagPrefix;
    final title = (widget.titles != null && _index < (widget.titles!.length)) ? (widget.titles![_index] ?? '') : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: imgs.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final src = imgs[i];
              final tag = '$tagPrefix$i';
              return Center(child: _ZoomableHeroImage(tag: tag, source: src));
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  // 우상단 다운로드
                  IconButton(
                    tooltip: '다운로드',
                    onPressed: _downloading ? null : _downloadCurrent,
                    icon: _downloading
                        ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_rounded, color: Colors.white),
                  ),
                  if (imgs.length > 1) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_index + 1} / ${imgs.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 아래 _ZoomableHeroImage 는 이전 버전 그대로 사용
class _ZoomableHeroImage extends StatefulWidget {
  final String tag;
  final String source;
  const _ZoomableHeroImage({required this.tag, required this.source});
  @override
  State<_ZoomableHeroImage> createState() => _ZoomableHeroImageState();
}

class _ZoomableHeroImageState extends State<_ZoomableHeroImage> {
  late final TransformationController _tc;
  @override
  void initState() { super.initState(); _tc = TransformationController(); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }
  void _handleDoubleTap() {
    final m = _tc.value;
    final zoomed = m.getMaxScaleOnAxis() > 1.01;
    _tc.value = zoomed ? Matrix4.identity() : (Matrix4.identity()..scale(2.5));
  }
  @override
  Widget build(BuildContext context) {
    final isNet = widget.source.startsWith('http');
    final img = isNet
        ? Image.network(widget.source, fit: BoxFit.contain)
        : Image.file(File(widget.source), fit: BoxFit.contain);
    return Hero(
      tag: widget.tag,
      child: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _tc,
          minScale: 1.0, maxScale: 6.0, panEnabled: true, scaleEnabled: true,
          child: img,
        ),
      ),
    );
  }
}
