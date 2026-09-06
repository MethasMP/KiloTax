import 'package:flutter/material.dart';

class AppColors {
  static const Color ink = Color(0xFF0F172A);
  static const Color background = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF64748B);
  static const Color emerald = Color(0xFF059669);
  static const Color emeraldLight = Color(0xFFECFDF5);
  static const Color crimson = Color(0xFFDC2626);
  static const Color crimsonLight = Color(0xFFFEF2F2);
  static const Color workBlue = Color(0xFF2563EB);
  static const Color workBlueLight = Color(0xFFEFF6FF);
}

class AppConstants {
  static const String appTitle = 'KiloTax';
  static const double centsPerKmRate2026 = 0.91; // 91c / km for 2026/27 ATO rate
  static const double centsPerKmCapKm = 5000.0;
  static const double maxCentsPerKmClaim = centsPerKmRate2026 * centsPerKmCapKm; // $4,550.00
  static const int statutoryLogbookWeeks = 12;
  static const int statutoryLogbookDays = 84;
}
