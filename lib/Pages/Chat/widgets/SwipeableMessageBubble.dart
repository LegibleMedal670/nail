// lib/Pages/Chat/widgets/SwipeableMessageBubble.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 왼쪽 스와이프로 답장 모드를 활성화하는 메시지 버블 래퍼
class SwipeableMessageBubble extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool canReply;
  final bool isMine;

  const SwipeableMessageBubble({
    Key? key,
    required this.child,
    required this.onReply,
    this.canReply = true,
    this.isMine = false,
  }) : super(key: key);

  @override
  State<SwipeableMessageBubble> createState() => _SwipeableMessageBubbleState();
}

class _SwipeableMessageBubbleState extends State<SwipeableMessageBubble> {
  double _dragOffset = 0.0;
  static const double _dragThreshold = 45.0; // 답장 활성화 임계값
  static const double _maxDragDistance = 45.0; // 최대 이동 거리
  bool _hasTriggered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.canReply) return widget.child;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          // 오른쪽에서 왼쪽으로 스와이프만 허용
          final newOffset = _dragOffset + details.delta.dx;
          _dragOffset = newOffset.clamp(-_maxDragDistance, 0.0);

          // 임계값 도달 시 햅틱 피드백 (1회만)
          if (_dragOffset <= -_dragThreshold && !_hasTriggered) {
            HapticFeedback.mediumImpact();
            _hasTriggered = true;
          }

          // 임계값 미달로 돌아오면 플래그 리셋
          if (_dragOffset > -_dragThreshold && _hasTriggered) {
            _hasTriggered = false;
          }
        });
      },
      onHorizontalDragEnd: (details) {
        // 임계값 이상 스와이프 시 답장 모드 활성화
        if (_dragOffset <= -_dragThreshold) {
          widget.onReply();
        }

        // 애니메이션으로 원위치
        setState(() {
          _dragOffset = 0.0;
          _hasTriggered = false;
        });
      },
      onHorizontalDragCancel: () {
        setState(() {
          _dragOffset = 0.0;
          _hasTriggered = false;
        });
      },
      child: Stack(
        children: [
          // 답장 아이콘 배경
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(
                  left: widget.isMine ? 16 : 0,
                  right: widget.isMine ? 0 : 16,
                ),
                child: AnimatedOpacity(
                  opacity: _dragOffset < -20 ? ((-_dragOffset) / _dragThreshold).clamp(0.0, 1.0) : 0.0,
                  duration: Duration(milliseconds: 100),
                  child: Icon(
                    Icons.reply,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          // 메시지 버블 (이동)
          AnimatedContainer(
            duration: _dragOffset == 0 ? Duration(milliseconds: 200) : Duration.zero,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
