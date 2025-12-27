import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:nail/Services/StorageService.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Pages/Chat/widgets/ChatImageViewer.dart';

class MediaGridPage extends StatefulWidget {
  final String roomId;
  const MediaGridPage({Key? key, required this.roomId}) : super(key: key);

  @override
  State<MediaGridPage> createState() => _MediaGridPageState();
}

class _MediaGridPageState extends State<MediaGridPage> {
  final _svc = ChatService.instance;
  final _storage = StorageService();
  bool _loading = false;
  String? _error;
  List<_MediaItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final up = context.read<UserProvider>();
    final key = up.isAdmin ? (up.adminKey ?? '') : (up.current?.loginKey ?? '');
    if (key.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _svc.listMedia(
        loginKey: key,
        roomId: widget.roomId,
        kinds: const ['image'],
        limit: 120,
      );
      final List<_MediaItem> items = [];
      for (final r in rows) {
        // 묶어서 보낸 사진의 경우 urls 배열이 있으면 모든 경로를 처리
        final urls = r['urls'];
        final senderNick = (r['sender_nick'] ?? '').toString();
        
        if (urls is List && urls.isNotEmpty) {
          // urls 배열이 있으면 모든 경로를 처리
          for (final urlPath in urls) {
            final sp = urlPath?.toString() ?? '';
            if (sp.isEmpty) continue;
            final url = await _storage.getOrCreateSignedUrlChat(sp);
            items.add(_MediaItem(
              storagePath: sp,
              signedUrl: url,
              senderNick: senderNick,
            ));
          }
        } else {
          // urls 배열이 없으면 기존 방식대로 storage_path 사용
          final sp = (r['storage_path'] ?? '').toString();
          if (sp.isEmpty) continue;
          final url = await _storage.getOrCreateSignedUrlChat(sp);
          items.add(_MediaItem(
            storagePath: sp,
            signedUrl: url,
            senderNick: senderNick,
          ));
        }
      }
      setState(() => _items = items);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사진/동영상', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: UiTokens.title),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          Center(child: Text('오류: $_error', style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 8),
          Center(child: TextButton(onPressed: _load, child: const Text('다시 시도'))),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 40),
          Center(child: Text('사진/동영상이 없습니다.', style: TextStyle(color: Colors.black54))),
        ],
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final it = _items[i];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                barrierColor: Colors.black,
                opaque: false,
                pageBuilder: (_, __, ___) => ChatImageViewer(
                  images: _items.map((e) => e.signedUrl).toList(),
                  initialIndex: i,
                  titles: _items.map((e) => e.senderNick).toList(),
                ),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(imageUrl: it.signedUrl, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

class _MediaItem {
  final String storagePath;
  final String signedUrl;
  final String senderNick;
  _MediaItem({required this.storagePath, required this.signedUrl, required this.senderNick});
}
