import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/MentorProvider.dart';

class AttemptReviewPage extends StatefulWidget {
  final String mentorLoginKey;
  final String attemptId;
  const AttemptReviewPage({
    super.key,
    required this.mentorLoginKey,
    required this.attemptId,
  });

  @override
  State<AttemptReviewPage> createState() => _AttemptReviewPageState();
}

class _AttemptReviewPageState extends State<AttemptReviewPage> {
  bool _loading = true;
  String? _error;

  // 로드된 데이터
  Map<String, dynamic>? _attempt; // mentee_name, set_code, attempt_no, submitted_at ...
  List<String> _images = [];       // 제출 이미지 url
  String? _instructions;           // 세트 지시문
  List<Map<String, dynamic>> _prev = []; // {attempt_no, reviewed_at, rating}

  // 입력 상태
  String? _gradeKor; // '상'|'중'|'하'
  final _fbCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });

    try {
      // TODO: 실제 RPC로 교체
      _attempt = {
        'mentee_name': '홍길동',
        'set_code'   : 'PS-001',
        'attempt_no' : 3,
        'submitted_at': DateTime.now().toIso8601String(),
      };
      _instructions = '큐티클 정리 후 베이스 컬러 2코트. 라인 번짐 주의.\n참고 이미지를 확인하고 최대한 비슷하게 완성하세요.';
      _images = [
        'https://picsum.photos/seed/1/1200/900',
        'https://picsum.photos/seed/2/1200/900',
        'https://picsum.photos/seed/3/1200/900',
      ];
      _prev = [
        {'attempt_no': 1, 'reviewed_at': DateTime.now().subtract(const Duration(days: 9)).toIso8601String(), 'rating': 'low'},
        {'attempt_no': 2, 'reviewed_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'rating': 'mid'},
      ];
      setState(() { _loading = false; });
    } catch (e) {
      setState(() { _error = '불러오기 실패: $e'; _loading = false; });
    }
  }

  @override
  void dispose() {
    _fbCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_gradeKor == null) {
      _showSnack('등급을 선택해주세요');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<MentorProvider>().reviewAttempt(
        attemptId: widget.attemptId,
        gradeKor: _gradeKor!, // '상'|'중'|'하'
        feedback: _fbCtrl.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _unfocus() => FocusScope.of(context).unfocus();

  // ✅ 이미지 전체화면 갤러리 열기
  void _openGallery(int initialIndex) {
    if (_images.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        barrierColor: Colors.black,
        opaque: false,
        pageBuilder: (_, __, ___) => _ImageGalleryScreen(
          images: _images,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom; // 키보드 높이
    final bottomPad = max(12.0, viewInsets + 12.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent, // 빈 공간 탭도 인식
      onTap: _unfocus,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            tooltip: '나가기',
            icon: const Icon(Icons.arrow_back, color: UiTokens.title),
            onPressed: (){
              if (mounted) Navigator.pop(context);
            },
          ),
          backgroundColor: Colors.white, elevation: 0,
          title: const Text('실습 리뷰',
              style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        ),
        // 키보드 올라올 때 버튼도 같이 올라오도록 패딩 적용
        bottomNavigationBar: SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad),
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: UiTokens.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
            ? _Error(message: _error!, onRetry: _load)
            : ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          children: [
            _InfoCard(attempt: _attempt!),
            if (_instructions != null && _instructions!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _InstructionsBoxGreen(text: _instructions!), // ✅ 초록 톤
            ],
            const SizedBox(height: 12),
            // ✅ 이미지 섹션: 탭하면 전체화면
            _ImagesSection(
              images: _images,
              onTapImage: _openGallery,
            ),
            const SizedBox(height: 16),
            const _SectionTitle('등급'),
            const SizedBox(height: 8),
            _GradeSegment(
              value: _gradeKor,
              onChanged: (g) => setState(() => _gradeKor = g),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('피드백'),
            const SizedBox(height: 8),
            TextField(
              controller: _fbCtrl,
              maxLines: 8,
              textInputAction: TextInputAction.done,
              onEditingComplete: _unfocus,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '상세 피드백을 작성하세요',
              ),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('이전 시도'),
            const SizedBox(height: 8),
            if (_prev.isEmpty)
              const _EmptyBox(text: '이전 시도가 없습니다.')
            else
              Column(
                children: _prev.map((e) {
                  final int no = (e['attempt_no'] ?? 0) as int;
                  final date = e['reviewed_at'];
                  final rating = (e['rating'] as String?) ?? 'low';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PrevItemTile(
                      attemptNo: no,
                      date: date,
                      rating: rating,
                      onTap: () => _openPrevDetail(e), // 상세 모달
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 80), // 여유
          ],
        ),
      ),
    );
  }

  Future<void> _openPrevDetail(Map<String, dynamic> e) async {
    final int no = (e['attempt_no'] ?? 0) as int;
    final date = e['reviewed_at'];
    final rating = (e['rating'] as String?) ?? 'low';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final pad = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: pad),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, controller) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text('이전 시도 • ${no}회차',
                          style: const TextStyle(
                              color: UiTokens.title,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                      _StatusBadgeRating(rating: rating),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('검토일: ${_fmtDateOnly(date)}',
                        style: TextStyle(
                          color: UiTokens.title.withOpacity(0.6),
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: const [
                      SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ===== 섹션 타이틀 =====
class _SectionTitle extends StatelessWidget {
  final String text; const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(
        color: UiTokens.title, fontSize: 16, fontWeight: FontWeight.w800));
  }
}

/// ===== 상단 정보 카드 =====
class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> attempt;
  const _InfoCard({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final menteeName = '${attempt['mentee_name'] ?? ''}';
    final setCode    = '${attempt['set_code'] ?? ''}';
    final attemptNo  = attempt['attempt_no'] ?? 0;
    final submitted  = attempt['submitted_at'];
    final reviewed   = attempt['reviewed_at'];
    final rating     = attempt['rating'] as String?;
    final waiting    = (rating == null); // rating 없으면 대기

    final dateLabel  = waiting ? '제출일' : '검토일';
    final date       = waiting ? submitted : reviewed;

    final dateText = _fmtDateOnly(date);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_outlined, color: UiTokens.actionIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$menteeName • $setCode • ${attemptNo}회차',
                  style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('$dateLabel: $dateText',
                  style: TextStyle(
                    color: UiTokens.title.withOpacity(0.6),
                    fontWeight: FontWeight.w700,
                  )),
            ]),
          ),
          if (waiting) const _StatusBadgeWaiting(),
          if (!waiting && rating != null) _StatusBadgeRating(rating: rating!),
        ],
      ),
    );
  }
}

/// ===== 이미지 섹션(갤러리) — 탭하면 전체화면 =====
class _ImagesSection extends StatelessWidget {
  final List<String> images;
  final void Function(int index)? onTapImage;
  const _ImagesSection({required this.images, this.onTapImage});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('제출 이미지 없음',
              style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6,
      ),
      itemBuilder: (_, i) {
        final url = images[i];
        final tag = 'attempt_img_${i}_$url';
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(
            onTap: () => onTapImage?.call(i),
            child: Hero(
              tag: tag,
              child: Image.network(url, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}

/// ===== 지시문 박스 (그린 톤) =====
class _InstructionsBoxGreen extends StatelessWidget {
  final String text;
  const _InstructionsBoxGreen({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        border: Border.all(color: const Color(0xFFB7F3DB)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== 예쁜 등급 세그먼트 =====
class _GradeSegment extends StatelessWidget {
  final String? value; // '상' | '중' | '하'
  final ValueChanged<String> onChanged;
  const _GradeSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      _SegItem(label: '상', icon: Icons.trending_up_rounded, bg: const Color(0xFFECFDF5), bd: const Color(0xFFB7F3DB), fg: const Color(0xFF059669)),
      _SegItem(label: '중', icon: Icons.horizontal_rule_rounded, bg: const Color(0xFFF1F5F9), bd: const Color(0xFFE2E8F0), fg: const Color(0xFF64748B)),
      _SegItem(label: '하', icon: Icons.trending_down_rounded, bg: const Color(0xFFFFFBEB), bd: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309)),
    ];
    return Row(
      children: List.generate(items.length, (i) {
        final it = items[i];
        final selected = value == it.label;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
            child: GestureDetector(
              onTap: () => onChanged(it.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? it.bg : Colors.white,
                  border: Border.all(color: selected ? it.bd : UiTokens.cardBorder),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected ? [UiTokens.cardShadow] : const [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(it.icon, size: 18, color: selected ? it.fg : const Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      it.label,
                      style: TextStyle(
                        color: selected ? it.fg : UiTokens.title,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SegItem {
  final String label; final IconData icon; final Color bg; final Color bd; final Color fg;
  _SegItem({required this.label, required this.icon, required this.bg, required this.bd, required this.fg});
}

/// ===== 이전 시도 미니 타일 =====
class _PrevItemTile extends StatelessWidget {
  final int attemptNo;
  final dynamic date;
  final String rating; // 'high' | 'mid' | 'low'
  final VoidCallback? onTap;
  const _PrevItemTile({
    super.key,
    required this.attemptNo,
    required this.date,
    required this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = _fmtDateOnly(date);

    return GestureDetector(
      onTap: onTap,
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
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.history_rounded, color: UiTokens.actionIcon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$attemptNo회차',
                    style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('검토일: $dateText',
                    style: TextStyle(
                      color: UiTokens.title.withOpacity(0.6),
                      fontWeight: FontWeight.w700,
                    )),
              ]),
            ),
            _StatusBadgeRating(rating: rating),
          ],
        ),
      ),
    );
  }
}

/// ===== 상태/등급 배지 =====
class _StatusBadgeWaiting extends StatelessWidget {
  const _StatusBadgeWaiting();

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF7ED);
    const border = Color(0xFFFCCFB3);
    const fg = Color(0xFFEA580C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_bottom_rounded, size: 14, color: fg),
          SizedBox(width: 4),
          Text('대기', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusBadgeRating extends StatelessWidget {
  final String rating; // 'high'|'mid'|'low'
  const _StatusBadgeRating({required this.rating});

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
      default: // 'low'
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = '하';
        icon = Icons.trending_down_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

/// ===== 전체화면 이미지 갤러리 =====
class _ImageGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _ImageGalleryScreen({required this.images, required this.initialIndex});

  @override
  State<_ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<_ImageGalleryScreen> {
  late final PageController _pc;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
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
              final tag = 'attempt_img_${i}_$url';
              return Center(
                child: _ZoomableHeroImage(tag: tag, url: url),
              );
            },
          ),
          // 상단 닫기/인덱스
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1} / ${imgs.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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

class _ZoomableHeroImage extends StatefulWidget {
  final String tag;
  final String url;
  const _ZoomableHeroImage({required this.tag, required this.url});

  @override
  State<_ZoomableHeroImage> createState() => _ZoomableHeroImageState();
}

class _ZoomableHeroImageState extends State<_ZoomableHeroImage> {
  late TransformationController _tc;
  TapDownDetails? _lastTapDown;

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
    // 더블탭: 원상/2.5x 토글
    final m = _tc.value;
    final isZoomed = m.getMaxScaleOnAxis() > 1.01;
    _tc.value = isZoomed ? Matrix4.identity() : Matrix4.identity()..scale(2.5);
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: widget.tag,
      child: GestureDetector(
        onDoubleTapDown: (d) => _lastTapDown = d,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _tc,
          minScale: 1.0,
          maxScale: 6.0,
          panEnabled: true,
          scaleEnabled: true,
          child: Image.network(widget.url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// ===== 유틸/공통 =====
String _fmtDateOnly(dynamic v) {
  if (v == null) return '';
  try {
    if (v is DateTime) {
      return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    }
    final s = v.toString();
    final DateTime d = DateTime.tryParse(s) ??
        DateTime.tryParse(s.split(' ').first) ??
        DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return v.toString().split(' ').first;
  }
}

class _EmptyBox extends StatelessWidget {
  final String text; const _EmptyBox({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text(
        text,
        style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700),
      )),
    );
  }
}

class _Error extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(message, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: onRetry, style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
        child: const Text('다시 시도'),
      ),
    ]));
  }
}
