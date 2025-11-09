// lib/Pages/Chat/modals/CreateChatRoomModal.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class CreateChatRoomModal extends StatefulWidget {
  const CreateChatRoomModal({Key? key}) : super(key: key);

  @override
  State<CreateChatRoomModal> createState() => _CreateChatRoomModalState();
}

class _CreateChatRoomModalState extends State<CreateChatRoomModal> {
  final _nameCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(999)),
              ),
              const SizedBox(height: 12),
              const Text('채팅방 생성', style: TextStyle(color: UiTokens.title, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '방 이름',
                  hintText: '예: 공지방, 디자인방',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _creating ? null : () async {
                    final name = _nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('방 이름을 입력하세요')));
                      return;
                    }
                    setState(() => _creating = true);
                    await Future.delayed(const Duration(milliseconds: 400)); // 목업 딜레이

                    // ✅ 서버 연결 시: 여기서 방 생성 RPC 호출 → 반환된 room id/name 사용
                    final created = _MockRoomReturn(id: 'room_${DateTime.now().millisecondsSinceEpoch}', name: name);

                    if (!mounted) return;
                    Navigator.of(context).pop(created.toRoomItem());
                  },
                  child: _creating ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('생성'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockRoomReturn {
  final String id;
  final String name;
  _MockRoomReturn({required this.id, required this.name});

  // 상위 리스트 페이지에서 쓰는 간단한 형태로 반환
  dynamic toRoomItem() {
    return _RoomItemCompat(id: id, name: name);
  }
}

// 리스트 페이지에서 받기 위한 최소 호환 객체
class _RoomItemCompat {
  final String id;
  final String name;
  _RoomItemCompat({required this.id, required this.name});
}