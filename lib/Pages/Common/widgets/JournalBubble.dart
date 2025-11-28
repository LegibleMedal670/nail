import 'package:flutter/material.dart';
import 'package:nail/Pages/Chat/widgets/ChatImageViewer.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 멘티/멘토 공용 일지 버블 위젯
///
/// [author] : 'mentee' | 'mentor'
/// [selfRole] : 현재 화면 사용자 역할 ('mentee' | 'mentor')
class JournalBubble extends StatelessWidget {
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
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
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
                                  color: UiTokens.primaryBlue
                                      .withOpacity(0.3),
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


