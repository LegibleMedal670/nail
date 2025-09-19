import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Manager/models/Mentee.dart';

/// 간단 시험 기록 모델 (서버 연동 전 데모/요약용)
class ExamRecord {
  final int attempts;     // 응시 횟수
  final int? bestScore;   // 최고 점수 (없으면 null)
  final bool passed;      // 합격 여부
  const ExamRecord({this.attempts = 0, this.bestScore, this.passed = false});
}

/// 관리자 탭의 "멘티 요약 타일" (영상+시험 통합 UI)
class MenteeSummaryTile extends StatelessWidget {
  final Mentee mentee;

  /// 전체 커리큘럼
  final List<CurriculumItem> curriculum;

  /// 영상 시청률(0.0~1.0), 키: item.id
  final Map<String, double> watchRatio;

  /// 시험 기록, 키: item.id
  final Map<String, ExamRecord> examMap;

  /// 상세보기 버튼 콜백
  final VoidCallback? onDetail;

  final double? overrideProgress;


  const MenteeSummaryTile({
    super.key,
    required this.mentee,
    required this.curriculum,
    required this.watchRatio,
    required this.examMap,
    this.onDetail,
    this.overrideProgress,
  });

  double _calcProgressFromCurriculum() {
    final doneCount = curriculum.where(_isModuleDone).length;
    final totalCount = curriculum.length;
    if (totalCount == 0) return 0.0;
    final r = doneCount / totalCount;
    if (r.isNaN || r.isInfinite) return 0.0;
    return r.clamp(0.0, 1.0);
  }



  @override
  Widget build(BuildContext context) {
    final bool useFallback = curriculum.isEmpty;

    final double progress = (overrideProgress != null)
        ? overrideProgress!.clamp(0.0, 1.0)
        : _calcProgressFromCurriculum(); // 기존 방식 fallback

    final percentText = '${(progress * 100).round()}%';

    final int examPass  = useFallback ? mentee.examDone  : curriculum.where((e) => e.requiresExam).where((e) => (examMap[e.id]?.passed ?? false)).length;
    final int examTotal = useFallback ? mentee.examTotal : curriculum.where((e) => e.requiresExam).length;

    // ✅ 완료/총 모듈 카운트
    final int doneCount = useFallback ? mentee.courseDone  : _doneCountLocal;
    final int totalCount = useFallback ? mentee.courseTotal : _totalCountLocal;

    // 현재 모듈(처음으로 완료가 아닌 항목)
    final current = curriculum.firstWhere(
          (e) => !_isModuleDone(e),
      orElse: () => curriculum.isNotEmpty ? curriculum.last : const CurriculumItem(
        id: '_empty',
        week: 0,
        title: '커리큘럼 없음',
        summary: '',
        hasVideo: false,
        requiresExam: false,
          videoUrl: '', resources: [], goals: []
      ),
    );


    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UiTokens.cardBorder, width: 1),
        boxShadow: [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== 헤더: 프로필 + 진행바 + 연필 =====
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey[400],
                backgroundImage: mentee.photoUrl != null ? NetworkImage(mentee.photoUrl!) : null,
                child: mentee.photoUrl == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mentee.name,
                        style: const TextStyle(
                            color: UiTokens.title, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE9EEF6),
                        valueColor: AlwaysStoppedAnimation(const Color(0xFF22C55E)), // green
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Text(percentText,
                  style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w900)),
            ],
          ),

          const SizedBox(height: 12),

          // ===== 현재 모듈 진행(영상+시험 통합 카드) =====
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('현재 모듈  ·  W${current.week}. ${current.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: UiTokens.title, fontWeight: FontWeight.w800,),),
                SizedBox(height: 15,),
                Text(
                  '영상 시청: $doneCount/$totalCount 완료  ·  시험: $examPass/$examTotal 합격',
                  style: TextStyle(
                    color: UiTokens.title.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 5),

          // ===== 푸터 =====
          Row(
            children: [
              Text(
                '시작일: ${_fmtDate(mentee.startedAt)}',
                style: TextStyle(
                  color: UiTokens.title.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 36,
                child: FilledButton(
                  onPressed: onDetail,
                  style: FilledButton.styleFrom(
                    backgroundColor: UiTokens.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text(
                    '상세보기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === helpers ===
  bool _isModuleDone(CurriculumItem it) {
    final vr = (watchRatio[it.id] ?? 0.0) >= 0.9;
    final examOk = !it.requiresExam ? true : (examMap[it.id]?.passed ?? false);
    return vr && examOk;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get _totalCountLocal => curriculum.length;
  int get _doneCountLocal  => curriculum.where(_isModuleDone).length;
}
