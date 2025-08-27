// ... imports
import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/models/curriculum_item.dart';
import 'package:nail/Manager/page/curriculum_detail_page.dart';
import 'package:nail/Manager/widgets/curriculum_tile.dart';

class EducationManageTab extends StatefulWidget {
  final List<CurriculumItem> items;
  const EducationManageTab({super.key, required this.items});

  @override
  State<EducationManageTab> createState() => _EducationManageTabState();
}

class _EducationManageTabState extends State<EducationManageTab> {
  late List<CurriculumItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List<CurriculumItem>.from(widget.items); // 로컬 상태로 복사
  }

  Future<void> _openDetail(CurriculumItem item) async {
    final res = await Navigator.of(context).push<CurriculumDetailResult>(
      MaterialPageRoute(
        builder: (_) => CurriculumDetailPage(item: item),
      ),
    );
    if (res?.deleted == true) {
      setState(() => _items.removeWhere((e) => e.id == item.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('‘${item.title}’이(가) 삭제되었습니다.')),
      );
    }
  }

  void _edit(CurriculumItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('[편집] ${item.title} (상세 화면의 “수정하기” 버튼에서)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_mentee_add',
        backgroundColor: UiTokens.primaryBlue,
        onPressed: (){},
        icon: const Icon(Icons.add_card_outlined),
        label: const Text('추가'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                '교육 과정 목록',
                style: TextStyle(
                  color: UiTokens.title,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListView.separated(
              itemCount: _items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final item = _items[i];
                return CurriculumTile(
                  item: item,
                  onTap: () => _openDetail(item),
                  onEdit: () => _edit(item),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
