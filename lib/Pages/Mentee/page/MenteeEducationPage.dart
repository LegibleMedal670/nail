import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Mentee/page/MenteeMainPage.dart';
import 'package:nail/Pages/Mentee/page/MenteePracticePage.dart';

/// 멘티용 교육 탭: 상단 세그먼트(이론/실습)로 전환
class MenteeEducationPage extends StatefulWidget {
  final bool embedded;
  /// 상위(AppBar 토글 등)와 동기화할 외부 상태. true=이론, false=실습
  final ValueNotifier<bool>? isTheoryNotifier;
  const MenteeEducationPage({super.key, this.embedded = false, this.isTheoryNotifier});

  @override
  State<MenteeEducationPage> createState() => _MenteeEducationPageState();
}

class _MenteeEducationPageState extends State<MenteeEducationPage> {
  late bool _isTheory = widget.isTheoryNotifier?.value ?? true;

  void _onExternalChanged() {
    final v = widget.isTheoryNotifier!.value;
    if (v == _isTheory) return;
    setState(() => _isTheory = v);
  }

  @override
  void initState() {
    super.initState();
    widget.isTheoryNotifier?.addListener(_onExternalChanged);
  }

  @override
  void dispose() {
    widget.isTheoryNotifier?.removeListener(_onExternalChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        const SizedBox(height: 4),
        Expanded(
          child: IndexedStack(
            index: _isTheory ? 0 : 1,
            children: const [
              MenteeMainPage(embedded: true),
              MenteePracticePage(embedded: true),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return content;
    return Scaffold(backgroundColor: Colors.white, body: content);
  }
}


