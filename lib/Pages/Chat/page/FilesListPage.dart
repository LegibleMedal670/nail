import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:nail/Services/StorageService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:dio/dio.dart' as dio;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FilesListPage extends StatefulWidget {
  final String roomId;
  const FilesListPage({Key? key, required this.roomId}) : super(key: key);

  @override
  State<FilesListPage> createState() => _FilesListPageState();
}

class _FilesListPageState extends State<FilesListPage> {
  final _svc = ChatService.instance;
  final _storage = StorageService();
  bool _loading = false;
  String? _error;
  List<_FileItem> _items = const [];
  final Set<int> _downloading = <int>{};
  SharedPreferences? _prefs;
  Map<int, String> _cache = {};

  String get _cacheKey => 'chat_file_cache_${widget.roomId}';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final s = _prefs!.getString(_cacheKey);
    if (s != null && s.isNotEmpty) {
      try {
        final m = json.decode(s) as Map<String, dynamic>;
        _cache = m.map((k, v) => MapEntry(int.parse(k), v.toString()));
      } catch (_) {}
    }
    await _load();
  }

  Future<void> _persistCache() async {
    if (_prefs == null) return;
    await _prefs!.setString(_cacheKey, json.encode(_cache.map((k, v) => MapEntry(k.toString(), v))));
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
        kinds: const ['file'],
        limit: 200,
      );
      final List<_FileItem> items = [];
      for (final r in rows) {
        final msgId = (r['message_id'] as num).toInt();
        final sp = (r['storage_path'] ?? '').toString();
        if (sp.isEmpty) continue;
        final url = await _storage.getOrCreateSignedUrlChat(sp);
        final name = (r['file_name'] ?? p.basename(sp)).toString();
        final sender = (r['sender_nick'] ?? '').toString();
        final local = _cache[msgId];
        items.add(_FileItem(messageId: msgId, fileName: name, storagePath: sp, signedUrl: url, localPath: local, senderNick: sender));
      }
      setState(() => _items = items);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openOrDownload(_FileItem it) async {
    if (it.localPath != null && it.localPath!.isNotEmpty && File(it.localPath!).existsSync()) {
      await OpenFilex.open(it.localPath!);
      return;
    }
    if (_downloading.contains(it.messageId)) return;
    setState(() => _downloading.add(it.messageId));
    try {
      final dir = await getApplicationDocumentsDirectory();
      final chatDir = p.join(dir.path, 'chat', widget.roomId);
      await Directory(chatDir).create(recursive: true);
      final savePath = p.join(chatDir, it.fileName);
      final client = dio.Dio();
      await client.download(it.signedUrl, savePath);
      setState(() {
        _items = _items.map((e) => e.messageId == it.messageId ? e.copyWith(localPath: savePath) : e).toList();
        _cache[it.messageId] = savePath;
      });
      await _persistCache();
      await OpenFilex.open(savePath);
    } catch (_) {
      // 무시(필요 시 토스트)
    } finally {
      if (mounted) setState(() => _downloading.remove(it.messageId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('파일', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
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
          Center(child: Text('파일이 없습니다.', style: TextStyle(color: Colors.black54))),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final it = _items[i];
        final isDownloading = _downloading.contains(it.messageId);
        final downloaded = (it.localPath != null && it.localPath!.isNotEmpty);
        return ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(it.fileName, style: const TextStyle(fontWeight: FontWeight.w700, color: UiTokens.title)),
          subtitle: Row(
            children: [
              if (it.senderNick.isNotEmpty)
                Text('${it.senderNick} ·', style: const TextStyle(color: Colors.black54)),
              if (it.senderNick.isNotEmpty) const SizedBox(width: 6),
              Text(it.signedUrl.split('?').first.split('.').last.toUpperCase(), style: const TextStyle(color: Colors.grey)),
            ],
          ),
          trailing: isDownloading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(downloaded ? Icons.open_in_new_rounded : Icons.download_rounded, color: Colors.black54),
          onTap: () => _openOrDownload(it),
        );
      },
    );
  }
}

class _FileItem {
  final int messageId;
  final String fileName;
  final String storagePath;
  final String signedUrl;
  final String? localPath;
  final String senderNick;
  _FileItem({
    required this.messageId,
    required this.fileName,
    required this.storagePath,
    required this.signedUrl,
    this.localPath,
    this.senderNick = '',
  });
  _FileItem copyWith({String? localPath}) => _FileItem(
    messageId: messageId,
    fileName: fileName,
    storagePath: storagePath,
    signedUrl: signedUrl,
    localPath: localPath ?? this.localPath,
    senderNick: senderNick,
  );
}
