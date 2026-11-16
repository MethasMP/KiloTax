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
      badge: 'ATO 1-Tonne Rule',
      badgeIcon: LucideIcons.truck,
      title: "Don't leave \$9,140\non the table with the ATO.",
      description:
          "The ATO's 5,000 km shortcut burns cash on commercial utes. KiloTax claims your actual fuel, tyres, and finance automatically.",
      accentColor: AppColors.deepNavy,
      type: _ArtworkType.taxDeduction,
    ),
    _SlideItem(
      badge: 'Statutory 12-Week Shield',
      badgeIcon: LucideIcons.shieldCheck,
      title: '12 weeks of driving.\n5 years of audit safety.',
      description:
          'Log 12 consecutive weeks just once. Lock in your business use percentage for 5 full ATO tax years.',
      accentColor: AppColors.emerald,
      type: _ArtworkType.evidenceCapture,
    ),
    _SlideItem(
      badge: 'Zero Shoeboxes',
      badgeIcon: LucideIcons.archiveX,
      title: 'One tap at tax time.\nHanded to your accountant.',
      description:
          '1-tap export of your certified 2-page ATO summary and Xero-ready schedule with all receipts attached.',
      accentColor: Color(0xFF2563EB), // Deep Royal Blue
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
                    label: _currentPage == 0
                        ? 'See My Full Claim'
                        : (_currentPage == 1
                            ? 'Protect My 5 Years'
                            : 'Start My Tax Shield'),
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
  final IconData badgeIcon;
  final String title;
  final String description;
  final Color accentColor;
  final _ArtworkType type;

  const _SlideItem({
    required this.badge,
    required this.badgeIcon,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Upper Hero Section: Tightly Anchored (Flex 5)
          Expanded(
            flex: 5,
            child: Align(
              alignment: const Alignment(0, 0.35),
              child: FadeTransition(
                opacity: artworkFade,
                child: ScaleTransition(
                  scale: artworkScale,
                  child: _buildArtwork(slide.type, slide.accentColor),
                ),
              ),
            ),
          ),

          // Lower Narrative Section: Unified First-Screenful Density (Flex 5)
          Expanded(
            flex: 5,
            child: SlideTransition(
              position: textSlide,
              child: FadeTransition(
                opacity: textFade,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 345),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Premium Semantic Category Badge with Leading Micro-Icon
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: slide.accentColor == AppColors.deepNavy
                                ? const Color(0xFFF1F5F9)
                                : slide.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: slide.accentColor == AppColors.deepNavy
                                  ? const Color(0xFFCBD5E1)
                                  : slide.accentColor.withValues(alpha: 0.28),
                              width: 1.1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                slide.badgeIcon,
                                size: 13,
                                color: slide.accentColor == AppColors.deepNavy
                                    ? const Color(0xFF1E293B)
                                    : slide.accentColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                slide.badge,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: slide.accentColor == AppColors.deepNavy
                                      ? const Color(0xFF1E293B)
                                      : slide.accentColor,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Main Heading
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.7,
                            height: 1.18,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Descriptive Body (Humanized & High-Legibility)
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.muted,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
        return _ActualCostVsShortcutArtwork(animation: animation);
      case _ArtworkType.evidenceCapture:
        return _TwelveWeekShieldArtwork(animation: animation);
      case _ArtworkType.taxShield:
        return _AccountantHandOffArtwork(animation: animation);
    }
  }
}

/// Artwork 1: Unified Comparison HUD ($4,400 ATO Shortcut vs $13,540 Your Real Costs)
/// Aligns directly with: "Don't leave $9,140 on the table with the ATO."
class _ActualCostVsShortcutArtwork extends StatelessWidget {
  final Animation<double> animation;
  const _ActualCostVsShortcutArtwork({required this.animation});

  @override
  Widget build(BuildContext context) {
    final stampPop = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.45, 0.9, curve: Curves.easeOutBack),
      ),
    );

    return SizedBox(
      height: 235,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Ambient Glow Aura
          Container(
            width: 240,
            height: 155,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
            ),
          ),

          // Unified Comparison HUD Card Shell
          Container(
            width: 326,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Integrated Banner: +$9,140 Claim Unlocked (Eliminating visual jumping)
                ScaleTransition(
                  scale: stampPop,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 7.5),
                    decoration: const BoxDecoration(
                      color: AppColors.deepNavy,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.shieldCheck,
                            size: 13.5, color: AppColors.emerald),
                        SizedBox(width: 6),
                        Text(
                          '+\$9,140 Claim Unlocked',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Side-by-Side Comparison Columns
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Row(
                    children: [
                      // Left Column: Standard Trap (Dimmed Slate)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF94A3B8),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Expanded(
                                    child: Text(
                                      'ATO SHORTCUT',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '\$4,400',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF94A3B8),
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Color(0xFFEF4444),
                                  decorationThickness: 2,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Capped at 5k km',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Center VS Badge
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),

                      // Right Column: KiloTax Actual Cost Shield (Dominant Highlight)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFF10B981), width: 1.5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF059669),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Expanded(
                                    child: Text(
                                      'YOUR REAL COSTS',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '\$13,540',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF065F46),
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Fuel + Ute Maint',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
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
                ),

                // Trust Signal Microcopy
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Estimates based on ATO logbook rules',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Artwork 2: 12-Week Sprint ➔ 5-Year Protection Timeline
/// Directly aligns with: "12 weeks of driving. 5 years of audit safety."
class _TwelveWeekShieldArtwork extends StatelessWidget {
  final Animation<double> animation;
  const _TwelveWeekShieldArtwork({required this.animation});

  @override
  Widget build(BuildContext context) {
    final chipPop = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.45, 0.9, curve: Curves.easeOutBack),
      ),
    );

    return SizedBox(
      height: 235,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Timeline Base Card
          Container(
            width: 326,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta: Ratio Established
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(LucideIcons.checkCheck,
                              size: 14, color: Color(0xFF059669)),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          '84.2% Business Use',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '12/12 Wks Done',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Visual Timeline Bar (12 Weeks Tracked -> 5 Years Protected)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        // Phase 1: 12-Week Active Sprint (33%)
                        Expanded(
                          flex: 33,
                          child: Container(
                            color: const Color(0xFFF1F5F9),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.calendarCheck,
                                    size: 13, color: Color(0xFF64748B)),
                                SizedBox(width: 4),
                                Text(
                                  '12 WEEKS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Directional Transition Arrow
                        Container(
                          width: 18,
                          color: const Color(0xFFF1F5F9),
                          alignment: Alignment.center,
                          child: const Icon(
                            LucideIcons.chevronRight,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        // Phase 2: 5-Year Protection Shield (67%) - Hero Benefit
                        Expanded(
                          flex: 67,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF0F1B3B),
                                  Color(0xFF064E3B),
                                ],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_rounded,
                                    size: 14, color: AppColors.emerald),
                                SizedBox(width: 5),
                                Text(
                                  '5 YEARS PROTECTED',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Log once in 2026',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.checkCheck,
                              size: 11, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text(
                            'Valid until 2031',
                            style: TextStyle(
                              fontSize: 11,
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

          // Floating Chip: ATO Section 28-115 Compliant
          Positioned(
            bottom: 4,
            child: ScaleTransition(
              scale: chipPop,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.shieldCheck,
                        size: 12.5, color: AppColors.emerald),
                    SizedBox(width: 5),
                    Text(
                      'ATO Division 28-F Compliant',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Artwork 3: The Zero-Shoebox Accountant Dispatch Card
/// Directly aligns with: "One tap at tax time. Handed to your accountant."
class _AccountantHandOffArtwork extends StatelessWidget {
  final Animation<double> animation;
  const _AccountantHandOffArtwork({required this.animation});

  @override
  Widget build(BuildContext context) {
    final handOffPop = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.45, 0.9, curve: Curves.easeOutBack),
      ),
    );

    return SizedBox(
      height: 235,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Main Dispatch Card Shell
          Container(
            width: 326,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F1B3B), // Deep Navy
                  Color(0xFF090D1A), // Obsidian Core
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF1E2E5D), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.28),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Recipient Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(LucideIcons.send,
                              size: 11, color: Color(0xFF93C5FD)),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'To: accountant@cpa.com.au',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'EOFY Ready',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Certified File Attachment Inner Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.fileText,
                            size: 18, color: Color(0xFFFCA5A5)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ATO_Tax_Pack_2026.pdf',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.1,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '142 Trips • All Fuel & Bunnings Receipts',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '100% Tax Evidence Verified',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'XERO READY',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: Color(0xFF93C5FD),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Floating Pill: 0 Shoeboxes Needed (Tactile Glow & Contrast)
          Positioned(
            bottom: 4,
            child: ScaleTransition(
              scale: handOffPop,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.checkCheck, size: 13.5, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Sent in 1-Tap • 0 Shoeboxes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


