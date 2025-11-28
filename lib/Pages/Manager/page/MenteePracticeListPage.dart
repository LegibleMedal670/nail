import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/MenteeBrief.dart';
import 'package:nail/Pages/Manager/models/PracticeAttempt.dart';
import 'package:nail/Pages/Manager/widgets/UnassignMenteeConfirmModal.dart';
import 'package:nail/Providers/AdminMentorDetailProvider.dart';
import 'package:nail/Services/StorageService.dart'; // ★ 키 → 서명 URL
import 'package:provider/provider.dart';

class MenteePracticeListPage extends StatefulWidget {
  final String mentorId;
  final MenteeBrief mentee;
  final Future<bool> Function() onUnassign;

  const MenteePracticeListPage({
    super.key,
    required this.mentorId,
    required this.mentee,
    required this.onUnassign,
  });

  @override
  State<MenteePracticeListPage> createState() => _MenteePracticeListPageState();
}

class _MenteePracticeListPageState extends State<MenteePracticeListPage> {
  List<PracticeAttempt> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtDateTime(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ───── 이미지 키(List) → 서명 URL(List)
  Future<List<String>> _signAll(List<dynamic> keys) async {
    final storage = StorageService();
    final out = <String>[];
    for (final k in keys) {
      if (k == null) continue;
      final s = k.toString();
      if (s.isEmpty) continue;
      if (s.startsWith('http')) {
        out.add(s);
      } else {
        final u = await storage.getOrCreateSignedUrlPractice(s);
        if (u != null && u.isNotEmpty) out.add(u);
      }
    }
    return out;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = context.read<MentorDetailProvider>();
      final rows = await p.listAttempts(widget.mentee.id);

      // ★ 각 항목의 images(키/상대경로) → 서명 URL로 바꿔서 보관
      final signed = <PracticeAttempt>[];
      for (final a in rows) {
        final newImgs = await _signAll(a.images);
        signed.add(
          PracticeAttempt(
            id: a.id,
            attemptNo: a.attemptNo,
            setCode: a.setCode,
            submittedAt: a.submittedAt,
            status: a.status,
            reviewedAt: a.reviewedAt,
            rating: a.rating,
            feedbackText: a.feedbackText,
            reviewerId: a.reviewerId,
            reviewerName: a.reviewerName,
            images: newImgs, // ← 치환
            feedbackDays: a.feedbackDays,
            // setTitle을 모델에 추가했다면 여기에 세팅해줘야 함
            // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
          ),
        );
      }

      setState(() {
        _items = signed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  String _practiceLabel(PracticeAttempt a) {
    final t = (a as dynamic).setTitle as String?; // setTitle이 추가된 모델 가정
    final tt = t?.trim();
    if (tt != null && tt.isNotEmpty) return tt;
    return a.setCode;
  }

  // ───── 전체 화면 갤러리
  void _openGallery(List<String> images, int initialIndex) {
    if (images.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        barrierColor: Colors.black,
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _ImageGalleryScreen(images: images, initialIndex: initialIndex),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mentee;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UiTokens.title),
          tooltip: '뒤로가기',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          m.name,
          style:
          const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '배정 해제',
            icon: const Icon(Icons.link_off_rounded, color: UiTokens.actionIcon),
            onPressed: () async {
              final ok = await showUnassignMenteeConfirmDialog(
                context,
                menteeName: m.name,
              );
              if (!ok) return;

              try {
                // 상위에서 실제 RPC 호출 및 목록 갱신
                final success = await widget.onUnassign();
                if (!mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${m.name}님이 이 멘토에서 배정 해제되었습니다.',
                      ),
                    ),
                  );
                  Navigator.of(context).pop(); // 멘티 실습 목록 페이지 닫기
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('배정 해제에 실패했습니다.'),
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('배정 해제 중 오류가 발생했습니다: $e'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
          child: Text(_error!,
              style:
              const TextStyle(color: UiTokens.title)))
          : (_items.isEmpty)
          ? const Center(child: Text('제출된 실습이 없습니다'))
          : RefreshIndicator(
        color: UiTokens.primaryBlue,
        onRefresh: _load,
        child: ListView.separated(
          itemCount: _items.length,
          padding:
          const EdgeInsets.fromLTRB(12, 12, 12, 24),
          separatorBuilder: (_, __) =>
          const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final a = _items[i];
            final bool isPending = a.status == 'pending';
            final String statusLabel =
            isPending ? '대기' : '완료';
            final Color statusColor = isPending
                ? const Color(0xFF0EA5E9)
                : const Color(0xFF059669);
            final String? days =
            a.feedbackDays?.toStringAsFixed(1);

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border:
                Border.all(color: UiTokens.cardBorder),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [UiTokens.cardShadow],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Row(
                    children: [
                      Container(
                        padding:
                        const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor
                              .withOpacity(0.1),
                          border: Border.all(
                              color: statusColor
                                  .withOpacity(0.25)),
                          borderRadius:
                          BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!isPending &&
                          (a.rating ?? '').isNotEmpty)
                        _RatingBadge(rating: a.rating!),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_practiceLabel(a)} • #${a.attemptNo}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: UiTokens.title
                                .withOpacity(0.7),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text(
                    '제출: ${_fmtDateTime(a.submittedAt)}',
                    style: TextStyle(
                      color: UiTokens.title
                          .withOpacity(0.6),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (a.reviewedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '검수: ${_fmtDateTime(a.reviewedAt!)}  (${days ?? '—'}일)',
                      style: TextStyle(
                        color: UiTokens.title
                            .withOpacity(0.6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // 썸네일 리스트 (서명 URL 사용)
                  if (a.images.isNotEmpty)
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection:
                        Axis.horizontal,
                        itemCount: a.images.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                        itemBuilder: (_, j) {
                          final url = a.images[j];
                          final placeholder = Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color:
                              const Color(0xFFF1F5F9),
                              border: Border.all(
                                  color:
                                  const Color(0xFFE2E8F0)),
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons
                                  .image_not_supported_outlined,
                              color: Color(0xFF94A3B8),
                            ),
                          );
                          return ClipRRect(
                            borderRadius:
                            BorderRadius.circular(8),
                            child: GestureDetector(
                              onTap: () => _openGallery(
                                  a.images, j),
                              child: Image.network(
                                url,
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) =>
                                placeholder,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  if ((a.feedbackText ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      a.feedbackText!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 상/중/하 배지
class _RatingBadge extends StatelessWidget {
  final String rating; // 'high'|'mid'|'low'
  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    late Color bg, border, fg;
    late String label;
    late IconData icon;

    switch (rating) {
      case 'high':
        bg = const Color(0xFFECFDF5);
        border = const Color(0xFFB7F3DB);
        fg = const Color(0xFF059669);
        label = '상';
        icon = Icons.trending_up_rounded;
        break;
      case 'mid':
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFE2E8F0);
        fg = const Color(0xFF64748B);
        label = '중';
        icon = Icons.horizontal_rule_rounded;
        break;
      default:
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = '하';
        icon = Icons.trending_down_rounded;
        break;
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                fontSize: 12)),
      ]),
    );
  }
}

/// 전체화면 이미지 갤러리 (핀치/더블탭 줌)
class _ImageGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _ImageGalleryScreen({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ImageGalleryScreen> createState() =>
      _ImageGalleryScreenState();
}

class _ImageGalleryScreenState
    extends State<_ImageGalleryScreen> {
  late final PageController _pc;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex
        .clamp(0, widget.images.length - 1);
    _pc = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: imgs.length,
            itemBuilder: (_, i) {
              final url = imgs[i];
              return Center(child: _ZoomableImage(url: url));
            },
          ),
          SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white),
                    onPressed: () =>
                        Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                      Colors.white.withOpacity(0.15),
                      borderRadius:
                      BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1} / ${imgs.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final String url;
  const _ZoomableImage({required this.url});

  @override
  State<_ZoomableImage> createState() =>
      _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  late TransformationController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TransformationController();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final m = _tc.value;
    final isZoomed = m.getMaxScaleOnAxis() > 1.01;
    _tc.value =
    isZoomed ? Matrix4.identity() : Matrix4.identity()..scale(2.5);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1.0,
        maxScale: 6.0,
        panEnabled: true,
        scaleEnabled: true,
        child: Image.network(widget.url, fit: BoxFit.contain),
      ),
    );
  }
}
