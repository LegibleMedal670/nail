// lib/Pages/Manager/page/CurriculumCreatePage.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nail/Services/StorageService.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Common/model/ExamModel.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Manager/page/ExamEditPage.dart';
import 'package:nail/Pages/Manager/widgets/DiscardConfirmSheet.dart';
import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 저장 결과 (필요 시 확장 가능)
class CurriculumCreateResult {
  final CurriculumItem item;
  final List<String> goals;
  final List<_EditMaterial> materials;
  final String? videoUrl; // 업로드된 비디오 경로/URL

  const CurriculumCreateResult({
    required this.item,
    required this.goals,
    required this.materials,
    this.videoUrl,
  });
}

/// 간단 자료 모델(이 페이지 전용)
class _EditMaterial {
  String name;
  IconData icon;
  String? url;
  _EditMaterial({
    required this.name,
    this.icon = Icons.insert_drive_file_outlined,
    this.url,
  });
}

class CurriculumCreatePage extends StatefulWidget {
  final int suggestedWeek;
  const CurriculumCreatePage({super.key, this.suggestedWeek = 1});

  @override
  State<CurriculumCreatePage> createState() => _CurriculumCreatePageState();
}

class _CurriculumCreatePageState extends State<CurriculumCreatePage> {
  // ── 기본 정보 입력값
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtl = TextEditingController();
  late final TextEditingController _weekCtl =
  TextEditingController(text: widget.suggestedWeek.toString());

  // ── 섹션 상태(상세 페이지와 동일 구조)
  String _summary = '핵심 개념 이해, 실습 체크리스트 숙지';
  bool _requiresExam = false;
  String? _videoUrl;
  final List<_EditMaterial> _materials = [];

  bool _dirty = false;
  bool _saving = false;

  // 로컬 선택 대기 중 영상/썸네일 (저장 시 업로드)
  File? _pendingLocalVideoFile;
  Uint8List? _pendingThumbBytes;
  int _pendingThumbRev = 0;

  // 시험 편집 결과(저장 시 업로드)
  ExamEditResult? _pendingExam;
  int _examPassScore = 60; // (선택) 화면 표시용


// 갤러리에서 선택한 파일을 반영(썸네일 즉시 생성)
  Future<void> _setPendingVideo(File file) async {
    final Uint8List? thumb = await VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 640,
      quality: 80,
      timeMs: 3000,
    );
    if (!mounted) return;
    setState(() {
      _pendingLocalVideoFile = file;
      _pendingThumbBytes = thumb;  // UI에서 즉시 사용할 수 있음(원한다면)
      _videoUrl = null;            // 원격 연결은 비워두고 저장 시 업로드
      _dirty = true;
      _pendingThumbRev++;
    });
  }

// 선택 취소/삭제 시 즉시 초기화
  void _clearPendingVideo() {
    setState(() {
      _pendingLocalVideoFile = null;
      _pendingThumbBytes = null;
      _videoUrl = null;
      _dirty = true;
      _pendingThumbRev++;
    });
  }


  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  // ====== 모달 편집기들 ======
  Future<void> _editVideoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      isScrollControlled: false,
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
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sheetGrabber(),
                    const SizedBox(height: 8),
                    const Text(
                      '영상 관리',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: UiTokens.title,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.video_library_outlined),
                      title: Text(_videoUrl == null ? '영상 업로드' : '영상 변경'),
                      subtitle: Text('영상을 선택합니다'),
                      // 기존: setState로 'uploaded://demo_video.mp4' 설정하던 부분 전체 교체
                      onTap: () async {
                        try {
                          final pf = await SupabaseService.instance.pickOneFile(); // 갤러리에서 "동영상만" 선택됨
                          if (pf?.path == null) return;
                          await _setPendingVideo(File(pf!.path!));                 // ★ 즉시 썸네일 생성/반영(필드에 보관)
                          if (mounted) Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('영상이 선택되었습니다. 저장 시 업로드됩니다.')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('영상 선택 실패: $e')),
                          );
                        }
                      },

                    ),
                    if (_videoUrl != null || _pendingLocalVideoFile != null)
                      ListTile(
                        leading:
                        const Icon(Icons.delete_outline, color: Colors.red),
                        title: const Text('영상 삭제'),
                        subtitle: const Text('현재 연결된 영상을 제거합니다'),
                        onTap: () {
                          _clearPendingVideo(); // ★ 즉시 반영(로컬/원격 연결 초기화)
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('영상이 삭제되었습니다')),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editGoalsSheet() async {
    final goals = _splitGoals(_summary);
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
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (_, controller) {
                return StatefulBuilder(
                  builder: (context, setInner) {
                    void addGoal() => setInner(() => goals.add(''));
                    void removeGoal(int i) {
                      if (i >= 0 && i < goals.length) {
                        setInner(() => goals.removeAt(i));
                      }
                    }

                    return SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          children: [
                            _sheetGrabber(),
                            const SizedBox(height: 8),
                            const Text(
                              '학습 목표 편집',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: UiTokens.title,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.separated(
                                keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                                controller: controller,
                                itemCount: goals.length,
                                separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final ctl =
                                  TextEditingController(text: goals[i]);
                                  return Row(
                                    children: [
                                      const Icon(Icons.flag_outlined,
                                          color: UiTokens.actionIcon, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: ctl,
                                          onChanged: (v) => goals[i] = v,
                                          onSubmitted: (_) => _unfocus(),
                                          scrollPadding: const EdgeInsets.only(
                                              bottom: 120),
                                          decoration: _inputDeco('목표 내용'),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        tooltip: '삭제',
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () => removeGoal(i),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: addGoal,
                                  icon: const Icon(Icons.add),
                                  label: const Text('목표 추가'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      _summary = goals
                                          .map((e) => e.trim())
                                          .where((e) => e.isNotEmpty)
                                          .join(', ');
                                      _dirty = true;
                                    });
                                    Navigator.pop(sheetCtx);
                                  },
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('저장',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _editExamSheet() async {
    bool temp = _requiresExam;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _unfocus,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: StatefulBuilder(
              builder: (context, setInner) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sheetGrabber(),
                      Row(
                        children: [
                          const Text(
                            '시험 설정',
                            style: TextStyle(
                              color: UiTokens.title,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: temp ? const Color(0xFFEFF6FF) : const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: temp ? const Color(0xFFBFDBFE) : const Color(0xFFE6ECF3),
                              ),
                            ),
                            child: Text(
                              temp ? '사용 중' : '미사용',
                              style: TextStyle(
                                color: temp ? const Color(0xFF2563EB) : UiTokens.title.withOpacity(0.6),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile.adaptive(
                        activeColor: UiTokens.primaryBlue,
                        contentPadding: EdgeInsets.zero,
                        value: temp,
                        onChanged: (v) => setInner(() => temp = v),
                        title: const Text('이 과정에 시험 포함', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),

                      const Divider(height: 20),

                      if (temp) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE6ECF3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.check_circle_outline, size: 18, color: UiTokens.primaryBlue),
                                  SizedBox(width: 8),
                                  Text(
                                    '통과 기준: 60점 / 100점',
                                    style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  Navigator.pop(sheetCtx);

                                  // ✅ 모달의 context가 아니라 State의 루트 context 사용
                                  final result = await Navigator.push<ExamEditResult>(
                                    this.context,
                                    MaterialPageRoute(
                                      builder: (_) => const ExamEditPage(
                                        initialQuestions: [],
                                        initialPassScore: 60,
                                      ),
                                    ),
                                  );

                                  if (!mounted) return;
                                  if (result != null) {
                                    setState(() {
                                      _pendingExam = result;
                                      _examPassScore = result.passScore;
                                      _requiresExam = result.questions.isNotEmpty;
                                      _dirty = true;
                                    });
                                    // ✅ 루트 context로 스낵바
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '시험 구성 완료: 문항 ${result.questions.length}개 · 통과 ${result.passScore}점',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.assignment, size: 18),
                                label: const Text('편집하기', style: TextStyle(fontWeight: FontWeight.w600)),
                                style: FilledButton.styleFrom(
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: const Size(0, 0),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 22, color: UiTokens.actionIcon),
                              const SizedBox(width: 8),
                              Text(
                                _requiresExam
                                    ? '이 과정에는 시험이 있습니다.\n통과 기준: ${_examPassScore}점 / 100점'
                                    : '이 과정에는 시험이 없습니다.',
                                style: const TextStyle(
                                  color: UiTokens.title,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('닫기'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                _requiresExam = temp;
                                _dirty = true;
                              });
                              Navigator.pop(sheetCtx);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: UiTokens.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('저장'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Future<void> _editMaterialsSheet() async {
  //   // 로컬 temp 복사
  //   final temp = _materials
  //       .map((e) => _EditMaterial(name: e.name, icon: e.icon, url: e.url))
  //       .toList();
  //
  //   await showModalBottomSheet<void>(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.white,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  //     ),
  //     builder: (sheetCtx) {
  //       const double kActionBarHeight = 52;
  //       const double kActionBarPaddingV = 16;
  //       final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
  //
  //       return GestureDetector(
  //         behavior: HitTestBehavior.opaque,
  //         onTap: _unfocus,
  //         child: AnimatedPadding(
  //           duration: const Duration(milliseconds: 200),
  //           curve: Curves.easeOut,
  //           padding: EdgeInsets.only(bottom: bottomInset),
  //           child: DraggableScrollableSheet(
  //             expand: false,
  //             initialChildSize: 0.6,
  //             minChildSize: 0.4,
  //             maxChildSize: 0.9,
  //             builder: (_, controller) {
  //               return StatefulBuilder(
  //                 builder: (context, setInner) {
  //                   void addItem() => setInner(() => temp.add(_EditMaterial(name: '새 자료')));
  //                   void removeAt(int i) {
  //                     if (i >= 0 && i < temp.length) {
  //                       setInner(() => temp.removeAt(i));
  //                     }
  //                   }
  //
  //                   return SafeArea(
  //                     top: false,
  //                     child: Column(
  //                       children: [
  //                         Padding(
  //                           padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
  //                           child: Column(
  //                             children: [
  //                               _sheetGrabber(),
  //                               const SizedBox(height: 8),
  //                               const Text(
  //                                 '관련 자료 편집',
  //                                 style: TextStyle(
  //                                   fontSize: 18,
  //                                   fontWeight: FontWeight.w800,
  //                                   color: UiTokens.title,
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                         Expanded(
  //                           child: ListView.separated(
  //                             controller: controller,
  //                             padding: const EdgeInsets.fromLTRB(
  //                               16, 0, 16, kActionBarHeight + kActionBarPaddingV + 12,
  //                             ),
  //                             itemCount: temp.length,
  //                             separatorBuilder: (_, __) =>
  //                             const SizedBox(height: 8),
  //                             itemBuilder: (_, i) {
  //                               final nameCtl =
  //                               TextEditingController(text: temp[i].name);
  //                               return Row(
  //                                 children: [
  //                                   Expanded(
  //                                     child: TextField(
  //                                       controller: nameCtl,
  //                                       onChanged: (v) => temp[i].name = v,
  //                                       onSubmitted: (_) => _unfocus(),
  //                                       onTapOutside: (_) => _unfocus(),
  //                                       decoration: InputDecoration(
  //                                         labelText: '자료 이름',
  //                                         filled: true,
  //                                         fillColor: const Color(0xFFF7F9FC),
  //                                         prefixIcon: Icon(temp[i].icon,
  //                                             color: UiTokens.primaryBlue),
  //                                         contentPadding:
  //                                         const EdgeInsets.symmetric(
  //                                           horizontal: 12,
  //                                           vertical: 14,
  //                                         ),
  //                                         border: OutlineInputBorder(
  //                                           borderRadius:
  //                                           BorderRadius.circular(14),
  //                                           borderSide: const BorderSide(
  //                                               color: Color(0xFFE6ECF3)),
  //                                         ),
  //                                         enabledBorder: OutlineInputBorder(
  //                                           borderRadius:
  //                                           BorderRadius.circular(14),
  //                                           borderSide: const BorderSide(
  //                                               color: Color(0xFFE6ECF3)),
  //                                         ),
  //                                         focusedBorder: OutlineInputBorder(
  //                                           borderRadius:
  //                                           BorderRadius.circular(14),
  //                                           borderSide: const BorderSide(
  //                                             color: UiTokens.primaryBlue,
  //                                             width: 2,
  //                                           ),
  //                                         ),
  //                                       ),
  //                                     ),
  //                                   ),
  //                                   IconButton(
  //                                     tooltip: '삭제',
  //                                     icon: const Icon(Icons.close_rounded),
  //                                     onPressed: () => removeAt(i),
  //                                   ),
  //                                 ],
  //                               );
  //                             },
  //                           ),
  //                         ),
  //                         SafeArea(
  //                           top: false,
  //                           child: Padding(
  //                             padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
  //                             child: SizedBox(
  //                               height: kActionBarHeight,
  //                               child: Row(
  //                                 children: [
  //                                   OutlinedButton.icon(
  //                                     onPressed: addItem, // ← setInner 사용
  //                                     icon: const Icon(Icons.add),
  //                                     label: const Text('자료 추가'),
  //                                     style: OutlinedButton.styleFrom(
  //                                       minimumSize: const Size(0, 0),
  //                                       padding: const EdgeInsets.symmetric(
  //                                           horizontal: 12, vertical: 12),
  //                                       shape: RoundedRectangleBorder(
  //                                         borderRadius:
  //                                         BorderRadius.circular(10),
  //                                       ),
  //                                     ),
  //                                   ),
  //                                   const Spacer(),
  //                                   FilledButton(
  //                                     onPressed: () {
  //                                       _unfocus();
  //                                       setState(() {
  //                                         _materials
  //                                           ..clear()
  //                                           ..addAll(temp);
  //                                         _dirty = true;
  //                                       });
  //                                       Navigator.pop(sheetCtx);
  //                                     },
  //                                     style: FilledButton.styleFrom(
  //                                       minimumSize: const Size(0, 0),
  //                                       padding: const EdgeInsets.symmetric(
  //                                           horizontal: 18, vertical: 12),
  //                                       shape: RoundedRectangleBorder(
  //                                         borderRadius:
  //                                         BorderRadius.circular(10),
  //                                       ),
  //                                     ),
  //                                     child: const Text('저장',
  //                                         style: TextStyle(
  //                                             fontWeight: FontWeight.w800)),
  //                                   ),
  //                                 ],
  //                               ),
  //                             ),
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   );
  //                 },
  //               );
  //             },
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  // ===== 저장 & 종료 =====
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return await showDiscardChangesDialog(
      context,
      title: '작성을 종료할까요?',
      message: '저장하지 않은 내용은 사라집니다.',
      stayText: '계속 작성',
      leaveText: '나가기',
      barrierDismissible: true,
    );
  }

  Future<void> _save() async {
    _unfocus();
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final int week = int.parse(_weekCtl.text.trim());
      final List<String> goals = _splitGoals(_summary)
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // 1) 먼저 비디오 없이 커리큘럼 생성(코드/버전 확보)
      final String code = _generateId(week);
      final created = await SupabaseService.instance.createCurriculumViaRpc(
        code: code,
        week: week,
        title: _titleCtl.text.trim(),
        summary: goals.join(', '),
        goals: goals,
        resources: [],
        videoUrl: null, // ← 최초 생성 시 비워둠
      );

      // 2) 로컬 대기 중 영상이 있다면 업로드 → 메타 반영
      if (_pendingLocalVideoFile != null) {
        final storage = StorageService();

        // (a) 동영상 업로드
        final String newVideoPath = await storage.uploadVideo(
          file: _pendingLocalVideoFile!,
          moduleCode: created.id,
          version: created.version ?? 1,
          week: created.week,
        );

        // (b) 썸네일 업로드(있으면 사용, 없으면 생성)
        Uint8List? thumbBytes = _pendingThumbBytes;
        thumbBytes ??= await VideoThumbnail.thumbnailData(
          video: _pendingLocalVideoFile!.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 640,
          quality: 80,
          timeMs: 3000,
        );

        String? newThumbPath;
        if (thumbBytes != null) {
          newThumbPath = await storage.uploadThumbnailBytes(
            bytes: thumbBytes,
            moduleCode: created.id,
            version: created.version ?? 1,
            week: created.week,
            filename: 'thumb.jpg',
            upsert: true,
          );
        }

        // (c) 비디오/썸네일 경로를 RPC로 반영
        await SupabaseService.instance.saveEditsViaRpc(
          code: created.id,
          goals: goals,
          resources: const [],
          videoPathOrNull: newVideoPath,
          thumbPathOrNull: newThumbPath ?? '',
        );
      } else if ((_videoUrl ?? '').isNotEmpty) {
        // (옵션) 외부/데모 URL을 입력한 경우 그대로 반영
        await SupabaseService.instance.saveEditsViaRpc(
          code: created.id,
          goals: goals,
          resources: const [],
          videoPathOrNull: _videoUrl,
          thumbPathOrNull: null,
        );
      }

      // 2-시험) 시험 세트 업서트 (편집해둔 내용이 있으면 저장)
      if (_pendingExam != null && _pendingExam!.questions.isNotEmpty) {
        await SupabaseService.instance.adminUpsertExamSet(
          moduleCode: created.id,
          passScore: _pendingExam!.passScore,
          questions: _pendingExam!.questions
              .map((q) => q.toJson()) // ✅ List<ExamQuestion> → List<Map<String,dynamic>>
              .toList(),
        );
      }

      // 3) 갱신된 항목 재조회(비디오/썸네일/시험 여부 반영본)
      final updated = await SupabaseService.instance.getCurriculumItemByCode(created.id) ?? created;

      // 4) 로컬 스토어 반영 및 종료
      final provider = context.read<CurriculumProvider>();
      provider.upsertLocal(updated);
      // ignore: unawaited_futures
      provider.refresh(force: true);

      if (!mounted) return;
      Navigator.pop(
        context,
        CurriculumCreateResult(
          item: updated,        // durationMinutes는 모델 0 유지
          goals: goals,
          materials: _materials,
          videoUrl: updated.videoUrl,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('과정이 생성되었습니다')),
      );

      // (선택) 로컬 대기 상태 정리
      setState(() {
        _pendingLocalVideoFile = null;
        _pendingThumbBytes = null;
        _pendingExam = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _generateId(int week) =>
      'w${week.toString().padLeft(2, '0')}_${DateTime.now().millisecondsSinceEpoch}';

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
            title: const Text('교육과정 추가',
                style: TextStyle(
                    color: UiTokens.title, fontWeight: FontWeight.w700)),
            actions: [
              TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
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
                  // 기본 정보 (소요 시간 필드 제거됨)
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('기본 정보'),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _titleCtl,
                          onChanged: (_) => _markDirty(),
                          onTapOutside: (_) => _unfocus(),
                          decoration: _inputDeco('강의 제목'),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _weekCtl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _markDirty(),
                          onTapOutside: (_) => _unfocus(),
                          decoration: _inputDeco('주차 (숫자)'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return '1 이상의 숫자';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 영상
                  _SectionCard(
                    onEdit: _editVideoSheet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('영상'),
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [
                                UiTokens.primaryBlue.withOpacity(0.15),
                                const Color(0xFFCBD5E1).withOpacity(0.18),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: (_pendingThumbBytes != null)
                                ? Container(
                              color: Colors.black, // 레터박스 배경
                              child: Center(
                                child: Image.memory(
                                  _pendingThumbBytes!,
                                  key: ValueKey(_pendingThumbRev),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain, // ✅ 비율 보존 (레터박스)
                                ),
                              ),
                            )
                                : Center(
                              child: Icon(
                                _videoUrl == null
                                    ? Icons.videocam_off_rounded
                                    : Icons.videocam_rounded,
                                size: 48,
                                color: UiTokens.actionIcon,
                              ),
                            ),
                          ),

                        ),

                        if (_videoUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('임시 경로: $_videoUrl',
                                style: TextStyle(
                                    color: UiTokens.title.withOpacity(0.55),
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 학습 목표
                  _SectionCard(
                    onEdit: _editGoalsSheet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('학습 목표'),
                        const SizedBox(height: 8),
                        ..._splitGoals(_summary).map(_bullet),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 시험 정보
                  _SectionCard(
                    onEdit: _editExamSheet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('시험 정보'),
                        const SizedBox(height: 8),
                        Text(
                          (_pendingExam != null && _pendingExam!.questions.isNotEmpty) || _requiresExam
                              ? '이 과정에는 시험이 있습니다.\n통과 기준: ${_examPassScore}점 / 100점'
                              : '이 과정에는 시험이 없습니다.',
                          style: const TextStyle(
                            color: UiTokens.title,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 관련 자료
                  // _SectionCard(
                  //   onEdit: _editMaterialsSheet,
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       const _SectionTitle('관련 자료'),
                  //       const SizedBox(height: 8),
                  //       if (_materials.isEmpty)
                  //         Text('등록된 자료가 없습니다.',
                  //             style: TextStyle(
                  //                 color: UiTokens.title.withOpacity(0.6),
                  //                 fontWeight: FontWeight.w700))
                  //       else
                  //         Wrap(
                  //           spacing: 8,
                  //           runSpacing: 8,
                  //           children: _materials
                  //               .map((m) => _fileChip(m.icon, m.name))
                  //               .toList(),
                  //         ),
                  //     ],
                  //   ),
                  // ),

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
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
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

  // ===== 유틸 =====
  static List<String> _splitGoals(String s) {
    final parts = s
        .split(RegExp(r'[,\u3001]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty
        ? ['핵심 개념 이해', '실습 체크리스트 숙지']
        : parts;
  }

  // String _guessType(String? url) {
  //   final u = (url ?? '').toLowerCase();
  //   if (u.endsWith('.pdf')) return 'pdf';
  //   if (RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(u)) return 'image';
  //   if (RegExp(r'\.(mp4|mov|m4v|webm)$').hasMatch(u)) return 'video';
  //   if (u.contains('docs.google.com/spreadsheets')) return 'sheet';
  //   if (u.contains('docs.google.com/document')) return 'doc';
  //   return 'web';
  // }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style:
              TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: UiTokens.title.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
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

  Widget _fileChip(IconData icon, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F2FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: UiTokens.primaryBlue),
        const SizedBox(width: 6),
        Text(name,
            style: const TextStyle(
                color: UiTokens.primaryBlue, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// 상세 페이지에서 쓰던 카드 컴포넌트 그대로 복붙
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
    return Text(text,
        style: const TextStyle(
            color: UiTokens.title, fontSize: 14, fontWeight: FontWeight.w800));
  }
}
