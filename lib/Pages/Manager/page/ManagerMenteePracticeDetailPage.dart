import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/widgets/SortBottomSheet.dart';
import 'package:nail/Pages/Mentor/page/AttemptReviewPage.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 필터 옵션 (멘토 페이지와 동일)
enum _AdminFilter { all, done, notDone }

/// 관리자용: 특정 멘티의 실습 현황(세트 리스트 + 최근 시도 요약) 보기
class ManagerMenteePracticeDetailPage extends StatefulWidget {
  final String menteeId;
  final String menteeName;
  final String? menteePhotoUrl;
  final DateTime? joinedAt;

  const ManagerMenteePracticeDetailPage({
    super.key,
    required this.menteeId,
    required this.menteeName,
    this.menteePhotoUrl,
    this.joinedAt,
  });

  @override
  State<ManagerMenteePracticeDetailPage> createState() => _ManagerMenteePracticeDetailPageState();
}

class _ManagerMenteePracticeDetailPageState extends State<ManagerMenteePracticeDetailPage> {
  bool _loading = true;
  String? _error;

  _AdminFilter _filter = _AdminFilter.all;

  /// 서버에서 내려오는 형태(멘토 페이지와 같은 포맷 가정)
  /// {
  ///   set_id, set_code, set_title,
  ///   attempted: bool,
  ///   last_status: 'submitted'|'reviewed'|null,
  ///   last_grade: 'high'|'mid'|'low'|null,
  ///   last_reviewed_at: DateTime? (검토 완료면),
  ///   last_attempt_id: String? (있으면 상세로 이동)
  /// }
  List<Map<String, dynamic>> _sets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = SupabaseService.instance;

      // ✅ 관리자용 RPC 호출 (프로젝트에서 쓰는 실제 함수명으로 치환해도 됨)
      //    ex) adminFetchMenteeSets / adminListMenteeSetsSummary 등
      final list = await api.adminFetchMenteeSets(
        menteeId: widget.menteeId,
        limit: 200,
        offset: 0,
      );

      setState(() {
        _sets = List<Map<String, dynamic>>.from(list);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_AdminFilter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortBottomSheet<_AdminFilter>(
        title: '필터',
        current: _filter,
        options: const [
          SortOption(value: _AdminFilter.all,     label: '전체',   icon: Icons.list),
          SortOption(value: _AdminFilter.done,    label: '완료',   icon: Icons.verified_rounded),
          SortOption(value: _AdminFilter.notDone, label: '미완료', icon: Icons.pending_actions_rounded),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _filter = result);
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case _AdminFilter.done:
        return _sets.where((e) => (e['attempted'] == true) && (e['last_status'] == 'reviewed')).toList();
      case _AdminFilter.notDone:
        return _sets.where((e) => e['attempted'] != true).toList();
      default:
        return _sets;
    }
  }

  int get _doneCount => _sets.where((e) => e['last_status'] == 'reviewed').length;
  int get _totalCount => _sets.length;
  double get _progress => _totalCount == 0 ? 0.0 : _doneCount / max(1, _totalCount);

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('멘티 실습 현황', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          tooltip: '뒤로가기',
          icon: const Icon(Icons.arrow_back, color: UiTokens.title),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded, color: UiTokens.title),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? _Error(message: _error!, onRetry: _load)
          : RefreshIndicator(
        color: UiTokens.primaryBlue,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _HeaderCard(
              name: widget.menteeName,
              photoUrl: widget.menteePhotoUrl,
              joinedText: widget.joinedAt != null ? _fmtDate(widget.joinedAt!) : null,
              done: _doneCount, total: _totalCount, progress: _progress,
            ),
            const SizedBox(height: 12),
            _FilterBar(filter: _filter, onOpenFilter: _openFilterSheet),
            const SizedBox(height: 8),
            if (_filtered.isEmpty)
              const _Empty(message: '표시할 실습이 없습니다.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final it = _filtered[i];
                  final code = '${it['set_code'] ?? ''}';
                  final title = '${it['set_title'] ?? ''}';
                  final attempted = it['attempted'] == true;
                  final status = it['last_status'] as String?;
                  final grade  = it['last_grade'] as String?;
                  final reviewedAt = it['last_reviewed_at'];
                  final attemptId  = it['last_attempt_id']?.toString();

                  return _SetTile(
                    code: code,
                    title: title,
                    attempted: attempted,
                    status: status,
                    grade: grade,
                    reviewedAt: reviewedAt,
                    onOpen: attemptId == null
                        ? null
                        : () async {
                      // ⛑️ 관리자 키는 이미 SupabaseService.instance.loginKey에 들어있다고 가정
                      final adminKey = SupabaseService.instance.adminKey ?? '';
                      print(adminKey);
                      await Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => AttemptReviewPage(
                            mentorLoginKey: adminKey, // 파라미터명만 mentorLoginKey일 뿐, 키 문자열이면 OK
                            attemptId: attemptId,
                          ),
                        ),
                      );
                      if (!ctx.mounted) return;
                      await _load(); // 돌아오면 목록 갱신
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// ===== 헤더(프로필 + 가입일 + 진행률: 원형 게이지) =====
class _HeaderCard extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String? joinedText;
  final int done;
  final int total;
  final double progress;

  const _HeaderCard({
    required this.name,
    required this.photoUrl,
    required this.joinedText,
    required this.done,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final percentText = '${(clamped * 100).round()}%';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Row(
        children: [
          // 프로필/가입일
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: (photoUrl == null || photoUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Color(0xFF8C96A1))
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: UiTokens.title,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      joinedText != null ? '가입일: $joinedText' : '멘티 정보',
                      style: TextStyle(
                        color: UiTokens.title.withOpacity(0.6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 원형 진행 게이지
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CircularProgressIndicator(
                    value: clamped,
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFFE9EEF6),
                    valueColor: const AlwaysStoppedAnimation(UiTokens.primaryBlue),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  percentText,
                  style: const TextStyle(
                    color: UiTokens.title,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== 필터 바 =====
class _FilterBar extends StatelessWidget {
  final _AdminFilter filter;
  final VoidCallback onOpenFilter;

  const _FilterBar({required this.filter, required this.onOpenFilter});

  @override
  Widget build(BuildContext context) {
    String label;
    switch (filter) {
      case _AdminFilter.done: label = '완료'; break;
      case _AdminFilter.notDone: label = '미완료'; break;
      default: label = '전체';
    }

    return Row(
      children: [
        Text('실습 목록',
            style: const TextStyle(color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800)),
        const Spacer(),
        TextButton.icon(
          onPressed: onOpenFilter,
          icon: const Icon(Icons.filter_list_rounded, color: UiTokens.actionIcon, size: 18),
          label: Text(label,
              style: const TextStyle(color: UiTokens.actionIcon, fontSize: 14, fontWeight: FontWeight.w700)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

/// ===== 세트 타일 =====
class _SetTile extends StatelessWidget {
  final String code;
  final String title;
  final bool attempted;
  final String? status; // submitted/reviewed/null
  final String? grade;  // high/mid/low
  final dynamic reviewedAt; // DateTime/String?
  final VoidCallback? onOpen;

  const _SetTile({
    required this.code,
    required this.title,
    required this.attempted,
    required this.status,
    required this.grade,
    required this.reviewedAt,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final waiting = status == 'submitted';
    final reviewed = status == 'reviewed';

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: UiTokens.cardBorder),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [UiTokens.cardShadow],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_outlined, color: UiTokens.actionIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$code • $title',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Row(children: [
                if (!attempted)
                  _Chip(label: '미완료', bg: const Color(0xFFEFF6FF), bd: const Color(0xFFDBEAFE), fg: const Color(0xFF2563EB), icon: Icons.remove_circle_outline)
                else if (waiting)
                  _Chip(label: '검토 대기', bg: const Color(0xFFFFF7ED), bd: const Color(0xFFFCCFB3), fg: const Color(0xFFEA580C), icon: Icons.hourglass_bottom_rounded)
                else if (reviewed)
                    _GradeChip(grade: grade ?? 'low'),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(onOpen == null ? Icons.lock_outline : Icons.chevron_right_rounded,
              color: UiTokens.actionIcon),
        ]),
      ),
    );
  }
}

/// 상태 칩
class _Chip extends StatelessWidget {
  final String label;
  final Color bg, bd, fg;
  final IconData icon;
  const _Chip({required this.label, required this.bg, required this.bd, required this.fg, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, border: Border.all(color: bd), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg), const SizedBox(width: 4),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    );
  }
}

/// 등급 칩
class _GradeChip extends StatelessWidget {
  final String grade; // high|mid|low
  const _GradeChip({required this.grade});
  @override
  Widget build(BuildContext context) {
    late Color bg, bd, fg; late String label; late IconData icon;
    switch (grade) {
      case 'high': bg = const Color(0xFFECFDF5); bd = const Color(0xFFB7F3DB); fg = const Color(0xFF059669); label = '상'; icon = Icons.trending_up_rounded; break;
      case 'mid':  bg = const Color(0xFFF1F5F9); bd = const Color(0xFFE2E8F0); fg = const Color(0xFF64748B); label = '중'; icon = Icons.horizontal_rule_rounded; break;
      default:     bg = const Color(0xFFFFFBEB); bd = const Color(0xFFFEF3C7); fg = const Color(0xFFB45309); label = '하'; icon = Icons.trending_down_rounded; break;
    }
    return _Chip(label: label, bg: bg, bd: bd, fg: fg, icon: icon);
  }
}

/// 공통 비어있음/에러
class _Empty extends StatelessWidget {
  final String message;
  const _Empty({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 40, 12, 20),
      child: Center(child: Text(message,
          style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700))),
    );
  }
}

class _Error extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(message, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: onRetry,
        style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
        child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    ]));
  }
}
