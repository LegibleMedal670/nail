import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/models/curriculum_item.dart';
import 'package:nail/Manager/widgets/DiscardConfirmSheet.dart';

/// 화면 모드
enum CurriculumViewMode { admin, mentee }

/// 멘티 진행/시험 상태(점수는 최고점만 유지)
class CurriculumProgress {
  final double watchedRatio;   // 0.0 ~ 1.0
  final int attempts;          // 시험 시도 수
  final int? bestScore;        // 최고 점수(없으면 null)
  final bool passed;           // 통과 여부

  const CurriculumProgress({
    this.watchedRatio = 0.0,
    this.attempts = 0,
    this.bestScore,
    this.passed = false,
  });
}

class CurriculumDetailResult {
  final bool deleted;
  const CurriculumDetailResult({this.deleted = false});
}

/// 간단 자료 모델(이 페이지 전용)
class _EditMaterial {
  String name;
  IconData icon;
  String? url;
  _EditMaterial({required this.name, this.icon = Icons.insert_drive_file_outlined, this.url});
}

class CurriculumDetailPage extends StatefulWidget {
  final CurriculumItem item;

  /// admin/mentee 모드
  final CurriculumViewMode mode;

  /// 멘티 모드에서만 사용(없으면 0% 진행/미응시로 표시)
  final CurriculumProgress? progress;

  /// 콜백들 (필요 시)
  final VoidCallback? onPlay;                  // 동영상 재생
  final Future<bool> Function()? onDeleteConfirm; // 삭제 전 확인(선택)
  final VoidCallback? onTakeExam;              // (멘티) 시험 보기
  final VoidCallback? onContinueWatch;         // (멘티) 시청/이어보기
  final VoidCallback? onOpenExamEditor;        // (관리자) 시험 정보 수정 페이지로 이동

  const CurriculumDetailPage({
    super.key,
    required this.item,
    this.mode = CurriculumViewMode.admin,
    this.progress,
    this.onPlay,
    this.onDeleteConfirm,
    this.onTakeExam,
    this.onContinueWatch,
    this.onOpenExamEditor,
  });

  @override
  State<CurriculumDetailPage> createState() => _CurriculumDetailPageState();
}

class _CurriculumDetailPageState extends State<CurriculumDetailPage> {
  // === 로컬 편집 상태 (이 페이지에서 즉시 반영) ===
  late CurriculumItem _item = widget.item;
  late String _summary = widget.item.summary;
  late bool _requiresExam = widget.item.requiresExam;

  // 영상은 실제 URL 보관 대신 존재 여부만 데모로 관리
  late String? _videoUrl = widget.item.hasVideo ? 'present://video' : null;

  // 자료(데모 기본 두 개)
  final List<_EditMaterial> _materials = [
    _EditMaterial(name: '위생 체크리스트.pdf', icon: Icons.picture_as_pdf_rounded),
    _EditMaterial(name: '시술 단계 가이드.txt'),
  ];

  bool _dirty = false; // ← 변경사항 발생 시 true
  void _markDirty() => setState(() => _dirty = true);

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  // UI 데모용 시험 문항 수 생성
  Map<String, int> _examCounts(CurriculumItem it) {
    if (!_requiresExam) return {'mcq': 0, 'sa': 0, 'order': 0};
    final base = 4 + (it.week % 3); // 4~6
    return {'mcq': base + 4, 'sa': (base / 2).floor(), 'order': it.week % 2};
  }

  // 학습 목표 파싱/출력
  static List<String> _splitGoals(String s) {
    final parts = s.split(RegExp(r'[,\u3001]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? ['핵심 개념 이해', '실습 체크리스트 숙지', '시험 대비 포인트 정리'] : parts;
  }

  // 뒤로가기 공통 처리
  Future<void> _handleBack() async {
    if (!_dirty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final leave = await showDiscardChangesDialog(
      context,
      title: '변경사항을 저장하지 않고 나갈까요?',
      message: '저장하지 않은 변경사항이 사라집니다.',
      stayText: '계속 보기',
      leaveText: '나가기',
      barrierDismissible: true,
    );
    if (leave && mounted) Navigator.pop(context);
  }

  // ====== 모달 편집기들 ======
  Future<void> _editVideoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                    const Text('영상 관리', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: UiTokens.title)),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.video_library_outlined),
                      title: Text(_videoUrl == null ? '영상 업로드' : '영상 변경'),
                      subtitle: Text(_videoUrl == null ? '서버로 업로드하여 연결합니다' : '기존 영상을 새로운 영상으로 교체합니다'),
                      onTap: () {
                        setState(() {
                          _videoUrl = 'uploaded://demo_video.mp4';
                          _dirty = true; // ← 변경됨
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('영상이 연결(변경)되었습니다 (데모)')));
                      },
                    ),
                    if (_videoUrl != null)
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: Colors.red),
                        title: const Text('영상 삭제'),
                        subtitle: const Text('현재 연결된 영상을 제거합니다'),
                        onTap: () {
                          setState(() {
                            _videoUrl = null;
                            _dirty = true; // ← 변경됨
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('영상이 삭제되었습니다')));
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                    void removeGoal(int i) => setInner(() => goals.removeAt(i));
                    return SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          children: [
                            _sheetGrabber(),
                            const SizedBox(height: 8),
                            const Text('학습 목표 편집', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: UiTokens.title)),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.separated(
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                controller: controller,
                                itemCount: goals.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final ctl = TextEditingController(text: goals[i]);
                                  return Row(
                                    children: [
                                      const Icon(Icons.flag_outlined, color: UiTokens.actionIcon, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: ctl,
                                          onChanged: (v) => goals[i] = v,
                                          onSubmitted: (_) => _unfocus(),
                                          scrollPadding: const EdgeInsets.only(bottom: 120),
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
                                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      _summary = goals.map((e) => e.trim()).where((e) => e.isNotEmpty).join(', ');
                                      _dirty = true; // ← 변경됨
                                    });
                                    Navigator.pop(context);
                                  },
                                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
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
                      // grabber
                      _sheetGrabber(),
                      // 제목 + 상태 뱃지
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6,
                            ),
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

                      // 토글
                      SwitchListTile.adaptive(
                        activeColor: UiTokens.primaryBlue,
                        contentPadding: EdgeInsets.zero,
                        value: temp,
                        onChanged: (v) => setInner(() => temp = v),
                        title: const Text(
                          '이 과정에 시험 포함',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text('필요 시 ON으로 전환하세요.'),
                      ),

                      const Divider(height: 20),

                      // 간단 정보 블럭 (시험 사용 중일 때만)
                      if (temp) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE6ECF3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 통과 기준
                              Row(
                                children: const [
                                  Icon(Icons.check_circle_outline,
                                      size: 18, color: UiTokens.primaryBlue),
                                  SizedBox(width: 8),
                                  Text(
                                    '통과 기준: 60점 / 100점',
                                    style: TextStyle(
                                      color: UiTokens.title,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // 편집 안내 + 이동 버튼
                              FilledButton.icon(
                                onPressed: widget.onOpenExamEditor ??
                                        () {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('시험 편집 페이지로 이동 (데모)')),
                                      );
                                    },
                                icon: const Icon(Icons.tune_rounded, size: 18),
                                label: const Text('편집 열기'),
                                style: FilledButton.styleFrom(
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: const Size(0, 0),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8,16,8,16),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 22, color: UiTokens.actionIcon),
                              const SizedBox(width: 8),
                              Text(
                                '현재 이 과정에는 시험이 없습니다.',
                                style: TextStyle(
                                  color: UiTokens.title.withOpacity(0.7),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // actions
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
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
                                _dirty = true; // 변경됨 표시
                              });
                              Navigator.pop(context);
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


  Future<void> _editMaterialsSheet() async {
    // 복사본으로 편집 후 저장 시 반영
    final temp = _materials
        .map((e) => _EditMaterial(name: e.name, icon: e.icon, url: e.url))
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // ← 키보드 대응
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        const double kActionBarHeight = 52;  // 저장 버튼 행 높이
        const double kActionBarPaddingV = 16; // 위/아래 여백 합 일부
        final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;

        return GestureDetector(
          behavior: HitTestBehavior.opaque, // ← 빈 곳 탭도 인식
          onTap: _unfocus,                  // ← 아무데나 탭하면 포커스 해제
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset), // ← 키보드만큼 올리기
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (_, controller) {
                return SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      // 헤더
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Column(
                          children: [
                            _sheetGrabber(),
                            const SizedBox(height: 8),
                            const Text(
                              '관련 자료 편집',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: UiTokens.title,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 목록
                      Expanded(
                        child: ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            // ← 액션바(버튼 행) 높이 + 여백만큼 바닥 패딩을 줘서 가려지지 않게
                            kActionBarHeight + kActionBarPaddingV + 12,
                          ),
                          itemCount: temp.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final ctl = TextEditingController(text: temp[i].name);
                            return TextField(
                              controller: ctl,
                              onChanged: (v) => temp[i].name = v,
                              onSubmitted: (_) => _unfocus(),
                              onTapOutside: (_) => _unfocus(),
                              scrollPadding: const EdgeInsets.only(bottom: 180), // 키보드 위로 밀기
                              decoration: InputDecoration(
                                labelText: '자료 이름',
                                filled: true,
                                fillColor: const Color(0xFFF7F9FC),
                                prefixIcon: Icon(
                                  temp[i].icon,
                                  color: UiTokens.primaryBlue,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: '삭제',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    setState(() => temp.removeAt(i));
                                  },
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE6ECF3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE6ECF3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: UiTokens.primaryBlue,
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // 액션 바(항상 시트 하단에 고정)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: SizedBox(
                            height: kActionBarHeight,
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() => temp.add(_EditMaterial(name: '새 자료')));
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('자료 추가'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 0),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: () {
                                    _unfocus();
                                    setState(() {
                                      _materials
                                        ..clear()
                                        ..addAll(temp);
                                      _dirty = true; // ← 변경됨
                                    });
                                    Navigator.pop(sheetCtx);
                                  },
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 0),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ),
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
  }

  @override
  Widget build(BuildContext context) {
    final counts = _examCounts(_item);
    final pr = widget.progress ?? const CurriculumProgress();
    final isAdmin = widget.mode == CurriculumViewMode.admin;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _unfocus, // 화면 아무데나 탭 → 키보드 닫기
      child: PopScope( // ← 시스템/스와이프/뒤로 모두 가로채기
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          await _handleBack();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton( // ← BackButton 대신 명시제어
              icon: const Icon(Icons.arrow_back, color: UiTokens.title),
              onPressed: _handleBack,
              tooltip: '뒤로가기',
            ),
            title: Text(
              'W${_item.week}. ${_item.title}',
              style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700),
            ),
            actions: [
              if (isAdmin)
                IconButton(
                  tooltip: '삭제',
                  icon: const Icon(Icons.delete_outline, color: UiTokens.actionIcon),
                  onPressed: () async {
                    bool ok = false;
                    if (widget.onDeleteConfirm != null) {
                      ok = await widget.onDeleteConfirm!();
                    } else {
                      ok = (await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('과정 삭제'),
                          content: Text('‘${_item.title}’을(를) 삭제할까요? 되돌릴 수 없어요.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                          ],
                        ),
                      )) == true;
                    }
                    if (ok && context.mounted) {
                      Navigator.of(context).pop(const CurriculumDetailResult(deleted: true));
                    }
                  },
                ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== 영상 섹션 (+진행바/이어보기) =====
                  _SectionCard(
                    padding: EdgeInsets.zero,
                    onEdit: isAdmin ? _editVideoSheet : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: (_videoUrl != null) ? (widget.onPlay) : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      UiTokens.primaryBlue.withOpacity(0.18),
                                      const Color(0xFFCBD5E1).withOpacity(0.25),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    _videoUrl == null ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                                    size: 72,
                                    color: UiTokens.actionIcon,
                                  ),
                                ),
                              ),
                              if (_videoUrl != null)
                                Center(
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [UiTokens.cardShadow],
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, size: 36, color: UiTokens.title),
                                  ),
                                ),
                              if (widget.mode == CurriculumViewMode.mentee && pr.watchedRatio > 0)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: LinearProgressIndicator(
                                    minHeight: 4,
                                    value: pr.watchedRatio.clamp(0.0, 1.0),
                                    backgroundColor: Colors.white.withOpacity(0.35),
                                    valueColor: const AlwaysStoppedAnimation(UiTokens.primaryBlue),
                                  ),
                                ),
                              if (widget.mode == CurriculumViewMode.mentee && pr.watchedRatio > 0 && pr.watchedRatio < 1)
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [UiTokens.cardShadow],
                                      border: Border.all(color: UiTokens.cardBorder),
                                    ),
                                    child: Text(
                                      '이어보기 ${(pr.watchedRatio * 100).round()}%',
                                      style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ===== 학습 목표 =====
                  _SectionCard(
                    onEdit: isAdmin ? _editGoalsSheet : null,
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

                  // ===== 시험 정보 (왼쪽 텍스트 · 오른쪽 버튼) =====
                  _SectionCard(
                    onEdit: isAdmin ? _editExamSheet : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('시험 정보'),
                        const SizedBox(height: 8),
                        if (!_requiresExam)
                          Text(
                            '이 과정에는 시험이 없습니다.',
                            style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700),
                          )
                        else ...[
                          _examRow('객관식', counts['mcq']!),
                          const SizedBox(height: 6),
                          _examRow('주관식', counts['sa']!),
                          const SizedBox(height: 6),
                          _examRow('순서 맞추기', counts['order']!),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 왼쪽: 통과 기준 + (멘티면) 시도/최고/통과
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.check_circle_outline, size: 18, color: UiTokens.primaryBlue),
                                        SizedBox(width: 8),
                                        Text('통과 기준: 60점 / 100점',
                                            style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (widget.mode == CurriculumViewMode.mentee)
                                      Row(
                                        children: [
                                          Icon(
                                            (widget.progress?.passed ?? false) ? Icons.verified_rounded : Icons.shield_moon_outlined,
                                            size: 18,
                                            color: (widget.progress?.passed ?? false)
                                                ? Colors.green.shade600
                                                : UiTokens.actionIcon,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '시도 ${widget.progress?.attempts ?? 0}회'
                                                '${(widget.progress?.bestScore != null) ? ' / 최고 ${widget.progress!.bestScore}점' : ''}',
                                            style: TextStyle(color: UiTokens.title.withOpacity(0.75), fontWeight: FontWeight.w700),
                                          ),
                                          if (widget.progress?.passed == true) ...[
                                            const SizedBox(width: 6),
                                            const Text('통과',
                                                style: TextStyle(color: UiTokens.primaryBlue, fontWeight: FontWeight.w800)),
                                          ],
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              if (widget.mode == CurriculumViewMode.mentee)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: FilledButton.tonal(
                                    onPressed: widget.onTakeExam,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                    ),
                                    child: const Text('시험보기', style: TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ===== 관련 자료 =====
                  _SectionCard(
                    onEdit: isAdmin ? _editMaterialsSheet : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('관련 자료'),
                        const SizedBox(height: 8),
                        if (_materials.isEmpty)
                          Text('등록된 자료가 없습니다.',
                              style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _materials.map((m) => _fileChip(m.icon, m.name)).toList(),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== 하단 CTA (멘티/관리자 공용) =====
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _ctaOnPressed(pr),
                      style: FilledButton.styleFrom(
                        backgroundColor: UiTokens.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_ctaLabel(pr), style: const TextStyle(fontWeight: FontWeight.w800)),
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

  // ===== CTA 라벨/동작 =====
  String _ctaLabel(CurriculumProgress pr) {
    if (widget.mode == CurriculumViewMode.admin) return '수정하기';
    if (pr.watchedRatio <= 0) return '시청하기';
    if (pr.watchedRatio < 1) return '이어보기';
    return '다시보기';
  }

  VoidCallback? _ctaOnPressed(CurriculumProgress pr) {
    if (widget.mode == CurriculumViewMode.admin) {
      // 전체 수정 진입 대신 첫 섹션(학습 목표) 편집 모달 열기 등으로 활용 가능
      return _editGoalsSheet;
    }
    return widget.onContinueWatch ?? widget.onPlay;
  }

  // ===== 작은 UI 유틸 =====
  static Iterable<String> _bulletsFrom(String s) => _splitGoals(s);

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: UiTokens.title.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _examRow(String label, int n) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('$n문항', style: TextStyle(color: UiTokens.title.withOpacity(0.85), fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _fileChip(IconData icon, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFE9F2FF), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: UiTokens.primaryBlue),
        const SizedBox(width: 6),
        Text(name, style: const TextStyle(color: UiTokens.primaryBlue, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  static Widget _sheetGrabber() => Container(
    width: 44,
    height: 4,
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: const Color(0xFFE6EAF0), borderRadius: BorderRadius.circular(3)),
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

/// 공통 섹션 카드 + (관리자일 때) 우상단 연필 버튼
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
        boxShadow: [UiTokens.cardShadow],
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: UiTokens.title, fontSize: 14, fontWeight: FontWeight.w800));
  }
}
