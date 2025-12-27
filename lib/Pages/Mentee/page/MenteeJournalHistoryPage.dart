import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Pages/Chat/widgets/ChatImageViewer.dart';

/// 멘티용 일지 히스토리(달력) 페이지
class MenteeJournalHistoryPage extends StatefulWidget {
  const MenteeJournalHistoryPage({super.key});

  @override
  State<MenteeJournalHistoryPage> createState() =>
      _MenteeJournalHistoryPageState();
}

class _MenteeJournalHistoryPageState extends State<MenteeJournalHistoryPage> {
  DateTime _currentMonth = DateTime.now();
  bool _loading = false;
  String? _error;

  /// key: yyyy-MM-dd, value: {journal_id, date, status}
  Map<String, Map<String, dynamic>> _byDate = {};
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _loadMonth();
  }

  DateTime get _firstDayOfMonth =>
      DateTime(_currentMonth.year, _currentMonth.month, 1);

  DateTime get _lastDayOfMonth =>
      DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

  String _keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadMonth() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.instance.menteeListJournalsByMonth(
        from: _firstDayOfMonth,
        to: _lastDayOfMonth,
      );
      final map = <String, Map<String, dynamic>>{};
      for (final r in rows) {
        final date = r['date'];
        DateTime? d;
        if (date is DateTime) {
          d = date.toLocal();
        } else if (date is String && date.isNotEmpty) {
          d = DateTime.tryParse(date)?.toLocal();
        }
        if (d == null) continue;
        map[_keyOf(d)] = Map<String, dynamic>.from(r);
      }
      setState(() {
        _byDate = map;
        _selectedDate = null;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + offset,
        1,
      );
      _selectedDate = null;
    });
    _loadMonth();
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFEA580C); // 주황
      case 'replied':
      case 'completed':
        return const Color(0xFF059669); // 초록
      default:
        return UiTokens.title.withOpacity(0.25);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':
        return '제출(미응답)';
      case 'replied':
      case 'completed':
        return '응답 완료';
      default:
        return '미제출';
    }
  }

  Future<void> _openDetailFor(DateTime date) async {
    final key = _keyOf(date);
    final row = _byDate[key];
    if (row == null) return;
    final journalId = (row['journal_id'] ?? row['id']).toString();
    if (journalId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _MenteeJournalDetailPage(journalId: journalId, date: date),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${_currentMonth.year}.${_currentMonth.month.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UiTokens.title),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '일지 히스토리',
          style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: UiTokens.title,
                  ),
                  onPressed: () => _changeMonth(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      monthLabel,
                      style: const TextStyle(
                        color: UiTokens.title,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    color: UiTokens.title,
                  ),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _LegendRow(),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '히스토리를 불러오지 못했습니다.',
                    style: TextStyle(
                      color: UiTokens.title.withOpacity(0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_error',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _loadMonth,
                    style: FilledButton.styleFrom(
                      backgroundColor: UiTokens.primaryBlue,
                    ),
                    child: const Text(
                      '다시 시도',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: _CalendarGrid(
                  month: _currentMonth,
                  byDate: _byDate,
                  selectedDate: _selectedDate,
                  statusColor: _statusColor,
                  onTapDate: (d) {
                    final key = _keyOf(d);
                    if (_byDate.containsKey(key)) {
                      setState(() {
                        _selectedDate = d;
                      });
                    }
                  },
                ),
              ),
            ),
            if (_selectedDate != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        final d = _selectedDate;
                        if (d != null) {
                          _openDetailFor(d);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: UiTokens.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        '${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.day.toString().padLeft(2, '0')} 일지 자세히 보기',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          _LegendDot(color: Color(0xFFD4D4D8), label: '미제출'),
          _LegendDot(color: Color(0xFFEA580C), label: '제출(미응답)'),
          _LegendDot(color: Color(0xFF059669), label: '응답 완료'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: UiTokens.title.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final Map<String, Map<String, dynamic>> byDate;
  final DateTime? selectedDate;
  final Color Function(String? status) statusColor;
  final void Function(DateTime date) onTapDate;

  const _CalendarGrid({
    required this.month,
    required this.byDate,
    required this.selectedDate,
    required this.statusColor,
    required this.onTapDate,
  });

  String _keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final int startWeekday = firstDay.weekday % 7; // 월=1, 일=7 → 0~6로 변환
    final int totalDays = lastDay.day;
    final int totalCells = ((startWeekday + totalDays + 6) ~/ 7) * 7; // 6주까지 커버

    final daysOfWeek = const ['일', '월', '화', '수', '목', '금', '토'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final isSunday = i == 0;
            final isSaturday = i == 6;
            return Expanded(
              child: Center(
                child: Text(
                  daysOfWeek[i],
                  style: TextStyle(
                    color:
                        isSunday
                            ? const Color(0xFFFB7185)
                            : isSaturday
                            ? UiTokens.primaryBlue
                            : UiTokens.title.withOpacity(0.7),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: totalCells,
            itemBuilder: (_, index) {
              final dayNumber = index - startWeekday + 1;
              if (dayNumber < 1 || dayNumber > totalDays) {
                return const SizedBox.shrink();
              }
              final date = DateTime(month.year, month.month, dayNumber);
              final key = _keyOf(date);
              final row = byDate[key];
              final status = row?['status'] as String?;
              final hasJournal = row != null;

              final bool isToday =
                  DateTime.now().year == date.year &&
                  DateTime.now().month == date.month &&
                  DateTime.now().day == date.day;

              final bool isSelected = selectedDate != null &&
                  selectedDate!.year == date.year &&
                  selectedDate!.month == date.month &&
                  selectedDate!.day == date.day;

              final Color dotColor =
                  hasJournal
                      ? statusColor(status)
                      : UiTokens.title.withOpacity(0.15);

              return _DayCell(
                date: date,
                isToday: isToday,
                isSelected: isSelected,
                hasJournal: hasJournal,
                dotColor: dotColor,
                statusLabel: status,
                onTap: hasJournal ? () => onTapDate(date) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool hasJournal;
  final Color dotColor;
  final String? statusLabel;
  final VoidCallback? onTap;

  const _DayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.hasJournal,
    required this.dotColor,
    required this.statusLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final int day = date.day;
    final bool isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    final Color textColor =
        hasJournal
            ? UiTokens.title
            : UiTokens.title.withOpacity(isWeekend ? 0.35 : 0.45);

    final bool highlight = isSelected || isToday;
    final Color bgColor = highlight ? const Color(0xFFE0ECFF) : Colors.white;

    final Border border = Border.all(
      color: highlight ? UiTokens.primaryBlue : const Color(0xFFE2E8F0),
      width: highlight ? 1.4 : 1,
    );

    final child = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: border,
        boxShadow: highlight ? [UiTokens.cardShadow] : const [],
      ),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$day',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: child,
    );
  }
}

/// 멘티용 일지 상세 페이지 (히스토리에서 진입)
class _MenteeJournalDetailPage extends StatefulWidget {
  final String journalId;
  final DateTime? date;

  const _MenteeJournalDetailPage({required this.journalId, this.date});

  @override
  State<_MenteeJournalDetailPage> createState() =>
      _MenteeJournalDetailPageState();
}

class _MenteeJournalDetailPageState extends State<_MenteeJournalDetailPage> {
  bool _loading = true;
  List<dynamic> _messages = [];
  Map<String, dynamic>? _journal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await SupabaseService.instance.getJournalDetail(
        journalId: widget.journalId,
      );
      if (data != null) {
        final rawMsgs = (data['messages'] as List?) ?? [];
        setState(() {
          _journal = data['journal'] as Map<String, dynamic>?;
          _messages = List.from(rawMsgs.reversed);
        });
      } else {
        setState(() {
          _journal = null;
          _messages = [];
        });
      }
    } catch (e) {
      debugPrint('MenteeJournalDetail load error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _fmtTitleDate() {
    DateTime? d = widget.date;
    final raw = _journal?['date'];
    if (d == null) {
      if (raw is DateTime) {
        d = raw;
      } else if (raw is String) {
        d = DateTime.tryParse(raw);
      }
    }
    if (d == null) return '일지 상세';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} 일지';
  }

  @override
  Widget build(BuildContext context) {
    final title = _fmtTitleDate();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UiTokens.title),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 42),
                reverse: true,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final bool isMine = msg['is_mine'] == true;
                  final String contentText = msg['content'] ?? '';
                  final List photos = (msg['photos'] as List?) ?? [];
                  final String timeStr =
                      (msg['created_at'] as String?)?.substring(11, 16) ?? '';
                  final bool confirmed = msg['confirmed_at'] != null;

                  final bool isLatest = index == 0;

                  return _JournalBubble(
                    author: isMine ? 'mentee' : 'mentor',
                    selfRole: 'mentee',
                    text: contentText,
                    photos: photos,
                    time: timeStr,
                    showConfirm: isLatest && !isMine,
                    confirmed: confirmed,
                    onConfirm: null,
                  );
                },
              ),
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
  final bool confirmed; // 내 버블에 상대방이 확인했을 때 체크 표시
  final VoidCallback? onConfirm;

  const _JournalBubble({
    required this.author,
    required this.selfRole,
    required this.text,
    required this.photos,
    required this.time,
    required this.showConfirm,
    required this.confirmed,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMenteeMsg = author == 'mentee';
    final bool mine = author == selfRole;
    final Color bg =
        isMenteeMsg ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);
    final Color border =
        isMenteeMsg ? const Color(0xFFDBEAFE) : const Color(0xFFB7F3DB);
    final Color fg =
        isMenteeMsg ? const Color(0xFF2563EB) : const Color(0xFF059669);

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
          pageBuilder:
              (_, __, ___) => ChatImageViewer(
                images: photoUrls,
                initialIndex: initialIndex.clamp(0, photoUrls.length - 1),
                titles: null,
              ),
          transitionsBuilder:
              (_, anim, __, child) =>
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
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMenteeMsg ? '멘티' : '멘토',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
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
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
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
              Text(
                text,
                style: const TextStyle(
                  color: UiTokens.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!mine &&
                            showConfirm &&
                            !confirmed) // confirmed가 true면 버튼 숨기고 체크 표시로 전환 (원한다면)
                          InkWell(
                            onTap:
                                onConfirm ??
                                () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('데모: 확인 처리')),
                                  );
                                },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: UiTokens.primaryBlue.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: UiTokens.primaryBlue,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '확인하기',
                                    style: TextStyle(
                                      color: UiTokens.primaryBlue,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // 내가 받은 최신 메시지인데 이미 확인한 경우
                        if (!mine && confirmed && showConfirm) ...[
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: UiTokens.primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '확인함',
                            style: TextStyle(
                              color: UiTokens.primaryBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        // 내가 보낸 최신 메시지를 상대가 확인한 경우
                        if (mine && confirmed && showConfirm) ...[
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '확인됨',
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
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
