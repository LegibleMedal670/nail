import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/models/curriculum_item.dart';

class CurriculumDetailResult {
  final bool deleted;
  const CurriculumDetailResult({this.deleted = false});
}

class CurriculumDetailPage extends StatelessWidget {
  final CurriculumItem item;
  const CurriculumDetailPage({super.key, required this.item});

  // UI 데모용 시험 문항 수(주차/설정에 따라 대충 생성)
  Map<String, int> _examCounts(CurriculumItem it) {
    if (!it.requiresExam) return {'mcq': 0, 'sa': 0, 'order': 0};
    // 간단 룰: 주차를 바탕으로 변형
    final base = 4 + (it.week % 3); // 4~6
    return {
      'mcq': base + 4,              // 객관식
      'sa': (base / 2).floor(),     // 주관식
      'order': it.week % 2,         // 순서 맞추기 0~1
    };
  }

  @override
  Widget build(BuildContext context) {
    final counts = _examCounts(item);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: UiTokens.title),
        title: Text(
          'W${item.week}. ${item.title}',
          style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700),
        ),
        actions: [
          // 복제 같은 빠른 액션이 있으면 편해서 하나 넣어줌
          IconButton(
            tooltip: '복제',
            icon: const Icon(Icons.copy_rounded, color: UiTokens.actionIcon),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('과정을 복제했습니다 (UI 데모)')),
              );
            },
          ),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline, color: UiTokens.actionIcon),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('과정 삭제'),
                  content: Text('‘${item.title}’을(를) 삭제할까요? 되돌릴 수 없어요.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.of(context).pop(const CurriculumDetailResult(deleted: true));
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // 영상 플레이스홀더
              _SectionCard(
                padding: const EdgeInsets.all(0),
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
                          child: const Center(
                            child: Icon(Icons.videocam_rounded, size: 72, color: UiTokens.actionIcon),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [UiTokens.cardShadow],
                            ),
                            child: const Icon(Icons.play_arrow_rounded, size: 36, color: UiTokens.title),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 학습 목표 / 내용
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('학습 목표'),
                    const SizedBox(height: 8),
                    // 요약 텍스트를 쉼표 기준으로 불릿화
                    ..._bulletsFrom(item.summary).map((t) => _bullet(t)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 시험 정보
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('시험 정보'),
                    const SizedBox(height: 8),
                    if (!item.requiresExam)
                      Text('이 과정에는 시험이 없습니다.',
                          style: TextStyle(
                            color: UiTokens.title.withOpacity(0.6),
                            fontWeight: FontWeight.w700,
                          ))
                    else
                      Column(
                        children: [
                          _examRow('객관식', counts['mcq']!),
                          const SizedBox(height: 6),
                          _examRow('주관식', counts['sa']!),
                          const SizedBox(height: 6),
                          _examRow('순서 맞추기', counts['order']!),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 18, color: UiTokens.primaryBlue),
                              const SizedBox(width: 8),
                              Text(
                                '통과 기준: 60점 / 100점',
                                style: const TextStyle(
                                  color: UiTokens.title,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 관련 자료(체크리스트, PDF 등) - 있으면 좋을 요소
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('관련 자료'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _fileChip(Icons.picture_as_pdf_rounded, '위생 체크리스트.pdf'),
                        _fileChip(Icons.insert_drive_file_outlined, '시술 단계 가이드.txt'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 수정 버튼 (동작은 데모용)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('수정 화면으로 이동 (UI 데모)')),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: UiTokens.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('수정하기', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 작은 UI 유틸 =====
  static Iterable<String> _bulletsFrom(String s) {
    final parts = s.split(RegExp(r'[,\u3001]')).map((e) => e.trim()).where((e) => e.isNotEmpty);
    // 그래도 적으면 기본 예시 추가
    return parts.isNotEmpty ? parts : ['핵심 개념 이해', '실습 체크리스트 숙지', '시험 대비 포인트 정리'];
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

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: UiTokens.actionIcon),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: UiTokens.title, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _examRow(String label, int n) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('$n문항',
            style: TextStyle(
              color: UiTokens.title.withOpacity(0.85),
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }

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
            style: const TextStyle(color: UiTokens.primaryBlue, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _SectionCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [UiTokens.cardShadow],
      ),
      child: child,
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
      style: const TextStyle(color: UiTokens.title, fontSize: 14, fontWeight: FontWeight.w800),
    );
  }
}
