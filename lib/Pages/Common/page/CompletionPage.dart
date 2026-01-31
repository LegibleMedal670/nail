import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/SignatureConfirmPage.dart';
import 'package:nail/Pages/Common/page/SignaturePage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:nail/Providers/PracticeProvider.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Services/SignatureService.dart';
import 'package:provider/provider.dart';

/// 교육 수료 신청 페이지 (멘티용)
/// - 모든 이론 + 실습 완료 후 수료 신청 가능
/// - 서명 -> 멘토 승인 대기
class CompletionPage extends StatefulWidget {

  String mentorName;
  String startedDate;
  String today;

  CompletionPage({super.key, required this.mentorName, required this.startedDate, required this.today});

  @override
  State<CompletionPage> createState() => _CompletionPageState();
}

class _CompletionPageState extends State<CompletionPage> {
  int _theoryCount = 0;
  int _practiceCount = 0;
  bool _loading = true;
  bool _submitting = false;

  String _menteeName = '';
  String _menteePhone = '';
  String _menteeId = '';

  // 서명 상태
  bool _menteeSigned = false;
  bool _mentorSigned = false;
  DateTime? _menteeSignedAt;
  DateTime? _mentorSignedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // 사용자 정보
      final user = context.read<UserProvider>().current;
      _menteeName = user?.nickname ?? '후임';
      _menteePhone = user?.phone ?? '';
      _menteeId = user?.id ?? '';
      final loginKey = user?.loginKey ?? '';

      // 이론 교육 개수
      final curriculumProvider = context.read<CurriculumProvider>();
      _theoryCount = curriculumProvider.items.length;

      // 실습 교육 개수
      final practiceProvider = context.read<PracticeProvider>();
      await practiceProvider.refreshAll(loginKey: loginKey);
      _practiceCount = practiceProvider.sets.length;

      // 수료 서명 상태 조회
      if (loginKey.isNotEmpty) {
        final signatureStatus = await SignatureService.instance.getCompletionSignatureStatus(
          loginKey: loginKey,
        );
        
        if (signatureStatus != null && mounted) {
          _menteeSigned = signatureStatus['mentee_signed'] ?? false;
          _mentorSigned = signatureStatus['mentor_signed'] ?? false;
          _menteeSignedAt = _parseDateTime(signatureStatus['mentee_signed_at']);
          _mentorSignedAt = _parseDateTime(signatureStatus['mentor_signed_at']);
        }
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('[CompletionPage] Failed to load data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _submitCompletionRequest() async {
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
          type: SignatureType.completionMentee,
          data: {
            'name': _menteeName,
            'phone': _menteePhone,
            'theoryCount': _theoryCount,
            'practiceCount': _practiceCount,
            'mentorName': widget.mentorName,
            'startedDate': widget.startedDate,
            'today': widget.today,
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
        menteeId: _menteeId,
        isMentor: false,
        signatureImage: signatureImage,
        phoneNumber: _menteePhone,
      );

      if (!mounted) return;
      
      _showSnack('✅ 수료 서명이 완료되었습니다!');
      
      // 상태 갱신
      await _loadData();
      
      if (!mounted) return;
      
      setState(() => _submitting = false);
      
      // 페이지 닫기 (변경사항 있음을 알림)
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[CompletionPage] Failed to submit completion: $e');
      if (!mounted) return;
      
      setState(() => _submitting = false);
      _showSnack('수료 서명 실패: $e');
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
          '교육 수료',
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
                            '모든 교육을 완료하셨습니다.\n수료 서명을 진행해주세요.',
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
                                    '수료 현황',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: UiTokens.title,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _menteeName,
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
                          value: '$_theoryCount개 완료',
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.assignment,
                          label: '실습 교육',
                          value: '$_practiceCount개 완료',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 서명 상태 표시
                  if (_menteeSigned)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _mentorSigned ? Colors.green[50] : Colors.orange[50],
                        border: Border.all(
                          color: _mentorSigned ? Colors.green[300]! : Colors.orange[300]!,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _mentorSigned ? Icons.check_circle : Icons.hourglass_bottom,
                                color: _mentorSigned ? Colors.green[700] : Colors.orange[700],
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _mentorSigned ? '수료 승인 완료' : '선임 승인 대기 중',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _mentorSigned ? Colors.green[900] : Colors.orange[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '후임 서명: ${_formatDateTime(_menteeSignedAt)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_mentorSigned && _mentorSignedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '선임 승인: ${_formatDateTime(_mentorSignedAt)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  if (!_menteeSigned) ...[
                    // 서명 버튼
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submitCompletionRequest,
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
                            : const Icon(Icons.edit, size: 20),
                        label: Text(
                          _submitting ? '처리 중...' : '수료 서명하기',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
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

