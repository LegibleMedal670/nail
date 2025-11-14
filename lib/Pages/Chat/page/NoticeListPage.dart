import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Providers/UserProvider.dart';

class NoticeListPage extends StatefulWidget {
  final String roomId;
  const NoticeListPage({Key? key, required this.roomId}) : super(key: key);

  @override
  State<NoticeListPage> createState() => _NoticeListPageState();
}

class _NoticeListPageState extends State<NoticeListPage> {
  final _svc = ChatService.instance;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

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
      final rows = await _svc.listNotices(loginKey: key, roomId: widget.roomId, limit: 200);
      setState(() => _rows = rows);
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
        title: const Text('공지 모아보기', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
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
    if (_loading && _rows.isEmpty) {
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
    if (_rows.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 40),
          Center(child: Text('등록된 공지가 없습니다.', style: TextStyle(color: Colors.black54))),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = _rows[i];
        final body = (r['body'] ?? '').toString();
        final author = (r['author_nick'] ?? '').toString();
        final createdRaw = r['created_at'];
        final created = createdRaw is DateTime
            ? createdRaw.toLocal()
            : DateTime.tryParse((createdRaw ?? '').toString())?.toLocal();
        final ts = created == null ? '' : _fmtKST(created);
        return ListTile(
          leading: const Icon(Icons.campaign_outlined, color: UiTokens.title),
          title: Text(
            body.isEmpty ? '(내용 없음)' : body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, color: UiTokens.title),
          ),
          subtitle: Text(
            [author, ts].where((e) => e.isNotEmpty).join(' · '),
            style: const TextStyle(color: Colors.grey),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _NoticeDetailPage(
                  body: body,
                  authorNick: author,
                  createdAt: created ?? DateTime.now(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _fmtKST(DateTime t) {
    final lt = t.toLocal();
    final y = lt.year.toString().padLeft(4, '0');
    final M = lt.month.toString().padLeft(2, '0');
    final d = lt.day.toString().padLeft(2, '0');
    final h = lt.hour.toString().padLeft(2, '0');
    final m = lt.minute.toString().padLeft(2, '0');
    return '$y-$M-$d $h:$m';
  }
}

class _NoticeDetailPage extends StatelessWidget {
  final String body;
  final String authorNick;
  final DateTime createdAt;
  const _NoticeDetailPage({
    Key? key,
    required this.body,
    required this.authorNick,
    required this.createdAt,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateStr = '${createdAt.toLocal().year}-${createdAt.toLocal().month.toString().padLeft(2, '0')}-${createdAt.toLocal().day.toString().padLeft(2, '0')} '
        '${createdAt.toLocal().hour.toString().padLeft(2, '0')}:${createdAt.toLocal().minute.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지 상세', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: UiTokens.title),
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            [authorNick, dateStr].where((e) => e.isNotEmpty).join(' · '),
            style: const TextStyle(color: UiTokens.title),
          ),
          const SizedBox(height: 16),
          Text(
            body.isEmpty ? '(내용 없음)' : body,
            style: const TextStyle(fontSize: 16, color: UiTokens.title, height: 1.4),
          ),
        ],
      ),
    );
  }
}
