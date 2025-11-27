import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nail/Pages/Chat/widgets/ChatImageViewer.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/SupabaseService.dart';

class MentorJournalPage extends StatefulWidget {
  final bool embedded;
  const MentorJournalPage({super.key, this.embedded = false});

  @override
  State<MentorJournalPage> createState() => _MentorJournalPageState();
}

class _MentorJournalPageState extends State<MentorJournalPage> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  /// null = 전체, 'pending' = 미응답만
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.instance.mentorListDailyJournals(
        date: null,
        statusFilter: _statusFilter,
      );
      setState(() {
        _items = rows;
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

  void _setFilter(String? status) {
    if (_statusFilter == status) return;
    setState(() {
      _statusFilter = status;
    });
    _load();
  }

  String _formatSubmittedAt(dynamic lastAt, dynamic dateValue) {
    DateTime? dt;
    if (lastAt is DateTime) {
      dt = lastAt.toLocal();
    } else if (lastAt is String && lastAt.isNotEmpty) {
      dt = DateTime.tryParse(lastAt)?.toLocal();
    }
    if (dt == null) {
      if (dateValue is DateTime) {
        dt = dateValue.toLocal();
      } else if (dateValue is String && dateValue.isNotEmpty) {
        dt = DateTime.tryParse(dateValue)?.toLocal();
      }
    }
    if (dt == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');

    if (d == today) return '오늘 $h:$m';
    if (d == today.subtract(const Duration(days: 1))) return '어제 $h:$m';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} $h:$m';
  }

  DateTime? _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v);
    }
    return null;
  }

  Future<void> _openDetail(Map<String, dynamic> row) async {
    final journalId = (row['journal_id'] ?? row['id']).toString();
    final menteeName = (row['mentee_name'] ?? '멘티').toString();
    final date = _parseDate(row['date']);

    final changed = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MentorJournalDetailPage(
          journalId: journalId,
          menteeName: menteeName,
          date: date,
        ),
      ),
    );
    if (changed == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Row(
            children: [
              _FilterChip(
                selected: _statusFilter == 'pending',
                label: '미응답 우선',
                onTap: () => _setFilter('pending'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                selected: _statusFilter == null,
                label: '전체',
                onTap: () => _setFilter(null),
              ),
              const Spacer(),
              IconButton(
                tooltip: '검색(데모)',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('데모: 검색/필터는 후속 단계에서 구현됩니다.'),
                    ),
                  );
                },
                icon: const Icon(Icons.search_rounded, color: UiTokens.actionIcon),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Text(
                    '목록을 불러오지 못했습니다.',
                    style: TextStyle(
                      color: UiTokens.title.withOpacity(0.8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_error',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _load,
                    style: FilledButton.styleFrom(
                      backgroundColor: UiTokens.primaryBlue,
                    ),
                    child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            )
          else if (_items.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: UiTokens.actionIcon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '표시할 일지가 없습니다.',
                      style: TextStyle(
                        color: UiTokens.title.withOpacity(0.8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...[
              for (int i = 0; i < _items.length; i++) ...[
                Builder(
                  builder: (context) {
                    final r = _items[i];
                    final menteeName = (r['mentee_name'] ?? '멘티').toString();
                    final status = (r['status'] ?? 'pending').toString();
                    final submittedAt = _formatSubmittedAt(
                      r['last_message_at'],
                      r['date'],
                    );
                    return _JournalListTile(
                      menteeName: menteeName,
                      submittedAt: submittedAt,
                      status: status,
                      onTap: () => _openDetail(r),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
        ],
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(backgroundColor: Colors.white, body: content);
  }
}

class _FilterChip extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback? onTap;
  const _FilterChip({required this.selected, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
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

class _JournalListTile extends StatelessWidget {
  final String menteeName;
  final String submittedAt;
  final String status; // 'pending' | 'replied' | 'completed'
  final VoidCallback onTap;
  const _JournalListTile({
    required this.menteeName,
    required this.submittedAt,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool pending = status == 'pending';
    final Color chipColor = pending
        ? const Color(0xFFEA580C)
        : (status == 'replied' ? const Color(0xFF059669) : const Color(0xFF64748B));
    final String chipText =
        pending ? '미응답' : (status == 'replied' ? '응답완료' : '완료');
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
                Text('제출: $submittedAt', style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700)),
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

class _MentorJournalDetailPage extends StatefulWidget {
  final String journalId;
  final String menteeName;
  final DateTime? date;
  const _MentorJournalDetailPage({
    required this.journalId,
    required this.menteeName,
    this.date,
  });

  @override
  State<_MentorJournalDetailPage> createState() => _MentorJournalDetailPageState();
}

class _MentorJournalDetailPageState extends State<_MentorJournalDetailPage> {
  bool _loading = true;
  Map<String, dynamic>? _journal;
  List<dynamic> _messages = [];
  bool _dirty = false; // 목록 새로고침 필요 여부

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
      final data = await SupabaseService.instance
          .getJournalDetail(journalId: widget.journalId);
      if (data != null) {
        final journal = data['journal'];
        final rawMsgs = (data['messages'] as List?) ?? [];
        setState(() {
          _journal =
              journal is Map<String, dynamic> ? journal : Map<String, dynamic>.from(journal ?? {});
          _messages = List.from(rawMsgs.reversed); // 최신이 0번
        });
      } else {
        setState(() {
          _journal = null;
          _messages = [];
        });
      }
    } catch (e) {
      // 간단히 로그만 남기고 빈 화면 유지
      debugPrint('MentorJournalDetail load error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirmMessage(int msgId) async {
    try {
      await SupabaseService.instance.commonConfirmMessage(messageId: msgId);
      _load();
      _dirty = true;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('확인 처리 실패: $e')),
      );
    }
  }

  Future<void> _openReply() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MentorJournalReplyPage(
          journalId: widget.journalId,
          menteeName: widget.menteeName,
        ),
      ),
    );
    if (result == true) {
      _dirty = true;
      _load();
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
    if (d == null) return '';
    return '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _fmtTitleDate();
    final title = dateLabel.isEmpty
        ? '${widget.menteeName} 일지'
        : '${widget.menteeName} · $dateLabel 일지';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _dirty);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w800,
          ),
        ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: UiTokens.title),
            onPressed: () => Navigator.pop(context, _dirty),
          ),
        actions: [
          IconButton(
            tooltip: '히스토리(달력) - 데모',
            icon: const Icon(Icons.calendar_month_rounded, color: UiTokens.title),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('데모: 히스토리는 후속 단계에서 구현됩니다.'),
                ),
              );
            },
          ),
        ],
        ),
        bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _openReply,
              style: FilledButton.styleFrom(
                backgroundColor: UiTokens.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('답장 작성', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
        body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
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
                final int msgId = (msg['id'] is int)
                    ? msg['id']
                    : int.parse(msg['id'].toString());

                final bool isLatest = index == 0;

                return _MentorJournalBubble(
                  author: isMine ? 'mentor' : 'mentee',
                  selfRole: 'mentor',
                  text: contentText,
                  photos: photos,
                  time: timeStr,
                  showConfirm: isLatest && !isMine,
                  confirmed: confirmed,
                  onConfirm: () => _confirmMessage(msgId),
                );
              },
            ),
      ),
    );
  }
}

class _MentorJournalBubble extends StatelessWidget {
  final String author; // 'mentee'|'mentor'
  final String selfRole; // 현재 화면의 사용자 역할
  final String text;
  final List photos; // 스토리지 경로 리스트
  final String time;
  final bool showConfirm; // 최신+상대방 버블에만 '확인' 버튼 노출
  final bool confirmed; // 내/상대가 확인했을 때 상태
  final VoidCallback? onConfirm;

  const _MentorJournalBubble({
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
                        if (!mine && showConfirm && !confirmed)
                          InkWell(
                            onTap: onConfirm ??
                                () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('데모: 확인 처리'),
                                    ),
                                  );
                                },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding:
                                  const EdgeInsets.fromLTRB(10, 5, 12, 5),
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

class _MentorJournalReplyPage extends StatefulWidget {
  final String journalId;
  final String menteeName;
  const _MentorJournalReplyPage({
    required this.journalId,
    required this.menteeName,
  });

  @override
  State<_MentorJournalReplyPage> createState() =>
      _MentorJournalReplyPageState();
}

class _MentorJournalReplyPageState extends State<_MentorJournalReplyPage> {
  final _textController = TextEditingController();
  final List<XFile> _photos = [];
  bool _uploading = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked.isNotEmpty) {
      setState(() {
        const maxCount = 5;
        final remaining = maxCount - _photos.length;
        if (remaining <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사진은 최대 5장까지 첨부할 수 있습니다.')),
          );
          return;
        }
        if (picked.length > remaining) {
          _photos.addAll(picked.take(remaining));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('사진은 최대 5장까지만 추가됩니다.')),
          );
        } else {
          _photos.addAll(picked);
        }
      });
    }
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용이나 사진을 입력해주세요.')),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      final List<String> uploadedPaths = [];
      for (final photo in _photos) {
        final path =
            await SupabaseService.instance.uploadJournalPhoto(File(photo.path));
        uploadedPaths.add(path);
      }
      await SupabaseService.instance.mentorReplyJournal(
        journalId: widget.journalId,
        content: text,
        photos: uploadedPaths,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('제출 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: UiTokens.title),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.menteeName} • 멘토 답장',
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _uploading ? null : _submit,
            child: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '전송',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '멘티에게 피드백을 남겨주세요.',
            style: TextStyle(
              color: UiTokens.title,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '사진은 최대 5장까지 첨부 가능합니다.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _textController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: '오늘 일지에 대한 피드백, 칭찬, 보완점을 적어주세요.',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '사진 첨부',
            style: TextStyle(
              color: UiTokens.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._photos.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(File(file.path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () =>
                            setState(() => _photos.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_photos.length < 5)
                InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_a_photo_rounded,
                        color: UiTokens.actionIcon,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

