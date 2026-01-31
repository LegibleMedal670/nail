import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/widgets/SortBottomSheet.dart';
import 'package:nail/Pages/Mentor/page/AttemptReviewPage.dart';
import 'package:nail/Providers/MentorProvider.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 필터 옵션
enum _Filter { all, done, notDone }

/// 선임가 특정 후임의 실습 현황을 보는 상세 페이지
class MentorMenteeDetailPage extends StatefulWidget {
  final String mentorLoginKey;
  final String menteeId;
  final String menteeName;
  final String? menteePhotoUrl;
  final DateTime? joinedAt;

  const MentorMenteeDetailPage({
    super.key,
    required this.mentorLoginKey,
    required this.menteeId,
    required this.menteeName,
    this.menteePhotoUrl,
    this.joinedAt,
  });

  @override
  State<MentorMenteeDetailPage> createState() => _MentorMenteeDetailPageState();
}

class _MentorMenteeDetailPageState extends State<MentorMenteeDetailPage> {
  bool _loading = true;
  String? _error;

  _Filter _filter = _Filter.all;

  /// 전체 세트 목록 + 최근 시도 요약
  /// 각 row 예시:
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
    // mentor login key 주입
    SupabaseService.instance.loginKey ??= widget.mentorLoginKey;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = SupabaseService.instance;

      // ✅ 서버에서 한 번에 내려주는 RPC가 있으면 그걸 쓰세요.
      //    없으면 임시로 만들어둔 서비스 함수를 사용하세요.
      //
      // 기대 포맷은 상단 _sets 주석 참고.
      final list = await api.fetchMenteeSetsForMentor(
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
    final result = await showModalBottomSheet<_Filter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortBottomSheet<_Filter>(
        title: '필터',
        current: _filter,
        options: const [
          SortOption(value: _Filter.all,     label: '전체',   icon: Icons.list),
          SortOption(value: _Filter.done,    label: '완료',   icon: Icons.verified_rounded),
          SortOption(value: _Filter.notDone, label: '미완료', icon: Icons.pending_actions_rounded),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _filter = result);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case _Filter.done:
        return _sets.where((e) => (e['attempted'] == true) && (e['last_status'] == 'reviewed')).toList();
      case _Filter.notDone:
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
    final p = context.watch<MentorProvider>(); // 같은 인스턴스 사용 가정

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('후임 상세', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
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
            _FilterBar(
              filter: _filter,
              onOpenFilter: _openFilterSheet,
            ),
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
                      // 같은 Provider 인스턴스 전달 (중복 인스턴스 방지)
                      final mentorProvider = ctx.read<MentorProvider>();
                      await Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: mentorProvider,
                            child: AttemptReviewPage(
                              mentorLoginKey: widget.mentorLoginKey,
                              attemptId: attemptId,
                            ),
                          ),
                        ),
                      );
                      if (!ctx.mounted) return;
                      // 돌아오면 KPI/큐/리스트 갱신
                      mentorProvider.refreshKpi();
                      // 세트 목록도 갱신(진행률, 상태 변경 반영)
                      await _load();
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

/// ===== 헤더(프로필 + 가입일 + 진행률) =====
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
      child: Column(
        children: [
          Row(
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
                          joinedText != null ? '가입일: $joinedText' : '후임 정보',
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
        ],
      ),
    );
  }
}


/// ===== 필터 바 =====
class _FilterBar extends StatelessWidget {
  final _Filter filter;
  final VoidCallback onOpenFilter;

  const _FilterBar({required this.filter, required this.onOpenFilter});

  @override
  Widget build(BuildContext context) {
    String label;
    switch (filter) {
      case _Filter.done: label = '완료'; break;
      case _Filter.notDone: label = '미완료'; break;
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
