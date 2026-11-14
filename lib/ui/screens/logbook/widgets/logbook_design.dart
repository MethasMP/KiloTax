import '../../../../core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_space.dart';
import '../../../../core/theme/app_typography.dart';

class LogbookPanel extends StatelessWidget {
  final Widget child;
  const LogbookPanel({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Material(
        color: AppColor.surface,
        shape: RoundedRectangleBorder(
            borderRadius: R.cardR,
            side: const BorderSide(color: AppColor.hairline)),
        child: Padding(padding: S.cardPad, child: child),
      );
}

class LogbookSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  const LogbookSection(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: S.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppType.section),
          if (subtitle != null) ...[
            const SizedBox(height: S.xs),
            Text(subtitle!, style: AppType.secondary)
          ],
        ]),
      );
}

InputDecoration logbookInput(String label, {String? hint, String? suffix}) =>
    InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: hint,
      suffixText: suffix,
      labelStyle: AppType.secondary,
      hintStyle: AppType.body.copyWith(color: AppColor.inkSubtle),
      suffixStyle: AppType.bodyStrong,
      filled: true,
      fillColor: AppColor.surfaceMuted,
      contentPadding: const EdgeInsets.all(S.lg),
      border: OutlineInputBorder(
          borderRadius: R.controlR,
          borderSide: const BorderSide(color: AppColor.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: R.controlR,
          borderSide: const BorderSide(color: AppColor.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: R.controlR,
          borderSide: const BorderSide(color: AppColor.ink, width: 2)),
    );

class LogbookFooter extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const LogbookFooter(
      {super.key, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppColor.surface,
        child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(S.xl, S.md, S.xl, S.md),
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColor.ink,
                    foregroundColor: AppColor.onNavy,
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.all(S.lg),
                    shape: RoundedRectangleBorder(borderRadius: R.controlR)),
                onPressed: onPressed,
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: AppType.bodyStrong
                        .copyWith(color: AppColor.scheme.onPrimary)),
              ),
            )),
      ));
}

AppBar logbookAppBar(BuildContext context, String title) => AppBar(
      automaticallyImplyLeading: false,
      leading: Navigator.of(context).canPop()
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(AppIcons.back, size: AppIconSize.navigation))
          : null,
      title: Text(title, style: AppType.cardTitle),
      centerTitle: false,
      backgroundColor: AppColor.canvas,
      foregroundColor: AppColor.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    );
