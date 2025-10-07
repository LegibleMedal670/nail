// lib/Pages/Mentee/page/PracticeDetailPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/SupabaseService.dart';

class PracticeDetailPage extends StatefulWidget {
  final String setId;
  const PracticeDetailPage({super.key, required this.setId});

  @override
  State<PracticeDetailPage> createState() => _PracticeDetailPageState();
}

class _PracticeDetailPageState extends State<PracticeDetailPage> {
  final _api = SupabaseService.instance;

  Map<String, dynamic>? detail;
  bool loading = false;
  String? error;

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      detail = await _api.menteePracticeSetDetail(setId: widget.setId, limit: 30);
      loading = false;
      setState(() {});
    } catch (e) {
      loading = false; error = '$e';
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _startOrContinue() async {
    final r = await _api.menteeStartOrContinue(setId: widget.setId);
    if (r != null) await _load();
  }

  Future<void> _submitDemo() async {
    // 스토리지 붙이기 전: 더미 경로 배열로 제출
    final attemptId = detail?['current_attempt_id'];
    if (attemptId == null) return;
    await _api.menteeSubmitAttempt(
      attemptId: attemptId,
      imagePaths: const ['practice/demo1.jpg', 'practice/demo2.jpg'],
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('실습'), backgroundColor: Colors.white, elevation: 0),
        body: Center(child: Text('오류: $error')),
      );
    }
    final d = detail;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(d?['title'] ?? '실습'), backgroundColor: Colors.white, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          if (d != null) ...[
            Text(d['instructions'] ?? '요구사항 없음',
                style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            // 레퍼런스 이미지(간단 텍스트로)
            if (d['reference_images'] != null) Text('예시: ${(d['reference_images'] as List).length}개'),
            const SizedBox(height: 12),

            // 현재 상태
            _statusBlock(d),

            const SizedBox(height: 12),

            // 액션들
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _startOrContinue,
                    style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
                    child: const Text('시작/이어하기', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitDemo,
                    child: const Text('제출(데모)', style: TextStyle(fontWeight: FontWeight.w800, color: UiTokens.title)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Text('히스토리', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (d['history'] is List && (d['history'] as List).isNotEmpty)
              ...((d['history'] as List).map((h) => _historyTile(h as Map<String, dynamic>)))
            else
              Text('기록 없음', style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }

  Widget _statusBlock(Map<String, dynamic> d) {
    final status = SupabaseService.instance.practiceStatusLabel(d['current_status'] as String?);
    final grade = (d['current_grade'] as String?) ?? '';
    final feedback = (d['current_feedback'] as String?) ?? '';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(14), boxShadow: [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.assignment_outlined, color: UiTokens.actionIcon),
          const SizedBox(width: 8),
          Text('현재 상태: $status', style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
        ]),
        if (status == '검토 완료') ...[
          const SizedBox(height: 8),
          Text('등급: ${_korGrade(grade)}', style: const TextStyle(fontWeight: FontWeight.w800)),
          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('피드백: $feedback', style: TextStyle(color: UiTokens.title.withOpacity(0.8), fontWeight: FontWeight.w700)),
          ],
        ],
      ]),
    );
  }

  String _korGrade(String en) {
    switch (en) {
      case 'high': return '상';
      case 'mid': return '중';
      case 'low': return '하';
      default: return '-';
    }
  }

  Widget _historyTile(Map<String, dynamic> h) {
    final label = SupabaseService.instance.practiceStatusLabel(h['status'] as String?);
    final grade = _korGrade((h['grade'] as String?) ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white, border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('회차 ${h['attempt_no']}', style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('$label · 등급 $grade',
                  style: TextStyle(color: UiTokens.title.withOpacity(0.7), fontWeight: FontWeight.w700)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: UiTokens.actionIcon),
        ],
      ),
    );
  }
}
