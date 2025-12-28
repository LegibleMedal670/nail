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
      exportBackgroundColor: Colors.transparent, // 투명 배경으로 변경
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

  List<String> _getContentLines() {
    final name = widget.data['name'] ?? '(이름 없음)';
    final phone = widget.data['phone'] ?? '(전화번호 없음)';

    switch (widget.type) {
      case SignatureType.theory:
        return [
          '과정: ${widget.data['moduleName'] ?? '(과정명 없음)'}',
          '이름: $name',
          '연락처: $phone',
          '영상 시청: ${widget.data['videoCompleted'] == true ? '완료' : '미완료'}',
          '시험 점수: ${widget.data['examScore'] ?? 0}점',
          '시험 결과: ${widget.data['examPassed'] == true ? '합격' : '불합격'}',
        ];

      case SignatureType.practiceMentor:
        return [
          '실습 과정: ${widget.data['practiceTitle'] ?? '(실습명 없음)'}',
          '멘티 이름: ${widget.data['menteeName'] ?? '(이름 없음)'}',
          '멘토 이름: $name',
          '평가 등급: ${_gradeLabel(widget.data['grade'])}',
          '검토 의견: ${widget.data['feedback']?.toString().substring(0, 20) ?? '없음'}...',
        ];

      case SignatureType.practiceMentee:
        return [
          '실습 과정: ${widget.data['practiceTitle'] ?? '(실습명 없음)'}',
          '멘티 이름: $name',
          '연락처: $phone',
          '멘토 평가: ${_gradeLabel(widget.data['grade'])}',
          '제출 일시: ${widget.data['submittedAt'] ?? '(날짜 없음)'}',
        ];

      case SignatureType.completionMentee:
        return [
          '교육생 이름: $name',
          '연락처: $phone',
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

  void _clear() {
    _controller.clear();
  }

  /// 서명 확인 다이얼로그 (프로젝트 스타일)
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
              // 상단 아이콘 배지
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                child: const Icon(Icons.edit_note_rounded, size: 30, color: accent),
              ),
              const SizedBox(height: 14),

              // 제목
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

              // 메시지
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

              // 액션 버튼
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

    // 확인 다이얼로그 (프로젝트 스타일)
    final confirmed = await _showSignatureConfirmDialog(context);
    if (confirmed != true) return;

    try {
      // RepaintBoundary를 사용하여 전체 캔버스(배경 + 서명) 캡처
      final RenderRepaintBoundary boundary = _canvasKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? signature = byteData?.buffer.asUint8List();

      if (signature == null || !mounted) return;

      // 결과 반환 (서명 이미지 + 메타데이터)
      Navigator.pop(context, {
        'signature': signature,
        'timestamp': DateTime.now().toIso8601String(),
        'type': widget.type.name,
      });
    } catch (e) {
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
        title: Text(_getTitle()),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 안내 문구
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '아래 영역에 서명해주세요',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clear,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.refresh,
                          size: 16,
                          color: Colors.blue[700],
                        ),
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

            // 서명 캔버스 (배경에 정보 표시)
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
                      // 배경 정보 (연하게 표시)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 제목
                              Text(
                                _getTitle(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[300],
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // 내용
                              ..._getContentLines().map(
                                (line) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[400],
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // 서명란 표시
                              Container(
                                width: double.infinity,
                                height: 1,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '서명 구역 (위 라인에 서명해주세요)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 서명 레이어 (투명 배경)
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

            // 법적 효력 안내
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '서명 정보는 암호화되어 안전하게 보관됩니다\n'
                '서명은 검정색으로 또렷하게 작성해주세요.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.amber[900],
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 하단 버튼
            FilledButton(
              onPressed: _isEmpty ? null : _confirm,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

