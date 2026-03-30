import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/professional_loader.dart';

enum OrderStep { received, preparing, qualityCheck, readyForPickup }

extension OrderStepExt on OrderStep {
  String get label {
    switch (this) {
      case OrderStep.received:
        return 'Order Received';
      case OrderStep.preparing:
        return 'Preparing Food';
      case OrderStep.qualityCheck:
        return 'Quality Check';
      case OrderStep.readyForPickup:
        return 'Ready for Pickup';
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStep.received:
        return Icons.check_circle_outline_rounded;
      case OrderStep.preparing:
        return Icons.restaurant_outlined;
      case OrderStep.qualityCheck:
        return Icons.done_all_rounded;
      case OrderStep.readyForPickup:
        return Icons.inventory_2_outlined;
    }
  }

  /// Map Firestore status string → which steps are active/completed
  bool isActiveOrDone(String firestoreStatus) {
    final order = [
      OrderStep.received,
      OrderStep.preparing,
      OrderStep.qualityCheck,
      OrderStep.readyForPickup,
    ];
    final statusMap = {
      'pending': OrderStep.received,
      'preparing': OrderStep.preparing,
      'ready': OrderStep.readyForPickup,
      'completed': OrderStep.readyForPickup,
    };
    final currentStep =
        statusMap[firestoreStatus.toLowerCase()] ?? OrderStep.received;
    return order.indexOf(this) <= order.indexOf(currentStep);
  }

  bool isCurrent(String firestoreStatus) {
    final statusMap = {
      'pending': OrderStep.received,
      'preparing': OrderStep.preparing,
      'ready': OrderStep.readyForPickup,
      'completed': OrderStep.readyForPickup,
    };
    return this ==
        (statusMap[firestoreStatus.toLowerCase()] ?? OrderStep.received);
  }
}

// ─── Main Screen ─────────────────────────────────────────────────────────────
class OrderPlacedScreen extends StatefulWidget {
  final String orderId;

  /// Optional callbacks wired from outside
  final VoidCallback? onTrackOrder;
  final VoidCallback? onContinueShopping;

  const OrderPlacedScreen({
    super.key,
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
  late AnimationController _cardCtrl;
  late AnimationController _checkCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _cardSlide;
  late Animation<double> _cardFade;
  late Animation<double> _checkScale;
  late Animation<double> _pulse;

  final List<_ConfettiParticle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _spawnParticles();

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();

    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _cardSlide = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic),
    );
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut),
    );
    _checkScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Always start animations immediately so status card is visible
    // regardless of navigation source (direct open, deep link, customer menu, etc.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkCtrl.forward();
        _cardCtrl.forward();
      }
    });
  }

  void _spawnParticles() {
    final colors = [
      const Color(0xFFE8532A),
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFFC107),
      const Color(0xFF9C27B0),
      const Color(0xFFFF5722),
      const Color(0xFF00BCD4),
      const Color(0xFFFFEB3B),
    ];
    for (int i = 0; i < 60; i++) {
      _particles.add(_ConfettiParticle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * -0.3,
        vx: (_rng.nextDouble() - 0.5) * 0.4,
        vy: 0.3 + _rng.nextDouble() * 0.5,
        color: colors[_rng.nextInt(colors.length)],
        size: 4 + _rng.nextDouble() * 6,
        rotation: _rng.nextDouble() * pi * 2,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 0.15,
        isRect: _rng.nextBool(),
        delay: _rng.nextDouble() * 0.4,
      ));
    }
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _cardCtrl.dispose();
    _checkCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEF4),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          // ── 1. Error state (check first so it's never swallowed) ──────────
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          // ── 2. Loading state (waiting OR no data yet) ─────────────────────
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const FullScreenLoader(
              type: LoaderType.foodLoader,
              message: 'Loading your order...',
              primaryColor: Color(0xFF7C3AED),
              secondaryColor: Color(0xFFEC4899),
            );
          }

          // ── 3. Order not found (invalid orderId from deep link) ───────────
          if (!snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Order not found.',
                style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
              ),
            );
          }

          // ── 4. Data ready ─────────────────────────────────────────────────
          final data =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final token = (data['tokenNumber'] ?? 0).toString();
          final total = (data['totalAmount'] ?? 0).toDouble();
          final status = data['status'] as String? ?? 'pending';

          return Stack(
            children: [
              // Background
              Container(color: const Color(0xFFEEEEF4)),

              // Confetti
              AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _ConfettiPainter(_particles, _confettiCtrl.value),
                  child: const SizedBox.expand(),
                ),
              ),

              // Content
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  child: AnimatedBuilder(
                    animation: Listenable.merge(
                        [_cardCtrl, _checkCtrl, _pulseCtrl]),
                    builder: (context, _) {
                      return Column(
                        children: [
                          const SizedBox(height: 10),

                          // ── Card 1: Success Header ──────────────────────
                          Transform.translate(
                            offset: Offset(0, _cardSlide.value),
                            child: Opacity(
                              opacity: _cardFade.value,
                              child: _SuccessCard(
                                checkScale: _checkScale.value,
                                pulse: _pulse.value,
                                tokenNumber: token,
                                totalAmount: total,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Card 2: Order Status (live from Firestore) ──
                          // NOTE: opacity is clamped to min 1.0 so the status
                          // card is always visible even when navigated from
                          // the customer menu link (where animation may not
                          // have run yet).
                          Transform.translate(
                            offset: Offset(0, _cardSlide.value * 1.3),
                            child: Opacity(
                              opacity: _cardFade.value.clamp(0.0, 1.0) == 0.0
                                  ? 1.0
                                  : _cardFade.value,
                              child: _OrderStatusCard(status: status),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Buttons ─────────────────────────────────────
                          Transform.translate(
                            offset: Offset(0, _cardSlide.value * 1.6),
                            child: Opacity(
                              opacity: _cardFade.value,
                              child: _ActionButtons(
                                onTrackOrder: widget.onTrackOrder,
                                onContinueShopping: widget.onContinueShopping,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Success Card ─────────────────────────────────────────────────────────────
class _SuccessCard extends StatelessWidget {
  final double checkScale;
  final double pulse;
  final String tokenNumber;
  final double totalAmount;

  const _SuccessCard({
    required this.checkScale,
    required this.pulse,
    required this.tokenNumber,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Green header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: const BoxDecoration(
              color: Color(0xFF3DC45A),
            ),
            child: Column(
              children: [
                // Animated check circle
                Transform.scale(
                  scale: checkScale * pulse,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      color: const Color(0xFF3DC45A),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Order Placed!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your order has been received',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.88),
                  ),
                ),
              ],
            ),
          ),

          // Token number section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF6881F), Color(0xFFE8532A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  'TOKEN NUMBER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.85),
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tokenNumber,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // Total amount row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  '₹${totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
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

class _OrderStatusCard extends StatelessWidget {
  final String status;

  const _OrderStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = OrderStep.values;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Order Status',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              // Live status badge
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBadgeBg(status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusBadgeFg(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.map((step) => _StatusRow(
            step: step,
            isActive: step.isCurrent(status),
            isDone:
            step.isActiveOrDone(status) && !step.isCurrent(status),
          )),
        ],
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'preparing':
        return 'Preparing';
      case 'ready':
        return 'Ready';
      case 'completed':
        return 'Completed';
      default:
        return s;
    }
  }

  Color _statusBadgeBg(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFEF9C3);
      case 'preparing':
        return const Color(0xFFDBEAFE);
      case 'ready':
      case 'completed':
        return const Color(0xFFDCFCE7);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _statusBadgeFg(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return const Color(0xFF854D0E);
      case 'preparing':
        return const Color(0xFF1E40AF);
      case 'ready':
      case 'completed':
        return const Color(0xFF15803D);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _StatusRow extends StatelessWidget {
  final OrderStep step;
  final bool isActive; // currently in progress
  final bool isDone; // already completed

  const _StatusRow({
    required this.step,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconBg = isDone
        ? const Color(0xFF3DC45A).withOpacity(0.12)
        : isActive
        ? const Color(0xFFEDE9FF)
        : const Color(0xFFF5F5F5);

    final Color iconColor = isDone
        ? const Color(0xFF3DC45A)
        : isActive
        ? const Color(0xFF6B4EFF)
        : const Color(0xFFB0B0B0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check_rounded : step.icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: (isActive || isDone)
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: (isActive || isDone)
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFAAAAAA),
                ),
              ),
              if (isActive)
                const Text(
                  '🕐 In progress...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF888888),
                  ),
                ),
              if (isDone)
                const Text(
                  '✓ Done',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF3DC45A),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Action Buttons ───────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  final VoidCallback? onTrackOrder;
  final VoidCallback? onContinueShopping;

  const _ActionButtons({this.onTrackOrder, this.onContinueShopping});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Track Order
          Expanded(
            child: OutlinedButton(
              onPressed: onTrackOrder ?? () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Track Order',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Continue Shopping
          Expanded(
            child: ElevatedButton(
              onPressed: onContinueShopping ??
                      () => Navigator.popUntil(context, (r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: const Color(0xFF6B4EFF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue Shopping',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiParticle {
  final double x;
  double y;
  final double vx;
  final double vy;
  final Color color;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final bool isRect;
  final double delay;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.isRect,
    required this.delay,
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
      final cx = (p.x + p.vx * t) * size.width;
      final cy = (p.y + p.vy * t) * size.height;
      final rot = p.rotation + p.rotationSpeed * t * 10;

      paint.color = p.color.withOpacity(alpha.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);

      if (p.isRect) {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
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