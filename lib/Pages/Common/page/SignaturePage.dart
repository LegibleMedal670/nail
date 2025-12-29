import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:signature/signature.dart';

enum SignatureType {
  theory,           // 이론 교육 - 멘티만
  practiceMentor,   // 실습 교육 - 멘토
  practiceMentee,   // 실습 교육 - 멘티
  completionMentee, // 교육 수료 - 멘티
  completionMentor, // 교육 수료 - 멘토
}

class SignaturePage extends StatefulWidget {
  final SignatureType type;
  final Map<String, dynamic> data;

  const SignaturePage({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {
  late SignatureController _controller;
  final GlobalKey _canvasKey = GlobalKey();
  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.transparent, // 투명 배경
    );
    _controller.addListener(() {
      setState(() {
        _isEmpty = _controller.isEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getTitle() {
    switch (widget.type) {
      case SignatureType.theory:
        return '이론 교육 이수 확인서';
      case SignatureType.practiceMentor:
        return '실습 교육 검토 확인서';
      case SignatureType.practiceMentee:
        return '실습 교육 이수 확인서';
      case SignatureType.completionMentee:
        return '교육 수료 신청서';
      case SignatureType.completionMentor:
        return '교육 수료 승인서';
    }
  }

  /// ✅ 연락처 표시용 포맷(010-0000-0000)
  /// - 입력이 '01022222222' / '010-2222-2222' / '+82 10 2222 2222' 등이어도 대응
  /// - 숫자만 추출 후 11자리면 010-0000-0000로 변환
  String _formatPhone(String? input) {
    if (input == null || input.trim().isEmpty) return '(전화번호 없음)';

    final digits = input.replaceAll(RegExp(r'\D'), '');

    // +82로 들어오는 케이스(+8210xxxxxxxx) → 010xxxxxxxx 변환
    String normalized = digits;
    if (normalized.startsWith('82') && normalized.length >= 12) {
      // 82 + 10xxxxxxxx → 010xxxxxxxx
      final rest = normalized.substring(2);
      if (rest.startsWith('10') && rest.length == 10) {
        normalized = '0$rest';
      }
    }

    // 010xxxxxxxx (11자리) 기준 포맷
    if (normalized.length == 11) {
      return '${normalized.substring(0, 3)}-'
          '${normalized.substring(3, 7)}-'
          '${normalized.substring(7)}';
    }

    // 그 외는 원본 유지
    return input;
  }

  List<String> _getContentLines() {
    final name = widget.data['name'] ?? '(이름 없음)';
    final phone = _formatPhone(widget.data['phone']?.toString());

    switch (widget.type) {
      case SignatureType.theory:
        return [
          '과정: ${widget.data['moduleName'] ?? '(과정명 없음)'}',
          '이름: $name',
          '연락처: $phone', // ✅ 여기서 하이픈 포맷된 값이 출력됨
          '영상 시청: ${widget.data['videoCompleted'] == true ? '완료' : '미완료'}',
          '시험 점수: ${widget.data['examScore'] ?? 0}점',
          '시험 결과: ${widget.data['examPassed'] == true ? '합격' : '불합격'}',
        ];

      case SignatureType.practiceMentor:
        final feedback = widget.data['feedback']?.toString() ?? '';
        final feedbackPreview = feedback.isEmpty 
            ? '없음' 
            : feedback.length > 20 
                ? '${feedback.substring(0, 20)}...' 
                : feedback;
        return [
          '실습 과정: ${widget.data['practiceTitle'] ?? '(실습명 없음)'}',
          '멘티 이름: ${widget.data['menteeName'] ?? '(이름 없음)'}',
          '멘토 이름: $name',
          '평가 등급: ${_gradeLabel(widget.data['grade'])}',
          '검토 의견: $feedbackPreview',
        ];

      case SignatureType.practiceMentee:
        final submittedAtRaw = widget.data['submittedAt']?.toString() ?? '';
        final submittedAtFormatted = _formatDateTime(submittedAtRaw);
        return [
          '실습 과정: ${widget.data['practiceTitle'] ?? '(실습명 없음)'}',
          '멘티 이름: $name',
          '연락처: $phone',
          '멘토 평가: ${_gradeLabel(widget.data['grade'])}',
          '제출 일시: $submittedAtFormatted',
        ];

      case SignatureType.completionMentee:
        return [
          '교육생 이름: $name',
          '연락처: $phone', // ✅ 여기서도 동일하게 포맷 적용
          '이론 교육: ${widget.data['theoryCount'] ?? 0}개 완료',
          '실습 교육: ${widget.data['practiceCount'] ?? 0}개 완료',
          '총 교육 시간: ${widget.data['totalHours'] ?? 0}시간',
        ];

      case SignatureType.completionMentor:
        return [
          '교육생 이름: ${widget.data['menteeName'] ?? '(이름 없음)'}',
          '담당 멘토: $name',
          '이론 교육: ${widget.data['theoryCount'] ?? 0}개 완료',
          '실습 교육: ${widget.data['practiceCount'] ?? 0}개 완료',
          '수료 승인 일자: ${widget.data['approvalDate'] ?? '(날짜 없음)'}',
        ];
    }
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

  /// ✅ DateTime 포맷 (ISO 8601 → 읽기 쉬운 형식)
  /// 예: "2025-12-28T12:55:15.859471+00:00" → "2025년 12월 28일 12:55"
  String _formatDateTime(String? input) {
    if (input == null || input.trim().isEmpty) return '(날짜 없음)';

    try {
      final dt = DateTime.parse(input).toLocal();
      return '${dt.year}년 ${dt.month}월 ${dt.day}일 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return input; // 파싱 실패 시 원본 반환
    }
  }

  void _clear() {
    _controller.clear();
  }

  Future<bool> _showSignatureConfirmDialog(BuildContext context) async {
    const Color accent = UiTokens.primaryBlue;
    const Color badgeBg = Color(0xFFEAF3FF);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                child: const Icon(Icons.edit_note_rounded, size: 30, color: accent),
              ),
              const SizedBox(height: 14),
              const Text(
                '서명을 완료하시겠습니까?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: UiTokens.title,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '서명 후에는 수정할 수 없으며,\n법적 효력을 가집니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: UiTokens.title.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.withOpacity(0.4)),
                        backgroundColor: const Color(0xFFF5F7FA),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: UiTokens.title,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '완료',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  Future<void> _confirm() async {
    if (_isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서명을 작성해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await _showSignatureConfirmDialog(context);
    if (confirmed != true) return;

    try {
      final RenderRepaintBoundary boundary =
      _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? signature = byteData?.buffer.asUint8List();

      if (signature == null || !mounted) return;

      Navigator.pop(context, {
        'signature': signature,
        'timestamp': DateTime.now().toIso8601String(),
        'type': widget.type.name,
      });
    } catch (e) {

      print(e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('서명 저장 실패: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _getTitle(),
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w700,
          ),
        ),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '아래 영역에 서명해주세요',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clear,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          '초기화',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _canvasKey,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),
                              Text(
                                _getTitle(),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 15),
                              ..._getContentLines().map(
                                    (line) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    line,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: UiTokens.title,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 80),
                              Container(
                                width: double.infinity,
                                height: 1,
                                color: UiTokens.title,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '서명 구역 (위 라인에 서명해주세요)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: UiTokens.title,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 400,
                        child: Signature(
                          controller: _controller,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[900], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '서명 정보는 암호화되어 안전하게 보관됩니다',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.amber[900],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isEmpty ? null : _confirm,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: UiTokens.primaryBlue,
              ),
              child: const Text(
                '서명 완료',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
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
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
