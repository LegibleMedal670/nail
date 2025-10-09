// lib/Pages/Mentee/page/MenteePracticePage.dart
import 'package:flutter/material.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/PracticeProvider.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Pages/Mentee/page/PracticeDetailPage.dart';
import 'package:nail/Pages/Common/widgets/SortBottomSheet.dart';
import 'package:nail/Pages/Common/widgets/CurriculumTile.dart';

enum PracticeFilter { all, incomplete }

class MenteePracticePage extends StatelessWidget {
  final bool embedded;
  const MenteePracticePage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PracticeProvider()..refreshAll(),
      child: _View(embedded: embedded),
    );
  }
}

class _View extends StatelessWidget {
  final bool embedded;
  const _View({required this.embedded});

  Future<void> _showFilterSheet(BuildContext context) async {
    final p = context.read<PracticeProvider>();
    final current = p.onlyIncomplete ? PracticeFilter.incomplete : PracticeFilter.all;

    final picked = await showModalBottomSheet<PracticeFilter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortBottomSheet<PracticeFilter>(
        title: '필터',
        current: current,
        options: const [
          SortOption(value: PracticeFilter.all, label: '전체', icon: Icons.list_alt),
          SortOption(value: PracticeFilter.incomplete, label: '미완료 실습', icon: Icons.hourglass_bottom_rounded),
        ],
      ),
    );

    if (picked != null) {
      p.setFilter(incompleteOnly: picked == PracticeFilter.incomplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PracticeProvider>();
    final user = context.watch<UserProvider>();

    final content = RefreshIndicator(
      color: UiTokens.primaryBlue,
      onRefresh: () => context.read<PracticeProvider>().refreshAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          _ProfileGauge(
            displayName: user.nickname.isNotEmpty ? user.nickname : '사용자',
            photoUrl: user.photoUrl,
            mentorName: user.mentorName ?? '미배정',
            ratio: p.completionRatio,
            startDate: _fmtDate(user.joinedAt),
          ),
          const SizedBox(height: 12),

          if (p.currentAttempt != null && p.currentSet != null) ...[
            _CurrentAttemptCard(
              set: p.currentSet!,
              attempt: p.currentAttempt!,
              onOpen: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PracticeDetailPage(setId: p.currentSet!['id']),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              const Text('실습 목록',
                  style: TextStyle(color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showFilterSheet(context),
                icon: const Icon(Icons.filter_list_rounded, color: UiTokens.actionIcon, size: 18),
                label: Text(
                  p.onlyIncomplete ? '미완료 실습' : '전체',
                  style: const TextStyle(color: UiTokens.actionIcon, fontWeight: FontWeight.w700),
                ),
              )
            ],
          ),
          const SizedBox(height: 8),

          if (p.loading && p.sets.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ))
          else if (p.error != null && p.sets.isEmpty)
            Center(child: Text('오류: ${p.error}'))
          else if (p.filteredSets.isEmpty)
              const _Empty(message: '실습 세트가 없습니다.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: p.filteredSets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final s = p.filteredSets[i];
                  return _PracticeTileWithBadge(
                    setId: s['id'],
                    title: s['title'] ?? '',
                    code: s['code'] ?? '',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PracticeDetailPage(setId: s['id'])),
                      );
                    },
                  );
                },
              ),
        ],
      ),
    );

    if (embedded) return content;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('실습', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<PracticeProvider>().refreshAll(),
            tooltip: '새로고침',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await context.read<UserProvider>().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: content,
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ===== 상태 뱃지 복구용 타일(서버에서 최신 상태 1회 조회) =====
class _PracticeTileWithBadge extends StatelessWidget {
  final String setId;
  final String title;
  final String code;
  final VoidCallback onTap;
  const _PracticeTileWithBadge({
    required this.setId,
    required this.title,
    required this.code,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final api = SupabaseService.instance;
    return FutureBuilder<Map<String, dynamic>?>(
      future: api.menteePracticeSetDetail(setId: setId, limit: 1, offset: 0),
      builder: (ctx, snap) {
        String? label; String? grade;
        if (snap.hasData && snap.data != null) {
          final st = snap.data!['current_status'] as String?;
          grade = snap.data!['current_grade'] as String?;
          label = SupabaseService.instance.practiceStatusLabel(st) == '시도 없음' ? null : SupabaseService.instance.practiceStatusLabel(st) ;
        }
        return Stack(
          children: [
            CurriculumTile.practice(
              title: title,
              summary: code,
              badges: const ['실습'],
              onTap: onTap,
            ),
            if (label != null && label.isNotEmpty)
              Positioned(
                top: 10, right: 10,
                child: _practiceBadge(label: label!, grade: grade),
              ),
          ],
        );
      },
    );
  }

  Widget _practiceBadge({required String label, String? grade}) {
    late Color bg, bd, fg; late IconData icon;
    switch (label) {
      case '검토 대기': bg = const Color(0xFFFFF7ED); bd = const Color(0xFFFCCFB3); fg = const Color(0xFFEA580C); icon = Icons.upload_rounded; break;
      case '검토 중':   bg = const Color(0xFFFFF7ED); bd = const Color(0xFFFCCFB3); fg = const Color(0xFFEA580C); icon = Icons.hourglass_bottom_rounded; break;
      case '검토 완료': bg = const Color(0xFFECFDF5); bd = const Color(0xFFB7F3DB); fg = const Color(0xFF059669); icon = Icons.verified_rounded; break;
      default:         bg = const Color(0xFFEFF6FF); bd = const Color(0xFFDBEAFE); fg = const Color(0xFF2563EB); icon = Icons.edit_note_rounded; break;
    }
    final text = (label == '검토 완료' && (grade == 'high' || grade == 'mid' || grade == 'low'))
        ? '$label · ${grade == 'high' ? '상' : grade == 'mid' ? '중' : '하'}'
        : label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, border: Border.all(color: bd), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: fg), const SizedBox(width: 6),
        Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ===== 아래 프로필/현재카드/Empty는 기존 그대로 =====

class _ProfileGauge extends StatelessWidget {
  final String displayName;
  final String? photoUrl;
  final String mentorName;
  final double ratio;
  final String startDate;
  const _ProfileGauge({required this.displayName, required this.photoUrl, required this.mentorName, required this.ratio, required this.startDate});
  @override
  Widget build(BuildContext context) {
    final percent = '${(ratio * 100).round()}%';
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: UiTokens.cardBorder), borderRadius: BorderRadius.circular(18), boxShadow: [UiTokens.cardShadow]),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Row(
        children: [
          Expanded(
            child: Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey[300],
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                child: photoUrl == null ? const Icon(Icons.person, color: Color(0xFF8C96A1)) : null,
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(displayName, style: const TextStyle(color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('멘토 : $mentorName', style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('시작일 : $startDate', style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          SizedBox(
            width: 84, height: 84,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 84, height: 84,
                child: CircularProgressIndicator(
                  value: ratio, strokeWidth: 10,
                  backgroundColor: const Color(0xFFE9EEF6),
                  valueColor: const AlwaysStoppedAnimation(UiTokens.primaryBlue),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(percent, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CurrentAttemptCard extends StatelessWidget {
  final Map<String, dynamic> set;
  final Map<String, dynamic> attempt;
  final VoidCallback onOpen;
  const _CurrentAttemptCard({required this.set, required this.attempt, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final status = SupabaseService.instance.practiceStatusLabel(attempt['status']);
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: UiTokens.cardBorder), borderRadius: BorderRadius.circular(18), boxShadow: [UiTokens.cardShadow]),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.brush_rounded, color: UiTokens.actionIcon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${set['code']} • ${attempt['attempt_no']}회차', style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              _badge(status),
            ]),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('상세 보기', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label) {
    Color bg, bd, fg; IconData icon;
    switch (label) {
      case '검토 대기': bg = const Color(0xFFFFF7ED); bd = const Color(0xFFFCCFB3); fg = const Color(0xFFEA580C); icon = Icons.upload_rounded; break;
      case '검토 중':   bg = const Color(0xFFFFF7ED); bd = const Color(0xFFFCCFB3); fg = const Color(0xFFEA580C); icon = Icons.hourglass_bottom_rounded; break;
      case '검토 완료': bg = const Color(0xFFECFDF5); bd = const Color(0xFFB7F3DB); fg = const Color(0xFF059669); icon = Icons.verified_rounded; break;
      default:         bg = const Color(0xFFEFF6FF); bd = const Color(0xFFDBEAFE); fg = const Color(0xFF2563EB); icon = Icons.edit_note_rounded; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, border: Border.all(color: bd), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 36),
      child: Text(message, style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700)),
    );
  }
}
