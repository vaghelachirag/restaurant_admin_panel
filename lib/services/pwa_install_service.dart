// ─────────────────────────────────────────────────────────────────────────────
//  PWA INSTALL SERVICE
//  File: lib/services/pwa_install_service.dart
//
//  Shows install banner in TWO modes:
//   Mode A — Automatic: beforeinstallprompt available → one-tap install
//   Mode B — Manual:    prompt not available → shows step-by-step instructions
//                       so customer can still install via browser menu
// ─────────────────────────────────────────────────────────────────────────────

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PwaInstallService {
  PwaInstallService._();

  static bool isInstallAvailable() {
    if (!kIsWeb) return false;
    try {
      _runScript('''
        var el = document.getElementById('_pwa_install_available');
        if (!el) { el = document.createElement('meta'); el.id = '_pwa_install_available'; document.head.appendChild(el); }
        el.setAttribute('content', window._pwaInstallPrompt ? 'true' : 'false');
      ''');
      final meta = html.document.getElementById('_pwa_install_available');
      return meta?.getAttribute('content') == 'true';
    } catch (_) {
      return false;
    }
  }

  static bool isInstalled() {
    if (!kIsWeb) return false;
    try {
      final standalone = html.window.matchMedia('(display-mode: standalone)').matches;
      if (standalone) return true;
      _runScript('''
        var el = document.getElementById('_pwa_is_installed');
        if (!el) { el = document.createElement('meta'); el.id = '_pwa_is_installed'; document.head.appendChild(el); }
        el.setAttribute('content', (window.navigator.standalone === true || window._pwaInstalled === true) ? 'true' : 'false');
      ''');
      final meta = html.document.getElementById('_pwa_is_installed');
      return meta?.getAttribute('content') == 'true';
    } catch (_) {
      return false;
    }
  }

  static bool _isMobile() {
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      return ua.contains('android') || ua.contains('iphone') ||
          ua.contains('ipad')    || ua.contains('mobile');
    } catch (_) {
      return false;
    }
  }

  static bool _isIOS() {
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
    } catch (_) {
      return false;
    }
  }

  static Future<String> triggerInstall() async {
    if (!kIsWeb) return 'unavailable';
    try {
      if (!isInstallAvailable()) return 'unavailable';

      _runScript('''
        var el = document.getElementById('_pwa_install_result');
        if (!el) { el = document.createElement('meta'); el.id = '_pwa_install_result'; document.head.appendChild(el); }
        el.setAttribute('content', 'waiting');
      ''');

      _runScript('''
        (function() {
          try {
            if (!window._pwaInstallPrompt) {
              document.getElementById('_pwa_install_result').setAttribute('content', 'unavailable');
              return;
            }
            window._pwaInstallPrompt.prompt();
            window._pwaInstallPrompt.userChoice
              .then(function(choice) {
                window._pwaInstallPrompt = null;
                document.getElementById('_pwa_install_result').setAttribute('content', choice.outcome || 'dismissed');
              })
              .catch(function() {
                document.getElementById('_pwa_install_result').setAttribute('content', 'dismissed');
              });
          } catch(e) {
            document.getElementById('_pwa_install_result').setAttribute('content', 'unavailable');
          }
        })();
      ''');

      const pollInterval = Duration(milliseconds: 300);
      final deadline     = DateTime.now().add(const Duration(seconds: 60));

      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(pollInterval);
        final meta   = html.document.getElementById('_pwa_install_result');
        final result = meta?.getAttribute('content') ?? 'waiting';
        if (result != 'waiting') return result;
      }
      return 'dismissed';
    } catch (e) {
      debugPrint('[PWA] triggerInstall error: $e');
      return 'unavailable';
    }
  }

  static void _runScript(String jsCode) {
    try {
      final script = html.ScriptElement()..text = jsCode;
      html.document.head!.append(script);
      Future.microtask(() { try { script.remove(); } catch (_) {} });
    } catch (e) {
      debugPrint('[PWA] _runScript error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  INSTALL BANNER
  //  Always shows on mobile (even when prompt is not available).
  //  Mode A: one-tap install when beforeinstallprompt is available.
  //  Mode B: manual instructions dialog when prompt is not available.
  //  Invisible when already installed as PWA.
  // ─────────────────────────────────────────────────────────────────────────
  static Widget buildInstallBanner(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    if (isInstalled()) return const SizedBox.shrink();
    if (!_isMobile()) return const SizedBox.shrink();
    return const _PwaInstallBanner();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INSTALL BANNER WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _PwaInstallBanner extends StatefulWidget {
  const _PwaInstallBanner();
  @override
  State<_PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<_PwaInstallBanner> {
  bool _loading   = false;
  bool _dismissed = false;
  bool _promptAvailable = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkPrompt();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _checkPrompt() {
    _promptAvailable = PwaInstallService.isInstallAvailable();
    // Poll for up to 10 seconds in case prompt fires after Flutter loads
    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      attempts++;
      if (!mounted || attempts > 20) { timer.cancel(); return; }
      if (PwaInstallService.isInstalled()) { timer.cancel(); setState(() => _dismissed = true); return; }
      final available = PwaInstallService.isInstallAvailable();
      if (available != _promptAvailable) {
        timer.cancel();
        setState(() => _promptAvailable = available);
      }
    });
  }

  // ── Mode A: one-tap install ───────────────────────────────────────────────
  Future<void> _onInstallTap() async {
    setState(() => _loading = true);
    final result = await PwaInstallService.triggerInstall();
    if (!mounted) return;
    setState(() { _loading = false; _dismissed = true; });
    debugPrint('[PWA] Install result: $result');
  }

  // ── Mode B: show manual instructions dialog ───────────────────────────────
  void _showManualInstructions() {
    final isIOS     = PwaInstallService._isIOS();
    final steps     = isIOS
        ? [
      '1. Tap the  Share  button at the bottom of Safari',
      '2. Scroll down and tap "Add to Home Screen"',
      '3. Tap "Add" in the top right corner',
    ]
        : [
      '1. Tap the  ⋮  menu (three dots) in Chrome',
      '2. Tap "Add to Home screen"',
      '3. Tap "Add" to confirm',
    ];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFC9A84C), width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                const Icon(Icons.install_mobile_rounded,
                    color: Color(0xFFC9A84C), size: 22),
                const SizedBox(width: 10),
                Text(
                  'Install App',
                  style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: const Color(0xFFC9A84C),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                "Add Deepa's Kitchen to your home screen:",
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 16),

              // Steps
              ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle,
                        color: Color(0xFFC9A84C), size: 8),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(step,
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.white)),
                    ),
                  ],
                ),
              )),

              const SizedBox(height: 8),

              // Close button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _dismissed = true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A84C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text('Got it',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: Colors.black)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Container(
      margin:  const EdgeInsets.fromLTRB(0, 0, 0, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC9A84C), width: 1.2),
        boxShadow: [BoxShadow(
          color: const Color(0xFFC9A84C).withOpacity(0.15),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFC9A84C).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFC9A84C).withOpacity(0.4), width: 1),
            ),
            child: const Icon(Icons.restaurant_rounded,
                color: Color(0xFFC9A84C), size: 22),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Install Deepa's Kitchen",
                  style: GoogleFonts.poppins(fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFC9A84C)),
                ),
                const SizedBox(height: 1),
                Text(
                  _promptAvailable
                      ? 'Tap Install to add to home screen'
                      : 'Tap to see how to add to home screen',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Button — Mode A (one tap) or Mode B (instructions)
          _loading
              ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFFC9A84C)))
              : GestureDetector(
            onTap: _promptAvailable
                ? _onInstallTap          // Mode A — direct install
                : _showManualInstructions, // Mode B — show how-to dialog
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFC9A84C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _promptAvailable ? 'Install' : 'How to',
                style: GoogleFonts.poppins(fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Dismiss
          GestureDetector(
            onTap: () => setState(() => _dismissed = true),
            child: const Icon(Icons.close_rounded,
                size: 18, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}