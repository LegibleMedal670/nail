// lib/Pages/Manager/page/CurriculumDetailPage.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/model/CurriculumProgress.dart';
import 'package:nail/Pages/Common/model/ExamModel.dart';
import 'package:nail/Pages/Common/page/VideoPlayerPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/widgets/SectionTitle.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Manager/page/ExamEditPage.dart';
import 'package:nail/Pages/Manager/page/ManagerExamResultPage.dart';
import 'package:nail/Pages/Manager/widgets/DiscardConfirmSheet.dart';
import 'package:nail/Pages/Mentee/page/ExamPage.dart';
import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Services/CourseProgressService.dart';
import 'package:nail/Services/ExamService.dart';
import 'package:nail/Services/StorageService.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Services/VideoProgressService.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 화면 모드: 관리자 편집 / 관리자 검토(멘티 진행 확인) / 멘티 수강
enum CurriculumViewMode { adminEdit, adminReview, mentee }


class CurriculumDetailResult {
  final bool deleted;
  const CurriculumDetailResult({this.deleted = false});
}


/// 페이지 내부 전용 자료 모델
class _EditMaterial {
  String name;
  IconData icon;
  String? url;          // 원격 URL(있을 때만 열기 가능)
  bool localPending;    // 파일피커로 추가만 된 상태(업로드 X)

  _EditMaterial({
    required this.name,
    this.icon = Icons.menu_book_outlined,
    this.url,
    this.localPending = false,
  });
}

class CurriculumDetailPage extends StatefulWidget {
  final CurriculumItem item;

  /// adminEdit / adminReview / mentee
  final CurriculumViewMode mode;

  /// 멘티 진행 데이터(mentee, adminReview에서 사용)
  final CurriculumProgress? progress;

  /// (adminReview 전용) 검토 대상 멘티명 표시용
  final String? menteeName;

  /// 관리자 인증 키(접속 코드 기반) — 없으면 SupabaseService.instance.adminKey 사용
  final String? adminKey;

  /// 콜백들

  // 관리자 편집/검토
  final Future<bool> Function()? onDeleteConfirm; // (adminEdit) 삭제 전 확인
  final VoidCallback? onOpenExamEditor;           // (adminEdit) 시험 편집 화면
  final VoidCallback? onOpenExamReport;           // (adminReview) 시험 결과/리포트 열기

  final String? menteeUserId;

  const CurriculumDetailPage({
    super.key,
    required this.item,
    this.mode = CurriculumViewMode.adminEdit,
    this.progress,
    this.menteeName,
    this.menteeUserId,
    this.adminKey,
    this.onDeleteConfirm,
    this.onOpenExamEditor,
    this.onOpenExamReport,
  });

  @override
  State<CurriculumDetailPage> createState() => _CurriculumDetailPageState();
}

class _CurriculumDetailPageState extends State<CurriculumDetailPage> {
  // === 로컬 상태 ===
  late CurriculumItem _item = widget.item;

  // 학습 목표는 item.goals 사용
  late List<String> _goals = List<String>.from(widget.item.goals);

  // 시험 필요 여부(파생값이지만 UI 토글용)
  late bool _requiresExam = widget.item.requiresExam;

  // 영상 URL(저장 시 서버 반영은 아직 안 함 – UI용)
  late String? _videoUrl = widget.item.videoUrl;

  // 자료(서버 resources → 변환). 서버에서 온 것은 localPending=false
  List<_EditMaterial> _materials = [];

  // ✅ 시험 세트 변경 임시 저장 (에디터에서 나온 결과만 담아둠)
  ExamEditResult? _pendingExam;

  // 시험 메타 캐시 (질문 리스트/개수/패스스코어)
  List<ExamQuestion>? _examQuestionsCache;     // 서버에서 받아온 질문들
  Map<String, int>? _examCountsCache;          // {'mcq':n, 'sa':n, 'order':n}

  // ▼ 추가: 시험/영상 후 화면 내 진행도 즉시 반영용
  CurriculumProgress? _prOverride;

// ▼ 추가: 이 페이지에서 진행도가 바뀌었는지 상위 화면에 알리기 위한 플래그
  bool _progressChanged = false;


  int? _examPassScore;                         // 그대로 재사용

  bool _dirty = false; // 변경사항 여부
  bool _saving = false;

  void _markDirty() => setState(() => _dirty = true);
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  bool get _isAdminEdit   => widget.mode == CurriculumViewMode.adminEdit;
  bool get _isAdminReview => widget.mode == CurriculumViewMode.adminReview;
  bool get _isMentee      => widget.mode == CurriculumViewMode.mentee;

  // ▼ 수정: 서버에서 재조회한 값(_prOverride)이 있으면 그것을 우선 사용
  CurriculumProgress get _pr => _prOverride ?? widget.progress ?? const CurriculumProgress();


  File? _pendingVideoFile;         // ★ 저장 대기(미업로드) 로컬 파일
  bool _videoRemovalRequested = false; // ★ 저장 시 비디오 제거 의도

  // 상태 필드(클래스 안)
  final StorageService _storage = StorageService();
  Future<String>? _thumbSignedFuture;   // 썸네일 서명 URL Future
  File? _pendingLocalVideoFile;   // 저장 대기 중인 새 영상 파일
  Uint8List? _pendingThumbBytes;  // 저장 전 임시 썸네일(메모리)

// (선택) 미세 강제 리빌드용
  int _pendingThumbRev = 0;

  // 멘티 진행률(서버에서 직접 조회한 결과)
  VideoProgressResult? _vp;

  /// 화면에서 사용할 시청 비율:
  /// - 우선 서버에서 가져온 값(_vp)
  /// - 없으면 부모에서 내려준 데모용 CurriculumProgress
  double get _watchedRatio => _vp?.watchedRatio ?? _pr.watchedRatio;

  Future<void> _loadMenteeProgress() async {
    if (!_isMentee) return;
    try {
      final loginKey = context.read<UserProvider>().current?.loginKey ?? '';
      if (loginKey.isEmpty) return;

      print('로그인키 $loginKey');

      final res = await VideoProgressService.instance.menteeGetProgress(
        loginKey: loginKey,
        moduleCode: _item.id, // == code
      );

      if (!mounted) return;
      setState(() => _vp = res);
    } catch (e) {
      // 실패는 무시(네트워크 일시 이슈 등)
      if (kDebugMode) {
        print('menteeGetProgress error: $e');
      }
    }
  }

  Map<String, int> _countByType(List<ExamQuestion> qs) {
    int mcq = 0, sa = 0, ord = 0;
    for (final q in qs) {
      switch (q.type) {
        case ExamQuestionType.mcq: mcq++; break;
        case ExamQuestionType.shortAnswer: sa++; break;
        case ExamQuestionType.ordering: ord++; break;
      }
    }
    return {'mcq': mcq, 'sa': sa, 'order': ord};
  }



  @override
  void initState() {
    super.initState();
    _hydrateFromItem(widget.item);
    _reloadFromServer();
    _loadExamMeta();

    // ✅ 멘티 모드면 서버에서 진행률 로드(이어보기 퍼센트 반영)
    if (_isMentee) _loadMenteeProgress();
  }


  // 로컬 동영상 파일로부터 임시 썸네일 바이트 생성
  Future<Uint8List?> _generateLocalThumb(String filePath) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: filePath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640, // 리스폰시브/메모리 절약
        quality: 80,
        timeMs: 3000,  // 3초 지점
      ); // plugin 사용법: pub.dev/video_thumbnail
    } catch (_) {
      return null;
    }
  }

// "새 영상 선택" → 임시 썸네일까지 즉시 반영
  Future<void> _setPendingVideo(File file) async {
    final thumb = await _generateLocalThumb(file.path);
    if (!mounted) return;
    setState(() {
      _pendingLocalVideoFile = file;
      _pendingThumbBytes = thumb;      // ★ 즉시 UI에 썸네일 반영
      _videoUrl = null;                // 기존 원격 연결은 끊긴 UI 상태로
      _thumbSignedFuture = null;       // 원격 썸네일 표시 중지
      _dirty = true;
      _pendingThumbRev++;              // 강제 리빌드 용(선택)
    });
  }

// "영상 삭제" → 임시/원격 썸네일 모두 제거(즉시 플레이스홀더)
  void _clearPendingVideo() {
    setState(() {
      _pendingLocalVideoFile = null;
      _pendingThumbBytes = null;
      _videoUrl = null;           // UI상 비디오 없음
      _thumbSignedFuture = null;  // 원격 썸네일 사용 안 함
      _dirty = true;
      _pendingThumbRev++;
    });
  }


  void _hydrateFromItem(CurriculumItem it) {
    _item = it;
    _goals = List<String>.from(it.goals);
    _requiresExam = it.requiresExam;
    _videoUrl = it.videoUrl;

    // ★ 편집 도중 남아있던 임시 상태 초기화(서버 최신 반영 시점)
    _pendingLocalVideoFile = null;
    _pendingThumbBytes = null;

    // 원격 썸네일 Future 준비
    if (it.thumbUrl != null && it.thumbUrl!.isNotEmpty) {
      _thumbSignedFuture = _storage.getOrCreateSignedUrl(it.thumbUrl!);
    } else {
      _thumbSignedFuture = null;
    }

    _materials = it.resources.map((m) {
      final title = (m['title'] ?? m['name'] ?? '').toString();
      final url = (m['url'] ?? '').toString();
      final type = (m['type'] ?? '').toString().toLowerCase();
      return _EditMaterial(
        name: title.isEmpty ? '자료' : title,
        icon: _iconFromType(type, url),
        url: url.isEmpty ? null : url,
        localPending: false,
      );
    }).toList();
  }

  Future<void> _reloadFromServer() async {
    final fresh = await SupabaseService.instance.getCurriculumItemByCode(_item.id);
    if (!mounted || fresh == null) return;
    setState(() {
      if (!_dirty) _hydrateFromItem(fresh);
    });
  }

  Future<void> _loadExamMeta() async {
    try {
      final set = await ExamService.instance.getExamSet(_item.id);
      if (!mounted) return;

      setState(() {
        _examPassScore     = set?.passScore;
        _examQuestionsCache = set?.questions;
        _examCountsCache    = (set?.questions != null)
            ? _countByType(set!.questions)
            : {'mcq': 0, 'sa': 0, 'order': 0};
      });
    } catch (_) {
      // 실패는 조용히 무시(초기엔 0으로 보이고, 시험보기 눌렀을 때도 로드됨)
    }
  }


  Map<String, int> _examCounts(CurriculumItem it) {
    if (!_requiresExam) return {'mcq': 0, 'sa': 0, 'order': 0};

    // ❶ (관리자 편집 중 임시 세트가 있으면 그걸 우선)
    if (_pendingExam != null) {
      // ExamEditResult의 questions 타입이 ExamQuestion과 동일(또는 변환 가능)하다고 가정
      return _countByType(_pendingExam!.questions);
    }

    // ❷ 서버 캐시 있으면 그걸 사용
    if (_examCountsCache != null) return _examCountsCache!;

    // ❸ 아직 로드 전이면 0 표시(초기 렌더), 곧 아래 로더가 채울 것
    return {'mcq': 0, 'sa': 0, 'order': 0};
  }


  Future<void> _openExamResults() async {
    final user = context.read<UserProvider>();
    final adminKey = user.adminKey ?? widget.adminKey;
    final userId = widget.menteeUserId;
    final moduleCode = widget.item.id;

    if ((adminKey ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 인증(adminKey)이 필요합니다. 상단에서 관리자 로그인 먼저 진행하세요.')),
      );
      return;
    }
    if ((userId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('멘티 식별자(user_id)가 없어 결과를 조회할 수 없어요.')),
      );
      return;
    }

    // 1) 시험 세트(문항/통과기준)
    final set = await ExamService.instance.getExamSet(moduleCode);
    if (set == null || set.questions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록된 시험 세트가 없어요.')),
      );
      return;
    }

    // 2) 모든 시도 로드
    final raws = await ExamService.instance.adminGetExamAttempts(
      adminKey: adminKey!,
      moduleCode: moduleCode,
      userId: userId!,
    );

    if (!mounted) return;

    if (raws.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('응시 기록이 없습니다.')),
      );
      return;
    }

    // 3) 화면 모델로 매핑
    final attempts = _mapAttemptsForPage(
      questions: set.questions,
      attemptRows: raws,
    );

    // 4) 페이지로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManagerExamResultPage(
          menteeName: widget.menteeName ?? '멘티',
          curriculumTitle: 'W${_item.week}. ${_item.title}',
          passScore: set.passScore,
          attempts: attempts,
        ),
      ),
    );
  }

  Future<void> _openPlayer() async {
    if (_videoUrl == null || _videoUrl!.isEmpty) return;
    final title = 'W${_item.week}. ${_item.title}';
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          storageObjectPath: _videoUrl!,
          title: title,
          signedUrlTtlSec: 21600, // 6시간
          minTtlBufferSec: 300,   // 만료 5분 전 재발급
          moduleCode: widget.item.id,
        ),
      ),
    );
    if (!mounted) return;
    // ✅ 플레이어에서 보고 돌아오면 진행률 다시 로드
    await _loadMenteeProgress();
  }

  // ===== 매핑 유틸 =====

  List<ExamAttemptResult> _mapAttemptsForPage({
    required List<ExamQuestion> questions,
    required List<RawExamAttempt> attemptRows,
  }) {
    // answers 구조가 Map 또는 List일 수 있으니 안전하게 처리
    Map<String, dynamic> _asMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    // 정규화 (단답 채점용)
    String _norm(String s) =>
        s.toLowerCase().trim().replaceAll(RegExp(r'[\s\-]'), '');

    QuestionType _toResultType(ExamQuestionType t) {
      switch (t) {
        case ExamQuestionType.mcq:
          return QuestionType.mcq;
        case ExamQuestionType.shortAnswer:
          return QuestionType.short;
        case ExamQuestionType.ordering:
          return QuestionType.ordering;
      }
    }

    // 질문 id → 질문 맵
    final Map<String, ExamQuestion> qById = {
      for (final q in questions) q.id: q
    };

    return attemptRows.map((raw) {
      final aTop = _asMap(raw.answers);

      // duration 추출(없으면 0초)
      int durSec = 0;
      try {
        final meta = _asMap(aTop['_meta']);
        durSec = (meta['duration_sec'] ?? meta['duration'] ?? 0) as int? ?? 0;
      } catch (_) {}

      // 질문별 답맵: {qid: {...}} 또는 [{id:..., ...}]
      Map<String, dynamic> ansById = {};
      if (aTop.isNotEmpty && aTop.values.first is Map && aTop.containsKey('_meta')) {
        // _meta 같이 있는 형태라면 나머지 키만 사용
        ansById = Map.fromEntries(
          aTop.entries.where((e) => e.key != '_meta'),
        );
      } else if (aTop.isNotEmpty) {
        ansById = Map<String, dynamic>.from(aTop);
      }
      // 리스트 형태 지원
      final listForm = raw.answers is List ? List.from(raw.answers as List) : null;
      if (listForm != null) {
        for (final e in listForm) {
          final m = _asMap(e);
          final id = (m['id'] ?? '').toString();
          if (id.isNotEmpty) ansById[id] = m;
        }
      }

      final itemResults = <QuestionResult>[];
      for (final q in questions) {
        final a = ansById[q.id];

        // 공통 기본값
        List<String>? choices;
        int? selectedIndex;
        int? correctIndex;
        String? answerText;
        List<String>? accepteds;
        List<String>? selectedOrdering;
        List<String>? correctOrdering;
        bool isCorrect = false;

        switch (q.type) {
          case ExamQuestionType.mcq:
            choices = q.choices ?? const <String>[];
            correctIndex = q.correctIndex ?? 0;
            // a가 int거나, {selectedIndex:index} 형태일 수 있음
            if (a is int) {
              selectedIndex = a;
            } else if (a is Map) {
              selectedIndex = (a['selectedIndex'] ?? a['index']) as int?;
            }
            isCorrect = (selectedIndex != null) && (selectedIndex == correctIndex);
            break;

          case ExamQuestionType.shortAnswer:
            accepteds = (q.answers ?? const <String>[]);
            if (a is String) {
              answerText = a;
            } else if (a is Map) {
              answerText = (a['text'] ?? a['answer'])?.toString();
            }
            final ansNorm = answerText == null ? '' : _norm(answerText);
            isCorrect = accepteds.any((acc) => _norm(acc) == ansNorm);
            break;

          case ExamQuestionType.ordering:
            correctOrdering = q.ordering ?? const <String>[];
            if (a is List) {
              selectedOrdering = a.map((e) => e.toString()).toList();
            } else if (a is Map) {
              final ls = a['ordering'] as List?;
              if (ls != null) {
                selectedOrdering = ls.map((e) => e.toString()).toList();
              }
            }
            isCorrect = (selectedOrdering != null) &&
                selectedOrdering!.length == correctOrdering.length &&
                List.generate(correctOrdering.length, (i) => i)
                    .every((i) => correctOrdering![i] == selectedOrdering![i]);
            break;
        }

        itemResults.add(
          QuestionResult(
            id: q.id,
            type: _toResultType(q.type),
            prompt: q.prompt,
            choices: choices,
            selectedIndex: selectedIndex,
            correctIndex: correctIndex,
            answerText: answerText,
            accepteds: accepteds,
            selectedOrdering: selectedOrdering,
            correctOrdering: correctOrdering,
            isCorrect: isCorrect,
            explanation: null, // 현재 해설 스키마 없음
          ),
        );
      }

      return ExamAttemptResult(
        id: raw.id,
        takenAt: raw.createdAt,
        score: raw.score,
        passed: raw.passed,
        duration: Duration(seconds: durSec),
        items: itemResults,
      );
    }).toList();
  }

  // ▼ 모드별로 올바른 타입으로 pop
  void _popSelf() {
    if (!mounted) return;
    if (_isMentee) {
      // 멘티 모드: 진행도 갱신 여부를 bool로 반환
      Navigator.pop<bool>(context, _progressChanged);
    } else {
      // 관리자 모드: 특별한 결과 없으면 null (삭제시엔 기존 코드대로 별도 CurriculumDetailResult 반환)
      Navigator.pop<CurriculumDetailResult?>(context, null);
    }
  }


  Future<void> _handleBack() async {
    if (_saving) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중에는 나갈 수 없어요. 잠시만 기다려주세요.')),
        );
      }
      return;
    }
    _unfocus();
    if (!_dirty || !_isAdminEdit) {
      _popSelf();
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
    if (leave) _popSelf();
  }

  // ====== 편집 시트들 (모두 "로컬 변경만" 반영) ======

  Future<void> _editVideoSheet() async {
    if (!_isAdminEdit) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        return SafeArea(
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

                // 로컬 파일 선택(즉시 임시 썸네일까지 반영)
                ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: const Text('영상 파일 선택(저장 시 업로드)'),
                  onTap: () async {
                    try {
                      final pf = await SupabaseService.instance.pickOneFile();
                      if (pf?.path == null) return;
                      await _setPendingVideo(File(pf!.path!)); // ★ 즉시 썸네일 반영
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('파일 선택 실패: $e')));
                    }
                  },
                ),

                // 영상 연결 해제(즉시 플레이스홀더로)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('영상 연결 해제'),
                  onTap: () {
                    _clearPendingVideo(); // ★ 즉시 반영
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editGoalsSheet() async {
    if (!_isAdminEdit) return;
    final goals = List<String>.from(_goals);

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
                                    final newGoals = goals.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                                    setState(() {
                                      _goals = newGoals;
                                      _dirty = true;
                                    });
                                    Navigator.pop(context);
                                  },
                                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w800)),
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
    if (!_isAdminEdit) return;
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
                final shownPass = _pendingExam?.passScore ?? _examPassScore ?? 60;

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
                              border: Border.all(color: temp ? const Color(0xFFBFDBFE) : const Color(0xFFE6ECF3)),
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
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE6ECF3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 18, color: UiTokens.primaryBlue),
                                  const SizedBox(width: 8),
                                  Text('통과 기준: $shownPass점 / 100점',
                                      style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
                                  if (_pendingExam != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: const Color(0xFFFECBA1)),
                                      ),
                                      child: const Text('임시 변경 있음',
                                          style: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w800, fontSize: 12)),
                                    ),
                                  ],
                                ],
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  final user = context.read<UserProvider>();
                                  final adminKey = user.adminKey ?? widget.adminKey;
                                  final moduleCode = widget.item.id;

                                  if (adminKey == null || adminKey.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('관리자 인증(adminKey)이 필요합니다. 상단에서 관리자 로그인 먼저 진행하세요.')),
                                    );
                                    return;
                                  }

                                  // 서버 세트 불러와 초기값으로 사용
                                  final set = await ExamService.instance.getExamSet(moduleCode);
                                  final initQs = set?.questions ?? <ExamQuestion>[];
                                  final initPass = set?.passScore ?? (_pendingExam?.passScore ?? (_examPassScore ?? 60));

                                  final result = await Navigator.push<ExamEditResult>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ExamEditPage(
                                        initialQuestions: initQs,
                                        initialPassScore: initPass,
                                      ),
                                    ),
                                  );
                                  if (result == null) return;

                                  // ✅ 여기서는 서버 저장하지 않음 — 임시 반영만
                                  if (!mounted) return;
                                  setState(() {
                                    _pendingExam = result;
                                    _requiresExam = true;
                                    _examPassScore = result.passScore; // 미리 표시 갱신
                                    _dirty = true;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('시험 변경사항이 임시 저장되었습니다. 하단 "저장하기"를 눌러 반영하세요.')),
                                  );
                                },

                                icon: const Icon(Icons.assignment, size: 18),
                                label: const Text('편집하기', style: TextStyle(fontWeight: FontWeight.w600)),
                                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
                                style: TextStyle(color: UiTokens.title.withOpacity(0.7), fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

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
                                _dirty = true;
                              });
                              Navigator.pop(context);
                            },
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('확인'),
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
    if (!_isAdminEdit) return;
    final temp = _materials.map((e) => _EditMaterial(name: e.name, icon: e.icon, url: e.url, localPending: e.localPending)).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        const double kActionBarHeight = 52;
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
              initialChildSize: 0.72,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              builder: (_, controller) {
                return StatefulBuilder(
                  builder: (context, setInner) {
                    Future<void> addByPickFile() async {
                      try {
                        final pf = await SupabaseService.instance.pickOneFile();
                        if (pf == null) return;

                        // 업로드는 하지 않음 — UI에만 추가(미업로드 상태)
                        setInner(() {
                          temp.add(_EditMaterial(
                            name: pf.name,
                            icon: _iconFromType(_guessType(pf.name), pf.name),
                            url: null,            // 아직 원격 URL 없음
                            localPending: true,   // 미업로드 표시
                          ));
                        });
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('파일 선택 실패: $e')));
                      }
                    }

                    return SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                            child: Column(
                              children: const [
                                _SheetGrabber(),
                                SizedBox(height: 8),
                                Text('관련 자료 편집',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: UiTokens.title)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              controller: controller,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, kActionBarHeight + 28),
                              itemCount: temp.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                final nameCtl = TextEditingController(text: temp[i].name);
                                final isPending = temp[i].localPending;
                                final hint = isPending
                                    ? '로컬 파일(미업로드) — 저장하기 이후에 업로드 흐름 연결 예정'
                                    : (temp[i].url ?? '');
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: nameCtl,
                                      onChanged: (v) => temp[i].name = v,
                                      onSubmitted: (_) => _unfocus(),
                                      decoration: _inputDeco('자료 이름'),
                                    ),
                                    if (hint.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isPending ? Icons.file_download_off_rounded : Icons.link_rounded,
                                              size: 16,
                                              color: isPending ? Colors.orange : UiTokens.actionIcon,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                hint,
                                                style: TextStyle(
                                                  color: UiTokens.title.withOpacity(0.55),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        tooltip: '삭제',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => setInner(() => temp.removeAt(i)),
                                      ),
                                    ),
                                  ],
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
                                      onPressed: addByPickFile,
                                      icon: const Icon(Icons.file_upload_outlined),
                                      label: const Text('파일 추가'),
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
                                          _dirty = true;
                                        });
                                        Navigator.pop(sheetCtx);
                                      },
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 0),
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w800)),
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
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ===== 저장: CTA에서 한 번에 서버 동기화 =====
  Future<void> _saveAllEdits() async {
    if (!_dirty || _saving) return;

    final adminKey = widget.adminKey ?? SupabaseService.instance.adminKey;
    if (adminKey == null || adminKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('관리자 인증이 필요합니다(adminKey 없음)')));
      return;
    }

    setState(() => _saving = true);

    // 원격 URL만 서버에 반영
    final ready = _materials.where((m) => !m.localPending && (m.url?.trim().isNotEmpty ?? false)).toList();
    final resourcesJson = ready.map((m) {
      final name = m.name.trim().isEmpty ? '자료' : m.name.trim();
      final url  = (m.url ?? '').trim();
      final type = _guessType(url);
      return {'title': name, 'url': url, 'type': type};
    }).toList();

    String? newVideoPath;   // null=변경없음, ''=해제, 'path'=설정
    String? newThumbPath;

    try {
      // 1) 삭제 의도?
      if (_videoUrl == null && _item.videoUrl != null && _pendingLocalVideoFile == null) {
        newVideoPath = '';   // 해제
        newThumbPath = '';   // 해제
      }

      // 2) 신규 업로드가 대기 중이면 업로드
      if (_pendingLocalVideoFile != null) {
        final storage = StorageService();

        // (a) 비디오 업로드
        newVideoPath = await storage.uploadVideo(
          file: _pendingLocalVideoFile!,
          moduleCode: _item.id,
          version: _item.version ?? 1,
          week: _item.week,
        );

        // (b) 썸네일 생성(3초 지점, 640px, JPEG 품질 80)
        final Uint8List? thumbBytes = await VideoThumbnail.thumbnailData(
          video: _pendingLocalVideoFile!.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 640,
          quality: 80,
          timeMs: 3000,
        ); // video_thumbnail 사용법 참고 :contentReference[oaicite:3]{index=3}

        if (thumbBytes != null) {
          newThumbPath = await storage.uploadThumbnailBytes(
            bytes: thumbBytes,
            moduleCode: _item.id,
            version: _item.version ?? 1,
            week: _item.week,
            filename: 'thumb.jpg',
            upsert: true,
          );
        } else {
          newThumbPath = ''; // 생성 실패 시 비워두기(옵션)
        }
      }

      // 3) RPC로 메타 한 번에 저장
      await SupabaseService.instance.saveEditsViaRpc(
        code: _item.id,
        goals: _goals,
        resources: resourcesJson,
        videoPathOrNull: newVideoPath,
        thumbPathOrNull: newThumbPath,
        adminKey: adminKey,
      );

      // 4) 기존 시험 세트 처리(네 프로젝트 로직 그대로)
      if (!_requiresExam) {
        try {
          await ExamService.instance.adminDeleteExamSet(
            adminKey: adminKey,
            moduleCode: _item.id,
          );
        } catch (_) {}
      }
      if (_pendingExam != null) {
        await ExamService.instance.adminUpsertExamSet(
          adminKey: adminKey,
          moduleCode: _item.id,
          passScore: _pendingExam!.passScore,
          questions: _pendingExam!.questions,
        );
      }

      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saving = false;
        _pendingLocalVideoFile = null;
        _pendingThumbBytes = null;   // ★ 임시 썸네일 제거 → 원격 썸네일 Future로 자연 전환
        _pendingThumbRev++;
        if (_pendingExam != null) {
          _examPassScore = _pendingExam!.passScore;
          _pendingExam = null;
        }
      });

      try { context.read<CurriculumProvider>().refresh(force: true); } catch (_) {}
      await _reloadFromServer();
      await _loadExamMeta();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('변경사항이 저장되었습니다.')));
    } catch (e) {
      print(e);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    }
  }

  // ===== 뷰 =====
  @override
  Widget build(BuildContext context) {
    final counts = _examCounts(_item);
    final shownPass = _pendingExam?.passScore ?? _examPassScore ?? 60;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _unfocus,
      child: PopScope(
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: UiTokens.title),
              onPressed: _handleBack,
              tooltip: '뒤로가기',
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'W${_item.week}. ${_item.title}',
                    style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _modeChip(),
              ],
            ),
            actions: [
              if (_isAdminEdit)
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
                  if (_isAdminReview && (widget.menteeName?.isNotEmpty ?? false)) ...[
                    _reviewHeader(widget.menteeName!),
                    const SizedBox(height: 12),
                  ],

                  // ===== 영상 섹션 (+진행/배지) =====
                  _SectionCard(
                    padding: EdgeInsets.zero,
                    onEdit: _isAdminEdit ? _editVideoSheet : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: (_videoUrl != null && _isMentee)
                          ? _openPlayer
                          : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 배경
                              // 배경: 썸네일(캐시 사용) → 실패/없음이면 그라디언트
                              Positioned.fill(
                                child: _ThumbOrGradient(
                                  cacheKey: 'thumb:${_item.thumbUrl ?? ''}-${_pendingThumbRev}', // 강제리프레시용 rev 포함(선택)
                                  overrideBytes: _pendingThumbBytes,          // ★ 있으면 최우선으로 표시
                                  signedUrlFuture: _thumbSignedFuture,        // 원격(저장 반영 후)
                                  fallback: _gradientPlaceholder(),
                                ),
                              ),

                              // (추가) 영상이 없을 때 중앙 안내 오버레이
                              if ( (_videoUrl == null || _videoUrl!.isEmpty) &&
                                  _pendingLocalVideoFile == null &&
                                  (_pendingThumbBytes == null || _pendingThumbBytes!.isEmpty) &&
                                  _thumbSignedFuture == null )
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam_off_rounded, size: 36, color: UiTokens.actionIcon),
                                      const SizedBox(height: 6),
                                      Text(
                                        '영상이 등록되지 않았어요',
                                        style: TextStyle(
                                          color: UiTokens.title.withOpacity(0.75),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (_isAdminEdit) ...[
                                        const SizedBox(height: 10),
                                        OutlinedButton.icon(
                                          onPressed: _editVideoSheet,
                                          icon: const Icon(Icons.add_rounded),
                                          label: const Text('영상 추가'),
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),


                              // mentee 모드: 중앙 Play 버튼
                              if (_videoUrl != null && _isMentee)
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

                              // mentee 모드: 하단 진행바 + 이어보기
                              if (_videoUrl != null && _isMentee && _watchedRatio > 0)
                                Positioned(
                                  left: 0, right: 0, bottom: 0,
                                  child: LinearProgressIndicator(
                                    minHeight: 4,
                                    value: _watchedRatio.clamp(0.0, 1.0).toDouble(),
                                    backgroundColor: Colors.white.withOpacity(0.35),
                                    valueColor: const AlwaysStoppedAnimation(UiTokens.primaryBlue),
                                  ),
                                ),
                              if (_videoUrl != null && _isMentee && _watchedRatio > 0 && _watchedRatio < 1)
                                Positioned(
                                  right: 10, bottom: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [UiTokens.cardShadow],
                                      border: Border.all(color: UiTokens.cardBorder),
                                    ),
                                    child: Text(
                                      '이어보기 ${(_watchedRatio * 100).round()}%',
                                      style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                                  ),
                                ),

                              if (_videoUrl != null && _isMentee && _watchedRatio == 1)
                                Positioned(
                                  right: 10, bottom: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [UiTokens.cardShadow],
                                      border: Border.all(color: UiTokens.cardBorder),
                                    ),
                                    child: Text(
                                      '시청 완료',
                                      style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                                  ),
                                ),

                              // adminReview 모드: 우상단 시청률 뱃지
                              if (_isAdminReview)
                                Positioned(
                                  right: 12, top: 12,
                                  child: _watchRateChip(_pr.watchedRatio),
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
                    onEdit: _isAdminEdit ? _editGoalsSheet : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('학습 목표'),
                        const SizedBox(height: 8),
                        if (_goals.isEmpty)
                          Text('등록된 학습 목표가 없습니다.', style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700))
                        else
                          ..._goals.map(_bullet),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ===== 시험 정보 =====
                  _SectionCard(
                    onEdit: _isAdminEdit ? _editExamSheet : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('시험 정보'),
                        const SizedBox(height: 8),
                        if (!_requiresExam)
                          Text('이 과정에는 시험이 없습니다.',
                              style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700))
                        else ...[
                          finalExamRows(counts),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 왼쪽: 통과 기준 + (모드별 통계)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline, size: 18, color: UiTokens.primaryBlue),
                                        const SizedBox(width: 8),
                                        Text('통과 기준: $shownPass점 / 100점',
                                            style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (_isMentee || _isAdminReview)
                                      Row(
                                        children: [
                                          Icon(
                                            _pr.passed ? Icons.verified_rounded : Icons.shield_moon_outlined,
                                            size: 18,
                                            color: _pr.passed ? Colors.green.shade600 : UiTokens.actionIcon,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _pr.attempts == 0
                                                ? '미응시'
                                                : '시도 ${_pr.attempts}회'
                                                '${(_pr.bestScore != null) ? ' / 최고 ${_pr.bestScore}점' : ''}'
                                                '${_pr.passed ? ' / 통과' : ''}',
                                            style: TextStyle(color: UiTokens.title.withOpacity(0.75), fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              // 오른쪽: 모드별 버튼
                              if (_isMentee)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: FilledButton.tonal(
                                    onPressed: () async {
                                      final moduleCode = widget.item.id;
                                      final loginKey = context.read<UserProvider>().current?.loginKey ?? '';

                                      // 1) 캐시 우선 — 없으면 로드 & 캐시
                                      List<ExamQuestion>? qs = _examQuestionsCache;
                                      int pass = _examPassScore ?? 60;

                                      if (qs == null) {
                                        final set = await ExamService.instance.getExamSet(moduleCode);
                                        if (set == null || set.questions.isEmpty) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('등록된 시험이 없어요.')),
                                          );
                                          return;
                                        }
                                        qs = set.questions;
                                        pass = set.passScore;
                                        if (mounted) {
                                          setState(() {
                                            _examQuestionsCache = qs;
                                            _examPassScore = pass;
                                            _examCountsCache = _countByType(qs!); // 상단 요약 즉시 반영
                                          });
                                        }
                                      }

                                      // 2) ExamPage로 이동 (여기서 onSubmitted는 서버 저장만)
                                      final bool? submitted = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ExamPage(
                                            questions: qs!,
                                            passScore: pass,
                                            explanations: const {},
                                            moduleCode: moduleCode,
                                            loginKey: loginKey,
                                            initialAttempts: _pr.attempts,
                                            initialBestScore: _pr.bestScore,
                                            onSubmitted: (score, answers) async {
                                              await ExamService.instance.menteeSubmitExam(
                                                loginKey: loginKey,
                                                moduleCode: moduleCode,
                                                answers: answers,
                                                score: score,
                                              );
                                            },
                                          ),
                                        ),
                                      );

                                      // 3) 결과페이지 '닫기'로 돌아오면 디테일/메인 갱신 트리거는 이전 지시대로
                                      if (submitted == true) {
                                        // (필요 시) 서버 최신 재확인
                                        try {
                                          final map = await CourseProgressService.listCurriculumProgress(loginKey: loginKey);
                                          final fresh = map[moduleCode];
                                          if (fresh != null && mounted) {
                                            setState(() => _prOverride = fresh);
                                          }
                                        } catch (_) {}
                                        await _loadMenteeProgress();
                                        _progressChanged = true;
                                        // if (mounted) {
                                        //   ScaffoldMessenger.of(context).showSnackBar(
                                        //     const SnackBar(content: Text('시험 결과가 반영되었습니다.')),
                                        //   );
                                        // }
                                      }
                                    },

                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor: UiTokens.primaryBlue,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('시험보기', style: TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                )
                              else if (_isAdminReview)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: FilledButton.tonal(
                                    onPressed: _openExamResults,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor: UiTokens.primaryBlue,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('시험 결과 보기', style: TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // // ===== 관련 자료 =====
                  // _SectionCard(
                  //   onEdit: _isAdminEdit ? _editMaterialsSheet : null,
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       const SectionTitle('관련 자료'),
                  //       const SizedBox(height: 8),
                  //       if (_materials.isEmpty)
                  //         Text('등록된 자료가 없습니다.',
                  //             style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700))
                  //       else
                  //         Wrap(
                  //           spacing: 8,
                  //           runSpacing: 8,
                  //           children: _materials.map((m) => _fileChip(m.icon, m.name, url: m.url, localPending: m.localPending)).toList(),
                  //         ),
                  //     ],
                  //   ),
                  // ),

                  const SizedBox(height: 24),

                  // ===== 하단 CTA =====
                  _isAdminReview
                      ? const SizedBox.shrink() // 관리자 검토 모드에선 CTA 숨김
                      : SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isAdminEdit
                          ? (_dirty && !_saving ? _saveAllEdits : null)
                          : (_videoUrl != null) ? _openPlayer : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: UiTokens.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _isAdminEdit
                            ? (_saving ? '저장 중...' : (_dirty ? '저장하기' : '변경 없음'))
                            : _watchedRatio <= 0 ? '시청하기' : (_watchedRatio < 1 ? '이어보기' : '다시보기'),
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

  // ===== 작은 빌더들/유틸 =====
  Widget _modeChip() {
    String label;
    Color bg, border, fg;
    if (_isAdminEdit) {
      label = '관리자(수정)';
      bg = const Color(0xFFFFF7ED);
      border = const Color(0xFFFECBA1);
      fg = const Color(0xFF9A3412);
    } else if (_isAdminReview) {
      label = '관리자(검토)';
      bg = const Color(0xFFEFF6FF);
      border = const Color(0xFFBFDBFE);
      fg = const Color(0xFF2563EB);
    } else {
      label = '멘티';
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      fg = const Color(0xFF059669);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: border)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }

  Widget _watchRateChip(double ratio) {
    final p = (ratio * 100).round();
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '시청률 $p%',
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: const Icon(Icons.play_arrow_rounded, size: 14, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _reviewHeader(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6ECF3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: UiTokens.actionIcon),
          const SizedBox(width: 8),
          Text(
            '검토 대상: $name',
            style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget finalExamRows(Map<String, int> counts) {
    return Column(
      children: [
        _examRow('객관식', counts['mcq']!),
        const SizedBox(height: 6),
        _examRow('주관식', counts['sa']!),
        const SizedBox(height: 6),
        _examRow('순서 맞추기', counts['order']!),
      ],
    );
  }

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

  IconData _iconFromType(String type, String url) {
    final u = url.toLowerCase();
    if (type == 'pdf' || u.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (type == 'image' || RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(u)) return Icons.image_outlined;
    if (type == 'video' || RegExp(r'\.(mp4|mov|m4v|webm)$').hasMatch(u)) return Icons.movie_outlined;
    if (type == 'sheet' || u.contains('docs.google.com/spreadsheets')) return Icons.table_view_outlined;
    if (type == 'doc' || u.contains('docs.google.com/document')) return Icons.description_outlined;
    return Icons.link_outlined;
  }

  String _guessType(String? urlOrName) {
    final u = (urlOrName ?? '').toLowerCase();
    if (u.endsWith('.pdf')) return 'pdf';
    if (RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(u)) return 'image';
    if (RegExp(r'\.(mp4|mov|m4v|webm)$').hasMatch(u)) return 'video';
    if (u.contains('docs.google.com/spreadsheets')) return 'sheet';
    if (u.contains('docs.google.com/document')) return 'doc';
    return 'web';
  }

  Widget _fileChip(IconData icon, String name, {String? url, bool localPending = false}) {
    final canOpen = !localPending && url != null && url.isNotEmpty && Uri.tryParse(url)?.hasScheme == true;
    return InkWell(
      onTap: canOpen
          ? () async {
        final uri = Uri.parse(url!);
        final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요')));
        }
      }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: localPending ? const Color(0xFFFFF1E6) : const Color(0xFFE9F2FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: localPending ? const Color(0xFFFECBA1) : const Color(0xFFD7E6FF)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: localPending ? const Color(0xFF9A3412) : UiTokens.primaryBlue),
          const SizedBox(width: 6),
          Text(
            localPending ? '$name (미업로드)' : name,
            style: TextStyle(
              color: localPending ? const Color(0xFF9A3412) : UiTokens.primaryBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ]),
      ),
    );
  }

  static Widget _sheetGrabber() => Container(
    width: 44,
    height: 4,
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: const Color(0xFFE6EAF0), borderRadius: BorderRadius.circular(3)),
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

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFE6EAF0),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

Widget _gradientPlaceholder() {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [UiTokens.primaryBlue.withOpacity(0.18), const Color(0xFFCBD5E1).withOpacity(0.25)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );
}

/// 미리보기(메모리) > 원격(서명 URL + 캐시) > 폴백 순서로 표시
class _ThumbOrGradient extends StatelessWidget {
  final String cacheKey;
  final Uint8List? overrideBytes;       // ★ 편집 중 임시 썸네일
  final Future<String>? signedUrlFuture;
  final Widget fallback;

  const _ThumbOrGradient({
    required this.cacheKey,
    required this.overrideBytes,
    required this.signedUrlFuture,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    // 1) 메모리 이미지가 있으면 최우선 표시(저장 전 미리보기)
    if (overrideBytes != null && overrideBytes!.isNotEmpty) {
      // 공식: Image.memory는 Uint8List로 즉시 이미지를 그린다.
      return Image.memory(
        overrideBytes!,
        fit: BoxFit.cover,
      ); // :contentReference[oaicite:4]{index=4}
    }

    // 2) 원격 썸네일(서명 URL) — 캐시 사용
    if (signedUrlFuture != null) {
      return FutureBuilder<String>(
        future: signedUrlFuture,
        builder: (context, snap) {
          if (!snap.hasData || (snap.data ?? '').isEmpty) return fallback;
          return CachedNetworkImage(
            imageUrl: snap.data!,
            cacheKey: cacheKey,            // 같은 오브젝트면 URL이 바뀌어도 캐시 재사용
            fit: BoxFit.cover,
            placeholder: (_, __) => fallback,
            errorWidget: (_, __, ___) => fallback,
          ); // :contentReference[oaicite:5]{index=5}
        },
      );
    }

    // 3) 폴백
    return fallback;
  }
}



InputDecoration _inputDeco(String label) => InputDecoration(
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
