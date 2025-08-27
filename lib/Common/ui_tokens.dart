import 'package:flutter/material.dart';

class UiTokens {
  static const Color title = Color(0xFF222631);
  static const Color primaryBlue = Color(0xFF2F82F6);
  static const Color actionIcon = Color(0xFFB0B9C1);

  static const Color cardBorder = Color(0xFFE6EAF0);

  // 6%의 #101828 => AA = 0x0F
  static const Color shadowColor = Color(0x0F101828);

  static const BoxShadow cardShadow = BoxShadow(
    color: shadowColor,
    blurRadius: 16,
    offset: Offset(0, 6),
  );
}