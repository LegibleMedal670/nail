import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Pages/Chat/widgets/ChatImageViewer.dart';

import 'package:nail/Pages/Mentee/page/MenteeJournalSubmitPage.dart';

class MenteeJournalPage extends StatefulWidget {
  final bool embedded;
  const MenteeJournalPage({super.key, this.embedded = false});

  @override
  State<MenteeJournalPage> createState() => _MenteeJournalPageState();
}

class _MenteeJournalPageState extends State<MenteeJournalPage> {
  bool _loading = true;
  Map<String, dynamic>? _journalData; // null이면 오늘 제출 안 함
  List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // 1. 오늘의 일지 조회
      final data = await SupabaseService.instance.menteeGetTodayJournal();
      _journalData = data;
      
      if (data != null) {
        final rawMsgs = (data['messages'] as List?) ?? [];
        _messages = List.from(rawMsgs.reversed); // 최신이 0번 인덱스로 오게 뒤집음
      } else {
        _messages = [];
      }
    } catch (e) {
      debugPrint('MenteeJournalPage load error: $e');
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goToSubmitPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MenteeJournalSubmitPage()),
    );
    if (result == true) {
      _load(); // 제출 성공 시 새로고침
    }
  }

  Future<void> _confirmMessage(int msgId) async {
    try {
      await SupabaseService.instance.commonConfirmMessage(messageId: msgId);
      _load(); // 상태 갱신
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('확인 처리 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool hasJournal = _journalData != null;

    // 아직 오늘 일지를 한 번도 작성하지 않았고, 메시지도 전혀 없을 때:
    // 화면 하단 쪽에 안내 카드만 단독으로 배치
    if (!hasJournal && _messages.isEmpty) {
      final content = Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
          child: _TodayCardDemo(onTap: _goToSubmitPage),
        ),
      );

      if (widget.embedded) return content;
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('일일 일지',
              style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: '히스토리(달력) - 데모',
              icon: const Icon(Icons.calendar_month_rounded, color: UiTokens.title),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('데모: 히스토리는 후속 단계에서 구현됩니다.')),
                );
              },
            ),
          ],
        ),
        body: content,
      );
    }

    final content = Stack(
      children: [
        ListView.separated(
          reverse: true, // 최신이 아래(시각적) -> 실제론 리스트의 0번이 맨 아래 렌더링
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 110), // 하단 여백 확보 (답장 버튼용)
          itemCount: _messages.length + (hasJournal ? 0 : 1), // 일지 없으면 카드 하나 추가
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            // 일지 미제출 상태면 '오늘의 일지 제출' 카드 표시 (리스트의 유일한 아이템)
            if (!hasJournal) {
              return _TodayCardDemo(onTap: _goToSubmitPage);
            }

            // 메시지 렌더링
            final msg = _messages[index];
            final bool isMine = msg['is_mine'] == true;
            final String contentText = msg['content'] ?? '';
            final List photos = (msg['photos'] as List?) ?? [];
            final String timeStr = (msg['created_at'] as String?)?.substring(11, 16) ?? ''; // YYYY-MM-DDTHH:mm:ss... -> HH:mm
            final bool confirmed = msg['confirmed_at'] != null;
            final int msgId = (msg['id'] is int) ? msg['id'] : int.parse(msg['id'].toString());

            // 최신 메시지(0번)만 확인 UI 노출
            final bool isLatest = (index == 0);

            return _JournalBubble(
              author: isMine ? 'mentee' : 'mentor',
              selfRole: 'mentee',
              text: contentText,
              photos: photos,
              time: timeStr,
              showConfirm: isLatest && !isMine, // 최신이면서 상대방 메시지면 버튼 노출
              confirmed: confirmed,
              onConfirm: () => _confirmMessage(msgId),
            );
          },
        ),
        // 일지가 있을 때만 답장하기 버튼 노출
        if (hasJournal)
          Positioned(
            bottom: 24,
            left: 12,
            right: 12,
            child: _TodayCardDemo(
              onTap: _goToSubmitPage, // 답장도 동일한 제출 페이지 사용
            ),
          ),
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
  final VoidCallback? onTap;
  const _TodayCardDemo({this.onTap});
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
          Expanded(child: Text('오늘의 일지 제출', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900))),
          FilledButton(
            onPressed: onTap ?? () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데모: 제출 화면은 후속 단계에서 구현됩니다.')));
            },
            style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('작성하기', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
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
  final List photos; // 실제 사진 경로 리스트
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

    // 스토리지 경로(List)를 실제 표시/뷰어용 URL 리스트로 변환
    final List<String> photoUrls = photos
        .map((e) => SupabaseService.instance.getJournalPhotoUrl(e.toString()))
        .toList(growable: false);

    void openGallery(int initialIndex) {
      if (photoUrls.isEmpty) return;
      Navigator.of(context).push(
        PageRouteBuilder(
          barrierColor: Colors.black,
          opaque: false,
          pageBuilder: (_, __, ___) => ChatImageViewer(
            images: photoUrls,
            initialIndex: initialIndex.clamp(0, photoUrls.length - 1),
            titles: null,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }

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
              if (photoUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                photoUrls.length == 1
                    ? GestureDetector(
                        onTap: () => openGallery(0),
                        child: Container(
                          width: 200,
                          height: 140,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            image: DecorationImage(
                              image: NetworkImage(photoUrls.first),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(
                          photoUrls.length,
                          (i) => GestureDetector(
                            onTap: () => openGallery(i),
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                image: DecorationImage(
                                  image: NetworkImage(photoUrls[i]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
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


