import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/tactile_primary_button.dart';

/// 2026 Kodawari Onboarding Showcase:
/// Crafted with Japanese-grade product precision (Monozukuri):
/// - Bespoke Micro-Artworks for each of the 3 value propositions (Trip + Tax Meter, Receipt + Route Graph, Audit Shield Pack)
/// - Silk & Snap Spring Motion Choreography (Staggered Fade + SlideY + Scale physics)
/// - Fluid Segment Progress Indicators
/// - Concentric Hardware Double-Bezel CTA with Taptic Haptics
class OnboardingSlidesScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingSlidesScreen({super.key, required this.onComplete});

  @override
  State<OnboardingSlidesScreen> createState() => _OnboardingSlidesScreenState();
}

class _OnboardingSlidesScreenState extends State<OnboardingSlidesScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _revealController;
  int _currentPage = 0;

  final List<_SlideItem> _slides = const [
    _SlideItem(
      badge: 'Tax Deduction Engine',
      title: 'Never miss a dollar\nyou’re entitled to.',
      description:
          'Not an accounting app. KiloTax turns your daily ute drives and tool runs into audit-proof tax deductions automatically.',
      accentColor: Color(0xFFD97706),
      type: _ArtworkType.taxDeduction,
    ),
    _SlideItem(
      badge: 'Zero-Touch Capture',
      title: 'Drive your ute.\nSnap receipts in seconds.',
      description:
          'Sensor fusion detects when you park on-site. Snap Bunnings and fuel receipts in seconds to lock in an airtight tax chain.',
      accentColor: AppColors.emerald,
      type: _ArtworkType.evidenceCapture,
    ),
    _SlideItem(
      badge: 'Accountant Ready',
      title: 'Audit-ready records\nyour accountant loves.',
      description:
          'No more shoeboxes of crumpled receipts. 1-tap export of ATO-compliant tax packs whenever tax time arrives.',
      accentColor: AppColors.brandPrimary,
      type: _ArtworkType.taxShield,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _revealController.forward();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _revealController.reset();
    _revealController.forward();
  }

  void _nextOrFinish() {
    HapticFeedback.lightImpact();
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
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
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton(
              onPressed: _skip,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // PageView Canvas
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (ctx, idx) {
                  final slide = _slides[idx];
                  return _SlideView(
                    slide: slide,
                    animation: _revealController,
                  );
                },
              ),
            ),

            // Bottom Navigation Deck (Story Segment Progress + Tactile CTA)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fluid Story-style Segment Progress Bar
                  Row(
                    children: List.generate(_slides.length, (idx) {
                      final isSelected = idx == _currentPage;
                      final isPast = idx < _currentPage;

                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.deepNavy
                                : (isPast
                                    ? AppColors.deepNavy.withValues(alpha: 0.4)
                                    : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Concentric Double-Bezel Tactile Primary Button
                  TactilePrimaryButton(
                    label: isLastPage ? 'Get Started' : 'Continue',
                    trailingIcon: isLastPage
                        ? LucideIcons.arrowRight
                        : Icons.arrow_forward_ios_rounded,
                    onPressed: _nextOrFinish,
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

enum _ArtworkType {
  taxDeduction,
  evidenceCapture,
  taxShield,
}

class _SlideItem {
  final String badge;
  final String title;
  final String description;
  final Color accentColor;
  final _ArtworkType type;

  const _SlideItem({
    required this.badge,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.type,
  });
}

class _SlideView extends StatelessWidget {
  final _SlideItem slide;
  final Animation<double> animation;

  const _SlideView({
    required this.slide,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    // Staggered Motion curves (ui-motion: Silk & Snap)
    final artworkScale = Tween<double>(begin: 0.93, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    final artworkFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    final textSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    final textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. Bespoke Micro-Artwork
          FadeTransition(
            opacity: artworkFade,
            child: ScaleTransition(
              scale: artworkScale,
              child: _buildArtwork(slide.type, slide.accentColor),
            ),
          ),
          const SizedBox(height: 34),

          // 2. Staggered Editorial Typography
          SlideTransition(
            position: textSlide,
            child: FadeTransition(
              opacity: textFade,
              child: Column(
                children: [
                  // Subtle Semantic Pill Tag (No yelling uppercase)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: slide.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: slide.accentColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      slide.badge,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: slide.accentColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Main Heading
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.6,
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Descriptive Body
                  Text(
                    slide.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: AppColors.muted,
                      height: 1.48,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(_ArtworkType type, Color accentColor) {
    switch (type) {
      case _ArtworkType.taxDeduction:
        return const _TaxDeductionArtwork();
      case _ArtworkType.evidenceCapture:
        return const _EvidenceCaptureArtwork();
      case _ArtworkType.taxShield:
        return const _TaxShieldArtwork();
    }
  }
}

/// Artwork 1: Floating Trip Card + Live Tax Meter with Gold Sparkle
class _TaxDeductionArtwork extends StatelessWidget {
  const _TaxDeductionArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient Glow Aura
          Container(
            width: 190,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFDE68A).withValues(alpha: 0.35),
            ),
          ),

          // Primary Floating Trip Card
          Container(
            width: 280,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.navigation,
                              size: 14, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Bondi Reno → North Sydney',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      '24.2 km',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(LucideIcons.briefcase,
                            size: 13, color: AppColors.muted),
                        SizedBox(width: 5),
                        Text(
                          'Site inspection',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.sparkles,
                              size: 12, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text(
                            '+\$22.02 Claimed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Floating Mini Badge: ATO Certified Cents/Km
          Positioned(
            top: 10,
            right: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.deepNavy,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 13, color: AppColors.emerald),
                  SizedBox(width: 5),
                  Text(
                    'ATO 91¢/km',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Artwork 2: Bunnings Receipt + GPS Trail Sensor Chain
class _EvidenceCaptureArtwork extends StatelessWidget {
  const _EvidenceCaptureArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background GPS Geodesic Grid
          Container(
            width: 240,
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: CustomPaint(
              painter: _RouteGridPainter(),
            ),
          ),

          // Angled Bunnings Receipt Slip
          Transform.rotate(
            angle: -0.06,
            child: Container(
              width: 210,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BUNNINGS WAREHOUSE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: AppColors.ink,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.emerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Timber, Fixings & Drill Bits',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Tax Deductible',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted),
                      ),
                      Text(
                        '\$184.60',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Evidence Matched Floating Chip
          Positioned(
            bottom: 12,
            right: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.link, size: 12, color: Color(0xFF059669)),
                  SizedBox(width: 5),
                  Text(
                    'Linked to Trip ✓',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Artwork 3: Deep Navy Audit Shield & Certified Tax Pack
class _TaxShieldArtwork extends StatelessWidget {
  const _TaxShieldArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Document Slate
          Transform.rotate(
            angle: 0.04,
            child: Container(
              width: 250,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
            ),
          ),

          // Primary Obsidian & Emerald Shield Card
          Container(
            width: 270,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F1B3B), // Deep Navy
                  Color(0xFF090D1A), // Obsidian Core
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E2E5D)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.shieldCheck,
                              size: 16, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'ATO Tax Pack 2026',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PDF & CSV',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Subdivision 28-F Compliant Logbook',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 5),
                    Text(
                      'Ready for 1-Tap Accountant Hand-off',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper custom painter for subtle background GPS route lines
class _RouteGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(20, size.height * 0.7)
      ..cubicTo(size.width * 0.3, size.height * 0.9, size.width * 0.6,
          size.height * 0.2, size.width - 20, size.height * 0.4);

    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(20, size.height * 0.7), 3.5, dotPaint);
    canvas.drawCircle(Offset(size.width - 20, size.height * 0.4), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
