import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/SignatureConfirmPage.dart';
import 'package:nail/Pages/Common/page/SignaturePage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:provider/provider.dart';

/// 교육 수료 페이지
/// - 멘티가 먼저 서명
/// - 멘토가 확인 후 승인 서명
class CompletionPage extends StatefulWidget {
  final String menteeId;
  final String? menteeName;
  final int theoryCount;
  final int practiceCount;
  final int totalHours;

  const CompletionPage({
    super.key,
    required this.menteeId,
    this.menteeName,
    this.theoryCount = 0,
    this.practiceCount = 0,
    this.totalHours = 0,
  });

  @override
  State<CompletionPage> createState() => _CompletionPageState();
}

class _CompletionPageState extends State<CompletionPage> {
  Uint8List? _menteeSignature;
  String? _menteeSignatureTime;
  bool _mentorApproved = false;
  Uint8List? _mentorSignature;
  String? _mentorSignatureTime;

  bool get _canMentorApprove => _menteeSignature != null && !_mentorApproved;

  Future<void> _openMenteeSignature() async {
    final user = context.read<UserProvider>().current;
    if (user == null) {
      _showSnack('사용자 정보를 불러올 수 없습니다.');
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => SignatureConfirmPage(
          type: SignatureType.completionMentee,
          data: {
            'name': user.nickname,
            'phone': user.phone,
            'theoryCount': widget.theoryCount,
            'practiceCount': widget.practiceCount,
            'totalHours': widget.totalHours,
          },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _menteeSignature = result['signature'] as Uint8List?;
        _menteeSignatureTime = result['timestamp'] as String?;
      });
      _showSnack('✅ 멘티 서명이 완료되었습니다!');
    }
  }

  Future<void> _openMentorSignature() async {
    if (!_canMentorApprove) return;

    final user = context.read<UserProvider>().current;
    if (user == null) {
      _showSnack('사용자 정보를 불러올 수 없습니다.');
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => SignatureConfirmPage(
          type: SignatureType.completionMentor,
          data: {
            'menteeName': widget.menteeName ?? '멘티',
            'name': user.nickname,
            'theoryCount': widget.theoryCount,
            'practiceCount': widget.practiceCount,
            'approvalDate': DateTime.now().toString().substring(0, 10),
          },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _mentorApproved = true;
        _mentorSignature = result['signature'] as Uint8List?;
        _mentorSignatureTime = result['timestamp'] as String?;
      });
      _showSnack('✅ 멘토 승인 서명이 완료되었습니다!');

      // TODO: 서버에 수료 정보 저장
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('교육 수료'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 수료 정보 카드
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.school,
                          color: Colors.green[700],
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '교육 수료 신청',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.menteeName ?? '멘티',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.video_library,
                    label: '이론 교육',
                    value: '${widget.theoryCount}개 완료',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.assignment,
                    label: '실습 교육',
                    value: '${widget.practiceCount}개 완료',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.access_time,
                    label: '총 교육 시간',
                    value: '${widget.totalHours}시간',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 멘티 서명 섹션
            _SignatureSection(
              title: '1. 멘티 서명',
              subtitle: '교육을 완료했음을 확인합니다.',
              signature: _menteeSignature,
              signatureTime: _menteeSignatureTime,
              onSign: _menteeSignature == null ? _openMenteeSignature : null,
              buttonText: '서명하기',
            ),

            const SizedBox(height: 16),

            // 멘토 승인 섹션
            _SignatureSection(
              title: '2. 멘토 승인',
              subtitle: '교육 수료를 승인합니다.',
              signature: _mentorSignature,
              signatureTime: _mentorSignatureTime,
              onSign: _canMentorApprove ? _openMentorSignature : null,
              buttonText: '승인 서명',
              isDisabled: !_canMentorApprove,
              disabledReason: _menteeSignature == null
                  ? '멘티 서명을 먼저 완료해주세요.'
                  : (_mentorApproved ? '승인 완료' : null),
            ),

            const SizedBox(height: 24),

            // 완료 안내
            if (_menteeSignature != null && _mentorApproved)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 32),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '교육 수료가 승인되었습니다!\n수료증은 마이페이지에서 확인할 수 있습니다.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _SignatureSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Uint8List? signature;
  final String? signatureTime;
  final VoidCallback? onSign;
  final String buttonText;
  final bool isDisabled;
  final String? disabledReason;

  const _SignatureSection({
    required this.title,
    required this.subtitle,
    this.signature,
    this.signatureTime,
    this.onSign,
    this.buttonText = '서명하기',
    this.isDisabled = false,
    this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSigned = signature != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSigned
              ? Colors.green[300]!
              : (isDisabled ? Colors.grey[300]! : UiTokens.cardBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSigned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '완료',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isSigned) ...[
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Image.memory(signature!, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Text(
              '서명 완료: ${signatureTime?.substring(0, 19) ?? ''}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onSign,
                style: FilledButton.styleFrom(
                  backgroundColor: isDisabled
                      ? Colors.grey[300]
                      : UiTokens.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  isDisabled ? Icons.lock : Icons.edit,
                  size: 20,
                ),
                label: Text(
                  disabledReason ?? buttonText,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDisabled ? Colors.grey[700] : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

