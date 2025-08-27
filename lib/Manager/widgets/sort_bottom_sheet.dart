import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';

/// 선택지 모델 (제네릭)
class SortOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  const SortOption({required this.value, required this.label, this.icon});
}

/// 어디서나 쓰는 공용 정렬 바텀시트
class SortBottomSheet<T> extends StatelessWidget {
  final String title;
  final T current;
  final List<SortOption<T>> options;

  const SortBottomSheet({
    super.key,
    required this.title,
    required this.current,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    Widget item(SortOption<T> opt) {
      final selected = opt.value == current;
      return InkWell(
        onTap: () => Navigator.of(context).pop<T>(opt.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              if (opt.icon != null) ...[
                Icon(opt.icon, size: 20, color: UiTokens.actionIcon),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  opt.label,
                  style: TextStyle(
                    color: UiTokens.title,
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.check_rounded,
                size: 22,
                color: selected ? UiTokens.primaryBlue : const Color(0xFFD6DADF),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // 드래그 핸들
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE6EAF0),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          // 제목
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  color: UiTokens.title,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 항목들
          for (final opt in options) item(opt),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
