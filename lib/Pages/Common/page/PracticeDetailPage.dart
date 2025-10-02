// lib/Pages/Manager/page/PracticeDetailPage.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/widgets/SectionTitle.dart';
import 'package:nail/Pages/Manager/widgets/DiscardConfirmSheet.dart';
import 'package:nail/Services/StorageService.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 상세 페이지에 전달할 데이터(서버 모델을 그대로 써도 무방)
class PracticeSetViewData {
  final String id;
  final String code;
  final String title;
  final String? instructions;
  final List<String> referenceImages; // Storage 객체 키 또는 URL(레거시)
  final bool active;
  final String createdAt;
  final String updatedAt;

  const PracticeSetViewData({
    required this.id,
    required this.code,
    required this.title,
    required this.instructions,
    required this.referenceImages,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// 부모로 돌려줄 결과 (제목/지시문/이미지와 삭제여부 모두 포함)
class PracticeDetailResult {
  final bool saved;                   // 이 세션에서 저장이 있었는가
  final bool deleted;                 // 삭제되었는가
  final String? title;                // 저장 이후 제목
  final String? instructions;         // 저장 이후 지시문
  final List<String> referenceImages; // 저장 이후 최종 이미지 리스트

  const PracticeDetailResult({
    this.saved = false,
    this.deleted = false,
    this.title,
    this.instructions,
    this.referenceImages = const [],
  });
}

/// 내부 편집용 이미지 모델(서버키 or 로컬바이트 보관)
class _EditImage {
  final String id;          // Reorder key
  Uint8List? bytes;         // 신규 로컬 바이트(업로드 전 미리보기)
  String? keyOrUrl;         // 기존 키/URL (업로드 X)

  _EditImage({required this.id, this.bytes, this.keyOrUrl});
}

class PracticeDetailPage extends StatefulWidget {
  final PracticeSetViewData data;

  const PracticeDetailPage({
    super.key,
    required this.data,
  });

  @override
  State<PracticeDetailPage> createState() => _PracticeDetailPageState();
}

class _PracticeDetailPageState extends State<PracticeDetailPage> {
  // ── 편집 상태 ────────────────────────────────────────────────────────────────
  late String _title = widget.data.title;               // ✅ 제목 편집
  late String _instructions = widget.data.instructions ?? '';
  late List<_EditImage> _images = [
    for (final s in widget.data.referenceImages)
      _EditImage(id: UniqueKey().toString(), keyOrUrl: s),
  ];

  PracticeDetailResult? _lastSaved; // 마지막 저장 결과
  bool _everSaved = false;          // 세션 중 한 번이라도 저장했는지

  bool _dirty = false;
  bool _saving = false;

  // ── 썸네일 / 스토리지 / 픽커 ────────────────────────────────────────────────
  final StorageService _storage = StorageService();
  final ImagePicker _picker = ImagePicker();
  final Map<String, Future<String?>> _signedMap = {}; // 키→서명URL Future 캐시

  // ── 생명주기 ────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _signedMap.clear();
    for (final e in _images) { e.bytes = null; }
    super.dispose();
  }

  // ── Pop 가드 ────────────────────────────────────────────────────────────────
  Future<void> _handleBack() async {
    if (_saving) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 중에는 나갈 수 없어요. 잠시만 기다려주세요.')),
      );
      return;
    }

    // 변경 없음: 이전 저장결과(or null)로 반환
    if (!_dirty) {
      if (!mounted) return;
      Navigator.pop(
        context,
        _lastSaved ?? const PracticeDetailResult(saved: false, referenceImages: []),
      );
      return;
    }

    // 변경사항 있음: 버릴지 확인
    final leave = await showDiscardChangesDialog(
      context,
      title: '변경사항을 저장하지 않고 나갈까요?',
      message: '저장하지 않은 변경사항이 사라집니다.',
      stayText: '계속 보기',
      leaveText: '나가기',
      barrierDismissible: true,
    );

    if (leave == true && mounted) {
      Navigator.pop(
        context,
        _everSaved
            ? (_lastSaved ?? const PracticeDetailResult(saved: true))
            : const PracticeDetailResult(saved: false),
      );
    }
  }

  // ── 제목 편집 바텀시트 ──────────────────────────────────────────────────────
  Future<void> _editTitle() async {
    final ctl = TextEditingController(text: _title);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, controller) {
              return SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      _sheetGrabber(),
                      const SizedBox(height: 8),
                      const Text('제목 수정',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: UiTokens.title)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctl,
                        maxLines: 1,
                        decoration: _inputDeco('제목을 입력하세요'),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('닫기'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              final v = ctl.text.trim();
                              if (!mounted) return;
                              if (v.isNotEmpty) {
                                setState(() {
                                  _title = v;
                                  _dirty = true;
                                });
                              }
                              Navigator.pop(ctx);
                            },
                            child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── 삭제 (RPC 사용) ─────────────────────────────────────────────────────────
  Future<void> _delete() async {
    if (_saving) return;

    final sure = await showDiscardChangesDialog(
      context,
      title: '정말 삭제할까요?',
      message: '이 실습과 연결된 참고 이미지를 포함해 되돌릴 수 없어요.',
      stayText: '취소',
      leaveText: '삭제',
      isDanger: true,
      barrierDismissible: true,
    );
    if (!sure || !mounted) return;

    setState(() => _saving = true);
    try {
      // 관리 세션 보장 + RPC 호출
      try { await SupabaseService.instance.ensureAdminSessionLinked(); } catch (_) {}
      await SupabaseService.instance.adminDeletePracticeSet(code: widget.data.code);

      if (!mounted) return;
      Navigator.pop(context, const PracticeDetailResult(deleted: true));
    } catch (e) {
      print(e);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  // ── 썸네일 URL 해석(키→서명URL, 이미 URL이면 통과) ───────────────────────────
  Future<String?> _resolveDisplayUrl(String raw) async {
    final s = raw.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s; // 이미 URL
    try {
      final key = _storage.normalizeObjectPath(s);
      final url = await _storage.getOrCreateSignedUrlPractice(key);
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _futureFor(String raw) =>
      _signedMap.putIfAbsent(raw, () => _resolveDisplayUrl(raw));

  Widget _thumbSkeleton() => Container(
    color: const Color(0xFFF1F5F9),
    child: const Center(
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );

  Widget _thumbError() => Container(
    color: const Color(0xFFF1F5F9),
    child: const Center(
      child: Icon(Icons.broken_image_outlined, color: UiTokens.actionIcon),
    ),
  );

  // ── 이미지 편집 시트(갤러리 추가/삭제/정렬) ──────────────────────────────────
  Future<void> _editImagesSheet() async {
    // 딥카피
    final temp = _images
        .map((e) => _EditImage(id: e.id, bytes: e.bytes, keyOrUrl: e.keyOrUrl))
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setInner) {
            Future<void> addFromGallery() async {
              try {
                final XFile? xf = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 2048,
                );
                if (xf == null) return;

                final bytes = await xf.readAsBytes();
                if (!sheetCtx.mounted) return;

                setInner(() {
                  temp.add(_EditImage(id: UniqueKey().toString(), bytes: bytes));
                });
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('이미지 선택 실패: $e')),
                );
              }
            }

            void removeAt(int i) {
              if (i >= 0 && i < temp.length) setInner(() => temp.removeAt(i));
            }

            void onReorder(int oldIndex, int newIndex) {
              setInner(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = temp.removeAt(oldIndex);
                temp.insert(newIndex, item);
              });
            }

            final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.88,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (_, controller) {
                    return SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          // Header
                          const SizedBox(height: 8),
                          _sheetGrabber(),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Text(
                                  '참고 이미지 편집',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: UiTokens.title,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF3FF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${temp.length}개',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: UiTokens.primaryBlue,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: '닫기',
                                  onPressed: () => Navigator.of(sheetCtx).pop(),
                                  icon: const Icon(Icons.close_rounded, color: UiTokens.title),
                                ),
                              ],
                            ),
                          ),

                          // Toolbar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: addFromGallery,
                                  icon: const Icon(Icons.photo_library_outlined),
                                  label: const Text('갤러리'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const Spacer(),
                                Tooltip(
                                  message: '길게 눌러 순서 변경',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.drag_indicator_rounded, size: 18, color: UiTokens.actionIcon),
                                      SizedBox(width: 4),
                                      Text('정렬', style: TextStyle(color: UiTokens.actionIcon, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // List
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: temp.isEmpty
                                  ? _EmptyImagesHint(onAddFromGallery: addFromGallery)
                                  : ReorderableListView.builder(
                                buildDefaultDragHandles: false,
                                proxyDecorator: (child, index, animation) {
                                  return Material(
                                    elevation: 6,
                                    borderRadius: BorderRadius.circular(16),
                                    child: child,
                                  );
                                },
                                itemCount: temp.length,
                                onReorder: onReorder,
                                padding: const EdgeInsets.only(bottom: 8),
                                itemBuilder: (_, i) {
                                  final it = temp[i];
                                  final isLocal = it.bytes != null;

                                  const tileW = 84;
                                  return Container(
                                    key: ValueKey('img-${it.id}'),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE6ECF3)),
                                      boxShadow: const [UiTokens.cardShadow],
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Thumb + delete
                                        Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: SizedBox(
                                                  width: tileW.toDouble(),
                                                  height: tileW.toDouble(),
                                                  child: isLocal
                                                      ? Image.memory(
                                                    it.bytes!,
                                                    fit: BoxFit.cover,
                                                    cacheWidth: tileW * 3,
                                                  )
                                                      : (it.keyOrUrl == null || it.keyOrUrl!.isEmpty)
                                                      ? _thumbError()
                                                      : FutureBuilder<String?>(
                                                    future: _futureFor(it.keyOrUrl!),
                                                    builder: (context, snap) {
                                                      if (snap.connectionState != ConnectionState.done) {
                                                        return _thumbSkeleton();
                                                      }
                                                      final url = snap.data;
                                                      if (url == null || url.isEmpty) return _thumbError();
                                                      return Image.network(
                                                        url,
                                                        fit: BoxFit.cover,
                                                        cacheWidth: tileW * 3,
                                                        errorBuilder: (_, __, ___) => _thumbError(),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                right: 4,
                                                top: 4,
                                                child: InkWell(
                                                  onTap: () => removeAt(i),
                                                  borderRadius: BorderRadius.circular(999),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(999),
                                                      boxShadow: const [UiTokens.cardShadow],
                                                      border: Border.all(color: const Color(0xFFE6ECF3)),
                                                    ),
                                                    padding: const EdgeInsets.all(4),
                                                    child: const Icon(Icons.close_rounded, size: 16),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Meta
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isLocal ? const Color(0xFFFFF3E9) : const Color(0xFFE9F2FF),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Text(
                                                    isLocal ? '로컬' : '서버',
                                                    style: TextStyle(
                                                      color: isLocal ? const Color(0xFFB25E00) : UiTokens.primaryBlue,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  isLocal ? '로컬 이미지(저장 시 업로드)' : (it.keyOrUrl ?? ''),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: UiTokens.title.withOpacity(0.85),
                                                    fontWeight: FontWeight.w700,
                                                    height: 1.25,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Drag handle
                                        ReorderableDragStartListener(
                                          index: i,
                                          child: Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF4F7FB),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFE6ECF3)),
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            child: const Icon(Icons.drag_handle_rounded, color: UiTokens.actionIcon),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // Bottom actions
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: addFromGallery,
                                  icon: const Icon(Icons.add_photo_alternate_outlined),
                                  label: const Text('갤러리 추가'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: () {
                                    if (!mounted) return;
                                    setState(() {
                                      _images = temp;
                                      _dirty = true;
                                      _signedMap.clear(); // 썸네일 캐시 무효화
                                    });
                                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    backgroundColor: UiTokens.primaryBlue,
                                  ),
                                  child: const Text('완료', style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── 저장(업로드→RPC→정리) ───────────────────────────────────────────────────
  Future<void> _save() async {
    if (_saving || !_dirty) return;

    if (!mounted) return;
    setState(() => _saving = true);

    try {
      // (권장) 관리자 세션 키 링크 보장
      try { await SupabaseService.instance.ensureAdminSessionLinked(); } catch (_) {}

      final code = widget.data.code;

      // 1) 신규 로컬 바이트 업로드 → 키 수집
      final List<String> finalKeys = [];
      int idx = 0;

      for (final e in _images) {
        if (e.bytes != null) {
          final fileName = 'ref_${DateTime.now().millisecondsSinceEpoch}_${idx++}.jpg';
          final key = await _storage.uploadPracticeImageBytes(
            bytes: e.bytes!,
            code: code,      // practice_sets/<code>/refs/<filename>
            filename: fileName,
            upsert: true,
          );
          finalKeys.add(key);
        } else if ((e.keyOrUrl ?? '').trim().isNotEmpty) {
          finalKeys.add(e.keyOrUrl!.trim());
        }
      }

      // 2) RPC upsert (제목 + 지시문 + 이미지 키리스트 교체)
      final saved = await SupabaseService.instance.adminUpsertPracticeSet(
        code: code,
        title: _title, // ✅ 제목 포함
        instructions: _instructions.isEmpty ? null : _instructions,
        referenceImages: finalKeys,
        active: widget.data.active,
      );

      // 3) 스토리지 정리(삭제된 기존 키 제거) — 비차단/병렬/타임아웃
      final before = widget.data.referenceImages.map((e) => e.trim()).toSet();
      final after = finalKeys.map((e) => e.trim()).toSet();
      final removed = before.difference(after);
      _cleanupRemovedKeys(code: code, removed: removed);

      // 4) 화면 상태를 서버 최신 기준으로 싱크
      final List<String> retRefs = (() {
        final v = saved['reference_images'];
        if (v is List) return v.map((e) => e.toString()).toList();
        return finalKeys;
      })();

      _everSaved = true;
      _lastSaved = PracticeDetailResult(
        saved: true,
        title: _title,
        instructions: _instructions.isEmpty ? null : _instructions,
        referenceImages: retRefs,
      );

      if (!mounted) return;
      setState(() {
        _images = [for (final s in retRefs) _EditImage(id: UniqueKey().toString(), keyOrUrl: s)];
        _dirty = false;
        _saving = false;
        _signedMap.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('변경사항이 저장되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  // 삭제 정리를 비차단으로 수행(병렬 + 5초 타임아웃, 실패 무시)
  void _cleanupRemovedKeys({required String code, required Set<String> removed}) {
    if (removed.isEmpty) return;

    final futures = <Future<void>>[];
    for (final r in removed) {
      final key = _storage.normalizeObjectPath(r);
      if (key.isEmpty) continue;
      if (!key.startsWith('practice_sets/$code/refs/')) continue; // 안전핀
      futures.add(_storage.deletePracticeObject(key).catchError((_) {}));
      _storage.evictSignedUrl(key);
    }

    if (futures.isEmpty) return;

    unawaited(Future.any([
      Future.wait(futures),
      Future.delayed(const Duration(seconds: 5)),
    ]));
  }

  // ── 뷰 ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: PopScope(
        canPop: false, // 항상 우리가 pop 제어(결과 전달 위해)
        onPopInvoked: (didPop) {
          if (didPop) return;
          _handleBack();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              tooltip: '뒤로가기',
              icon: const Icon(Icons.arrow_back, color: UiTokens.title),
              onPressed: _handleBack,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    _title, // ✅ 로컬 제목 반영
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                _adminChip(),
              ],
            ),
            actions: [
              IconButton(
                tooltip: '제목 수정',
                onPressed: _editTitle,
                icon: const Icon(Icons.edit_outlined, color: UiTokens.actionIcon),
              ),
              IconButton(
                tooltip: '삭제',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, color: UiTokens.actionIcon),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상태 배지
                  _SectionCard(
                    child: Row(
                      children: [
                        _activeBadge(active: data.active),
                        const Spacer(),
                        _tinyBadge('코드 ${data.code}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 지시문
                  _SectionCard(
                    onEdit: () async {
                      final ctl = TextEditingController(text: _instructions);
                      await showModalBottomSheet<void>(
                        context: context,
                        useSafeArea: true,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (ctx) {
                          final inset = MediaQuery.of(ctx).viewInsets.bottom;
                          return Padding(
                            padding: EdgeInsets.only(bottom: inset),
                            child: DraggableScrollableSheet(
                              expand: false,
                              initialChildSize: 0.7,
                              minChildSize: 0.4,
                              maxChildSize: 0.95,
                              builder: (_, controller) {
                                return SafeArea(
                                  top: false,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                    child: Column(
                                      children: [
                                        _sheetGrabber(),
                                        const SizedBox(height: 8),
                                        const Text('지시문 편집',
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: UiTokens.title)),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: ctl,
                                            maxLines: null,
                                            scrollController: controller,
                                            decoration: _inputDeco('지시문을 입력하세요'),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            OutlinedButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('닫기'),
                                            ),
                                            const Spacer(),
                                            FilledButton(
                                              onPressed: () {
                                                if (!mounted) return;
                                                setState(() {
                                                  _instructions = ctl.text.trim();
                                                  _dirty = true;
                                                });
                                                Navigator.pop(ctx);
                                              },
                                              child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w800)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('지시문'),
                        const SizedBox(height: 8),
                        Text(
                          _instructions.isEmpty ? '지시문이 없습니다.' : _instructions,
                          maxLines: 10,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: UiTokens.title.withOpacity(0.9),
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 참고 이미지
                  _SectionCard(
                    onEdit: _editImagesSheet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('참고 이미지'),
                        const SizedBox(height: 14),
                        if (_images.isEmpty)
                          Text(
                            '등록된 이미지가 없습니다.',
                            style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _images.map((m) {
                              const w = 84;
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: w.toDouble(),
                                  height: w.toDouble(),
                                  child: (m.bytes != null)
                                      ? Image.memory(
                                    m.bytes!,
                                    fit: BoxFit.cover,
                                    cacheWidth: w * 3, // Retina 대비 3배
                                  )
                                      : (m.keyOrUrl == null || m.keyOrUrl!.isEmpty)
                                      ? _thumbError()
                                      : FutureBuilder<String?>(
                                    future: _futureFor(m.keyOrUrl!),
                                    builder: (context, snap) {
                                      if (snap.connectionState != ConnectionState.done) {
                                        return _thumbSkeleton();
                                      }
                                      final url = snap.data;
                                      if (url == null || url.isEmpty) return _thumbError();
                                      return Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        cacheWidth: w * 3,
                                        errorBuilder: (_, __, ___) => _thumbError(),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _tinyBadge('이미지 ${_images.length}개'),
                            const Spacer(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 하단 CTA
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: UiTokens.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _saving ? '저장 중...' : (_dirty ? '저장하기' : '변경 없음'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Small UI bits ───────────────────────────────────────────────────────────
  Widget _adminChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFECBA1)),
      ),
      child: const Text(
        '관리자',
        style: TextStyle(color: Color(0xFF9A3412), fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _activeBadge({required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
      ),
      child: Text(
        active ? '활성' : '비활성',
        style: TextStyle(
          color: active ? const Color(0xFF059669) : const Color(0xFFB91C1C),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _tinyBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6ECF3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: UiTokens.title.withOpacity(0.7),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  static Widget _sheetGrabber() => Container(
    width: 44,
    height: 4,
    decoration: BoxDecoration(
      color: const Color(0xFFE6EAF0),
      borderRadius: BorderRadius.circular(3),
    ),
  );

  static InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE6ECF3)),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: UiTokens.primaryBlue, width: 2),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onEdit;

  const _SectionCard({required this.child, this.padding, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [UiTokens.cardShadow],
      ),
      child: child,
    );

    if (onEdit == null) return card;

    return Stack(
      children: [
        card,
        Positioned(
          right: 6,
          top: 0,
          child: IconButton(
            tooltip: '수정',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18, color: UiTokens.actionIcon),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(28, 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFE6ECF3)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyImagesHint extends StatelessWidget {
  final VoidCallback onAddFromGallery;
  const _EmptyImagesHint({required this.onAddFromGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6ECF3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_outlined, color: UiTokens.primaryBlue, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            '참고 이미지를 추가하세요',
            style: TextStyle(
              color: UiTokens.title.withOpacity(0.9),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '갤러리에서 선택해 추가할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: UiTokens.title.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAddFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('갤러리'),
          ),
        ],
      ),
    );
  }
}
