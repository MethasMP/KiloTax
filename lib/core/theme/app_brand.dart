import 'package:flutter/material.dart';

/// Folio identity. Action and status colours remain in AppColor.
class AppBrand {
  AppBrand._();

  static const vermilion = Color(0xFFE74716);
  static const aubergine = Color(0xFF351329);
  static const markAsset = 'assets/brand/folio/folio-mark.svg';
  static const iconAsset = 'assets/brand/folio/folio-app-icon.svg';

  static const wordmark = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    color: aubergine,
  );

  static const wordmarkCompact = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: aubergine,
  );
}
