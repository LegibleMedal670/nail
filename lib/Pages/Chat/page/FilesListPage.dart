import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class FilesListPage extends StatelessWidget {
  final String roomId;
  const FilesListPage({Key? key, required this.roomId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: messages where type=file and deleted=false
    return Scaffold(
      appBar: AppBar(
        title: const Text('파일', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: UiTokens.title),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text('파일_$i.pdf', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('2.3MB · 2025-11-09'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {},
        ),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: 40,
      ),
    );
  }
}
