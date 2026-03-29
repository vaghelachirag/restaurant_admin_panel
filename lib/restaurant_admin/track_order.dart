import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

const _kPrimary = Color(0xFF7C3AED);
const _kPrimaryLight = Color(0xFFA855F7);
const _kPrimaryBg = Color(0xFFF3EEFF);
const _kBg = Color(0xFFF8F9FA);
const _kCard = Colors.white;
const _kText = Color(0xFF111827);
const _kSubText = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kGreenBg = Color(0xFFDCFCE7);
const _kGreenText = Color(0xFF15803D);

Color hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  if (hex.length == 6) hex = "FF$hex";
  return Color(int.parse(hex, radix: 16));
}

double _s(double val) => kIsWeb ? val : val.sp;
double _h(double val) => kIsWeb ? val : val.h;
double _w(double val) => kIsWeb ? val : val.w;

class TrackOrderPage extends StatefulWidget {
  final String restaurantId;

  /// Optional: pass a token number to pre-fill and auto-search (e.g. after order success)
  final String? initialToken;

  /// Called when user taps "Continue Shopping" button
  final VoidCallback? onContinueShopping;

  const TrackOrderPage({
    super.key,
    required this.restaurantId,
    this.initialToken,
    this.onContinueShopping,
  });

  @override
  State<TrackOrderPage> createState() => _TrackOrderPageState();
}

class _TrackOrderPageState extends State<TrackOrderPage> {
  final TextEditingController _tokenCtrl = TextEditingController();
  String? _searchedToken;

  @override
  void initState() {
    super.initState();
    // Pre-fill token and auto-search when navigated from order success
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      _tokenCtrl.text = widget.initialToken!;
      _searchedToken = widget.initialToken;
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .snapshots(),
      builder: (context, restaurantSnap) {
        if (restaurantSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${restaurantSnap.error}',
                  style: GoogleFonts.poppins()),
            ),
          );
        }
        if (!restaurantSnap.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: _kPrimary),
            ),
          );
        }

        final rawData = restaurantSnap.data!.data();
        if (rawData == null) {
          return const Scaffold(body: Center(child: Text('Restaurant not found')));
        }

        return Scaffold(
          backgroundColor: _kBg,
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: _s(16),
              vertical: _h(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Title
                // _PageHeader(),

                SizedBox(height: _h(20)),

                // Track Your Order Banner Card
                _TrackBannerCard(
                  tokenCtrl: _tokenCtrl,
                  onTrack: () => setState(
                          () => _searchedToken = _tokenCtrl.text.trim()),
                ),

                SizedBox(height: _h(28)),

                // Order Result (shown after search)
                if (_searchedToken != null && _searchedToken!.isNotEmpty)
                  _OrderResultSection(
                    restaurantId: widget.restaurantId,
                    token: _searchedToken!,
                    buildStatusChip: _buildStatusChip,
                    onContinueShopping: widget.onContinueShopping,
                  ),

                // Past Orders Section
                if (_searchedToken == null || _searchedToken!.isEmpty) ...[
                  _SectionLabel(label: 'Past Orders'),
                  SizedBox(height: _h(12)),
                  _PastOrdersList(restaurantId: widget.restaurantId),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      centerTitle: false,
      title: Row(
        children: [
          // Logo circle
          Container(
            width: _s(34),
            height: _s(34),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('🍦', style: TextStyle(fontSize: _s(18))),
            ),
          ),
          SizedBox(width: _w(10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Havmore Icecream',
                style: GoogleFonts.poppins(
                  fontSize: _s(16),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              Text(
                'Premium Ice Cream',
                style: GoogleFonts.poppins(
                  fontSize: _s(10),
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: _w(16)),
          child: Icon(Icons.shopping_cart_outlined,
              color: Colors.white, size: _s(24)),
        ),
      ],
    );
  }

  // ── Status Chip ────────────────────────────────────────────────────────────
  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFF854D0E);
        label = 'Pending';
        break;
      case 'preparing':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1E40AF);
        label = 'Preparing';
        break;
      case 'ready':
        bg = _kGreenBg;
        fg = _kGreenText;
        label = 'Ready';
        break;
      case 'completed':
        bg = _kGreenBg;
        fg = _kGreenText;
        label = 'Completed';
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = _kSubText;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _s(12),
        vertical: _s(5),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_s(20)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: _s(12),
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ─── Page Header ──────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Orders',
          style: GoogleFonts.poppins(
            fontSize: _s(22),
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        SizedBox(height: _h(2)),
        Text(
          'Track and view your order history',
          style: GoogleFonts.poppins(
            fontSize: _s(13),
            fontWeight: FontWeight.w400,
            color: _kSubText,
          ),
        ),
      ],
    );
  }
}

// ─── Track Banner Card ────────────────────────────────────────────────────────
class _TrackBannerCard extends StatefulWidget {
  final TextEditingController tokenCtrl;
  final VoidCallback onTrack;

  const _TrackBannerCard({required this.tokenCtrl, required this.onTrack});

  @override
  State<_TrackBannerCard> createState() => _TrackBannerCardState();
}

class _TrackBannerCardState extends State<_TrackBannerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_expanded) setState(() => _expanded = true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(_s(16)),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withOpacity(0.3),
              blurRadius: _s(16),
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _expanded ? _expandedContent() : _collapsedContent(),
      ),
    );
  }

  Widget _collapsedContent() {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: _s(20), vertical: _s(22)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track Your Order',
                  style: GoogleFonts.poppins(
                    fontSize: _s(17),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: _h(4)),
                Text(
                  'Enter your token number to track',
                  style: GoogleFonts.poppins(
                    fontSize: _s(12),
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.inventory_2_outlined,
              color: Colors.white.withOpacity(0.9), size: _s(36)),
        ],
      ),
    );
  }

  Widget _expandedContent() {
    return Padding(
      padding: EdgeInsets.all(_s(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Track Your Order',
                style: GoogleFonts.poppins(
                  fontSize: _s(17),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _expanded = false),
                child: Icon(Icons.keyboard_arrow_up_rounded,
                    color: Colors.white70, size: _s(24)),
              ),
            ],
          ),
          SizedBox(height: _h(14)),

          // Token Input Field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_s(12)),
            ),
            child: TextField(
              controller: widget.tokenCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(
                fontSize: _s(15),
                color: _kText,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Enter token number...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: _s(14),
                  color: _kSubText,
                ),
                prefixIcon: Icon(
                  Icons.confirmation_number_outlined,
                  color: _kPrimary,
                  size: _s(20),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    vertical: _s(14), horizontal: _s(4)),
              ),
            ),
          ),

          SizedBox(height: _h(12)),

          // Track Button
          SizedBox(
            width: double.infinity,
            height: _s(48),
            child: ElevatedButton(
              onPressed: widget.onTrack,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _kPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_s(12)),
                ),
              ),
              child: Text(
                'Track Order',
                style: GoogleFonts.poppins(
                  fontSize: _s(15),
                  fontWeight: FontWeight.w700,
                  color: _kPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: _s(15),
        fontWeight: FontWeight.w600,
        color: _kText,
      ),
    );
  }
}

// ─── Past Orders List ─────────────────────────────────────────────────────────
class _PastOrdersList extends StatelessWidget {
  final String restaurantId;
  const _PastOrdersList({required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: restaurantId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kPrimary));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No past orders',
            subtitle: 'Your order history will appear here',
          );
        }

        return Column(
          children: snap.data!.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final token = d['tokenNumber'] ?? '';
            final amount = d['totalAmount'] ?? 0;
            final status = d['status'] as String? ?? 'pending';
            final itemCount = (d['items'] as List?)?.length ?? 0;
            final ts = d['createdAt'];
            String dateStr = '';
            if (ts is Timestamp) {
              final dt = ts.toDate();
              dateStr =
              '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
            }

            return _PastOrderCard(
              token: token.toString(),
              amount: amount.toString(),
              status: status,
              date: dateStr,
              itemCount: itemCount,
            );
          }).toList(),
        );
      },
    );
  }

  String _monthName(int m) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[m];
  }
}

// ─── Past Order Card ──────────────────────────────────────────────────────────
class _PastOrderCard extends StatelessWidget {
  final String token;
  final String amount;
  final String status;
  final String date;
  final int itemCount;

  const _PastOrderCard({
    required this.token,
    required this.amount,
    required this.status,
    required this.date,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    Color statusBg;
    Color statusFg;
    switch (status.toLowerCase()) {
      case 'completed':
        statusBg = _kGreenBg;
        statusFg = _kGreenText;
        break;
      case 'preparing':
        statusBg = const Color(0xFFDBEAFE);
        statusFg = const Color(0xFF1E40AF);
        break;
      case 'pending':
        statusBg = const Color(0xFFFEF9C3);
        statusFg = const Color(0xFF854D0E);
        break;
      default:
        statusBg = const Color(0xFFF3F4F6);
        statusFg = _kSubText;
    }

    return Container(
      margin: EdgeInsets.only(bottom: _h(12)),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(_s(14)),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: _s(10),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row
          Padding(
            padding: EdgeInsets.fromLTRB(_s(16), _s(14), _s(16), _s(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Token #$token',
                      style: GoogleFonts.poppins(
                        fontSize: _s(12),
                        fontWeight: FontWeight.w500,
                        color: _kSubText,
                      ),
                    ),
                    SizedBox(height: _h(2)),
                    Text(
                      '₹$amount',
                      style: GoogleFonts.poppins(
                        fontSize: _s(22),
                        fontWeight: FontWeight.w700,
                        color: _kText,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: _s(12), vertical: _s(5)),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(_s(20)),
                  ),
                  child: Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: GoogleFonts.poppins(
                      fontSize: _s(12),
                      fontWeight: FontWeight.w600,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: _kBorder),

          // Bottom row
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: _s(16), vertical: _s(10)),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: _s(13), color: _kSubText),
                SizedBox(width: _w(5)),
                Text(
                  date,
                  style: GoogleFonts.poppins(
                    fontSize: _s(12),
                    color: _kSubText,
                  ),
                ),
                const Spacer(),
                Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                  style: GoogleFonts.poppins(
                    fontSize: _s(12),
                    color: _kSubText,
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

// ─── Order Result Section ─────────────────────────────────────────────────────
class _OrderResultSection extends StatelessWidget {
  final String restaurantId;
  final String token;
  final Widget Function(String) buildStatusChip;
  final VoidCallback? onContinueShopping;

  const _OrderResultSection({
    required this.restaurantId,
    required this.token,
    required this.buildStatusChip,
    this.onContinueShopping,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: restaurantId)
          .where('tokenNumber', isEqualTo: int.tryParse(token))
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(_s(40)),
              child: const CircularProgressIndicator(color: _kPrimary),
            ),
          );
        }

        if (snap.hasError) {
          return _StatusMessage(
            icon: Icons.error_outline_rounded,
            iconColor: Colors.red.shade400,
            title: 'Error loading order',
            subtitle: snap.error.toString(),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _StatusMessage(
            icon: Icons.search_off_rounded,
            iconColor: _kSubText,
            title: 'Order not found',
            subtitle: 'No order found for token #$token. Please check and try again.',
          );
        }

        final orderData = snap.data!.docs.first.data() as Map<String, dynamic>;
        final status = orderData['status'] as String? ?? 'pending';
        final tokenNumber = orderData['tokenNumber'] ?? 0;
        final totalAmount = orderData['totalAmount'] ?? 0;
        final customerName = orderData['customerName'] as String? ?? 'Guest';
        final orderType = orderData['orderType'] as String? ?? 'Dine In';
        final items = orderData['items'] as List<dynamic>? ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(label: 'Order Details'),
            SizedBox(height: _h(12)),
            _OrderDetailCard(
              status: status,
              tokenNumber: tokenNumber.toString(),
              totalAmount: totalAmount.toString(),
              customerName: customerName,
              orderType: orderType,
              items: items,
              buildStatusChip: buildStatusChip,
              onContinueShopping: onContinueShopping,
            ),
          ],
        );
      },
    );
  }
}

// ─── Order Detail Card ────────────────────────────────────────────────────────
class _OrderDetailCard extends StatelessWidget {
  final String status;
  final String tokenNumber;
  final String totalAmount;
  final String customerName;
  final String orderType;
  final List<dynamic> items;
  final Widget Function(String) buildStatusChip;
  final VoidCallback? onContinueShopping;

  const _OrderDetailCard({
    required this.status,
    required this.tokenNumber,
    required this.totalAmount,
    required this.customerName,
    required this.orderType,
    required this.items,
    required this.buildStatusChip,
    this.onContinueShopping,
  });

  /// Map status string → step index (0-based)
  int get _currentStep {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'preparing':
        return 1;
      case 'ready':
        return 2;
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Pending', 'Preparing', 'Ready', 'Completed'];
    final stepIcons = [
      Icons.receipt_outlined,
      Icons.restaurant_outlined,
      Icons.check_circle_outline_rounded,
      Icons.done_all_rounded,
    ];
    final activeStep = _currentStep;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(_s(16)),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: _s(12),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient Header ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(_s(16)),
                topRight: Radius.circular(_s(16)),
              ),
            ),
            padding: EdgeInsets.symmetric(
                horizontal: _s(16), vertical: _s(14)),
            child: Row(
              children: [
                // Token badge
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: _s(12), vertical: _s(6)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(_s(10)),
                  ),
                  child: Text(
                    'Token #$tokenNumber',
                    style: GoogleFonts.poppins(
                      fontSize: _s(14),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                buildStatusChip(status),
              ],
            ),
          ),

          // ── Progress Stepper ───────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(_s(16), _s(20), _s(16), _s(4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Progress',
                  style: GoogleFonts.poppins(
                    fontSize: _s(13),
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                SizedBox(height: _h(14)),
                Row(
                  children: List.generate(steps.length * 2 - 1, (i) {
                    if (i.isOdd) {
                      // Connector line
                      final stepIdx = (i - 1) ~/ 2;
                      final isDone = stepIdx < activeStep;
                      return Expanded(
                        child: Container(
                          height: _s(2),
                          color: isDone ? _kPrimary : _kBorder,
                        ),
                      );
                    }
                    final stepIdx = i ~/ 2;
                    final isDone = stepIdx < activeStep;
                    final isActive = stepIdx == activeStep;
                    return Column(
                      children: [
                        Container(
                          width: _s(32),
                          height: _s(32),
                          decoration: BoxDecoration(
                            color: (isDone || isActive)
                                ? _kPrimary
                                : _kBorder,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDone
                                ? Icons.check_rounded
                                : stepIcons[stepIdx],
                            color: (isDone || isActive)
                                ? Colors.white
                                : _kSubText,
                            size: _s(16),
                          ),
                        ),
                        SizedBox(height: _h(4)),
                        Text(
                          steps[stepIdx],
                          style: GoogleFonts.poppins(
                            fontSize: _s(9),
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isActive ? _kPrimary : _kSubText,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),

          Divider(height: _s(24), color: _kBorder),

          // ── Body ───────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(_s(16), 0, _s(16), _s(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer row
                Row(
                  children: [
                    Container(
                      width: _s(36),
                      height: _s(36),
                      decoration: BoxDecoration(
                        color: _kPrimaryBg,
                        borderRadius: BorderRadius.circular(_s(10)),
                      ),
                      child: Icon(Icons.person_outline_rounded,
                          color: _kPrimary, size: _s(20)),
                    ),
                    SizedBox(width: _w(10)),
                    Expanded(
                      child: Text(
                        customerName,
                        style: GoogleFonts.poppins(
                          fontSize: _s(15),
                          fontWeight: FontWeight.w600,
                          color: _kText,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: _s(10), vertical: _s(4)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(_s(10)),
                      ),
                      child: Text(
                        orderType,
                        style: GoogleFonts.poppins(
                          fontSize: _s(12),
                          color: _kSubText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                if (items.isNotEmpty) ...[
                  SizedBox(height: _h(18)),
                  Text(
                    'Order Items',
                    style: GoogleFonts.poppins(
                      fontSize: _s(13),
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                  SizedBox(height: _h(10)),
                  ...items.map((item) => _ItemRow(item: item)),
                ],

                SizedBox(height: _h(16)),

                // Total amount row
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: _s(14), vertical: _s(12)),
                  decoration: BoxDecoration(
                    color: _kPrimaryBg,
                    borderRadius: BorderRadius.circular(_s(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.poppins(
                          fontSize: _s(14),
                          fontWeight: FontWeight.w600,
                          color: _kText,
                        ),
                      ),
                      Text(
                        '₹$totalAmount',
                        style: GoogleFonts.poppins(
                          fontSize: _s(18),
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Continue Shopping Button ────────────────────────────
                if (onContinueShopping != null) ...[
                  SizedBox(height: _h(16)),
                  SizedBox(
                    width: double.infinity,
                    height: _s(48),
                    child: OutlinedButton.icon(
                      onPressed: onContinueShopping,
                      icon: Icon(Icons.shopping_bag_outlined,
                          size: _s(18), color: _kPrimary),
                      label: Text(
                        'Continue Shopping',
                        style: GoogleFonts.poppins(
                          fontSize: _s(14),
                          fontWeight: FontWeight.w600,
                          color: _kPrimary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kPrimary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_s(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Item Row ─────────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final dynamic item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: _h(8)),
      child: Row(
        children: [
          Container(
            width: _s(4),
            height: _s(16),
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(_s(2)),
            ),
          ),
          SizedBox(width: _w(10)),
          Expanded(
            child: Text(
              "${item['name']} (${item['variant']}) x${item['qty']}",
              style: GoogleFonts.poppins(
                fontSize: _s(13),
                color: _kSubText,
              ),
            ),
          ),
          Text(
            "₹${item['price'] * item['qty']}",
            style: GoogleFonts.poppins(
              fontSize: _s(13),
              fontWeight: FontWeight.w600,
              color: _kPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Message (empty / error) ──────────────────────────────────────────
class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _StatusMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_s(24)),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(_s(16)),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: _s(48)),
          SizedBox(height: _h(12)),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: _s(15),
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          SizedBox(height: _h(6)),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: _s(13),
              color: _kSubText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _s(40)),
        child: Column(
          children: [
            Container(
              width: _s(72),
              height: _s(72),
              decoration: BoxDecoration(
                color: _kPrimaryBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _kPrimary, size: _s(36)),
            ),
            SizedBox(height: _h(16)),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: _s(16),
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
            SizedBox(height: _h(6)),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: _s(13),
                color: _kSubText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}