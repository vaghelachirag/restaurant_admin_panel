import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_update_service.dart';

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

// ── Helper: returns the currently signed-in user's uid, or null ──────────────
String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

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
    // ── FIX: restaurants/{id} is allow read: if true — no auth needed ─────────
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
          return const Scaffold(
              body: Center(child: Text('Restaurant not found')));
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
                SizedBox(height: _h(20)),

                _TrackBannerCard(
                  tokenCtrl: _tokenCtrl,
                  onTrack: () =>
                      setState(() => _searchedToken = _tokenCtrl.text.trim()),
                ),

                SizedBox(height: _h(28)),

                // Order result (shown after token search)
                if (_searchedToken != null && _searchedToken!.isNotEmpty)
                  _OrderResultSection(
                    restaurantId: widget.restaurantId,
                    token: _searchedToken!,
                    buildStatusChip: _buildStatusChip,
                    onContinueShopping: widget.onContinueShopping,
                  ),

                // Past orders (shown when no search active)
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

  // ── Status Chip ─────────────────────────────────────────────────────────────
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
      padding: EdgeInsets.symmetric(horizontal: _s(20), vertical: _s(22)),
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
                hintStyle:
                GoogleFonts.poppins(fontSize: _s(14), color: _kSubText),
                prefixIcon: Icon(Icons.confirmation_number_outlined,
                    color: _kPrimary, size: _s(20)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    vertical: _s(14), horizontal: _s(4)),
              ),
            ),
          ),
          SizedBox(height: _h(12)),
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
    // ── FIX: Customers have no restaurantId claim, so Firestore denies any
    //    collection query that the rules evaluate with isAdminOrOwner().
    //    The rules DO allow: request.auth.uid == resource.data.userId
    //    But that only works if we include userId in the query — Firestore
    //    needs it as a filter to safely evaluate per-document rules on a
    //    collection scan.
    final uid = _currentUid;
    if (uid == null) {
      return _EmptyState(
        icon: Icons.lock_outline,
        title: 'Not signed in',
        subtitle: 'Please sign in to view your past orders.',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: restaurantId)
          .where('userId', isEqualTo: uid) // ← FIX: scope to this user
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kPrimary));
        }
        if (snap.hasError) {
          return _EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load orders',
            subtitle: snap.error.toString(),
          );
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
              dateStr = '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
            }

            return _PastOrderCard(
              orderId: doc.id,
              restaurantId: restaurantId,
              token: token.toString(),
              amount: amount.toString(),
              status: status,
              date: dateStr,
              itemCount: itemCount,
              items: (d['items'] as List? ?? [])
                  .map((i) => Map<String, dynamic>.from(i as Map))
                  .toList(),
            );
          }).toList(),
        );
      },
    );
  }

  String _monthName(int m) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[m];
  }
}

// ─── Past Order Card ──────────────────────────────────────────────────────────
class _PastOrderCard extends StatelessWidget {
  final String orderId;
  final String restaurantId;
  final String token;
  final String amount;
  final String status;
  final String date;
  final int itemCount;
  final List<Map<String, dynamic>> items;

  const _PastOrderCard({
    required this.orderId,
    required this.restaurantId,
    required this.token,
    required this.amount,
    required this.status,
    required this.date,
    required this.itemCount,
    required this.items,
  });

  Color get _statusBg {
    switch (status.toLowerCase()) {
      case 'completed': return _kGreenBg;
      case 'preparing': return const Color(0xFFDBEAFE);
      case 'ready':     return const Color(0xFFDCFCE7);
      case 'pending':   return const Color(0xFFFEF9C3);
      default:          return const Color(0xFFF3F4F6);
    }
  }

  Color get _statusFg {
    switch (status.toLowerCase()) {
      case 'completed': return _kGreenText;
      case 'preparing': return const Color(0xFF1E40AF);
      case 'ready':     return const Color(0xFF15803D);
      case 'pending':   return const Color(0xFF854D0E);
      default:          return _kSubText;
    }
  }

  bool get _isCompleted => status.toLowerCase() == 'completed';

  void _showItemDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(_s(20))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: EdgeInsets.only(top: _s(12), bottom: _s(4)),
                width: _s(40), height: _s(4),
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(_s(2)),
                ),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _s(16), vertical: _s(12)),
              child: Row(
                children: [
                  Text(
                    'Token #$token',
                    style: GoogleFonts.poppins(
                      fontSize: _s(16), fontWeight: FontWeight.w700, color: _kText,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: _s(10), vertical: _s(4)),
                    decoration: BoxDecoration(
                      color: _statusBg, borderRadius: BorderRadius.circular(_s(20)),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: GoogleFonts.poppins(
                        fontSize: _s(12), fontWeight: FontWeight.w600, color: _statusFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _kBorder),
            // Items list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(_s(16), _s(8), _s(16), _s(16)),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: const Color(0xFFF5F5F5)),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final name    = (item['name']    ?? '').toString();
                  final variant = (item['variant'] ?? '').toString();
                  final qty     = item['qty']   ?? 1;
                  final price   = (item['price'] ?? 0) as num;
                  final isCancelled = (item['status'] ?? 'active') == 'cancelled';
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: _s(10)),
                    child: Opacity(
                      opacity: isCancelled ? 0.5 : 1.0,
                      child: Row(
                        children: [
                          Container(
                            width: _s(26), height: _s(26),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(_s(6)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: _s(11), fontWeight: FontWeight.w600,
                                color: _kSubText,
                              ),
                            ),
                          ),
                          SizedBox(width: _w(10)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${qty}x $name',
                                  style: GoogleFonts.poppins(
                                    fontSize: _s(13), fontWeight: FontWeight.w600,
                                    color: _kText,
                                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (variant.isNotEmpty)
                                  Text(
                                    variant,
                                    style: GoogleFonts.poppins(
                                      fontSize: _s(11), color: _kSubText,
                                    ),
                                  ),
                                if (isCancelled)
                                  Text(
                                    'Cancelled',
                                    style: GoogleFonts.poppins(
                                      fontSize: _s(10), color: Colors.red.shade400,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${(price * qty).toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: _s(13), fontWeight: FontWeight.w600,
                              color: isCancelled ? _kSubText : _kPrimary,
                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Total row
            Container(
              padding: EdgeInsets.symmetric(horizontal: _s(16), vertical: _s(12)),
              decoration: BoxDecoration(
                color: _kPrimaryBg,
                border: Border(top: BorderSide(color: _kBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.poppins(
                      fontSize: _s(14), fontWeight: FontWeight.w600, color: _kText,
                    ),
                  ),
                  Text(
                    '₹$amount',
                    style: GoogleFonts.poppins(
                      fontSize: _s(18), fontWeight: FontWeight.w700, color: _kPrimary,
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

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditOrderSheet(
        orderId: orderId,
        restaurantId: restaurantId,
        items: items,
        status: status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showItemDetails(context),
      child: Container(
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
            // ── Top row: token + amount + status ────────────────────────────
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
                          fontSize: _s(12), fontWeight: FontWeight.w500, color: _kSubText,
                        ),
                      ),
                      SizedBox(height: _h(2)),
                      Text(
                        '₹$amount',
                        style: GoogleFonts.poppins(
                          fontSize: _s(22), fontWeight: FontWeight.w700,
                          color: _kText, height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: _s(12), vertical: _s(5)),
                    decoration: BoxDecoration(
                      color: _statusBg,
                      borderRadius: BorderRadius.circular(_s(20)),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: GoogleFonts.poppins(
                        fontSize: _s(12), fontWeight: FontWeight.w600, color: _statusFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _kBorder),

            // ── Bottom row: date + items count + action buttons ──────────────
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
                        fontSize: _s(12), color: _kSubText),
                  ),
                  SizedBox(width: _w(10)),
                  Text(
                    '·',
                    style: GoogleFonts.poppins(
                        fontSize: _s(12), color: _kSubText),
                  ),
                  SizedBox(width: _w(10)),
                  Text(
                    '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    style: GoogleFonts.poppins(
                        fontSize: _s(12), color: _kSubText),
                  ),
                  const Spacer(),
                  // View details hint
                  Icon(Icons.receipt_long_outlined,
                      size: _s(14), color: _kPrimary),
                  SizedBox(width: _w(4)),
                  Text(
                    'Details',
                    style: GoogleFonts.poppins(
                      fontSize: _s(12), fontWeight: FontWeight.w600,
                      color: _kPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Update Order button (only when not completed) ────────────────
            if (!_isCompleted) ...[
              Divider(height: 1, color: _kBorder),
              Padding(
                padding: EdgeInsets.fromLTRB(_s(12), _s(10), _s(12), _s(12)),
                child: SizedBox(
                  width: double.infinity,
                  height: _s(40),
                  child: ElevatedButton.icon(
                    onPressed: () => _openEditSheet(context),
                    icon: Icon(Icons.edit_note_rounded, size: _s(16)),
                    label: Text(
                      'Update Order',
                      style: GoogleFonts.poppins(
                        fontSize: _s(13), fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_s(10)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
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
    // ── FIX: Same as _PastOrdersList — must include userId filter so that
    //    Firestore can evaluate request.auth.uid == resource.data.userId.
    //    Without it, the query is denied because the customer has no
    //    restaurantId claim for isAdminOrOwner() to pass.
    final uid = _currentUid;
    if (uid == null) {
      return _StatusMessage(
        icon: Icons.lock_outline_rounded,
        iconColor: _kSubText,
        title: 'Not signed in',
        subtitle: 'Please sign in to track your order.',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: restaurantId)
          .where('userId', isEqualTo: uid) // ← FIX: scope to this user
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
            subtitle:
            'No order found for token #$token. Please check and try again.',
          );
        }

        final orderData =
        snap.data!.docs.first.data() as Map<String, dynamic>;
        final status = orderData['status'] as String? ?? 'pending';
        final tokenNumber = orderData['tokenNumber'] ?? 0;
        final totalAmount = orderData['totalAmount'] ?? 0;
        final customerName =
            orderData['customerName'] as String? ?? 'Guest';
        final orderType =
            orderData['orderType'] as String? ?? 'Dine In';
        final items = orderData['items'] as List<dynamic>? ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(label: 'Order Details'),
            SizedBox(height: _h(12)),
            _OrderDetailCard(
              orderId: snap.data!.docs.first.id,
              restaurantId: restaurantId,
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
  final String orderId;
  final String restaurantId;
  final String status;
  final String tokenNumber;
  final String totalAmount;
  final String customerName;
  final String orderType;
  final List<dynamic> items;
  final Widget Function(String) buildStatusChip;
  final VoidCallback? onContinueShopping;

  const _OrderDetailCard({
    required this.orderId,
    required this.restaurantId,
    required this.status,
    required this.tokenNumber,
    required this.totalAmount,
    required this.customerName,
    required this.orderType,
    required this.items,
    required this.buildStatusChip,
    this.onContinueShopping,
  });

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
          // ── Gradient Header ──────────────────────────────────────────────
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

          // ── Progress Stepper ─────────────────────────────────────────────
          Padding(
            padding:
            EdgeInsets.fromLTRB(_s(16), _s(20), _s(16), _s(4)),
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

          // ── Update My Order / Locked banner ──────────────────────────────
          if (status.toLowerCase() == 'completed') ...[
            Padding(
              padding:
              EdgeInsets.fromLTRB(_s(16), 0, _s(16), _s(12)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: _s(14), vertical: _s(12)),
                decoration: BoxDecoration(
                  color: _kGreenBg,
                  borderRadius: BorderRadius.circular(_s(12)),
                  border:
                  Border.all(color: _kGreenText.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: _kGreenText, size: _s(18)),
                    SizedBox(width: _w(8)),
                    Expanded(
                      child: Text(
                        'Order completed — no further changes allowed.',
                        style: GoogleFonts.poppins(
                          fontSize: _s(12),
                          color: _kGreenText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: _kBorder),
          ] else if (OrderUpdateService.isEditable(status)) ...[
            Padding(
              padding:
              EdgeInsets.fromLTRB(_s(16), 0, _s(16), _s(4)),
              child: Text(
                'You can add items or adjust quantities until your order is completed.',
                style: GoogleFonts.poppins(
                  fontSize: _s(11),
                  color: _kSubText,
                ),
              ),
            ),
            Padding(
              padding:
              EdgeInsets.fromLTRB(_s(16), _s(6), _s(16), _s(12)),
              child: SizedBox(
                width: double.infinity,
                height: _s(46),
                child: ElevatedButton.icon(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _EditOrderSheet(
                      orderId: orderId,
                      restaurantId: restaurantId,
                      items: items
                          .map((i) =>
                      Map<String, dynamic>.from(i as Map))
                          .toList(),
                      status: status,
                    ),
                  ),
                  icon: Icon(Icons.edit_note_rounded, size: _s(18)),
                  label: Text(
                    'Update My Order',
                    style: GoogleFonts.poppins(
                      fontSize: _s(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_s(12)),
                    ),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: _kBorder),
          ],

          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding:
            EdgeInsets.fromLTRB(_s(16), 0, _s(16), _s(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                _KotHistorySection(orderId: orderId),

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
    final isCancelled = (item['status'] ?? 'active') == 'cancelled';
    return Padding(
      padding: EdgeInsets.only(bottom: _h(8)),
      child: Opacity(
        opacity: isCancelled ? 0.55 : 1.0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _s(4),
              height: _s(16),
              margin: EdgeInsets.only(top: _s(2)),
              decoration: BoxDecoration(
                color: isCancelled ? _kSubText : _kPrimary,
                borderRadius: BorderRadius.circular(_s(2)),
              ),
            ),
            SizedBox(width: _w(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${item['name']} (${item['variant']}) x${item['qty']}",
                    style: GoogleFonts.poppins(
                      fontSize: _s(13),
                      color: _kSubText,
                      decoration:
                      isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (isCancelled)
                    Text(
                      'Cancelled',
                      style: GoogleFonts.poppins(
                        fontSize: _s(10),
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              "₹${(item['price'] as num) * (item['qty'] as num)}",
              style: GoogleFonts.poppins(
                fontSize: _s(13),
                fontWeight: FontWeight.w600,
                color: isCancelled ? _kSubText : _kPrimary,
                decoration:
                isCancelled ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Message ───────────────────────────────────────────────────────────
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
            style: GoogleFonts.poppins(fontSize: _s(13), color: _kSubText),
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
              style: GoogleFonts.poppins(fontSize: _s(13), color: _kSubText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── KOT History Section ──────────────────────────────────────────────────────
class _KotHistorySection extends StatelessWidget {
  final String orderId;
  const _KotHistorySection({required this.orderId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('kots')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = snap.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: _h(16)),
            Text(
              'KOT History (${docs.length})',
              style: GoogleFonts.poppins(
                fontSize: _s(13),
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
            SizedBox(height: _h(8)),
            ...docs.asMap().entries.map(
                  (e) => _KotCard(
                kotNumber: e.key + 1,
                data: e.value.data() as Map<String, dynamic>,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── KOT Card ─────────────────────────────────────────────────────────────────
class _KotCard extends StatelessWidget {
  final int kotNumber;
  final Map<String, dynamic> data;
  const _KotCard({required this.kotNumber, required this.data});

  @override
  Widget build(BuildContext context) {
    final items = data['items'] as List<dynamic>? ?? [];
    final ts = data['createdAt'];
    String timeStr = '';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      timeStr =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: EdgeInsets.only(bottom: _h(8)),
      padding: EdgeInsets.all(_s(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(_s(12)),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: _s(8), vertical: _s(3)),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C),
                  borderRadius: BorderRadius.circular(_s(6)),
                ),
                child: Text(
                  'KOT #$kotNumber',
                  style: GoogleFonts.poppins(
                    fontSize: _s(11),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (timeStr.isNotEmpty)
                Text(
                  timeStr,
                  style:
                  GoogleFonts.poppins(fontSize: _s(11), color: _kSubText),
                ),
            ],
          ),
          SizedBox(height: _h(8)),
          ...items.map((i) {
            final m = Map<String, dynamic>.from(i as Map);
            return Padding(
              padding: EdgeInsets.only(bottom: _h(2)),
              child: Text(
                '• ${m['name']} (${m['variant']}) × ${m['qty']}',
                style: GoogleFonts.poppins(fontSize: _s(12), color: _kText),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Edit Order Sheet ─────────────────────────────────────────────────────────
class _EditOrderSheet extends StatefulWidget {
  final String orderId;
  final String restaurantId;
  final List<Map<String, dynamic>> items;
  final String status;

  const _EditOrderSheet({
    required this.orderId,
    required this.restaurantId,
    required this.items,
    required this.status,
  });

  @override
  State<_EditOrderSheet> createState() => _EditOrderSheetState();
}

class _EditOrderSheetState extends State<_EditOrderSheet> {
  late List<Map<String, dynamic>> _workingItems;
  final List<Map<String, dynamic>> _newItems = [];

  String _searchQuery = '';
  List<QueryDocumentSnapshot> _menuDocs = [];
  bool _loadingMenu = false;

  QueryDocumentSnapshot? _selectedMenuItem;
  int _selectedVariantIdx = 0;
  int _newItemQty = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _workingItems =
        widget.items.map((e) => Map<String, dynamic>.from(e)).toList();
    _loadMenu();
  }

  Future<void> _loadMenu([String query = '']) async {
    if (mounted) setState(() => _loadingMenu = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('menu_items')
          .where('restaurantId', isEqualTo: widget.restaurantId)
          .where('isAvailable', isEqualTo: true)
          .limit(100)
          .get();

      var docs = snap.docs;
      if (query.isNotEmpty) {
        final lower = query.toLowerCase();
        docs = docs
            .where((d) =>
            (d['name'] ?? '').toString().toLowerCase().contains(lower))
            .toList();
      }
      if (mounted) setState(() => _menuDocs = docs);
    } catch (_) {}
    if (mounted) setState(() => _loadingMenu = false);
  }

  void _stageNewItem() {
    if (_selectedMenuItem == null) return;
    final data = _selectedMenuItem!.data() as Map<String, dynamic>;
    final variants = data['variants'] as List<dynamic>? ?? [];
    final variant = variants.isNotEmpty
        ? Map<String, dynamic>.from(variants[_selectedVariantIdx] as Map)
        : <String, dynamic>{'name': 'Regular', 'price': 0};

    setState(() {
      _newItems.add({
        'name': data['name'] ?? '',
        'variant': (variant['name'] ?? 'Regular').toString(),
        'qty': _newItemQty,
        'price': variant['price'] ?? 0,
        'status': 'active',
      });
      _selectedMenuItem = null;
      _selectedVariantIdx = 0;
      _newItemQty = 1;
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    try {
      final fresh = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      final latestStatus =
      (fresh.data()?['status'] as String? ?? '').toLowerCase();
      if (latestStatus == 'completed') {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Your order is already completed and can no longer be changed.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
        if (mounted) setState(() => _saving = false);
        return;
      }

      await OrderUpdateService.updateRunningOrder(
        orderId: widget.orderId,
        updatedExistingItems: _workingItems,
        newItems: _newItems,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _newItems.isEmpty
                  ? 'Order updated successfully.'
                  : 'Order updated — KOT sent to kitchen.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  void _confirmCancelItem(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_s(16))),
        title: Text(
          'Cancel Item?',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: _s(16)),
        ),
        content: Text(
          'Remove "${_workingItems[index]['name']}" from this order?',
          style: GoogleFonts.poppins(fontSize: _s(14), color: _kSubText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            Text('Keep', style: GoogleFonts.poppins(color: _kSubText)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _workingItems[index]['status'] = 'cancelled');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_s(10))),
            ),
            child: Text('Cancel Item',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: _s(13))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.93;
    return Container(
      height: maxH,
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_s(20))),
      ),
      child: Column(
        children: [
          _handle(),
          _sheetHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(_s(16)),
              children: [
                if (_workingItems
                    .any((i) => (i['status'] ?? 'active') == 'active')) ...[
                  _sectionTitle('Current Items'),
                  SizedBox(height: _h(8)),
                  ..._workingItems
                      .asMap()
                      .entries
                      .where((e) =>
                  (e.value['status'] ?? 'active') == 'active')
                      .map((e) => _existingItemRow(e.key, e.value)),
                  SizedBox(height: _h(16)),
                ],

                if (_newItems.isNotEmpty) ...[
                  _sectionTitle(
                      'Items to Add  •  New KOT (${_newItems.length})'),
                  SizedBox(height: _h(8)),
                  ..._newItems
                      .asMap()
                      .entries
                      .map((e) => _stagedItemRow(e.key, e.value)),
                  SizedBox(height: _h(16)),
                ],

                _sectionTitle('Add from Menu'),
                SizedBox(height: _h(8)),
                _menuSearchBar(),
                SizedBox(height: _h(10)),
                _menuList(),
                SizedBox(height: _h(80)),
              ],
            ),
          ),
          _saveButton(),
        ],
      ),
    );
  }

  Widget _handle() => Center(
    child: Container(
      margin: EdgeInsets.only(top: _s(12), bottom: _s(4)),
      width: _s(40),
      height: _s(4),
      decoration: BoxDecoration(
        color: _kBorder,
        borderRadius: BorderRadius.circular(_s(2)),
      ),
    ),
  );

  Widget _sheetHeader() => Container(
    padding:
    EdgeInsets.symmetric(horizontal: _s(20), vertical: _s(12)),
    decoration: BoxDecoration(
      color: _kCard,
      border: Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Order',
                style: GoogleFonts.poppins(
                  fontSize: _s(17),
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              Text(
                'Status: ${widget.status[0].toUpperCase()}${widget.status.substring(1)}  •  Changes allowed until Completed',
                style: GoogleFonts.poppins(
                    fontSize: _s(11), color: _kSubText),
              ),
            ],
          ),
        ),
        if (_newItems.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: _s(10), vertical: _s(4)),
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(_s(20)),
            ),
            child: Text(
              '${_newItems.length} new',
              style: GoogleFonts.poppins(
                fontSize: _s(11),
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: GoogleFonts.poppins(
      fontSize: _s(13),
      fontWeight: FontWeight.w600,
      color: _kText,
    ),
  );

  Widget _existingItemRow(int index, Map<String, dynamic> item) =>
      Container(
        margin: EdgeInsets.only(bottom: _h(8)),
        padding: EdgeInsets.symmetric(
            horizontal: _s(14), vertical: _s(10)),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(_s(12)),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['name'] ?? '').toString(),
                    style: GoogleFonts.poppins(
                      fontSize: _s(13),
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                  if ((item['variant'] ?? '').toString().isNotEmpty)
                    Text(
                      item['variant'].toString(),
                      style: GoogleFonts.poppins(
                          fontSize: _s(11), color: _kSubText),
                    ),
                ],
              ),
            ),
            _qtyRow(
              qty: (item['qty'] ?? 1) as int,
              onDecrement: () {
                final q = (item['qty'] ?? 1) as int;
                if (q > 1) {
                  setState(() => _workingItems[index]['qty'] = q - 1);
                }
              },
              onIncrement: () => setState(
                      () => _workingItems[index]['qty'] = (item['qty'] ?? 1) + 1),
            ),
            SizedBox(width: _w(10)),
            GestureDetector(
              onTap: () => _confirmCancelItem(index),
              child: Icon(Icons.cancel_outlined,
                  color: Colors.red.shade400, size: _s(22)),
            ),
          ],
        ),
      );

  Widget _stagedItemRow(int index, Map<String, dynamic> item) =>
      Container(
        margin: EdgeInsets.only(bottom: _h(8)),
        padding: EdgeInsets.symmetric(
            horizontal: _s(14), vertical: _s(10)),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(_s(12)),
          border: Border.all(color: const Color(0xFF34D399)),
        ),
        child: Row(
          children: [
            Container(
              width: _s(8),
              height: _s(8),
              margin: EdgeInsets.only(right: _w(10)),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['name'] ?? '').toString(),
                    style: GoogleFonts.poppins(
                      fontSize: _s(13),
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                  Text(
                    '${item['variant']}  ×${item['qty']}  •  ₹${(item['price'] as num) * (item['qty'] as num)}',
                    style: GoogleFonts.poppins(
                        fontSize: _s(11), color: _kSubText),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _newItems.removeAt(index)),
              child: Icon(Icons.close, color: _kSubText, size: _s(18)),
            ),
          ],
        ),
      );

  Widget _menuSearchBar() => Container(
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(_s(12)),
      border: Border.all(color: _kBorder),
    ),
    child: TextField(
      onChanged: (v) {
        _searchQuery = v;
        _loadMenu(v);
      },
      style: GoogleFonts.poppins(fontSize: _s(14), color: _kText),
      decoration: InputDecoration(
        hintText: 'Search menu items…',
        hintStyle:
        GoogleFonts.poppins(fontSize: _s(13), color: _kSubText),
        prefixIcon:
        Icon(Icons.search, color: _kPrimary, size: _s(20)),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
            vertical: _s(12), horizontal: _s(4)),
      ),
    ),
  );

  Widget _menuList() {
    if (_loadingMenu) {
      return const Center(
          child: CircularProgressIndicator(color: _kPrimary));
    }
    if (_menuDocs.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? 'No menu items found'
              : 'No results for "$_searchQuery"',
          style: GoogleFonts.poppins(color: _kSubText, fontSize: _s(13)),
        ),
      );
    }
    return Column(
      children: _menuDocs.take(30).map((doc) => _menuItemTile(doc)).toList(),
    );
  }

  Widget _menuItemTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final variants = data['variants'] as List<dynamic>? ?? [];
    final isSelected = _selectedMenuItem?.id == doc.id;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedMenuItem = isSelected ? null : doc;
        _selectedVariantIdx = 0;
        _newItemQty = 1;
      }),
      child: Container(
        margin: EdgeInsets.only(bottom: _h(8)),
        padding: EdgeInsets.all(_s(12)),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimaryBg : _kCard,
          borderRadius: BorderRadius.circular(_s(12)),
          border: Border.all(
            color: isSelected ? _kPrimary : _kBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: _s(14),
                  height: _s(14),
                  margin: EdgeInsets.only(right: _w(6)),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: (data['isVeg'] ?? true) as bool
                          ? Colors.green
                          : Colors.red,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(_s(2)),
                  ),
                  child: Center(
                    child: Container(
                      width: _s(7),
                      height: _s(7),
                      decoration: BoxDecoration(
                        color: (data['isVeg'] ?? true) as bool
                            ? Colors.green
                            : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    (data['name'] ?? '').toString(),
                    style: GoogleFonts.poppins(
                      fontSize: _s(13),
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                ),
                if (variants.isNotEmpty)
                  Text(
                    '₹${(Map<String, dynamic>.from(variants.first as Map))['price']}',
                    style: GoogleFonts.poppins(
                      fontSize: _s(13),
                      fontWeight: FontWeight.w700,
                      color: _kPrimary,
                    ),
                  ),
                SizedBox(width: _w(6)),
                Icon(
                  isSelected
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.add_circle_outline_rounded,
                  color: _kPrimary,
                  size: _s(20),
                ),
              ],
            ),
            if (isSelected) ...[
              SizedBox(height: _h(10)),
              if (variants.length > 1) ...[
                Text('Variant:',
                    style: GoogleFonts.poppins(
                        fontSize: _s(11), color: _kSubText)),
                SizedBox(height: _h(6)),
                Wrap(
                  spacing: _w(6),
                  runSpacing: _h(6),
                  children: variants.asMap().entries.map((e) {
                    final v =
                    Map<String, dynamic>.from(e.value as Map);
                    final sel = e.key == _selectedVariantIdx;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedVariantIdx = e.key),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: _s(10), vertical: _s(4)),
                        decoration: BoxDecoration(
                          color: sel ? _kPrimary : _kCard,
                          borderRadius:
                          BorderRadius.circular(_s(20)),
                          border: Border.all(
                              color: sel ? _kPrimary : _kBorder),
                        ),
                        child: Text(
                          '${v['name']}  ₹${v['price']}',
                          style: GoogleFonts.poppins(
                            fontSize: _s(11),
                            color: sel ? Colors.white : _kText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: _h(10)),
              ],
              Row(
                children: [
                  Text('Qty:',
                      style: GoogleFonts.poppins(
                          fontSize: _s(12), color: _kSubText)),
                  SizedBox(width: _w(8)),
                  _qtyRow(
                    qty: _newItemQty,
                    onDecrement: () {
                      if (_newItemQty > 1) setState(() => _newItemQty--);
                    },
                    onIncrement: () => setState(() => _newItemQty++),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _stageNewItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(_s(10))),
                      padding: EdgeInsets.symmetric(
                          horizontal: _s(18), vertical: _s(8)),
                    ),
                    child: Text('Add',
                        style: GoogleFonts.poppins(
                            fontSize: _s(13),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _qtyRow({
    required int qty,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconBtn(Icons.remove, onDecrement),
          SizedBox(
            width: _s(30),
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: _s(14),
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
          ),
          _iconBtn(Icons.add, onIncrement),
        ],
      );

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: _s(28),
      height: _s(28),
      decoration: BoxDecoration(
        color: _kPrimaryBg,
        borderRadius: BorderRadius.circular(_s(8)),
      ),
      child: Icon(icon, size: _s(16), color: _kPrimary),
    ),
  );

  Widget _saveButton() => SafeArea(
    child: Container(
      padding: EdgeInsets.all(_s(16)),
      decoration: BoxDecoration(
        color: _kCard,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: _s(52),
        child: ElevatedButton(
          onPressed: _saving ? null : _saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _kPrimary.withOpacity(0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_s(14))),
          ),
          child: _saving
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: _s(20)),
              SizedBox(width: _w(8)),
              Text(
                _newItems.isEmpty
                    ? 'Save Changes'
                    : 'Save & Send KOT',
                style: GoogleFonts.poppins(
                  fontSize: _s(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}