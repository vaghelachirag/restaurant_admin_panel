import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/professional_loader.dart';
import '../services/fcm_web_service.dart';
import 'bill_screen.dart';
import 'customer_menu.dart';
import 'track_order.dart'; // ← Update Order navigation


// ─────────────────────────────────────────────────────────────────────────────
//  ORDER STEPS
// ─────────────────────────────────────────────────────────────────────────────
enum OrderStep { received, preparing, qualityCheck, readyForPickup }

extension OrderStepExt on OrderStep {
  String get label {
    switch (this) {
      case OrderStep.received:       return 'Order Received';
      case OrderStep.preparing:      return 'Preparing Your Food';
      case OrderStep.qualityCheck:   return 'Quality Check';
      case OrderStep.readyForPickup: return 'Ready to Serve';
    }
  }

  String get subtitle {
    switch (this) {
      case OrderStep.received:       return 'We got your order';
      case OrderStep.preparing:      return 'Our chefs are cooking';
      case OrderStep.qualityCheck:   return 'Final touches';
      case OrderStep.readyForPickup: return 'Enjoy your meal!';
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStep.received:       return Icons.receipt_long_rounded;
      case OrderStep.preparing:      return Icons.soup_kitchen_rounded;
      case OrderStep.qualityCheck:   return Icons.verified_rounded;
      case OrderStep.readyForPickup: return Icons.restaurant_rounded;
    }
  }

  bool isActiveOrDone(String s) {
    final statusMap = {
      'pending':   OrderStep.received,
      'preparing': OrderStep.preparing,
      'ready':     OrderStep.readyForPickup,
      'completed': OrderStep.readyForPickup,
    };
    final cur = statusMap[s.toLowerCase()] ?? OrderStep.received;
    return OrderStep.values.indexOf(this) <= OrderStep.values.indexOf(cur);
  }

  bool isCurrent(String s) {
    final statusMap = {
      'pending':   OrderStep.received,
      'preparing': OrderStep.preparing,
      'ready':     OrderStep.readyForPickup,
      'completed': OrderStep.readyForPickup,
    };
    return this == (statusMap[s.toLowerCase()] ?? OrderStep.received);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class OrderPlacedScreen extends StatefulWidget {
  final String restaurantId;
  final String orderId;
  final VoidCallback? onTrackOrder;
  final VoidCallback? onContinueShopping;

  const OrderPlacedScreen({
    super.key,
    required this.restaurantId,
    required this.orderId,
    this.onTrackOrder,
    this.onContinueShopping,
  });

  @override
  State<OrderPlacedScreen> createState() => _OrderPlacedScreenState();
}

class _OrderPlacedScreenState extends State<OrderPlacedScreen>
    with TickerProviderStateMixin {

  late AnimationController _confettiCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _slideAnim;

  final List<_ConfettiParticle> _particles = [];
  final Random _rng = Random();
  bool _authReady = false;
  bool _bannerKey = false;

  // ── Design tokens — matched to CustomerMenuPage (_C) ──────────────────────
  static const _bg     = Color(0xFFF8F5F0);   // _C.bg — warm cream
  static const _card   = Colors.white;
  static const _accent = Color(0xFFE8420E);   // _C.accent — orange-red
  static const _green  = Color(0xFF16A34A);   // _C.vegGreen
  static const _orange = Color(0xFFE8420E);   // same as accent
  static const _text1  = Color(0xFF1A1A2E);   // _C.textPrimary — dark navy
  static const _text2  = Color(0xFF6B7280);   // _C.textSecondary
  static const _border = Color(0xFFE5E7EB);   // _C.divider

  @override
  void initState() {
    super.initState();
    _ensureAuth();
    _spawnParticles();

    _confettiCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000),
    )..forward();

    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );

    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic),
    );

    // Register navigation callback for notification tap
    if (kIsWeb) {
      FcmWebService.onNavigateToOrder = (orderId, restaurantId) {
        if (!mounted) return;
        if (orderId == widget.orderId) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('You are already viewing this order'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ));
          return;
        }
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => OrderPlacedScreen(
            orderId: orderId, restaurantId: restaurantId,
          ),
        ));
      };
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fadeCtrl.forward();
    });
  }

  Future<void> _ensureAuth() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      await FirebaseAuth.instance.currentUser!.getIdToken(true);
    } catch (_) {}
    if (mounted) setState(() => _authReady = true);
  }

  void _spawnParticles() {
    final colors = [
      const Color(0xFFE8420E), // accent orange-red
      const Color(0xFF16A34A), // green
      const Color(0xFFFBBF24), // yellow
      const Color(0xFF1A1A2E), // navy
      const Color(0xFFEC4899), // pink
      const Color(0xFF06B6D4), // cyan
    ];
    for (int i = 0; i < 60; i++) {
      _particles.add(_ConfettiParticle(
        x: _rng.nextDouble(), y: _rng.nextDouble() * -0.4,
        vx: (_rng.nextDouble() - 0.5) * 0.3,
        vy: 0.25 + _rng.nextDouble() * 0.5,
        color: colors[_rng.nextInt(colors.length)],
        size: 3 + _rng.nextDouble() * 6,
        rotation: _rng.nextDouble() * pi * 2,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 0.12,
        isRect: _rng.nextBool(),
        delay: _rng.nextDouble() * 0.5,
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CONTINUE SHOPPING
  //
  //  Navigation stack when order placed:
  //    CustomerMenuPage → CartPage (pushReplacement → OrderPlacedScreen)
  //
  //  So stack is: CustomerMenuPage | OrderPlacedScreen
  //
  //  Three strategies in order of preference:
  //   1. If caller provided onContinueShopping callback — use it
  //   2. If there are pages to pop (CustomerMenuPage is below) — pop back
  //   3. If opened from notification (no menu below) — pushReplacement
  //      to CustomerMenuPage with restaurantId
  // ─────────────────────────────────────────────────────────────────────────
  void _onContinueShopping() {
    if (widget.onContinueShopping != null) {
      widget.onContinueShopping!();
      return;
    }

    // Check if there is a page below to pop back to
    final canPop = Navigator.of(context).canPop();

    if (canPop) {
      // CustomerMenuPage is below — just pop back to it
      Navigator.of(context).pop();
    } else {
      // Opened directly (e.g. from notification tap with tab closed)
      // No menu below — push a fresh CustomerMenuPage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CustomerMenuPage(
            restaurantId: widget.restaurantId,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _fadeCtrl.dispose();
    if (kIsWeb) FcmWebService.onNavigateToOrder = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: !_authReady
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('restaurants').doc(widget.restaurantId)
            .collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData ||
              snap.connectionState == ConnectionState.waiting) {
            return const FullScreenLoader(
              type: LoaderType.foodLoader,
              message: 'Loading your order...',
              primaryColor: _accent,
              secondaryColor: _orange,
            );
          }
          if (!snap.data!.exists) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 64, color: _text2),
                  const SizedBox(height: 16),
                  Text('Order not found.',
                      style: GoogleFonts.poppins(
                          fontSize: 16, color: _text2)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _onContinueShopping,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white),
                    child: Text('Back to Menu',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }

          final data   = snap.data!.data() as Map<String, dynamic>? ?? {};
          final token  = (data['tokenNumber'] ?? 0).toString();
          final total  = (data['totalAmount']  ?? 0).toDouble();
          final status = (data['status'] as String? ?? 'pending').toLowerCase();
          final isCancelled = status == 'cancelled';

          // ── Auto-navigate to bill when order is completed ─────────
          if (status == 'completed') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => BillScreen(
                    restaurantId: widget.restaurantId,
                    orderId:      widget.orderId,
                  ),
                ),
              );
            });
          }
          // ─────────────────────────────────────────────────────────

          return Stack(children: [
            Container(color: _bg),

            // Confetti
            if (!isCancelled)
              AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _ConfettiPainter(_particles, _confettiCtrl.value),
                  child: const SizedBox.expand(),
                ),
              ),

            // Content
            SafeArea(
              child: AnimatedBuilder(
                animation: _fadeCtrl,
                builder: (_, __) => Opacity(
                  opacity: _fadeAnim.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),

                          _buildHeader(
                            isCancelled: isCancelled,
                            token: token,
                            total: total,
                            status: status,
                          ),

                          const SizedBox(height: 16),

                          if (kIsWeb) ...[
                           // PwaInstallService.buildInstallBanner(context),
                            const SizedBox(height: 8),
                          ],

                          if (kIsWeb) ...[
                            FcmWebService.buildPermissionBanner(
                              context:      context,
                              orderId:      widget.orderId,
                              restaurantId: widget.restaurantId,
                              onGranted: () =>
                                  setState(() => _bannerKey = true),
                            ),
                            const SizedBox(height: 8),
                          ],

                          if (!isCancelled) _buildStatusTracker(status),
                          if (isCancelled)  _buildCancelledCard(),

                          const SizedBox(height: 20),
                          _buildActions(isCancelled: isCancelled, token: token),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader({
    required bool   isCancelled,
    required String token,
    required double total,
    required String status,
  }) {
    final headerColor = isCancelled
        ? const Color(0xFFEF4444)
        : (status == 'ready' || status == 'completed')
        ? const Color(0xFF16A34A)
        : const Color(0xFFE8420E);

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color: headerColor.withOpacity(0.12),
          blurRadius: 24, offset: const Offset(0, 8),
        )],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [headerColor, headerColor.withOpacity(0.8)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.6), width: 2),
              ),
              child: Icon(
                isCancelled ? Icons.cancel_rounded
                    : (status == 'ready' || status == 'completed')
                    ? Icons.check_circle_rounded
                    : Icons.receipt_long_rounded,
                color: Colors.white, size: 34,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isCancelled    ? 'Order Cancelled'
                  : status == 'ready'     ? 'Order Ready! 🍽️'
                  : status == 'completed' ? 'Order Completed!'
                  : 'Order Placed!',
              style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isCancelled
                  ? 'Your order has been cancelled'
                  : 'Your order has been received',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.white.withOpacity(0.85)),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            // Token
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8420E), Color(0xFFD63800)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Text('TOKEN',
                      style: GoogleFonts.poppins(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: Colors.white70, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text('#$token',
                      style: GoogleFonts.poppins(
                          fontSize: 28, fontWeight: FontWeight.w800,
                          color: Colors.white, height: 1)),
                ]),
              ),
            ),

            const SizedBox(width: 12),

            // Amount
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8420E).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8420E).withOpacity(0.15)),
                ),
                child: Column(children: [
                  Text('TOTAL',
                      style: GoogleFonts.poppins(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: _text2, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text('₹${total.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                          fontSize: 28, fontWeight: FontWeight.w800,
                          color: _accent, height: 1)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Status tracker ─────────────────────────────────────────────────────────
  Widget _buildStatusTracker(String status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 20, offset: const Offset(0, 6),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Order Status',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _text1)),
          const Spacer(),
          _StatusBadge(status: status),
        ]),
        const SizedBox(height: 20),
        ...List.generate(OrderStep.values.length, (i) {
          final step   = OrderStep.values[i];
          final isDone = step.isActiveOrDone(status) && !step.isCurrent(status);
          final isCurr = step.isCurrent(status);
          final isLast = i == OrderStep.values.length - 1;
          return _buildStepRow(
              step: step, isDone: isDone, isCurr: isCurr, isLast: isLast);
        }),
      ]),
    );
  }

  Widget _buildStepRow({
    required OrderStep step,
    required bool isDone,
    required bool isCurr,
    required bool isLast,
  }) {
    final circleColor = isDone ? _green : isCurr ? _accent : _border;
    final iconColor   = (isDone || isCurr) ? Colors.white : _text2;
    final lineColor   = isDone ? _green : _border;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              boxShadow: (isDone || isCurr)
                  ? [BoxShadow(color: circleColor.withOpacity(0.3),
                  blurRadius: 8, offset: const Offset(0, 3))]
                  : null,
            ),
            child: Icon(
              isDone ? Icons.check_rounded : step.icon,
              color: iconColor, size: 20,
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [lineColor, lineColor.withOpacity(0.2)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
        ]),

        const SizedBox(width: 16),

        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 10, bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.label,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: (isDone || isCurr)
                            ? FontWeight.w600 : FontWeight.w400,
                        color: (isDone || isCurr) ? _text1 : _text2)),
                const SizedBox(height: 2),
                Text(
                  isDone  ? '✓ Completed'
                      : isCurr ? '🕐 In progress...'
                      : step.subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDone ? _green : isCurr ? _accent : _text2,
                  ),
                ),
                if (isCurr) ...[
                  const SizedBox(height: 8),
                  _AnimatedProgressBar(color: _accent),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Cancelled card ─────────────────────────────────────────────────────────
  Widget _buildCancelledCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cancel_rounded,
              color: Color(0xFFEF4444), size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Order Cancelled',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: const Color(0xFF991B1B))),
            const SizedBox(height: 4),
            Text('Your order was cancelled. Please contact the staff.',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: const Color(0xFFDC2626))),
          ]),
        ),
      ]),
    );
  }

  // ── Action buttons ─────────────────────────────────────────────────────────
  Widget _buildActions({required bool isCancelled, required String token}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 16, offset: const Offset(0, 4),
        )],
      ),
      child: Column(children: [

        // ── Update Order — primary CTA ────────────────────────────────────
        if (!isCancelled) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TrackOrderPage(
                      restaurantId: widget.restaurantId,
                      initialToken: token,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: Text('Update Order',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,           // orange-red
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Return to Menu — secondary ────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _onContinueShopping,
            icon: Icon(Icons.restaurant_menu_rounded,
                size: 18, color: _accent),
            label: Text('Return to Menu',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: _text1)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: _accent.withOpacity(0.4), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = _config(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: cfg['bg'] as Color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(
                color: cfg['dot'] as Color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(cfg['label'] as String,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: cfg['text'] as Color)),
      ]),
    );
  }

  Map<String, dynamic> _config(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return { 'label': 'Pending',
          'bg': const Color(0xFFFEF9C3),
          'text': const Color(0xFF854D0E),
          'dot': const Color(0xFFEAB308) };
      case 'preparing':
        return { 'label': 'Preparing',
          'bg': const Color(0xFFFFF0EB),
          'text': const Color(0xFFE8420E),
          'dot': const Color(0xFFE8420E) };
      case 'ready':
        return { 'label': 'Ready! 🍽️',
          'bg': const Color(0xFFDCFCE7),
          'text': const Color(0xFF15803D),
          'dot': const Color(0xFF22C55E) };
      case 'completed':
        return { 'label': 'Completed ✓',
          'bg': const Color(0xFFDCFCE7),
          'text': const Color(0xFF15803D),
          'dot': const Color(0xFF22C55E) };
      case 'cancelled':
        return { 'label': 'Cancelled',
          'bg': const Color(0xFFFEE2E2),
          'text': const Color(0xFF991B1B),
          'dot': const Color(0xFFEF4444) };
      default:
        return { 'label': s,
          'bg': const Color(0xFFF3F4F6),
          'text': const Color(0xFF6B7280),
          'dot': const Color(0xFF9CA3AF) };
    }
  }
}

// ─── Animated Progress Bar ────────────────────────────────────────────────────
class _AnimatedProgressBar extends StatefulWidget {
  final Color color;
  const _AnimatedProgressBar({required this.color});

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 4,
        color: widget.color.withOpacity(0.15),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _anim.value,
            child: Container(
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Confetti ─────────────────────────────────────────────────────────────────
class _ConfettiParticle {
  final double x, vx, vy, size, rotation, rotationSpeed, delay;
  double y;
  final Color color;
  final bool isRect;

  _ConfettiParticle({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.color, required this.size, required this.rotation,
    required this.rotationSpeed, required this.isRect, required this.delay,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final t = (progress - p.delay).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final alpha = t < 0.7 ? 1.0 : (1.0 - t) / 0.3;
      final cx    = (p.x + p.vx * t) * size.width;
      final cy    = (p.y + p.vy * t) * size.height;
      final rot   = p.rotation + p.rotationSpeed * t * 10;
      paint.color = p.color.withOpacity(alpha.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      if (p.isRect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.5),
            const Radius.circular(1),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}