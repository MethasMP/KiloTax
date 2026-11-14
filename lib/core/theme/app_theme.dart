import 'package:flutter/material.dart';
import 'app_color.dart';
import 'app_typography.dart';

/// One control language for setup, record entry and ongoing work.
class AppTheme {
  AppTheme._();
  static ThemeData get light => ThemeData(
        fontFamily: 'Inter',
        colorScheme: AppColor.scheme,
        textTheme: AppType.textTheme,
        scaffoldBackgroundColor: AppColor.canvas,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
            backgroundColor: AppColor.canvas,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleTextStyle: AppType.section.copyWith(fontFamily: 'Inter')),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                backgroundColor: AppColor.ink,
                foregroundColor: AppColor.onNavy,
                minimumSize: const Size(48, 52),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                textStyle: AppType.bodyStrong.copyWith(fontFamily: 'Inter'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)))),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColor.ink,
                minimumSize: const Size(48, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                side: const BorderSide(color: AppColor.line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)))),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: AppColor.brand,
                minimumSize: const Size(48, 48),
                textStyle: AppType.bodyStrong.copyWith(fontFamily: 'Inter'))),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColor.ink,
            foregroundColor: AppColor.onNavy,
            elevation: 2,
            focusElevation: 2,
            hoverElevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        cardTheme: CardThemeData(
            color: AppColor.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColor.hairline))),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColor.surface,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColor.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColor.line)),
            labelStyle: AppType.body),
        dividerTheme:
            const DividerThemeData(color: AppColor.hairline, thickness: 1),
      );
}
