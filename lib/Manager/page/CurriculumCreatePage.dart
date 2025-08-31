import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/models/curriculum_item.dart';
import 'package:nail/Manager/widgets/DiscardConfirmSheet.dart';

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
  late final TextEditingController _durationCtl =
  TextEditingController(text: '60');

  // ── 섹션 상태(상세 페이지와 동일 구조)
  String _summary = '핵심 개념 이해, 실습 체크리스트 숙지';
  bool _requiresExam = false;
  String? _videoUrl;
  final List<_EditMaterial> _materials = [];

  bool _dirty = false;
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
                      subtitle: Text(_videoUrl == null
                          ? '서버로 업로드하여 연결합니다'
                          : '기존 영상을 새로운 영상으로 교체합니다'),
                      onTap: () {
                        // TODO: 파일피커 + Supabase 업로드 연결
                        setState(() {
                          _videoUrl = 'uploaded://demo_video.mp4';
                          _dirty = true;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('영상이 연결(변경)되었습니다 (데모)')),
                        );
                      },
                    ),
                    if (_videoUrl != null)
                      ListTile(
                        leading:
                        const Icon(Icons.delete_outline, color: Colors.red),
                        title: const Text('영상 삭제'),
                        subtitle: const Text('현재 연결된 영상을 제거합니다'),
                        onTap: () {
                          setState(() {
                            _videoUrl = null;
                            _dirty = true;
                          });
                          Navigator.pop(context);
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
                    void removeGoal(int i) => setInner(() => goals.removeAt(i));
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
                                    Navigator.pop(context);
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: StatefulBuilder(
                  builder: (context, setInner) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _sheetGrabber(),
                        const SizedBox(height: 8),
                        const Text('시험 설정',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: UiTokens.title)),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: temp,
                          onChanged: (v) => setInner(() => temp = v),
                          title: const Text('시험 사용'),
                          subtitle:
                          const Text('사용하지 않으면 해당 과정에는 시험이 없습니다'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '통과 기준: 60점 (데모)\n문항 구성은 별도 페이지에서 설정하세요.',
                                style: TextStyle(
                                  color:
                                  UiTokens.title.withOpacity(0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () {
                                // TODO: 시험 편집 페이지로 이동 연결
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('시험 편집 페이지로 이동 (데모)')),
                                );
                              },
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                minimumSize: const Size(0, 0),
                                tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('시험 정보 수정',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _requiresExam = temp;
                                _dirty = true;
                              });
                              Navigator.pop(context);
                            },
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('저장',
                                style:
                                TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editMaterialsSheet() async {
    final temp = _materials
        .map((e) => _EditMaterial(name: e.name, icon: e.icon, url: e.url))
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        const double kActionBarHeight = 52;
        const double kActionBarPaddingV = 16;
        final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _unfocus,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
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
                      Expanded(
                        child: ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, kActionBarHeight + kActionBarPaddingV + 12,
                          ),
                          itemCount: temp.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final ctl =
                            TextEditingController(text: temp[i].name);
                            return TextField(
                              controller: ctl,
                              onChanged: (v) => temp[i].name = v,
                              onSubmitted: (_) => _unfocus(),
                              onTapOutside: (_) => _unfocus(),
                              scrollPadding:
                              const EdgeInsets.only(bottom: 180),
                              decoration: InputDecoration(
                                labelText: '자료 이름',
                                filled: true,
                                fillColor: const Color(0xFFF7F9FC),
                                prefixIcon: Icon(temp[i].icon,
                                    color: UiTokens.primaryBlue),
                                suffixIcon: IconButton(
                                  tooltip: '삭제',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => setState(() => temp.removeAt(i)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE6ECF3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE6ECF3)),
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
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: SizedBox(
                            height: kActionBarHeight,
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => setState(() =>
                                      temp.add(_EditMaterial(name: '새 자료'))),
                                  icon: const Icon(Icons.add),
                                  label: const Text('자료 추가'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 0),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
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
                                      _dirty = true;
                                    });
                                    Navigator.pop(sheetCtx);
                                  },
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 0),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('저장',
                                      style:
                                      TextStyle(fontWeight: FontWeight.w800)),
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

  // ===== 저장 & 종료 =====
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return await showDiscardChangesDialog(
      context,
      title: '작성을 종료할까요?',
      message: '저장하지 않은 내용은 사라집니다.',
      stayText: '계속 작성',
      leaveText: '나가기',
      barrierDismissible: true, // 필요 시 false로 잠금 가능
    );
  }

  void _save() {
    _unfocus();
    if (!_formKey.currentState!.validate()) return;

    final week = int.parse(_weekCtl.text.trim());
    final duration = int.parse(_durationCtl.text.trim());
    final goals =
    _splitGoals(_summary).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final item = CurriculumItem(
      id: _generateId(week),
      week: week,
      title: _titleCtl.text.trim(),
      summary: goals.join(', '),
      durationMinutes: duration,
      hasVideo: _videoUrl != null,
      requiresExam: _requiresExam,
    );

    Navigator.pop(
      context,
      CurriculumCreateResult(
        item: item,
        goals: goals,
        materials: _materials,
        videoUrl: _videoUrl,
      ),
    );
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
                onPressed: _save,
                child: const Text('저장',
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
                          controller: _titleCtl,
                          onChanged: (_) => _markDirty(),
                          onTapOutside: (_) => _unfocus(),
                          decoration: _inputDeco('강의 제목'),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
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
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _durationCtl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _markDirty(),
                                onTapOutside: (_) => _unfocus(),
                                decoration: _inputDeco('소요 시간(분)'),
                                validator: (v) {
                                  final n = int.tryParse(v ?? '');
                                  if (n == null || n <= 0) return '1 이상의 숫자';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 영상 (우상단 연필 → 업로드/삭제)
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
                          child: Center(
                            child: Icon(
                              _videoUrl == null
                                  ? Icons.videocam_off_rounded
                                  : Icons.videocam_rounded,
                              size: 48,
                              color: UiTokens.actionIcon,
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

                  // 학습 목표 (연필 → 편집 모달)
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

                  // 시험 설정 (연필 → 토글 & 이동 버튼)
                  _SectionCard(
                    onEdit: _editExamSheet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('시험 정보'),
                        const SizedBox(height: 8),
                        Text(
                          _requiresExam
                              ? '이 과정에는 시험이 있습니다.\n통과 기준: 60점 (데모)'
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

                  // 관련 자료 (연필 → 편집 모달)
                  _SectionCard(
                    onEdit: _editMaterialsSheet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('관련 자료'),
                        const SizedBox(height: 8),
                        if (_materials.isEmpty)
                          Text('등록된 자료가 없습니다.',
                              style: TextStyle(
                                  color:
                                  UiTokens.title.withOpacity(0.6),
                                  fontWeight: FontWeight.w700))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _materials
                                .map((m) => _fileChip(m.icon, m.name))
                                .toList(),
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
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: UiTokens.primaryBlue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('저장',
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
    return Text(text, style: const TextStyle(color: UiTokens.title, fontSize: 14, fontWeight: FontWeight.w800));
  }
}