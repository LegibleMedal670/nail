import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/SignatureConfirmPage.dart';
import 'package:nail/Pages/Common/page/SignaturePage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Services/SignatureService.dart';
import 'package:provider/provider.dart';

/// 멘토용 수료 승인 페이지
/// - 멘티의 수료 신청을 확인하고 승인 서명
class CompletionApprovalPage extends StatefulWidget {
  final String menteeId;
  final String menteeName;
  final int theoryCount;
  final int practiceCount;
  final DateTime? menteeSignedAt;

  const CompletionApprovalPage({
    super.key,
    required this.menteeId,
    required this.menteeName,
    required this.theoryCount,
    required this.practiceCount,
    this.menteeSignedAt,
  });

  @override
  State<CompletionApprovalPage> createState() => _CompletionApprovalPageState();
}

class _CompletionApprovalPageState extends State<CompletionApprovalPage> {
  bool _loading = true;
  bool _submitting = false;
  
  DateTime? _menteeSignedAt;
  bool _mentorSigned = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // ✅ 전달받은 멘티 서명 시점 사용
      _menteeSignedAt = widget.menteeSignedAt;
      
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('[CompletionApprovalPage] Failed to load data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _approveCompletion() async {
    if (_submitting) return;

    final user = context.read<UserProvider>().current;
    if (user == null || user.loginKey.isEmpty) {
      _showSnack('사용자 정보를 불러올 수 없습니다.');
      return;
    }

    // 서명 컨펌 페이지로 이동
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => SignatureConfirmPage(
          type: SignatureType.completionMentor,
          data: {
            'menteeName': widget.menteeName,
            'name': user.nickname ?? user.mentorName ?? '멘토',
            'phone': user.phone,
            'theoryCount': widget.theoryCount,
            'practiceCount': widget.practiceCount,
            'approvalDate': DateTime.now().toString().substring(0, 10),
          },
        ),
      ),
    );

    if (result == null || !mounted) return;

    // 서명 데이터 서버에 저장
    setState(() => _submitting = true);

    try {
      final signatureImage = result['signature'];
      
      await SignatureService.instance.signCompletion(
        loginKey: user.loginKey,
        menteeId: widget.menteeId,
        isMentor: true,
        signatureImage: signatureImage,
        phoneNumber: user.phone ?? '',
      );

      if (!mounted) return;
      
      _showSnack('✅ 수료가 승인되었습니다!');
      
      // 페이지 닫기 (변경사항 있음을 알림)
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[CompletionApprovalPage] Failed to approve completion: $e');
      if (!mounted) return;
      
      setState(() => _submitting = false);
      _showSnack('수료 승인 실패: $e');
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
        title: const Text(
          '교육 수료 승인',
          style: TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UiTokens.title),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 안내 메시지
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '멘티가 모든 교육을 완료하고 수료 신청을 했습니다.\n승인 서명을 진행해주세요.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 수료 정보 카드
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: UiTokens.cardBorder),
                      boxShadow: [UiTokens.cardShadow],
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
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors.orange[700],
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '교육생 정보',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: UiTokens.title,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.menteeName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: UiTokens.title.withOpacity(0.6),
                                      fontWeight: FontWeight.w600,
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
                        if (_menteeSignedAt != null) ...[
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.edit,
                            label: '멘티 서명',
                            value: _formatDateTime(_menteeSignedAt),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 승인 버튼
                  if (!_mentorSigned)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _approveCompletion,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle, size: 20),
                        label: Text(
                          _submitting ? '처리 중...' : '수료 승인 서명하기',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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

