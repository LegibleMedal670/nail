import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/widgets/JournalBubble.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Pages/Chat/widgets/ChatImageViewer.dart';
import 'package:nail/Pages/Mentee/page/MenteeJournalHistoryPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nail/Pages/Mentee/page/MenteeJournalSubmitPage.dart';

class MenteeJournalPage extends StatefulWidget {
  final bool embedded;
  final ValueChanged<bool>? onBadgeChanged; // 하단 탭 점 상태 콜백
  const MenteeJournalPage({
    super.key,
    this.embedded = false,
    this.onBadgeChanged,
  });

  @override
  State<MenteeJournalPage> createState() => _MenteeJournalPageState();
}

class _MenteeJournalPageState extends State<MenteeJournalPage> {
  bool _loading = true;
  Map<String, dynamic>? _journalData; // null이면 오늘 제출 안 함
  List<dynamic> _messages = [];
  String? _journalId;
  RealtimeChannel? _journalRt;

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
        final journal = data['journal'];
        if (journal is Map) {
          final idVal = (journal['id'] ?? journal['journal_id'] ?? '').toString();
          _journalId = idVal.isNotEmpty ? idVal : null;
        }
        final rawMsgs = (data['messages'] as List?) ?? [];
        // journalId를 못 받은 경우, 메시지에서 fallback으로 추출
        if ((_journalId == null || _journalId!.isEmpty) && rawMsgs.isNotEmpty) {
          final last = rawMsgs.last;
          if (last is Map) {
            final idFromMsg = (last['journal_id'] ?? '').toString();
            if (idFromMsg.isNotEmpty) {
              _journalId = idFromMsg;
            }
          }
        }
        _messages = List.from(rawMsgs.reversed); // 최신이 0번 인덱스로 오게 뒤집음
      } else {
        _messages = [];
        _journalId = null;
      }

      // 배지 상태 동기화: 오늘 일지/최신 선임 피드백 기준
      if (widget.onBadgeChanged != null) {
        final bool needDot = await SupabaseService.instance.menteeJournalNeedDot();
        if (mounted) {
          widget.onBadgeChanged!.call(needDot);
        }
      }
    } catch (e) {
      debugPrint('MenteeJournalPage load error: $e');
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _ensureJournalRealtime();
      }
    }
  }

  Future<void> _goToSubmitPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MenteeJournalSubmitPage()),
    );
    if (result == true) {
      _load(); // 제출/답장 성공 시 리스트 및 배지 상태 새로고침
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

  void _ensureJournalRealtime() {
    _journalRt?.unsubscribe();
    final sb = Supabase.instance.client;
    final channelName = 'mentee_journal_today_${DateTime.now().microsecondsSinceEpoch}';
    final ch = sb.channel(channelName);

    void handler(PostgresChangePayload payload) {
      try {
        final rec = payload.newRecord ?? payload.oldRecord ?? <String, dynamic>{};
        // RLS로 이미 내 일지에 대한 변경만 오므로, 저널 ID 비교 없이 바로 리로드
        _load();
      } catch (e) {
        debugPrint('MenteeJournalPage realtime handler error: $e');
      }
    }

    ch
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'daily_journal_messages',
        callback: handler,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'daily_journal_messages',
        callback: handler,
      )
      ..subscribe();

    _journalRt = ch;
  }

  @override
  void dispose() {
    _journalRt?.unsubscribe();
    super.dispose();
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
          title: const Text(
            '일일 일지',
            style: TextStyle(
              color: UiTokens.title,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              tooltip: '히스토리(달력)',
              icon: const Icon(
                Icons.calendar_month_rounded,
                color: UiTokens.title,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MenteeJournalHistoryPage(),
                  ),
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

            return JournalBubble(
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
            tooltip: '히스토리(달력)',
            icon: const Icon(Icons.calendar_month_rounded, color: UiTokens.title),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MenteeJournalHistoryPage()),
              );
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

// 끝

