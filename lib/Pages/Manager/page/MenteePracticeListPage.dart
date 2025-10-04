import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/MenteeBrief.dart';
import 'package:nail/Pages/Manager/models/PracticeAttempt.dart';
import 'package:nail/Providers/AdminMentorDetailProvider.dart';
import 'package:provider/provider.dart';

class MenteePracticeListPage extends StatefulWidget {
  final String mentorId;
  final MenteeBrief mentee;
  final Future<bool> Function() onUnassign; // 성공 시 true
  const MenteePracticeListPage({
    super.key,
    required this.mentorId,
    required this.mentee,
    required this.onUnassign,
  });

  @override
  State<MenteePracticeListPage> createState() => _MenteePracticeListPageState();
}

class _MenteePracticeListPageState extends State<MenteePracticeListPage> {
  List<PracticeAttempt> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtDateTime(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')} '
          '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = context.read<MentorDetailProvider>();
      final rows = await p.listAttempts(widget.mentee.id);
      setState(() { _items = rows; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mentee;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: UiTokens.title,
          ),
          tooltip: '뒤로가기',
          onPressed: () async {
            Navigator.pop(context);
          },
        ),
        title: Text(m.name, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '배정 해제',
            icon: const Icon(Icons.link_off_rounded, color: UiTokens.actionIcon),
            // onPressed: () async {
            //   final ok = await showDialog<bool>(
            //     context: context,
            //     builder: (_) => AlertDialog(
            //       title: const Text('배정 해제'),
            //       content: Text('“${m.name}” 멘티를 이 멘토에서 해제할까요?'),
            //       actions: [
            //         TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('취소')),
            //         FilledButton(onPressed: () => Navigator.pop(context,true), child: const Text('해제')),
            //       ],
            //     ),
            //   );
            //   if (ok == true) {
            //     final success = await widget.onUnassign();
            //     if (!mounted) return;
            //     if (success) Navigator.of(context).pop();
            //   }
            // },
            onPressed: (){
              print(_error);
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: UiTokens.title)))
          : _items.isEmpty
          ? const Center(child: Text('제출된 실습이 없습니다'))
          : ListView.separated(
        itemCount: _items.length,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final a = _items[i];
          final status = a.status == 'pending' ? '대기' : '완료';
          final color = a.status == 'pending' ? const Color(0xFF0EA5E9) : const Color(0xFF059669);
          final days = a.feedbackDays?.toStringAsFixed(1);

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: UiTokens.cardBorder),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [UiTokens.cardShadow],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      border: Border.all(color: color.withOpacity(0.25)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                  ),
                  const Spacer(),
                  Text('#${a.attemptNo}  ${a.setCode}',
                      style: TextStyle(color: UiTokens.title.withOpacity(0.7), fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text('제출: ${_fmtDateTime(a.submittedAt)}',
                  style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700)),
              if (a.reviewedAt != null) ...[
                const SizedBox(height: 2),
                Text('검수: ${_fmtDateTime(a.reviewedAt!)}  (${days ?? '—'}일)',
                    style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 8),
              if (a.images.isNotEmpty)
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: a.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, j) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(a.images[j], width: 84, height: 84, fit: BoxFit.cover),
                    ),
                  ),
                ),
              if ((a.feedbackText ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(a.feedbackText!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ]),
          );
        },
      ),
    );
  }
}
