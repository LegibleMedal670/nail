import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class NoticeListPage extends StatelessWidget {
  final String roomId;
  const NoticeListPage({Key? key, required this.roomId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: messages where is_notice=true (또는 별도 테이블) and deleted=false
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지 모아보기', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: UiTokens.title),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.campaign_outlined),
          title: Text('공지 제목 $i', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('공지 내용 미리보기…'),
          onTap: () {},
        ),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: 12,
      ),
    );
  }
}
