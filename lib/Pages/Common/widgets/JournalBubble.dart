import 'package:flutter/material.dart';
import 'package:nail/Pages/Chat/widgets/ChatImageViewer.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 멘티/멘토 공용 일지 버블 위젯
///
/// [author] : 'mentee' | 'mentor'
/// [selfRole] : 현재 화면 사용자 역할 ('mentee' | 'mentor')
class JournalBubble extends StatefulWidget {
  final String author;
  final String selfRole;
  final String text;

  /// 스토리지 경로 리스트
  final List photos;

  final String time;

  /// 최신 + 상대방 버블에만 '확인' 버튼/라벨을 노출할지 여부
  final bool showConfirm;

  /// 확인 처리 여부
  final bool confirmed;

  final VoidCallback? onConfirm;

  const JournalBubble({
    super.key,
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
  State<JournalBubble> createState() => _JournalBubbleState();
}

class _JournalBubbleState extends State<JournalBubble> {
  List<String> _photoUrls = [];
  bool _loadingUrls = false;

  @override
  void initState() {
    super.initState();
    _loadPhotoUrls();
  }

  @override
  void didUpdateWidget(JournalBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // photos가 변경되면 URL 다시 로드
    if (widget.photos != oldWidget.photos) {
      _loadPhotoUrls();
    }
  }

  Future<void> _loadPhotoUrls() async {
    if (widget.photos.isEmpty) {
      setState(() {
        _photoUrls = [];
        _loadingUrls = false;
      });
      return;
    }

    setState(() => _loadingUrls = true);
    
    try {
      final urls = await Future.wait(
        widget.photos.map((e) => SupabaseService.instance.getJournalPhotoUrl(e.toString()))
      );
      if (mounted) {
        setState(() {
          _photoUrls = urls;
          _loadingUrls = false;
        });
      }
    } catch (e) {
      debugPrint('[JournalBubble] Failed to load photo URLs: $e');
      if (mounted) {
        setState(() => _loadingUrls = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMenteeMsg = widget.author == 'mentee';
    final bool mine = widget.author == widget.selfRole;

    final Color bg =
        isMenteeMsg ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);
    final Color border =
        isMenteeMsg ? const Color(0xFFDBEAFE) : const Color(0xFFB7F3DB);
    final Color fg =
        isMenteeMsg ? const Color(0xFF2563EB) : const Color(0xFF059669);

    void openGallery(int initialIndex) {
      if (_photoUrls.isEmpty) return;
      Navigator.of(context).push(
        PageRouteBuilder(
          barrierColor: Colors.black,
          opaque: false,
          pageBuilder: (_, __, ___) => ChatImageViewer(
            images: _photoUrls,
            initialIndex: initialIndex.clamp(0, _photoUrls.length - 1),
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
                isMenteeMsg ? '후임' : '선임',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              // ===== 사진 표시 영역 =====
              if (widget.photos.isNotEmpty) ...[
                const SizedBox(height: 8),
                _loadingUrls
                    ? const SizedBox(
                        width: 200,
                        height: 140,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _photoUrls.length == 1
                        ? GestureDetector(
                            onTap: () => openGallery(0),
                            child: Container(
                              width: 200,
                              height: 140,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(_photoUrls.first),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: List.generate(
                              _photoUrls.length,
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
                                      image: NetworkImage(_photoUrls[i]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
              ],
              if (widget.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(
                  widget.text,
                  style: const TextStyle(
                    color: UiTokens.title,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    widget.time,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  // ===== 확인 버튼/라벨 =====
                  if (!mine && widget.showConfirm && !widget.confirmed) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onConfirm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.confirmed
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '확인',
                          style: TextStyle(
                            color: widget.confirmed
                                ? const Color(0xFF2563EB)
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ] else if (!mine && widget.showConfirm && widget.confirmed) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2563EB),
                      size: 16,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
