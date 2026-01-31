import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/SignatureConfirmPage.dart';
import 'package:nail/Pages/Common/page/SignaturePage.dart';
import 'package:nail/Services/SignatureService.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/MentorProvider.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Services/StorageService.dart';

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

  Map<String, dynamic>? _attempt;
  List<String> _images = [];
  String? _instructions;
  List<Map<String, dynamic>> _prev = [];

  String? _gradeKor; // '상'|'중'|'하'
  final _fbCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final api = SupabaseService.instance;
    api.loginKey ??= widget.mentorLoginKey;
    _load();
  }

  // ---- helpers ----
  String? _ratingToKor(String? rating) {
    switch (rating) {
      case 'high': return '상';
      case 'mid':  return '중';
      case 'low':  return '하';
      default:     return null;
    }
  }

  Future<List<String>> _signAll(List keys) async {
    final storage = StorageService();
    final urls = <String>[];
    for (final it in keys) {
      if (it == null) continue;
      final s = it.toString();
      if (s.isEmpty) continue;
      if (s.startsWith('http')) { urls.add(s); continue; }
      final u = await storage.getOrCreateSignedUrlPractice(s);
      if (u != null && u.isNotEmpty) urls.add(u);
    }
    return urls;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = SupabaseService.instance;

      final row = await api.mentorGetAttempt(widget.attemptId);
      if (row == null) throw Exception('attempt not found');

      // 이미지
      final List urlsRaw = (row['image_urls'] as List?) ?? const [];
      final List keysRaw = (row['image_keys'] as List?) ?? const [];
      final images = urlsRaw.isNotEmpty
          ? urlsRaw.cast<String>()
          : (keysRaw.isNotEmpty ? await _signAll(keysRaw) : const <String>[]);

      // 이전 시도
      final menteeId = row['mentee_id'];
      final setId    = row['set_id'];
      
      // ✅ null 체크: UUID가 없으면 이전 시도 조회 스킵
      final prevList = (menteeId != null && setId != null)
          ? await api.mentorListPrevAttempts(
              menteeId: menteeId.toString(),
              setId: setId.toString(),
              excludeAttemptId: widget.attemptId,
              limit: 10,
            )
          : <Map<String, dynamic>>[];
      final prevSigned = <Map<String, dynamic>>[];
      for (final e in prevList) {
        final pUrls = (e['image_urls'] as List?) ?? const [];
        final pKeys = (e['image_keys'] as List?) ?? const [];
        final urls = pUrls.isNotEmpty
            ? pUrls.cast<String>()
            : (pKeys.isNotEmpty ? await _signAll(pKeys) : const <String>[]);
        prevSigned.add({...e, 'image_urls': urls});
      }
// ✅ 여기 추가: 서버 rating/feedback → UI 상태에 주입
      final String? rating = row['grade'] as String?;
      final String? feedback = row['feedback'] as String?;

      setState(() {
        _attempt = row;
        _images = images;
        _instructions = row['instructions'] as String?;
        _prev = prevSigned;

        // ✅ rating: 'high'|'mid'|'low' → '상'|'중'|'하'
        _gradeKor = rating == null
            ? null
            : (rating == 'high' ? '상' : rating == 'mid' ? '중' : '하');

        // ✅ 피드백 프리필
        _fbCtrl.text = feedback ?? '';

        _loading = false;
      });
    } catch (e) {
      setState(() { _error = '불러오기 실패: $e'; _loading = false; });
    }
  }

  bool get _isReviewed {
    final r = _attempt;
    if (r == null) return false;
    final status = r['status'] ?? r['attempt_status'];
    return r['reviewed_at'] != null || r['rating'] != null || status == 'reviewed';
  }

  @override
  void dispose() {
    _fbCtrl.dispose();
    super.dispose();
  }

  // ===== 서명 페이지로 이동 =====
  Future<void> _openSignature() async {
    if (_isReviewed) { _showSnack('검토 완료된 항목은 수정할 수 없어요'); return; }
    if (_gradeKor == null) { _showSnack('등급을 선택해주세요'); return; }

    final mp = context.read<MentorProvider>();
    final menteeName = _attempt?['mentee_nickname'] ?? '후임';
    final practiceTitle = _attempt?['set_title'] ?? '실습';

    // 사용자 정보 가져오기
    final user = context.read<UserProvider>().current;
    if (user == null) {
      _showSnack('❌ 사용자 정보를 불러올 수 없습니다.');
      return;
    }

    // ✅ 평가 등급 변환: '상'/'중'/'하' → 'high'/'mid'/'low'
    String? gradeEng;
    switch (_gradeKor) {
      case '상':
        gradeEng = 'high';
        break;
      case '중':
        gradeEng = 'mid';
        break;
      case '하':
        gradeEng = 'low';
        break;
    }

    // SignatureConfirmPage로 이동
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => SignatureConfirmPage(
          type: SignatureType.practiceMentor,
          data: {
            'practiceTitle': practiceTitle,
            'menteeName': menteeName,
            'name': mp.mentorName ?? user.nickname ?? '선임',
            'phone': user.phone ?? '',
            'grade': gradeEng, // ✅ 영문 grade 전달
            'feedback': _fbCtrl.text,
          },
        ),
      ),
    );

    if (result != null && mounted) {
      // 서명 완료 후 저장
      await _saveAfterSignature(
        result['signature'] as Uint8List?, 
        user.loginKey ?? user.firebaseUid ?? '', 
        user.phone ?? '',
      );
    }
  }

  Future<void> _saveAfterSignature(Uint8List? signature, String loginKey, String phoneNumber) async {
    if (signature == null) {
      _showSnack('❌ 서명 이미지를 가져올 수 없습니다.');
      return;
    }

    setState(() => _saving = true);
    try {
      final mp = context.read<MentorProvider>();

      // 1. 평가 저장 (grade + feedback)
      await mp.reviewAttempt(
        attemptId: widget.attemptId,
        gradeKor: _gradeKor!,
        feedback: _fbCtrl.text,
      );

      // 2. 서명 저장
      debugPrint('[AttemptReviewPage] Saving mentor signature for attempt: ${widget.attemptId}');
      await SignatureService.instance.signPracticeAttempt(
        loginKey: loginKey,
        attemptId: widget.attemptId,
        isMentor: true,
        signatureImage: signature,
        phoneNumber: phoneNumber,
      );
      debugPrint('[AttemptReviewPage] Mentor signature saved successfully');

      // 3. 전역 상태 갱신 (KPI/큐/후임/히스토리)
      await mp.refreshAllAfterReview();

      if (mounted) {
        _showSnack('✅ 평가 및 서명이 완료되었습니다!');
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      debugPrint('[AttemptReviewPage] Failed to save signature: $e');
      debugPrint('[AttemptReviewPage] Stack trace: $stackTrace');
      
      if (mounted) {
        String errorMsg = '평가 저장 실패';
        final errorStr = e.toString();
        
        if (errorStr.contains('already signed')) {
          errorMsg = '❌ 이미 서명이 완료된 실습입니다.';
        } else if (errorStr.contains('not authorized')) {
          errorMsg = '❌ 권한이 없습니다.';
        } else if (errorStr.contains('mentor must sign first')) {
          errorMsg = '❌ 선임가 먼저 서명해야 합니다.';
        } else {
          errorMsg = '❌ 평가 저장 실패: $e';
        }
        
        _showSnack(errorMsg);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _unfocus() => FocusScope.of(context).unfocus();

  void _openGallery(int initialIndex, {List<String>? images}) {
    final imgs = images ?? _images;
    if (imgs.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        barrierColor: Colors.black,
        opaque: false,
        pageBuilder: (_, __, ___) => _ImageGalleryScreen(
          images: imgs,
          initialIndex: initialIndex.clamp(0, imgs.length - 1),
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = max(12.0, viewInsets + 12.0);
    final canEdit = !_isReviewed;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _unfocus,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0,
          leading: IconButton(
            tooltip: '나가기',
            icon: const Icon(Icons.arrow_back, color: UiTokens.title),
            onPressed: () { if (mounted) Navigator.pop(context); },
          ),
          title: const Text('실습 리뷰',
              style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        ),

        bottomNavigationBar: SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad),
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: canEdit ? (_saving ? null : _openSignature) : () { if (mounted) Navigator.pop(context); },
                style: FilledButton.styleFrom(
                  backgroundColor: canEdit ? UiTokens.primaryBlue : const Color(0xFFE2E8F0),
                  foregroundColor: canEdit ? Colors.white : UiTokens.title,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: canEdit
                    ? (_saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.edit, size: 20))
                    : const Icon(Icons.close, size: 20),
                label: Text(
                  canEdit ? (_saving ? '처리 중...' : '서명하고 제출') : '닫기',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
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
              _InstructionsBoxGreen(text: _instructions!),
            ],

            const SizedBox(height: 12),
            _ImagesSection(images: _images, onTapImage: (i) => _openGallery(i)),

            const SizedBox(height: 16),
            const _SectionTitle('등급'),
            const SizedBox(height: 8),
            // ✅ 읽기 전용이어도 선택된 칸은 강하게 표시, 탭만 막음
            _GradeSegment(
              value: _gradeKor,
              onChanged: (g) => setState(() => _gradeKor = g),
              enabled: canEdit,
            ),

            const SizedBox(height: 16),
            const _SectionTitle('피드백'),
            const SizedBox(height: 8),
            _FeedbackBox(
              controller: _fbCtrl,
              onSubmit: _unfocus,
              readOnly: !canEdit, // 시각적 배지는 제거
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
                  final List<String> urls = ((e['image_urls'] as List?) ?? []).cast<String>();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PrevItemTile(
                      attemptNo: no,
                      date: date,
                      rating: rating,
                      hasImages: urls.isNotEmpty,
                      onTap: () => _openPrevDetail(e),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrevDetail(Map<String, dynamic> e) async {
    final int no = (e['attempt_no'] ?? 0) as int;
    final date = e['reviewed_at'];
    final rating = (e['rating'] as String?) ?? 'low';
    final List<String> urls = ((e['image_urls'] as List?) ?? []).cast<String>();
    final String? fb = e['feedback'] as String?;

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
            initialChildSize: 0.65,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (_, controller) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40, height: 4,
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
                if (fb != null && fb.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        fb,
                        style: TextStyle(
                            color: UiTokens.title.withOpacity(0.85),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: urls.isEmpty
                      ? ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: const [_EmptyBox(text: '이전 시도 이미지가 없습니다.')],
                  )
                      : GridView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: urls.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6,
                    ),
                    itemBuilder: (_, i) {
                      final url = urls[i];
                      final tag = 'prev_${no}_img_$i';
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GestureDetector(
                          onTap: () => _openGallery(i, images: urls),
                          child: Hero(tag: tag, child: Image.network(url, fit: BoxFit.cover)),
                        ),
                      );
                    },
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

// ---------- UI bits ----------

class _SectionTitle extends StatelessWidget {
  final String text; const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(color: UiTokens.title, fontSize: 16, fontWeight: FontWeight.w800));
  }
}

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
    final status     = attempt['status'] ?? attempt['attempt_status'];

    final isReviewed = reviewed != null || rating != null || status == 'reviewed';
    final waiting    = !isReviewed;

    final dateLabel = waiting ? '제출일' : '검토일';
    final date      = waiting ? submitted : reviewed;
    final dateText  = _fmtDateOnly(date);

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
          if (waiting)
            const _StatusBadgeWaiting()
          else if (rating != null)
            _StatusBadgeRating(rating: rating)
          else
            const _StatusBadgeReviewed(),
        ],
      ),
    );
  }
}

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
        final tag = 'attempt_img_$i';
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(
            onTap: () => onTapImage?.call(i),
            child: Hero(tag: tag, child: Image.network(url, fit: BoxFit.cover)),
          ),
        );
      },
    );
  }
}

/// 등급 세그먼트: 선택된 칸은 읽기 전용이라도 “활성 색상/강조 유지”. 탭만 차단.
class _GradeSegment extends StatelessWidget {
  final String? value; // '상' | '중' | '하'
  final ValueChanged<String> onChanged;
  final bool enabled;
  const _GradeSegment({required this.value, required this.onChanged, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final items = [
      _SegItem('상', Icons.trending_up_rounded, const Color(0xFFECFDF5), const Color(0xFFB7F3DB), const Color(0xFF059669)),
      _SegItem('중', Icons.horizontal_rule_rounded, const Color(0xFFEFF6FF), const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
      _SegItem('하', Icons.trending_down_rounded, const Color(0xFFFFFBEB), const Color(0xFFFEF3C7), const Color(0xFFB45309)),
    ];

    return Row(
      children: List.generate(items.length, (i) {
        final it = items[i];
        final selected = value == it.label;

        // 읽기 전용: 선택된 칸은 100% 불투명 + 컬러 유지, 비선택 칸만 살짝 흐리게
        final double opacity = enabled ? 1.0 : (selected ? 1.0 : 0.55);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: opacity,
              child: GestureDetector(
                onTap: enabled ? () => onChanged(it.label) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  height: 48,
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
          ),
        );
      }),
    );
  }
}

class _SegItem {
  final String label; final IconData icon; final Color bg; final Color bd; final Color fg;
  _SegItem(this.label, this.icon, this.bg, this.bd, this.fg);
}

class _PrevItemTile extends StatelessWidget {
  final int attemptNo;
  final dynamic date;
  final String rating; // 'high' | 'mid' | 'low'
  final bool hasImages;
  final VoidCallback? onTap;
  const _PrevItemTile({
    super.key,
    required this.attemptNo,
    required this.date,
    required this.rating,
    required this.hasImages,
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
              child: Icon(hasImages ? Icons.image_rounded : Icons.history_rounded,
                  color: UiTokens.actionIcon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$attemptNo회차',
                    style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('검토일: $dateText',
                    style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700)),
              ]),
            ),
            _StatusBadgeRating(rating: rating),
          ],
        ),
      ),
    );
  }
}

class _StatusBadgeWaiting extends StatelessWidget {
  const _StatusBadgeWaiting();
  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF7ED);
    const border = Color(0xFFFCCFB3);
    const fg = Color(0xFFEA580C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(10)),
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
    late Color bg, border, fg; late String label; late IconData icon;
    switch (rating) {
      case 'high': bg = const Color(0xFFECFDF5); border = const Color(0xFFB7F3DB); fg = const Color(0xFF059669); label = '상'; icon = Icons.trending_up_rounded; break;
      case 'mid':  bg = const Color(0xFFF1F5F9); border = const Color(0xFFE2E8F0); fg = const Color(0xFF64748B); label = '중'; icon = Icons.horizontal_rule_rounded; break;
      default:     bg = const Color(0xFFFFFBEB); border = const Color(0xFFFEF3C7); fg = const Color(0xFFB45309); label = '하'; icon = Icons.trending_down_rounded; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(10)),
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

class _StatusBadgeReviewed extends StatelessWidget {
  const _StatusBadgeReviewed();
  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFECFDF5); const border = Color(0xFFB7F3DB); const fg = Color(0xFF059669);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(10)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 14, color: fg),
          SizedBox(width: 4),
          Text('완료', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

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
  void dispose() { _pc.dispose(); super.dispose(); }
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
              final tag = 'attempt_img_$i';
              return Center(child: _ZoomableHeroImage(tag: tag, url: url));
            },
          ),
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
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
                    child: Text('${_index + 1} / ${imgs.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
  @override
  void initState() { super.initState(); _tc = TransformationController(); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }
  void _handleDoubleTap() {
    final m = _tc.value;
    final isZoomed = m.getMaxScaleOnAxis() > 1.01;
    _tc.value = isZoomed ? Matrix4.identity() : Matrix4.identity()..scale(2.5);
  }
  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: widget.tag,
      child: GestureDetector(
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

// ---- utils ----
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

class _FeedbackBox extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmit;
  final bool readOnly;
  const _FeedbackBox({required this.controller, this.onSubmit, this.readOnly = false});

  @override
  State<_FeedbackBox> createState() => _FeedbackBoxState();
}

class _FeedbackBoxState extends State<_FeedbackBox> {
  final _focus = FocusNode();
  static const int _maxLen = 800;
  String get _text => widget.controller.text;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});
  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filled = _text.trim().isNotEmpty;
    final remain = _maxLen - _text.characters.length;
    final ro = widget.readOnly;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder, width: _focus.hasFocus ? 1.2 : 1),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_rounded, size: 18, color: UiTokens.actionIcon),
              const SizedBox(width: 6),
              const Text('선임 피드백',
                  style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
              const Spacer(),
              if (filled && !ro)
                TextButton.icon(
                  onPressed: () { widget.controller.clear(); },
                  icon: const Icon(Icons.backspace_outlined, size: 16),
                  label: const Text('지우기'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.controller,
            focusNode: _focus,
            readOnly: ro,
            enableInteractiveSelection: !ro,
            maxLines: 8,
            maxLength: _maxLen,
            textInputAction: TextInputAction.done,
            onEditingComplete: widget.onSubmit,
            decoration: InputDecoration(
              isDense: true,
              hintText: ro ? '검토 완료된 항목입니다' : '예) 큐티클 라인 좌우 두께가 달라요',
              hintStyle: TextStyle(color: const Color(0xFF64748B).withOpacity(0.8), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: ro ? Color(0xFFE2E8F0) : UiTokens.primaryBlue, width: 1.2),
              ),
              counterText: '',
            ),
            style: TextStyle(
              color: ro ? UiTokens.title.withOpacity(0.75) : UiTokens.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '남은 글자: $remain',
              style: TextStyle(
                color: ro
                    ? UiTokens.title.withOpacity(0.45)
                    : (remain < 50 ? const Color(0xFFB45309) : UiTokens.title.withOpacity(0.45)),
                fontWeight: FontWeight.w800, fontSize: 12,
              ),
            ),
          ),
        ],
      ),
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
            child: Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF065F46),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

