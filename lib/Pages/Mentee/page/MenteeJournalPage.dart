import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class MenteeJournalPage extends StatefulWidget {
  final bool embedded;
  const MenteeJournalPage({super.key, this.embedded = false});

  @override
  State<MenteeJournalPage> createState() => _MenteeJournalPageState();
}

class _MenteeJournalPageState extends State<MenteeJournalPage> {
  final bool _hasMentor = true; // 데모용: 멘토 배정 여부
  final bool _isSubmittedToday = true; // 데모용: 오늘 일지 제출 여부 (스레드 노출용)
  bool _isLatestConfirmed = false; // 데모용: 최신 메시지 확인 상태

  @override
  Widget build(BuildContext context) {
    // ... (KST 기준 계산 로직은 실제 구현 시 적용)
    
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        // 멘토가 없거나, 오늘 제출 안 했으면 카드 노출 (멘토 없으면 배너가 대신 뜸)
        if (_hasMentor && !_isSubmittedToday) ...[
           const _TodayCardDemo(),
           const SizedBox(height: 12),
        ],

        const _SectionTitle('오늘 스레드(데모)'),
        const SizedBox(height: 8),
        if (!_hasMentor)
          const _EmptyBanner(message: '아직 멘토가 배정되지 않았어요.'),
        if (_hasMentor && !_isSubmittedToday)
          const _EmptyBanner(message: '아직 일지를 제출하지 않았어요!'),
        if (_hasMentor && _isSubmittedToday) ...[
          // 최신(멘토) → 오래된(멘티) 순으로 위→아래
          _JournalBubble(
            author: 'mentor', 
            selfRole: 'mentee', 
            text: '좋아요! 파일링 각도만 조금 더 세워보세요.', 
            photos: 1, 
            time: '오전 11:10', 
            showConfirm: true, // 최신 메시지이므로 확인 버튼 노출 대상
            confirmed: _isLatestConfirmed, // 로컬 상태 바인딩
            onConfirm: () {
              setState(() => _isLatestConfirmed = true);
            },
          ),
          const SizedBox(height: 8),
          const _JournalBubble(
            author: 'mentee', 
            selfRole: 'mentee', 
            text: '오늘은 큐티클 정리를 복습했고 사진도 첨부합니다.', 
            photos: 3, 
            time: '오전 10:32', 
            showConfirm: false, // 최신 아님
            confirmed: false, // 최신이 아니므로 확인 상태 표시 안 함
          ),
        ],
      ],
    );
    if (widget.embedded) return content;
    // ... Scaffold ...
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
  final VoidCallback? onConfirm;
  const _JournalBubble({required this.author, required this.selfRole, required this.text, required this.photos, required this.time, required this.showConfirm, required this.confirmed, this.onConfirm});

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
      child: IntrinsicWidth(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isMenteeMsg ? '멘티' : '멘토', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
              if (photos > 0) ...[
                const SizedBox(height: 8),
                photos == 1
                    ? Container(
                        width: 200,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.photo, size: 40, color: UiTokens.actionIcon),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(
                            photos,
                            (i) => Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0))),
                                  child: const Icon(Icons.photo, color: UiTokens.actionIcon),
                                )),
                      ),
              ],
              const SizedBox(height: 6),
              Text(text, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!mine && showConfirm && !confirmed) // confirmed가 true면 버튼 숨기고 체크 표시로 전환 (원한다면)
                        InkWell(
                          onTap: onConfirm ?? () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데모: 확인 처리')));
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: UiTokens.primaryBlue.withOpacity(0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_rounded, size: 14, color: UiTokens.primaryBlue),
                                SizedBox(width: 4),
                                Text(
                                  '확인하기',
                                  style: TextStyle(color: UiTokens.primaryBlue, fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // 내가 받은 메시지인데 이미 확인한 경우
                      if (!mine && confirmed) ...[
                        const Icon(Icons.check_circle, size: 14, color: UiTokens.primaryBlue),
                        const SizedBox(width: 4),
                        const Text('확인함', style: TextStyle(color: UiTokens.primaryBlue, fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                      // 내가 보낸 메시지를 상대가 확인한 경우
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
      ),
    );
  }
}


