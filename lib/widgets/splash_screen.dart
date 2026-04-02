import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';



class SplashScreen extends StatefulWidget {
  final Widget nextPage;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.nextPage,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  Timer? _timer;

  // Logo scale + fade
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  // Title slide-up + fade
  late AnimationController _titleController;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;

  // Subtitle fade
  late AnimationController _subtitleController;
  late Animation<double> _subtitleFade;

  // Progress bar
  late AnimationController _progressController;
  late Animation<double> _progressValue;

  // Decorative circles pulse
  late AnimationController _circleController;

  // Bottom tagline
  late AnimationController _taglineController;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    // --- Logo ---
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // --- Title ---
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOutCubic),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOut),
    );

    // --- Subtitle ---
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeOut),
    );

    // --- Progress bar ---
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration - const Duration(milliseconds: 400),
    );
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // --- Circles ---
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // --- Tagline ---
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOut),
    );

    // Staggered start sequence
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _titleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted) _subtitleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _progressController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _taglineController.forward();
    });

    _timer = Timer(widget.duration, _goNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logoController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _progressController.dispose();
    _circleController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.nextPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Navy from login page: #0D1B2A range
    const Color navyDark = Color(0xFF0D1B2A);
    const Color navyMid = Color(0xFF162032);
    const Color navyLight = Color(0xFF1E2D42);
    const Color orange = Color(0xFFE8622A);
    const Color orangeLight = Color(0xFFFF7A40);

    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient (matches login left panel) ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [navyDark, navyMid, navyLight],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Decorative circles (like login page background orbs) ──
          AnimatedBuilder(
            animation: _circleController,
            builder: (context, _) {
              final pulse =
                  0.85 +
                      0.15 *
                          math.sin(_circleController.value * 2 * math.pi);
              final pulse2 =
                  0.88 +
                      0.12 *
                          math.sin(
                            (_circleController.value + 0.5) * 2 * math.pi,
                          );

              return Stack(
                children: [
                  // Top-left large circle
                  Positioned(
                    top: -100,
                    left: -80,
                    child: Transform.scale(
                      scale: pulse,
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1A2E44).withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                  // Bottom-right large circle
                  Positioned(
                    bottom: -120,
                    right: -60,
                    child: Transform.scale(
                      scale: pulse2,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF162030).withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                  // Center-right accent circle
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.35,
                    right: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: orange.withOpacity(0.06),
                      ),
                    ),
                  ),
                  // Small orange glow near logo area
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.28,
                    left: MediaQuery.of(context).size.width * 0.5 - 60,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: orange.withOpacity(0.08 * pulse),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo icon with glow ring
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, _) {
                          return FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer glow ring
                                  Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: orange.withOpacity(0.25),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  // Inner icon container
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      color: orange,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: orange.withOpacity(0.45),
                                          blurRadius: 28,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.restaurant_menu_rounded,
                                        color: Colors.white,
                                        size: 42,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // App title
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: Column(
                            children: [
                              Text(
                                'Restaurant',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                'Management Portal',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: orangeLight,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Subtitle
                      FadeTransition(
                        opacity: _subtitleFade,
                        child: Text(
                          'Manage orders, menus, and your restaurant\noperations from one unified dashboard.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.55),
                            height: 1.7,
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Custom progress bar
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, _) {
                          return Column(
                            children: [
                              // Bar track
                              Container(
                                width: double.infinity,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progressValue.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [orange, orangeLight],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: orange.withOpacity(0.6),
                                          blurRadius: 6,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              FadeTransition(
                                opacity: _subtitleFade,
                                child: Text(
                                  'Preparing your dashboard...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.4),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Feature pills at bottom (like login page feature list) ──
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _taglineFade,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FeaturePill(
                    icon: Icons.bolt_rounded,
                    label: 'Live Orders',
                    orange: orange,
                  ),
                  const SizedBox(width: 10),
                  _FeaturePill(
                    icon: Icons.menu_book_rounded,
                    label: 'Menu Mgmt',
                    orange: orange,
                  ),
                  const SizedBox(width: 10),
                  _FeaturePill(
                    icon: Icons.bar_chart_rounded,
                    label: 'Analytics',
                    orange: orange,
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

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color orange;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: orange, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}