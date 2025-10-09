// lib/Pages/Mentee/page/PracticeDetailPage.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Services/StorageService.dart';

class PracticeDetailPage extends StatefulWidget {
  final String setId; // set_id(uuid)
  const PracticeDetailPage({super.key, required this.setId});

  @override
  State<PracticeDetailPage> createState() => _PracticeDetailPageState();
}

class _PracticeDetailPageState extends State<PracticeDetailPage> {
  final _api = SupabaseService.instance;
  final _picker = ImagePicker();

  Map<String, dynamic>? _detail;
  bool _loading = false;        // 초기 로딩
  bool _submitting = false;     // 부분 로딩(제출 섹션)
  bool _dirty = false;          // ← 목록으로 복귀 시 새로고침 필요 여부

  String? _error;

  // 참고 이미지(세트 reference; 표시용 URL)
  List<String> _refImages = const [];

  // 서버에 저장된 "현재 시도"의 제출 이미지 (표시용 URL)
  List<String> _serverSubmittedUrls = const [];

  // 로컬에서 새로 추가한 이미지(제출 전)
  final List<XFile> _localPicks = [];

  // 방금 제출한 로컬 이미지(서버 재조회 전에도 계속 보여주기)
  List<XFile> _lastSubmittedLocal = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<String>> _signAll(List raw) async {
    if (raw.isEmpty) return const <String>[];
    final storage = StorageService();
    final out = <String>[];
    for (final x in raw) {
      if (x == null) continue;
      final s = x.toString().trim();
      if (s.isEmpty) continue;
      if (s.startsWith('http')) { out.add(s); continue; }
      final u = await storage.getOrCreateSignedUrlPractice(s);
      if (u.isNotEmpty) out.add(u);
    }
    return out;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await _api.menteePracticeSetDetail(
        setId: widget.setId, limit: 30, offset: 0,
      );

      print(d);

      // 참고 이미지
      final refRaw = (d?['set_reference_imgs'] as List?) ?? const [];
      final refUrls = await _signAll(refRaw);

      // ✅ 서버 제출 이미지 (urls 우선, 없으면 paths → 서명URL)
      final curUrls = (d?['current_image_urls'] as List?) ?? const [];
      final curPaths = (d?['current_image_paths'] as List?) ?? const [];
      final submittedUrls = curUrls.isNotEmpty ? curUrls.cast<String>() : await _signAll(curPaths);

      setState(() {
        _detail = d;
        _refImages = refUrls;
        _serverSubmittedUrls = submittedUrls;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  // ===== 사진 추가(로컬만 유지) =====
  Future<void> _addPhotos() async {
    try {
      final imgs = await _picker.pickMultiImage(imageQuality: 90);
      if (imgs == null || imgs.isEmpty) return;
      setState(() => _localPicks.addAll(imgs));
    } catch (e) {
      _showSnack('사진 선택 실패: $e');
    }
  }

  // ===== 제출: 로컬 선택분을 스토리지 업로드 → 서버 제출 =====
  Future<void> _submitImages() async {
    if (_localPicks.isEmpty || _submitting) return;

    try {
      setState(() => _submitting = true);

      // 1) 진행중 시도 있으면 그대로, 없으면 새 시도 생성(pending)
      final attempt = await _api.menteeStartOrContinue(setId: widget.setId);
      final attemptId = '${attempt?['attempt_id'] ?? ''}';
      if (attemptId.isEmpty) throw Exception('attempt 생성 실패');

      // 2) 스토리지 업로드 → 객체 키 배열
      final storage = StorageService();
      final keys = <String>[];
      for (final x in _localPicks) {
        final key = await storage.uploadPracticeAttemptImageFile(
          file: File(x.path),
          attemptId: attemptId,
        );
        keys.add(key);
      }
      if (keys.isEmpty) throw Exception('이미지 업로드 실패');

      // 3) 제출 RPC
      await _api.menteeSubmitAttempt(attemptId: attemptId, imagePaths: keys);

      // 4) 상태 갱신 & 표시 지속
      _dirty = true; // ← 목록 갱신 필요
      final submittedCopy = List<XFile>.from(_localPicks);
      _localPicks.clear();
      _lastSubmittedLocal = submittedCopy;

      await _load(); // 상태/뱃지(검토 대기) 반영
      _showSnack('제출 완료! 멘토 검토를 기다려 주세요.');
    } catch (e) {
      _showSnack('제출 실패: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openGallery(List<String> images, int index) {
    if (images.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        barrierColor: Colors.black,
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _ImageGalleryScreen(images: images, initialIndex: index),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _openLocalGallery(List<XFile> files, int index) {
    if (files.isEmpty) return;
    final urls = files.map((f) => 'file://${f.path}').toList();
    _openGallery(urls, index);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      print(_error);
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('실습', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
          backgroundColor: Colors.white, elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: UiTokens.title),
            onPressed: () => Navigator.pop(context, _dirty), // 버튼 back도 결과 전달
            tooltip: '뒤로가기',
          ),
        ),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('오류: $_error', style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _load, style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
              child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      );
    }

    final d = _detail ?? const {};
    final title = (d['set_title'] as String?) ?? '실습';
    final instructions = (d['set_instructions'] as String?) ?? '';
    final statusLabel = SupabaseService.instance.practiceStatusLabel(d['current_status'] as String?);
    final grade = (d['current_grade'] as String?) ?? '';
    final feedback = (d['current_feedback'] as String?) ?? '';
    final attemptNo = (d['current_attempt_no'] as num?)?.toInt();

    // 제출 이미지 섹션 우선순위: 로컬 선택 > 방금 제출본(로컬 복사) > 서버 제출 URL
    final localForView = _localPicks.isNotEmpty ? _localPicks : _lastSubmittedLocal;
    final showLocal = localForView.isNotEmpty;
    final showServer = !showLocal && _serverSubmittedUrls.isNotEmpty;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _dirty); // 제스처 back에도 결과 전달
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: UiTokens.title),
            onPressed: () => Navigator.pop(context, _dirty), // 버튼 back도 결과 전달
            tooltip: '뒤로가기',
          ),
        ),

        // 하단 버튼만 부분 로딩
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _addPhotos,
                    icon: const Icon(Icons.add_photo_alternate_rounded, color: UiTokens.title),
                    label: const Text('사진 추가', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: UiTokens.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: (_localPicks.isEmpty || _submitting) ? null : _submitImages,
                    style: FilledButton.styleFrom(
                      backgroundColor: UiTokens.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _submitting
                        ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('이미지 제출', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),

        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            if (instructions.trim().isNotEmpty) _InstructionsBoxGreen(text: instructions),
            if (instructions.trim().isNotEmpty) const SizedBox(height: 12),

            _StatusCard(
              statusLabel: statusLabel,
              attemptNo: attemptNo,
              grade: grade,
              feedback: feedback,
            ),

            const SizedBox(height: 16),
            const _SectionTitle('예시 이미지'),
            const SizedBox(height: 8),
            _ImagesSection(
              images: _refImages,
              emptyText: '예시 이미지가 없습니다.',
              onTapImage: (i) => _openGallery(_refImages, i),
            ),

            const SizedBox(height: 16),
            const _SectionTitle('제출 이미지'),
            const SizedBox(height: 8),

            // 제출/업로드 구역만 부분 로딩 오버레이
            Stack(
              children: [
                if (showLocal)
                  _LocalImagesGrid(
                    files: localForView,
                    onRemove: _submitting && _localPicks.isNotEmpty
                        ? null
                        : (i) {
                      if (_localPicks.isNotEmpty) {
                        setState(() => _localPicks.removeAt(i));
                      }
                    },
                    onTap: (i) => _openLocalGallery(localForView, i),
                  )
                else
                  _ImagesSection(
                    images: _serverSubmittedUrls,
                    emptyText: '제출된 이미지가 없습니다.',
                    onTapImage: (i) => _openGallery(_serverSubmittedUrls, i),
                  ),

                if (_submitting)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withOpacity(0.35),
                      child: const Center(
                        child: SizedBox(
                          width: 28, height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== UI 조각 =====

class _SectionTitle extends StatelessWidget {
  final String text; const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(
        color: UiTokens.title, fontSize: 16, fontWeight: FontWeight.w800));
  }
}

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

class _StatusCard extends StatelessWidget {
  final String statusLabel;
  final int? attemptNo;
  final String grade;       // 'high'|'mid'|'low' or ''
  final String feedback;

  const _StatusCard({
    required this.statusLabel,
    required this.attemptNo,
    required this.grade,
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final showGrade = statusLabel == '검토 완료';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment_outlined, color: UiTokens.actionIcon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  attemptNo == null ? '현재 상태' : '현재 상태 • ${attemptNo}회차',
                  style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                _StatusBadge(statusLabel: statusLabel),
              ]),
            ),
          ],
        ),
        if (showGrade) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Text('등급: ', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
            _RatingBadge(grade: grade),
          ]),
          if (feedback.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Text(
                feedback,
                style: TextStyle(color: UiTokens.title.withOpacity(0.85), fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String statusLabel;
  const _StatusBadge({required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    late Color bg, bd, fg; late IconData icon;
    switch (statusLabel) {
      case '검토 대기': bg = const Color(0xFFFFF7ED); bd = const Color(0xFFFCCFB3); fg = const Color(0xFFEA580C); icon = Icons.upload_rounded; break;
      case '검토 중':   bg = const Color(0xFFFFF7ED); bd = const Color(0xFFFCCFB3); fg = const Color(0xFFEA580C); icon = Icons.hourglass_bottom_rounded; break;
      case '검토 완료': bg = const Color(0xFFECFDF5); bd = const Color(0xFFB7F3DB); fg = const Color(0xFF059669); icon = Icons.verified_rounded; break;
      default:         bg = const Color(0xFFEFF6FF); bd = const Color(0xFFDBEAFE); fg = const Color(0xFF2563EB); icon = Icons.edit_note_rounded; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, border: Border.all(color: bd), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: fg), const SizedBox(width: 6),
        Text(statusLabel, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final String grade; // 'high'|'mid'|'low'
  const _RatingBadge({required this.grade});

  @override
  Widget build(BuildContext context) {
    late Color bg, border, fg; late String label; late IconData icon;
    switch (grade) {
      case 'high': bg = const Color(0xFFECFDF5); border = const Color(0xFFB7F3DB); fg = const Color(0xFF059669); label = '상'; icon = Icons.trending_up_rounded; break;
      case 'mid':  bg = const Color(0xFFF1F5F9); border = const Color(0xFFE2E8F0); fg = const Color(0xFF64748B); label = '중'; icon = Icons.horizontal_rule_rounded; break;
      default:     bg = const Color(0xFFFFFBEB); border = const Color(0xFFFEF3C7); fg = const Color(0xFFB45309); label = '하'; icon = Icons.trending_down_rounded; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg), const SizedBox(width: 4),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    );
  }
}

class _ImagesSection extends StatelessWidget {
  final List<String> images;
  final String emptyText;
  final void Function(int index)? onTapImage;
  const _ImagesSection({required this.images, required this.emptyText, this.onTapImage});

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
          child: Text(emptyText, style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700)),
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
        final tag = 'img_s_$i';
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

/// 로컬(또는 방금 제출한 로컬) 이미지 미리보기
class _LocalImagesGrid extends StatelessWidget {
  final List<XFile> files;
  final void Function(int index)? onRemove;
  final void Function(int index)? onTap; // 전체보기
  const _LocalImagesGrid({required this.files, this.onRemove, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('추가한 사진이 없습니다.',
              style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6,
      ),
      itemBuilder: (_, i) {
        final f = files[i];
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GestureDetector(
                  onTap: () => onTap?.call(i),
                  child: Image.file(File(f.path), fit: BoxFit.cover),
                ),
              ),
            ),
            if (onRemove != null) // 직전 제출본 표시는 삭제 버튼 숨김
              Positioned(
                top: 4, right: 4,
                child: GestureDetector(
                  onTap: () => onRemove?.call(i),
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 전체화면 이미지 갤러리(서명 URL 또는 file:// 모두 지원)
class _ImageGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _ImageGalleryScreen({required this.images, required this.initialIndex});

  @override
  State<_ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<_ImageGalleryScreen> {
  late final PageController _pc;
  late int _idx;
  late final TransformationController _tc;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex.clamp(0, max(0, widget.images.length - 1));
    _pc = PageController(initialPage: _idx);
    _tc = TransformationController();
  }

  @override
  void dispose() {
    _pc.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final m = _tc.value;
    final zoomed = m.getMaxScaleOnAxis() > 1.01;
    _tc.value = zoomed ? Matrix4.identity() : Matrix4.identity()..scale(2.5);
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
            onPageChanged: (i) => setState(() => _idx = i),
            itemCount: imgs.length,
            itemBuilder: (_, i) {
              final url = imgs[i];
              final tag = 'img_s_$i';
              final isFile = url.startsWith('file://');
              final widgetImage = isFile
                  ? Image.file(File(url.replaceFirst('file://', '')), fit: BoxFit.contain)
                  : Image.network(url, fit: BoxFit.contain);

              return Center(
                child: Hero(
                  tag: tag,
                  child: GestureDetector(
                    onDoubleTap: _toggleZoom,
                    child: InteractiveViewer(
                      transformationController: _tc,
                      minScale: 1.0, maxScale: 6.0,
                      child: widgetImage,
                    ),
                  ),
                ),
              );
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
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_idx + 1} / ${imgs.length}',
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
