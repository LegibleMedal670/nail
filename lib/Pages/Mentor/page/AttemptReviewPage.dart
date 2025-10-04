import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/MentorProvider.dart';
import 'package:provider/provider.dart';

class AttemptReviewPage extends StatefulWidget {
  final String mentorLoginKey;
  final String attemptId;
  const AttemptReviewPage({super.key, required this.mentorLoginKey, required this.attemptId});

  @override
  State<AttemptReviewPage> createState() => _AttemptReviewPageState();
}

class _AttemptReviewPageState extends State<AttemptReviewPage> {
  String? _grade; // '상'|'중'|'하'
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('실습 리뷰', style: TextStyle(
            color: UiTokens.title, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // TODO: 제출 이미지 갤러리 / 지시문 요약 / 제출 정보
          const _SectionTitle('등급'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['상','중','하'].map((g) {
              final sel = _grade == g;
              return ChoiceChip(label: Text(g), selected: sel,
                  onSelected: (_) => setState(() => _grade = g));
            }).toList(),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('피드백'),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl, maxLines: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(), hintText: '상세 피드백을 작성하세요',
            ),
          ),
          const SizedBox(height: 16),
          // TODO: 이전 시도 목록(작은 카드 리스트) + 탭 시 확대보기
          const _SectionTitle('이전 시도'),
          const SizedBox(height: 8),
          _EmptyBox(text: '이전 시도 로드 예정'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_grade == null || _saving) ? null : () async {
              setState(() => _saving = true);
              try {
                await context.read<MentorProvider>().reviewAttempt(
                  attemptId: widget.attemptId,
                  gradeKor: _grade!,      // '상'|'중'|'하'
                  feedback: _ctrl.text,
                );
                if (mounted) Navigator.pop(context, true);
              } catch (e) {
                // 에러 스낵바 표시 등
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
            child: _saving ? const CircularProgressIndicator() : const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text; const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(
        color: UiTokens.title, fontSize: 16, fontWeight: FontWeight.w800));
  }
}

class _EmptyBox extends StatelessWidget {
  final String text; const _EmptyBox({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text(text,
          style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700))),
    );
  }
}
