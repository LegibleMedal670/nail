import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/widgets/DiscardConfirmSheet.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Services/StorageService.dart'; // ⬅️ 추가: StorageService 사용
// import 'package:supabase_flutter/supabase_flutter.dart'; // ⬅️ 삭제: 직접 스토리지 접근 안함

/// 저장 결과(서버 저장 후 최종 값 반환)
class PracticeCreateResult {
  final String id; // insert 후 반환
  final String code;
  final String title;
  final String instructions;
  final List<String> referenceImages; // 저장된 "객체 키" 리스트
  final bool active;

  const PracticeCreateResult({
    required this.id,
    required this.code,
    required this.title,
    required this.instructions,
    required this.referenceImages,
    required this.active,
  });
}

/// 내부 이미지 편집 모델
class _EditImage {
  final String id; // re-order key
  Uint8List? bytes; // 갤러리에서 고른 로컬 썸네일/원본 (미리보기 및 업로드용)
  String? url; // 과거 호환용(현 UI에선 사용 안 함)
  _EditImage({required this.id, this.bytes, this.url});
}

class PracticeCreatePage extends StatefulWidget {
  /// 요구사항 #2: 코드 자동 채움 — 상위 화면에서 계산해서 전달
  final String? suggestedCode;

  const PracticeCreatePage({super.key, this.suggestedCode});

  @override
  State<PracticeCreatePage> createState() => _PracticeCreatePageState();
}

class _PracticeCreatePageState extends State<PracticeCreatePage> {
  // ── 입력 컨트롤
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtl =
  TextEditingController(text: widget.suggestedCode ?? _suggestCode());
  late final TextEditingController _titleCtl = TextEditingController();
  late final TextEditingController _instructionsCtl = TextEditingController(
    text: '요구사항을 입력해주세요.',
  );

  // ── 상태
  bool _active = true;
  bool _dirty = false;
  bool _saving = false;

  final List<_EditImage> _images = [];
  final _picker = ImagePicker();

  // ── 유틸
  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  /// 요구사항 #2 보조: 상위에서 못 넘겨준 경우에만 fallback
  String _suggestCode() {
    // 예: PS-1A7 (fallback 용도)
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    final r = Random();
    final a = letters[r.nextInt(letters.length)];
    final b = letters[r.nextInt(letters.length)];
    final n = r.nextInt(9);
    return 'PS-$a$b$n';
  }

  // ===== 지시문 모달 =====
  Future<void> _editInstructionsSheet() async {
    final tempCtl = TextEditingController(text: _instructionsCtl.text);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _unfocus,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              minChildSize: 0.5,
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
                        const Text(
                          '지시문 편집',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: UiTokens.title,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TextField(
                            controller: tempCtl,
                            autofocus: true,
                            maxLines: null,
                            scrollController: controller,
                            keyboardType: TextInputType.multiline,
                            decoration: _inputDeco('지시문을 입력하세요'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(sheetCtx).pop(),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('닫기'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  _instructionsCtl.text = tempCtl.text.trim();
                                  _dirty = true;
                                });
                                Navigator.of(sheetCtx).pop();
                              },
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('저장',
                                  style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _editImagesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        // 로컬 temp 리스트로 조작 후 완료 시 반영
        final temp = _images
            .map((e) => _EditImage(id: e.id, bytes: e.bytes, url: e.url))
            .toList();

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
              if (i >= 0 && i < temp.length) {
                setInner(() => temp.removeAt(i));
              }
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
              onTap: _unfocus,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 200),
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
                          // ── Header
                          const SizedBox(height: 8),
                          _sheetGrabber(),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Text(
                                  '참고 이미지',
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

                          // ── Toolbar (갤러리만)
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
                                      Text(
                                        '정렬',
                                        style: TextStyle(
                                          color: UiTokens.actionIcon,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── List (Reorderable)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: temp.isEmpty
                                  ? _EmptyImagesHintGalleryOnly(onAddFromGallery: addFromGallery)
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
                                        // Thumb with delete button
                                        Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: SizedBox(
                                                  width: 84,
                                                  height: 84,
                                                  child: isLocal
                                                      ? Image.memory(it.bytes!, fit: BoxFit.cover)
                                                      : Image.network(
                                                    it.url!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) =>
                                                    const ColoredBox(color: Colors.black12),
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
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFFF3E9),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: const Text(
                                                    'LOCAL',
                                                    style: TextStyle(
                                                      color: Color(0xFFB25E00),
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  '로컬 이미지(저장 시 업로드)',
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
                                            child: const Icon(Icons.drag_handle_rounded,
                                                color: UiTokens.actionIcon),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // ── Bottom actions (갤러리만)
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
                                    setState(() {
                                      _images..clear()..addAll(temp);
                                      _dirty = true;
                                    });
                                    Navigator.of(sheetCtx).pop();
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

  // 비어있는 상태용 힌트 (갤러리만)
  Widget _EmptyImagesHintGalleryOnly({required VoidCallback onAddFromGallery}) {
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

  // ===== 저장(업로드 -> RPC upsert) =====
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    // 요구사항 #1: 공용 다이얼로그 사용
    return await showDiscardChangesDialog(
      context,
      title: '변경사항을 저장하지 않고 나갈까요?',
      message: '저장하지 않은 변경사항이 사라집니다.',
      stayText: '계속 작성',
      leaveText: '나가기',
      barrierDismissible: true,
      isDanger: false,
      icon: Icons.exit_to_app_rounded,
    );
  }

  Future<void> _save() async {
    _unfocus();
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final code = _codeCtl.text.trim();
      final title = _titleCtl.text.trim();
      final instructions = _instructionsCtl.text.trim();

      // 0) (권장) 관리자 세션-키 링크 보장
      try {
        await SupabaseService.instance.ensureAdminSessionLinked();
      } catch (_) {
        // 이미 링크되어 있거나 상위에서 처리 중이면 무시 가능
      }

      // 1) 이미지 업로드 (로컬 bytes만) — StorageService 사용, DB에는 "키" 저장
      final storageSvc = StorageService();
      final List<String> finalRefs = [];
      int idx = 0;

      for (final img in _images) {
        // URL 기반 항목은 현 UI에서 생성되지 않지만, 혹시 남아있다면 스킵
        if (img.bytes == null) continue;

        final fileName =
            'ref_${DateTime.now().millisecondsSinceEpoch}_${idx++}.jpg';
        final key = await storageSvc.uploadPracticeImageBytes(
          bytes: img.bytes!,
          code: code,             // practice_sets/<code>/refs/<filename>
          filename: fileName,
          upsert: true,
        );
        finalRefs.add(key);        // ← 공개 URL 대신 "객체 키" 저장
      }

      // 2) RPC upsert (DB는 항상 RPC로)
      final saved = await SupabaseService.instance.adminUpsertPracticeSet(
        code: code,
        title: title,
        instructions: instructions.isEmpty ? null : instructions,
        referenceImages: finalRefs, // ← 키 목록 전달
        active: _active,
      );

      // 3) 결과 파싱(서버가 반환한 최신 값 기준)
      final String id = (saved['id'] ?? '').toString();
      final String retCode = (saved['code'] ?? code).toString();
      final String retTitle = (saved['title'] ?? title).toString();
      final String retInstr = (saved['instructions'] ?? instructions).toString();
      final List<String> retRefs = (() {
        final v = saved['reference_images'];
        if (v is List) return v.map((e) => e.toString()).toList();
        return finalRefs;
      })();
      final bool retActive =
      (saved['active'] is bool) ? saved['active'] as bool : _active;

      if (!mounted) return;
      Navigator.pop(
        context,
        PracticeCreateResult(
          id: id,
          code: retCode,
          title: retTitle,
          instructions: retInstr,
          referenceImages: retRefs, // ← 객체 키 리스트
          active: retActive,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('실습 세트가 생성되었습니다')),
      );
    } catch (e) {
      print(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===== 뷰 =====
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) Navigator.pop(context);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _unfocus,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: UiTokens.title),
              onPressed: () async {
                if (await _confirmDiscard() && mounted) Navigator.pop(context);
              },
            ),
            title: const Text('실습 세트 추가',
                style:
                TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
            actions: [
              TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('저장',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 기본 정보
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('기본 정보'),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _codeCtl,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => _markDirty(),
                          onTapOutside: (_) => _unfocus(),
                          decoration: _inputDeco('코드'),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '코드를 입력하세요' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleCtl,
                          onChanged: (_) => _markDirty(),
                          onTapOutside: (_) => _unfocus(),
                          decoration: _inputDeco('제목'),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          value: _active,
                          onChanged: (v) => setState(() {
                            _active = v;
                            _dirty = true;
                          }),
                          activeColor: UiTokens.primaryBlue,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('활성화',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 지시문
                  _SectionCard(
                    onEdit: _editInstructionsSheet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('지시문'),
                        const SizedBox(height: 8),
                        Text(
                          _instructionsCtl.text.isEmpty
                              ? '지시문이 없습니다.'
                              : _instructionsCtl.text,
                          maxLines: 4,
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
                        const _SectionTitle('참고 이미지'),
                        const SizedBox(height: 8),
                        if (_images.isEmpty)
                          Text('등록된 이미지가 없습니다.',
                              style: TextStyle(
                                  color: UiTokens.title.withOpacity(0.6),
                                  fontWeight: FontWeight.w700))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _images.map((m) {
                              final w = 84.0;
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: w,
                                  height: w,
                                  child: m.bytes != null
                                      ? Image.memory(m.bytes!, fit: BoxFit.cover)
                                      : Image.network(
                                    m.url!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                    const ColoredBox(color: Colors.black12),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 저장 CTA
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: UiTokens.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('저장',
                          style: TextStyle(fontWeight: FontWeight.w800)),
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

  // ===== 공통 스타일 유틸 =====
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
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

/// 상세 톤 맞춘 카드
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
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: UiTokens.actionIcon),
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: UiTokens.title,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
