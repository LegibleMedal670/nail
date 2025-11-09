import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class MediaGridPage extends StatelessWidget {
  final String roomId;
  const MediaGridPage({Key? key, required this.roomId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: messages where type in (image, video) and deleted=false
    return Scaffold(
      appBar: AppBar(
        title: const Text('사진/동영상', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: UiTokens.title),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
        itemBuilder: (_, i) => Container(color: Colors.grey[300]),
        itemCount: 30,
      ),
    );
  }
}
