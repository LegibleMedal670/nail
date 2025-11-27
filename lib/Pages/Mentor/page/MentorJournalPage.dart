import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class MentorJournalPage extends StatelessWidget {
  final bool embedded;
  const MentorJournalPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Row(
          children: [
            _FilterChip(selected: true, label: '미응답 우선'),
            const SizedBox(width: 8),
            _FilterChip(selected: false, label: '전체'),
            const Spacer(),
            IconButton(
              tooltip: '검색(데모)',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데모: 검색/필터는 후속 단계에서 구현됩니다.')));
              },
              icon: const Icon(Icons.search_rounded, color: UiTokens.actionIcon),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _JournalListTileDemo(
          menteeName: '김멘티',
          submittedAt: '오늘 10:18',
          photos: 3,
          status: _JournalStatus.pending,
          onTap: () => _openDetail(context, '김멘티'),
        ),
        const SizedBox(height: 8),
        _JournalListTileDemo(
          menteeName: '박멘티',
          submittedAt: '어제 17:42',
          photos: 1,
          status: _JournalStatus.replied,
          onTap: () => _openDetail(context, '박멘티'),
        ),
      ],
    );
    if (embedded) return content;
    return Scaffold(backgroundColor: Colors.white, body: content);
  }

  void _openDetail(BuildContext context, String name) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _MentorJournalDetailDemo(menteeName: name)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final bool selected;
  final String label;
  const _FilterChip({required this.selected, required this.label});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? UiTokens.primaryBlue.withOpacity(0.12) : c.surface,
          border: Border.all(color: selected ? UiTokens.primaryBlue : const Color(0xFFE6EBF0)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: TextStyle(color: selected ? UiTokens.primaryBlue : c.onSurfaceVariant, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

enum _JournalStatus { pending, replied }

class _JournalListTileDemo extends StatelessWidget {
  final String menteeName;
  final String submittedAt;
  final int photos;
  final _JournalStatus status;
  final VoidCallback onTap;
  const _JournalListTileDemo({required this.menteeName, required this.submittedAt, required this.photos, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool pending = status == _JournalStatus.pending;
    final Color chipColor = pending ? const Color(0xFFEA580C) : const Color(0xFF059669);
    final String chipText = pending ? '미응답' : '응답완료';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: UiTokens.cardBorder),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [UiTokens.cardShadow],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(radius: 22, backgroundColor: Color(0xFFE2E8F0), child: Icon(Icons.person, color: UiTokens.actionIcon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(menteeName, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('제출: $submittedAt • 사진 $photos장', style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: chipColor.withOpacity(0.1), border: Border.all(color: chipColor), borderRadius: BorderRadius.circular(999)),
              child: Text(chipText, style: TextStyle(color: chipColor, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: UiTokens.actionIcon),
          ],
        ),
      ),
    );
  }
}

class _MentorJournalDetailDemo extends StatelessWidget {
  final String menteeName;
  const _MentorJournalDetailDemo({required this.menteeName});
  @override
  Widget build(BuildContext context) {
    String _fmtMd(DateTime d) => '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    final today = DateTime.now();
    const bool canEdit = true; // 데모용
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('$menteeName · ${_fmtMd(today)} 일지', style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UiTokens.title),
          onPressed: () => Navigator.maybePop(context),
        ),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: const [
          // 최신(멘토) → 오래된(멘티)
          _JournalBubble(author: 'mentor', selfRole: 'mentor', text: '수고했어요! 2번째 사진 각도만 조금 수정해 보세요.', photos: 1, time: '오전 11:00', showConfirm: false, confirmed: true),
          SizedBox(height: 8),
          _JournalBubble(author: 'mentee', selfRole: 'mentor', text: '오늘 제출합니다. 사진은 3장 첨부했어요.', photos: 3, time: '오전 10:12', showConfirm: false, confirmed: false),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const Text('데모: 피드백 입력 영역(후속 구현)', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데모: 피드백 전송은 후속 단계에서 구현됩니다.')));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: canEdit ? UiTokens.primaryBlue : const Color(0xFFE2E8F0),
                  foregroundColor: canEdit ? Colors.white : UiTokens.title,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(80, 44),
                ),
                child: const Text('전송', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalBubble extends StatelessWidget {
  final String author; // 'mentee'|'mentor'
  final String selfRole; // 현재 화면의 사용자 역할
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
                      if (!mine && showConfirm)
                        InkWell(
                          onTap: () {
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



