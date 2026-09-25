import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';

/// Spec: 3 Value Proposition Slides from ChatGPT thread
/// (https://chatgpt.com/share/6a9e5f8c-cfdc-83ec-b2c2-36f2f545fef1)
///
/// 1. The Core Purpose: "Never miss a dollar you're entitled to"
///    "Not an accounting app. KiloTax turns your daily ute drives and tool runs into tax deductions automatically."
///
/// 2. Daily Automatic Evidence Capture: "Zero-touch tracking for trips & receipts"
///    "Drive your ute. Snap Bunnings receipts in seconds. We turn them into tax evidence without the paperwork hassle."
///
/// 3. Tax Time Ready & Accountant Hand-off: "Audit-ready records your accountant will love"
///    "No shoebox of crumpled receipts. 1-tap export of clean ATO-compliant tax packs when tax time comes."
class OnboardingSlidesScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingSlidesScreen({super.key, required this.onComplete});

  @override
  State<OnboardingSlidesScreen> createState() => _OnboardingSlidesScreenState();
}

class _OnboardingSlidesScreenState extends State<OnboardingSlidesScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_SlideItem> _slides = const [
    _SlideItem(
      badge: 'ESTIMATED TAX DEDUCTION',
      title: 'Never miss a dollar you’re entitled to.',
      description: 'Not an accounting app. KiloTax is built for Australian tradies on the road — turning daily work drives into tax deductions automatically.',
      icon: LucideIcons.dollarSign,
      accentColor: AppColors.amberDark,
    ),
    _SlideItem(
      badge: 'DAILY EVIDENCE CAPTURE',
      title: 'Zero-touch tracking for trips & receipts.',
      description: 'Drive your ute and let GPS detect trips. Snap Bunnings and fuel receipts on-site. The app turns your daily work into ATO evidence in seconds.',
      icon: LucideIcons.receipt,
      accentColor: AppColors.emerald,
    ),
    _SlideItem(
      badge: 'TAX TIME HAND-OFF',
      title: 'Audit-ready records your accountant will love.',
      description: 'No more shoeboxes of crumpled receipts. Always know your Tax Readiness status and export clean, audit-proof reports in 1 tap.',
      icon: LucideIcons.shieldCheck,
      accentColor: AppColors.deepNavy,
    ),
  ];

  void _nextOrFinish() {
    HapticFeedback.lightImpact();
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _skip() {
    HapticFeedback.mediumImpact();
    widget.onComplete();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _skip,
            child: const Text(
              'Skip',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (ctx, idx) {
                  final slide = _slides[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            color: slide.accentColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(slide.icon, size: 50, color: slide.accentColor),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            slide.badge,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.muted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                            letterSpacing: -0.5,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: AppColors.muted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots & CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (idx) {
                      final isActive = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.deepNavy : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _nextOrFinish,
                      child: Text(
                        _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideItem {
  final String badge;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const _SlideItem({
    required this.badge,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}
