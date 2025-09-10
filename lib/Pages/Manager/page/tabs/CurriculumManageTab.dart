// lib/Pages/Manager/page/tabs/CurriculumManageTab.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Common/page/CurriculumDetailPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Manager/page/CurriculumCreatePage.dart';
import 'package:nail/Pages/Common/widgets/CurriculumTile.dart';
import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CurriculumManageTab extends StatefulWidget {
  const CurriculumManageTab({super.key});

  @override
  State<CurriculumManageTab> createState() => _CurriculumManageTabState();
}

class _CurriculumManageTabState extends State<CurriculumManageTab> {
  @override
  void initState() {
    super.initState();
    // 안전망: 이 탭이 처음 열릴 때도 보장적으로 로드 시도
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CurriculumProvider>().ensureLoaded();
    });
  }

  Future<void> _openDetail(CurriculumItem item) async {
    final res = await Navigator.of(context).push<CurriculumDetailResult>(
      MaterialPageRoute(
        builder: (_) => CurriculumDetailPage(
          item: item,
          mode: CurriculumViewMode.adminEdit,
        ),
      ),
    );
    // 삭제/저장 이후 최신화(목록 갱신)
    if (!mounted) return;
    if (res?.deleted == true) {
      // 서버 삭제 연결은 아직 없으므로 목록 재요청으로 동기화
      await context.read<CurriculumProvider>().refresh(force: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('‘${item.title}’이(가) 삭제되었습니다.')),
      );
    } else {
      // 상세에서 goals/resources 저장했다면 목록에도 반영되도록
      await context.read<CurriculumProvider>().refresh(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CurriculumProvider>();
    final items = provider.items;
    final loading = provider.loading;
    final error = provider.error;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_course_add',
        backgroundColor: UiTokens.primaryBlue,
        onPressed: () async {
          final items = context.read<CurriculumProvider>().items;
          final nextWeek = items.isEmpty ? 1 : (items.map((e) => e.week).reduce(max) + 1);

          final res = await Navigator.push<CurriculumCreateResult>(
            context,
            MaterialPageRoute(
              builder: (_) => CurriculumCreatePage(suggestedWeek: nextWeek),
            ),
          );

          if (res != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('‘${res.item.title}’이(가) 생성되었습니다.')),
            );
          }
        },
        icon: const Icon(Icons.add_card_outlined),
        label: const Text('추가'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<CurriculumProvider>().refresh(force: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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

              // 로딩/에러/성공 분기
              if (loading && items.isEmpty) ...[
                const SizedBox(height: 80),
                const Center(child: CircularProgressIndicator()),
              ] else if (error != null && items.isEmpty) ...[
                const SizedBox(height: 40),
                _ErrorBlock(
                  message: error,
                  onRetry: () => context.read<CurriculumProvider>().refresh(force: true),
                ),
              ] else if (items.isEmpty) ...[
                _EmptyBlock(onRetry: () => context.read<CurriculumProvider>().refresh(force: true)),
              ] else ...[
                ListView.separated(
                  itemCount: items.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return CurriculumTile(
                      item: item,
                      onTap: () => _openDetail(item),
                    );
                  },
                ),
                if (loading) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('업데이트 중…', style: TextStyle(color: UiTokens.title)),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyBlock({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UiTokens.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.menu_book_outlined, size: 40, color: UiTokens.actionIcon),
          const SizedBox(height: 8),
          Text('등록된 교육 과정이 없습니다.', style: TextStyle(color: UiTokens.title.withOpacity(0.7), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UiTokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
          const SizedBox(height: 8),
          Text(
            '불러오는 중 오류가 발생했어요',
            style: TextStyle(color: UiTokens.title.withOpacity(0.8), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
