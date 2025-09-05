import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: UiTokens.title, fontSize: 14, fontWeight: FontWeight.w800));
  }
}