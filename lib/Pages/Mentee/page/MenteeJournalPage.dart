import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class MenteeJournalPage extends StatelessWidget {
  final bool embedded;
  const MenteeJournalPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    // 데모 플래그: 오늘 스레드 유무, 멘토 배정 유무
    const bool hasToday = true;
    const bool hasMentor = true;

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        const _TodayCardDemo(),
        const SizedBox(height: 12),
        const _SectionTitle('오늘 스레드(데모)'),
        const SizedBox(height: 8),
        if (!hasMentor)
          _EmptyBanner(message: '아직 멘토가 배정되지 않았어요.'),
        if (hasMentor && !hasToday)
          _EmptyBanner(message: '아직 일지를 제출하지 않았어요!'),
        if (hasMentor && hasToday) ...const [
          // 최신(멘토) → 오래된(멘티) 순으로 위→아래
          _JournalBubble(author: 'mentor', selfRole: 'mentee', text: '좋아요! 파일링 각도만 조금 더 세워보세요.', photos: 1, time: '오전 11:10', showConfirm: true, confirmed: false),
          SizedBox(height: 8),
          _JournalBubble(author: 'mentee', selfRole: 'mentee', text: '오늘은 큐티클 정리를 복습했고 사진도 첨부합니다.', photos: 3, time: '오전 10:32', showConfirm: false, confirmed: true),
        ],
      ],
    );
    if (embedded) return content;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('일일 일지', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: '히스토리(달력) - 데모',
            icon: const Icon(Icons.calendar_month_rounded, color: UiTokens.title),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데모: 히스토리는 후속 단계에서 구현됩니다.')));
            },
          ),
        ],
      ),
      body: content,
    );
  }
}

class _TodayCardDemo extends StatelessWidget {
  const _TodayCardDemo();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UiTokens.cardBorder),
        boxShadow: [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          const Icon(Icons.today_rounded, color: UiTokens.actionIcon),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('오늘의 일지 제출', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('한국시간 24시까지 제출 가능', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데모: 제출 화면은 후속 단계에서 구현됩니다.')));
            },
            style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('제출하기', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(text, style: const TextStyle(color: UiTokens.title, fontSize: 16, fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptyBanner extends StatelessWidget {
  final String message;
  const _EmptyBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        border: Border.all(color: const Color(0xFFE6EBF0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, color: UiTokens.actionIcon),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _JournalBubble extends StatelessWidget {
  final String author; // 'mentee'|'mentor'
  final String selfRole; // 현재 화면의 사용자 역할: 'mentee'|'mentor'
  final String text;
  final int photos; // demo count
  final String time;
  final bool showConfirm; // 상대방 버블에만 '확인' 버튼 노출
  final bool confirmed;   // 내 버블에 상대방이 확인했을 때 체크 표시
  const _JournalBubble({required this.author, required this.selfRole, required this.text, required this.photos, required this.time, required this.showConfirm, required this.confirmed});

  @override
  Widget build(BuildContext context) {
    final bool isMenteeMsg = author == 'mentee';
    final bool mine = author == selfRole;
    final Color bg = isMenteeMsg ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);
    final Color border = isMenteeMsg ? const Color(0xFFDBEAFE) : const Color(0xFFB7F3DB);
    final Color fg = isMenteeMsg ? const Color(0xFF2563EB) : const Color(0xFF059669);

    const bool canEdit = true; // 데모용

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isMenteeMsg ? '멘티' : '멘토', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
            if (photos > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: List.generate(photos, (i) => Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: const Icon(Icons.photo, color: UiTokens.actionIcon),
                )),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!mine && showConfirm)
                      FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데모: 확인 처리는 후속 단계에서 구현됩니다.')));
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: canEdit ? UiTokens.primaryBlue : const Color(0xFFE2E8F0),
                          foregroundColor: canEdit ? Colors.white : UiTokens.title,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    if (mine && confirmed) ...[
                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      const Text('확인됨', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


