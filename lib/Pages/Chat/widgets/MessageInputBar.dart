import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class MessageInputBar extends StatefulWidget {
  final void Function(String text) onSendText;
  final void Function(String localImagePath) onSendImageLocalPath;
  final void Function(String localFilePath, String fileName, int fileBytes) onSendFileLocalPath;
  final void Function(List<String> localImagePaths)? onSendImagesLocalPaths; // 멀티 이미지
  final bool isReplyMode; // 답장 모드 여부

  const MessageInputBar({
    Key? key,
    required this.onSendText,
    required this.onSendImageLocalPath,
    required this.onSendFileLocalPath,
    this.onSendImagesLocalPaths,
    this.isReplyMode = false, // 기본값 false
  }) : super(key: key);

  @override
  State<MessageInputBar> createState() => MessageInputBarState();
}

class MessageInputBarState extends State<MessageInputBar> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _picker = ImagePicker();
  final _focusNode = FocusNode(); // FocusNode 추가
  bool _sending = false;
  bool _panelOpen = false;

  late final AnimationController _ac;
  late final Animation<double> _h; // 0.0~1.0

  void closeExtraPanel() {
    if (_panelOpen) {
      setState(() => _panelOpen = false);
      _ac.reverse();
    }
  }

  /// 입력창에 포커스 (답장 모드 등에서 사용)
  void focusInput() {
    _focusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _h  = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ac.dispose();
    _ctrl.dispose();
    _focusNode.dispose(); // FocusNode도 dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _ctrl.text.trim().isNotEmpty && !_sending;

    return Container(
      color: Colors.white, // ✅ 입력바 배경 흰색 고정
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 입력행
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  // 답장 모드일 때는 + 버튼 숨기기
                  if (!widget.isReplyMode) ...[
                    _PlusButton(onTap: () {
                      setState(() => _panelOpen = !_panelOpen);
                      if (_panelOpen) {
                        FocusScope.of(context).unfocus(); // 패널 열면 키보드 닫기
                        _ac.forward();
                      } else {
                        _ac.reverse();
                      }
                    }),
                    const SizedBox(width: 8),
                  ] else ...[
                    // 답장 모드일 때는 흰색 원으로 대체 (UI 균형 유지)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focusNode, // FocusNode 연결
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: '메세지',
                          border: InputBorder.none,
                        ),
                        onTap: () {
                          if (_panelOpen) {
                            setState(() => _panelOpen = false);
                            _ac.reverse();
                          }
                        },
                        onChanged: (_) => setState((){}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SendButton(enabled: canSend, sending: _sending, onSend: _sendText),
                ],
              ),
            ),

            // ▶ 패널(입력바 아래, 오버플로우 방지)
            SizeTransition(
              sizeFactor: _h,
              axisAlignment: -1.0, // 위쪽에서 펼쳐지는 느낌
              child: ClipRect(
                child: Container(
                  width: double.infinity,
                  height: 160,                // 콘텐츠 고정 높이
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: _buildPlusPanel(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlusPanel(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _PanelAction(
          icon: Icons.photo_library_outlined,
          label: '갤러리',
          onTap: () async {
            // 갤러리: 다중 선택 우선, 실패 시 단일 선택 fallback
            final sent = await _pickImagesGallery();
            if (!sent) {
              await _pickImage(ImageSource.gallery);
            }
          },
        ),
        _PanelAction(
          icon: Icons.photo_camera_outlined,
          label: '카메라',
          onTap: () async { await _pickImage(ImageSource.camera); },
        ),
        _PanelAction(
          icon: Icons.attach_file,
          label: '파일',
          onTap: () async { await _pickFile(); },
        ),
      ],
    );
  }

  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(()=>_sending=true);
    await Future.delayed(const Duration(milliseconds: 120)); // 목업 딜레이
    widget.onSendText(text);
    _ctrl.clear();
    setState(()=>_sending=false);
  }

  /// 갤러리 다중 선택 (최대 10장). 성공적으로 전송 콜백을 호출했으면 true.
  Future<bool> _pickImagesGallery() async {
    closeExtraPanel();
    try {
      final many = await _picker.pickMultiImage(imageQuality: 85);
      if (many.isEmpty) return false;
      final limited = many.take(10).toList(growable: false);
      final paths = <String>[];
      for (final x in limited) {
        final f = File(x.path);
        if (!await f.exists()) continue;
        final size = await f.length();
        if (size > 20 * 1024 * 1024) {
          // 20MB 초과 파일은 스킵
          continue;
        }
        paths.add(x.path);
      }
      if (paths.isEmpty) return false;
      // 1장만 선택된 경우: 기존 단일 이미지 전송 플로우로 처리(큰 이미지 버블)
      if (paths.length == 1) {
        widget.onSendImageLocalPath(paths.first);
        return true;
      }
      if (widget.onSendImagesLocalPaths != null) {
        widget.onSendImagesLocalPaths!(paths);
        return true;
      }
      // 멀티 콜백이 없으면 단일로 순차 전송
      for (final p in paths) {
        widget.onSendImageLocalPath(p);
        await Future.delayed(const Duration(milliseconds: 30));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    closeExtraPanel();
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final f = File(picked.path);
    final size = await f.length();
    if (size > 20 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('20MB 이하 파일만 전송 가능합니다.')));
      return;
    }
    widget.onSendImageLocalPath(picked.path);
  }

  Future<void> _pickFile() async {
    closeExtraPanel();
    final res = await FilePicker.platform.pickFiles(withReadStream: false);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final path = f.path;
    if (path == null) return;
    final size = f.size;
    if (size > 20 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('20MB 이하 파일만 전송 가능합니다.')));
      return;
    }
    widget.onSendFileLocalPath(path, f.name, size);
  }
}

// --- 작은 구성요소들 ---

class _PlusButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlusButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0,2))],
        ),
        alignment: Alignment.center,
        child: const Text('+', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87)),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool sending;
  final VoidCallback onSend;
  const _SendButton({required this.enabled, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? UiTokens.primaryBlue : Colors.grey[300];
    return GestureDetector(
      onTap: (enabled && !sending) ? onSend : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0,2))],
        ),
        alignment: Alignment.center,
        child: sending
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.arrow_upward_sharp, size: 18, color: Colors.white),
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PanelAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0,2))],
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.black87, size: 26),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }
}
