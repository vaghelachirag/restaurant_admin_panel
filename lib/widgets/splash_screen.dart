import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// Asset path – make sure this is declared in pubspec.yaml:
//   assets:
//     - assets/images/rasora_web.png

class SplashScreen extends StatefulWidget {
  final Widget nextPage;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.nextPage,
    this.duration = const Duration(seconds: 4),
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

  // Download buttons
  late AnimationController _downloadController;
  late Animation<double> _downloadFade;

  @override
  void initState() {
    super.initState();

    // --- Logo ---
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
      duration: widget.duration - const Duration(milliseconds: 500),
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

    // --- Download buttons ---
    _downloadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _downloadFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _downloadController, curve: Curves.easeOut),
    );

    // Staggered start sequence
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _titleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 950), () {
      if (mounted) _subtitleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _progressController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) _taglineController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) _downloadController.forward();
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
    _downloadController.dispose();
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
    const Color bgDark = Color(0xFF0D0D0D);
    const Color bgMid = Color(0xFF1A0800);
    const Color bgLight = Color(0xFF2A1200);
    const Color orange = Color(0xFFE8622A);
    const Color orangeLight = Color(0xFFFFAA00);

    return Scaffold(
      body: Stack(
        children: [
          // ── Background – warm dark matching Rasora brand ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bgDark, bgMid, bgLight],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Decorative pulsing orbs ──
          AnimatedBuilder(
            animation: _circleController,
            builder: (context, _) {
              final pulse =
                  0.85 + 0.15 * math.sin(_circleController.value * 2 * math.pi);
              final pulse2 =
                  0.88 +
                      0.12 *
                          math.sin(
                            (_circleController.value + 0.5) * 2 * math.pi,
                          );
              return Stack(
                children: [
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
                          color: orange.withOpacity(0.07),
                        ),
                      ),
                    ),
                  ),
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
                          color: orange.withOpacity(0.06),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Main content ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo: rasora_web.png (flame + Rasora wordmark) ──
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: orange.withOpacity(0.35),
                              blurRadius: 48,
                              spreadRadius: 4,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.asset(
                            'rasora_web.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── App title ──
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFFAA00), Color(0xFFE8622A)],
                            ).createShader(bounds),
                            child: Text(
                              'Rasora',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 46,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.2,
                                height: 1.1,
                              ),
                            ),
                          ),
                          Text(
                            'Management Portal',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: orangeLight.withOpacity(0.85),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Subtitle ──
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: Text(
                      'Manage orders, menus, and your restaurant\noperations from one unified dashboard.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.50),
                        height: 1.7,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Progress bar ──
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      return Column(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
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
                                color: Colors.white.withOpacity(0.35),
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

          // ── Feature pills at bottom ──
          Positioned(
            bottom: 120,
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

          // ── App Store Download Buttons ──
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _downloadFade,
              child: _DownloadButtons(orange: orange),
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
        border: Border.all(color: Colors.white.withOpacity(0.10)),
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
              color: Colors.white.withOpacity(0.70),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadButtons extends StatefulWidget {
  final Color orange;

  const _DownloadButtons({
    required this.orange,
  });

  @override
  State<_DownloadButtons> createState() => _DownloadButtonsState();
}

class _DownloadButtonsState extends State<_DownloadButtons> {
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildDownloadButton({
    required String platform,
    required String storeName,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.orange.withOpacity(0.0),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: widget.orange.withOpacity(0.2),
          highlightColor: widget.orange.withOpacity(0.1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  color: widget.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Download on',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.60),
                    ),
                  ),
                  Text(
                    storeName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // App store URLs (replace with actual URLs)
    const String androidUrl = 'https://play.google.com/store/apps/details?id=com.example.rasora';
    const String iosUrl = 'https://apps.apple.com/app/rasora/id123456789';
    const String webUrl = 'https://rasora.app';

    if (kIsWeb) {
      // Show web download button
      return Center(
        child: _buildDownloadButton(
          platform: 'web',
          storeName: 'Web App',
          icon: Icons.language,
          onTap: () => _launchURL(webUrl),
        ),
      );
    }

    // Detect current platform and show appropriate icon
    String currentPlatform = 'unknown';
    IconData platformIcon = Icons.smartphone;
    String storeName = 'App Store';
    String storeUrl = iosUrl;

    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        currentPlatform = 'android';
        platformIcon = Icons.android;
        storeName = 'Google Play';
        storeUrl = androidUrl;
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        currentPlatform = 'ios';
        platformIcon = Icons.apple;
        storeName = 'App Store';
        storeUrl = iosUrl;
      } else {
        // Default to showing both buttons for other platforms
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Get the mobile app',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.50),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDownloadButton(
                  platform: 'android',
                  storeName: 'Google Play',
                  icon: Icons.android,
                  onTap: () => _launchURL(androidUrl),
                ),
                const SizedBox(width: 12),
                _buildDownloadButton(
                  platform: 'ios',
                  storeName: 'App Store',
                  icon: Icons.apple,
                  onTap: () => _launchURL(iosUrl),
                ),
              ],
            ),
          ],
        );
      }
    } catch (e) {
      // Fallback to showing both buttons if platform detection fails
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Get the mobile app',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.50),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDownloadButton(
                platform: 'android',
                storeName: 'Google Play',
                icon: Icons.android,
                onTap: () => _launchURL(androidUrl),
              ),
              const SizedBox(width: 12),
              _buildDownloadButton(
                platform: 'ios',
                storeName: 'App Store',
                icon: Icons.apple,
                onTap: () => _launchURL(iosUrl),
              ),
            ],
          ),
        ],
      );
    }

    // Show single platform-specific button
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Get the mobile app',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.50),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: _buildDownloadButton(
            platform: currentPlatform,
            storeName: storeName,
            icon: platformIcon,
            onTap: () => _launchURL(storeUrl),
          ),
        ),
      ],
    );
  }
}