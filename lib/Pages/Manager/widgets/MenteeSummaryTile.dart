import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/curriculum_item.dart';
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


  const MenteeSummaryTile({
    super.key,
    required this.mentee,
    required this.curriculum,
    required this.watchRatio,
    required this.examMap,
    this.onDetail,
  });

  /// 데모용 팩토리 (빠른 미리보기)
  factory MenteeSummaryTile.demo(Mentee mentee) {
    final demoCur = _demoCurriculum();
    return MenteeSummaryTile(
      mentee: mentee,
      curriculum: demoCur,
      watchRatio: const {
        'w01': 1.0, // 완료
        'w02': 0.6, // 시청중
        // 나머지 0으로 간주
      },
      examMap: const {
        'w01': ExamRecord(attempts: 1, bestScore: 88, passed: true),
        'w02': ExamRecord(attempts: 0, bestScore: null, passed: false),
      },
      onDetail: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 전체 진행률(= 모든 모듈 완료율). 완료 정의: 영상 완료 && (시험이 있으면 합격)
    final doneCount = curriculum.where(_isModuleDone).length;
    final totalCount = curriculum.length;
    final progress = (totalCount == 0) ? 0.0 : (doneCount / totalCount);
    final percentText = '${(progress * 100).round()}%';

    // 전체 시험 집계
    final examTotal = curriculum.where((e) => e.requiresExam).length;
    final examPass = curriculum
        .where((e) => e.requiresExam)
        .where((e) => (examMap[e.id]?.passed ?? false))
        .length;

    // 현재 모듈(처음으로 완료가 아닌 항목)
    final current = curriculum.firstWhere(
          (e) => !_isModuleDone(e),
      orElse: () => curriculum.isNotEmpty ? curriculum.last : const CurriculumItem(
        id: '_empty',
        week: 0,
        title: '커리큘럼 없음',
        summary: '',
        durationMinutes: 0,
        hasVideo: false,
        requiresExam: false,
      ),
    );

    final videoRatio = (watchRatio[current.id] ?? 0.0).clamp(0.0, 1.0);
    final videoLabel = (videoRatio >= 1.0) ? '완료' : '시청률 ${_toPercent(videoRatio)}%';
    final examInfo = examMap[current.id];
    final examLabel = current.requiresExam
        ? (examInfo == null || examInfo.attempts == 0)
        ? '미응시'
        : (examInfo.passed
        ? '합격 · 최고 ${examInfo.bestScore ?? 0}점'
        : '응시 ${examInfo.attempts}회 · 최고 ${examInfo.bestScore ?? 0}점')
        : '없음';

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
                    // Text(mentee.role,
                    //     style: TextStyle(
                    //         color: UiTokens.title.withOpacity(0.6),
                    //         fontSize: 12,
                    //         fontWeight: FontWeight.w700)),
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
                        color: UiTokens.title, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // 영상 상태
                    Expanded(
                      child: _pill(
                        title: '교육 진행',
                        value: videoLabel,
                        icon: Icons.play_circle_outline,
                        bg: const Color(0xFFEFF6FF),
                        fg: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 시험 상태
                    Expanded(
                      child: _pill(
                        title: '시험 결과',
                        value: examLabel,
                        icon: Icons.assignment_turned_in_outlined,
                        bg: const Color(0xFFECFDF5),
                        fg: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ===== 전체 집계 =====
          Text(
            '교육 진행: $doneCount/$totalCount 완료  ·  시험 결과: $examPass/$examTotal 합격',
            style: TextStyle(
              color: UiTokens.title.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 10),

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
    final vr = (watchRatio[it.id] ?? 0.0) >= 1.0;
    final examOk = !it.requiresExam ? true : (examMap[it.id]?.passed ?? false);
    return vr && examOk;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _toPercent(double r) => (r * 100).round();

  Widget _pill({
    required String title,
    required String value,
    required IconData icon,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: fg.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: UiTokens.title,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 데모용 커리큘럼 =====
List<CurriculumItem> _demoCurriculum() => const [
  CurriculumItem(
    id: 'w01',
    week: 1,
    title: '기초 위생 및 도구 소개',
    summary: '필수 위생, 도구 종류, 기본 사용법',
    durationMinutes: 60,
    hasVideo: true,
    requiresExam: true,
  ),
  CurriculumItem(
    id: 'w02',
    week: 2,
    title: '파일링과 큐티클 케어',
    summary: '안전한 큐티클 정리와 파일링 각도',
    durationMinutes: 75,
    hasVideo: true,
    requiresExam: true,
  ),
  CurriculumItem(
    id: 'w03',
    week: 3,
    title: '베이스·컬러·탑 코트',
    summary: '도포 순서, 경화 시간, 흔한 실수',
    durationMinutes: 90,
    hasVideo: true,
    requiresExam: true,
  ),
];
