import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/SignaturePage.dart';
import 'package:nail/Pages/Common/page/SignaturePhoneVerifyPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// 서명 전 확인 페이지
class SignatureConfirmPage extends StatefulWidget {
  final SignatureType type;
  final Map<String, dynamic> data;

  const SignatureConfirmPage({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  State<SignatureConfirmPage> createState() => _SignatureConfirmPageState();
}

class _SignatureConfirmPageState extends State<SignatureConfirmPage> {
  bool _agreeEducation = false;
  bool _agreeModification = false;

  String _getTitle() {
    switch (widget.type) {
      case SignatureType.theory:
        return '이론 교육 이수 확인';
      case SignatureType.practiceMentor:
        return '실습 교육 검토 확인';
      case SignatureType.practiceMentee:
        return '실습 교육 이수 확인';
      case SignatureType.completionMentee:
        return '교육 수료 신청 확인';
      case SignatureType.completionMentor:
        return '교육 수료 승인 확인';
    }
  }

  List<MapEntry<String, String>> _getInfoList() {
    switch (widget.type) {
      case SignatureType.theory:
        return [
          MapEntry('과정명', widget.data['moduleName'] ?? '-'),
          MapEntry('이름', widget.data['name'] ?? '-'),
          MapEntry('연락처', _maskPhone(widget.data['phone'])),
          MapEntry('시험 점수', '${widget.data['examScore']}점'),
        ];
      case SignatureType.practiceMentor:
        return [
          MapEntry('실습 과정', widget.data['practiceTitle'] ?? '-'),
          MapEntry('후임', widget.data['menteeName'] ?? '-'),
          MapEntry('선임', widget.data['name'] ?? '-'),
          MapEntry('평가 등급', _gradeLabel(widget.data['grade'])),
        ];
      case SignatureType.practiceMentee:
        return [
          MapEntry('실습 과정', widget.data['practiceTitle'] ?? '-'),
          MapEntry('담당 선임', widget.data['mentorName'] ?? '-'),
          MapEntry('이름', widget.data['name'] ?? '-'),
          MapEntry('연락처', _maskPhone(widget.data['phone'])),
          MapEntry('선임 평가', _gradeLabel(widget.data['grade'])),
        ];
      case SignatureType.completionMentee:
        return [
          MapEntry('이름', widget.data['name'] ?? '-'),
          MapEntry('담당 선임', widget.data['mentorName'] ?? '-'),
          MapEntry('연락처', _maskPhone(widget.data['phone'])),
          MapEntry('이론 교육', '${widget.data['theoryCount']}개 완료'),
          MapEntry('실습 교육', '${widget.data['practiceCount']}개 완료'),
          MapEntry('교육 시작일', '${widget.data['startedDate']}'),
          MapEntry('교육 종료일', '${widget.data['today']}'),
        ];
      case SignatureType.completionMentor:
        return [
          MapEntry('교육생', widget.data['menteeName'] ?? '-'),
          MapEntry('선임', widget.data['name'] ?? '-'),
          MapEntry('이론 교육', '${widget.data['theoryCount']}개 완료'),
          MapEntry('실습 교육', '${widget.data['practiceCount']}개 완료'),
        ];
    }
  }

  String _maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '-';
    if (phone.length < 8) return phone;
    return '${phone.substring(0, 3)}-****-${phone.substring(phone.length - 4)}';
  }

  String _gradeLabel(String? grade) {
    switch (grade) {
      case 'high':
        return '상';
      case 'mid':
        return '중';
      case 'low':
        return '하';
      default:
        return '미평가';
    }
  }

  Future<void> _onConfirm() async {
    if (!_agreeEducation || !_agreeModification) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('필수 동의 항목에 모두 동의해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 전화번호 인증 페이지로 이동
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SignaturePhoneVerifyPage(
          expectedPhone: widget.data['phone'] ?? '',
        ),
      ),
    );

    if (verified != true || !mounted) return;

    // 서명 페이지로 이동
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SignaturePage(
          type: widget.type,
          data: widget.data,
        ),
      ),
    );

    if (result != null && mounted) {
      // 서명 완료 결과를 이전 화면으로 전달
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoList = _getInfoList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_getTitle(), style: TextStyle(
          color: UiTokens.title,
          fontWeight: FontWeight.w700,
        ),),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UiTokens.title),
          tooltip: '뒤로가기',
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 안내 문구
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
                      '서명 전 아래 내용을 확인해주세요',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 요약 정보 카드
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: UiTokens.cardBorder),
                boxShadow: [UiTokens.cardShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      // color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            color: UiTokens.primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          '요약 정보',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: infoList.asMap().entries.map((entry) {
                        final isLast = entry.key == infoList.length - 1;
                        final item = entry.value;
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    item.key,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: UiTokens.title,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.value,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!isLast) ...[
                              const SizedBox(height: 12),
                              Divider(height: 1, color: Colors.grey[200]),
                              const SizedBox(height: 12),
                            ],
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 유의사항
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: UiTokens.cardBorder),
                boxShadow: [UiTokens.cardShadow],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, 
                        color: Colors.orange[700], 
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '유의사항',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...[
                    '본 서명은 교육(영상 시청, 시험 및 실습) 완료 확인을 의미합니다.',
                    '서명 완료 후에는 수정/취소가 제한될 수 있습니다.',
                    '서명 정보는 분쟁 대응을 위해 일정 기간 보관됩니다.',
                  ].map(
                    (text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[600],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 동의 체크박스
            CheckboxListTile(
              value: _agreeEducation,
              onChanged: (val) => setState(() => _agreeEducation = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '(필수) 위 교육 내용을 확인했으며 자발적으로 서명합니다.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),

            CheckboxListTile(
              value: _agreeModification,
              onChanged: (val) =>
                  setState(() => _agreeModification = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '(필수) 서명 완료 후 수정이 제한될 수 있음을 이해합니다.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),

            const SizedBox(height: 24),

            // 하단 버튼
            FilledButton(
              onPressed: (_agreeEducation && _agreeModification)
                  ? _onConfirm
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: UiTokens.primaryBlue,
              ),
              child: const Text(
                '서명하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '취소',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

