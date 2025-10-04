import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/AdminMentorDetailProvider.dart';
import 'package:provider/provider.dart';
import 'package:nail/Services/SupabaseService.dart';

class AssignMenteesPage extends StatefulWidget {
  final String targetMentorId;
  const AssignMenteesPage({super.key, required this.targetMentorId});

  @override
  State<AssignMenteesPage> createState() => _AssignMenteesPageState();
}

class _AssignMenteesPageState extends State<AssignMenteesPage> {
  final _api = SupabaseService.instance;
  final _selected = <String>{};
  final _searchCtl = TextEditingController();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // TODO: 아래 RPC 이름/파라미터를 실제로 만든 것과 맞춰주세요.
      final res = await _api.adminListUnassignedMentees(
        search: _searchCtl.text,
        limit: 300,
        offset: 0,
      );
      setState(() {
        _rows = res;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.findAncestorWidgetOfExactType<ChangeNotifierProvider<MentorDetailProvider>>();

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
        title: const Text('멘티 배정하기', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading && _rows.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: UiTokens.title)))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: '이름/코드 검색',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF7F9FC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemBuilder: (_, i) {
                final r = _rows[i];
                final id = (r['id'] ?? '').toString();
                final name = (r['nickname'] ?? '').toString();
                final photoUrl = r['photo_url'] as String?;
                final checked = _selected.contains(id);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (checked) _selected.remove(id);
                      else _selected.add(id);
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: UiTokens.cardBorder),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [UiTokens.cardShadow],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null ? const Icon(Icons.person, color: Color(0xFF8C96A1)) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Checkbox(value: checked, onChanged: (_) {
                          setState(() {
                            if (checked) _selected.remove(id); else _selected.add(id);
                          });
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton(
            onPressed: _selected.isEmpty ? null : () async {
              final cnt = await SupabaseService.instance.adminAssignMenteesToMentor(
                mentorId: widget.targetMentorId,
                menteeIds: _selected.toList(),
              );
              if (!mounted) return;
              Navigator.of(context).pop<int>(cnt);
            },
            style: FilledButton.styleFrom(
              backgroundColor: UiTokens.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_selected.isEmpty ? '선택 후 배정' : '${_selected.length}명 배정'),
          ),
        ),
      ),
    );
  }
}
