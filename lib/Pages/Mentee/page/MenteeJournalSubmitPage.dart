import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/SupabaseService.dart';

class MenteeJournalSubmitPage extends StatefulWidget {
  const MenteeJournalSubmitPage({super.key});

  @override
  State<MenteeJournalSubmitPage> createState() => _MenteeJournalSubmitPageState();
}

class _MenteeJournalSubmitPageState extends State<MenteeJournalSubmitPage> {
  final _textController = TextEditingController();
  final List<XFile> _photos = [];
  bool _uploading = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    // 다중 선택
    final List<XFile> picked = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (picked.isNotEmpty) {
      setState(() {
        // 최대 5장 제한 (기존 + 신규)
        final remaining = 5 - _photos.length;
        if (remaining <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진은 최대 5장까지 첨부할 수 있습니다.')));
          return;
        }
        
        if (picked.length > remaining) {
          _photos.addAll(picked.take(remaining));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진은 최대 5장까지만 추가됩니다.')));
        } else {
          _photos.addAll(picked);
        }
      });
    }
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('내용이나 사진을 입력해주세요.')));
      return;
    }

    setState(() => _uploading = true);
    try {
      // 1. 사진 업로드
      final List<String> uploadedPaths = [];
      for (final photo in _photos) {
        final path = await SupabaseService.instance.uploadJournalPhoto(File(photo.path));
        uploadedPaths.add(path);
      }

      // 2. RPC 호출
      await SupabaseService.instance.menteeSubmitJournalEntry(
        content: text,
        photos: uploadedPaths,
      );

      if (!mounted) return;
      Navigator.pop(context, true); // 성공 반환
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('제출 실패: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: UiTokens.title),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('일지 작성', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
            child: FilledButton(
              onPressed: _uploading ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _uploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('제출', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('오늘의 학습 내용을 기록해주세요.', style: TextStyle(color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('사진은 최대 5장까지 첨부 가능합니다.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          const SizedBox(height: 24),
          TextField(
            controller: _textController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: '오늘 배운 내용, 어려웠던 점, 질문 등을 자유롭게 적어주세요.',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),
          const Text('사진 첨부', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._photos.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(image: FileImage(File(file.path)), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => setState(() => _photos.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_photos.length < 5)
                InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(child: Icon(Icons.add_a_photo_rounded, color: UiTokens.actionIcon)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

