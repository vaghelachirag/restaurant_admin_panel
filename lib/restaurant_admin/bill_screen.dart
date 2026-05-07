// ─────────────────────────────────────────────────────────────────────────────
//  BILL SCREEN
//  File: lib/restaurant_admin/bill_screen.dart
//
//  Shows automatically when order status changes to 'completed'.
//  Reads all billing data directly from the Firestore order document.
//  Customer can view the bill as a full-screen page.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'customer_menu.dart'; // for Continue Shopping navigation

class BillScreen extends StatelessWidget {
  final String restaurantId;
  final String orderId;

  const BillScreen({
    super.key,
    required this.restaurantId,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, orderSnap) {
          if (!orderSnap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF065F46)));
          }
          if (!orderSnap.data!.exists) {
            return const Center(child: Text('Order not found'));
          }

          final order = orderSnap.data!.data() as Map<String, dynamic>;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('restaurants')
                .doc(restaurantId)
                .snapshots(),
            builder: (context, restSnap) {
              final restaurant = restSnap.hasData && restSnap.data!.exists
                  ? restSnap.data!.data() as Map<String, dynamic>
                  : <String, dynamic>{};

              return _BillContent(
                restaurantId: restaurantId,
                orderId:      orderId,
                order:        order,
                restaurant:   restaurant,
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BILL CONTENT
// ─────────────────────────────────────────────────────────────────────────────
class _BillContent extends StatelessWidget {
  final String restaurantId;
  final String orderId;
  final Map<String, dynamic> order;
  final Map<String, dynamic> restaurant;

  const _BillContent({
    required this.restaurantId,
    required this.orderId,
    required this.order,
    required this.restaurant,
  });

  // ── Parse order fields ─────────────────────────────────────────────────────
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final restaurantName = (restaurant['name']     ?? 'Restaurant').toString();
    final restaurantAddr = (restaurant['address']  ?? '').toString();
    final restaurantPhone= (restaurant['phone']    ?? '').toString();
    final restaurantGstin= (restaurant['gstin']    ?? '').toString();

    final items         = (order['items']      as List?) ?? [];
    final tokenNumber   = (order['tokenNumber'] ?? '').toString();
    final orderNumber   = (order['orderNumber'] ?? '').toString();
    final tableName     = (order['tableName']   ?? order['tableId'] ?? '').toString();
    final customerName  = (order['customerName']?? '').toString();
    final orderType     = (order['orderType']   ?? 'Dine In').toString();
    final createdAt     = order['createdAt']    as Timestamp?;

    final subtotal      = _toDouble(order['subtotal']);
    final totalAmount   = _toDouble(order['totalAmount']);
    final enableGst     = order['enableGst']    == true;
    final gstPct        = _toDouble(order['gstPercentage']);
    final sgstPct       = _toDouble(order['sgstPercentage']  ?? order['cessPercentage']);
    final gstAmt        = _toDouble(order['gstAmount']);
    final sgstAmt       = _toDouble(order['sgstAmount']);
    final enablePkg     = order['enablePackagingCharge'] == true;
    final pkgCharge     = _toDouble(order['packagingCharge']);

    final dateStr = createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate())
        : DateFormat('dd MMM yyyy').format(DateTime.now());

    final isDineIn = orderType.toLowerCase().contains('dine');

    return SafeArea(
      child: Column(
        children: [
          // ── Top bar ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF065F46),
            ),
            child: Row(children: [
              Expanded(
                child: Text('Your Bill',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              // Copy order ID
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: orderId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Order ID copied'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.copy_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),

          // ── Bill content ──────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Bill card ─────────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20, offset: const Offset(0, 4),
                      )],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Restaurant header ─────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFF065F46),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          child: Column(children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.restaurant_rounded,
                                  color: Colors.white, size: 26),
                            ),
                            const SizedBox(height: 10),
                            Text(restaurantName,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontSize: 18, fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            if (restaurantAddr.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(restaurantAddr,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.8))),
                            ],
                            if (restaurantPhone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(restaurantPhone,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.8))),
                            ],
                            if (restaurantGstin.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('GSTIN: $restaurantGstin',
                                    style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.white.withOpacity(0.9))),
                              ),
                            ],
                          ]),
                        ),

                        // ── TAX INVOICE label ─────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: const BoxDecoration(
                              color: Color(0xFFF0FDF4)),
                          child: Center(
                            child: Text('TAX INVOICE',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, fontWeight: FontWeight.w700,
                                    color: Color(0xFF065F46),
                                    letterSpacing: 2)),
                          ),
                        ),

                        // ── Order meta ────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Column(children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (tokenNumber.isNotEmpty)
                                      _MetaChip(
                                        icon: Icons.tag_rounded,
                                        label: 'Token #$tokenNumber',
                                        color: const Color(0xFFF97316),
                                      ),
                                    const SizedBox(height: 4),
                                    _MetaChip(
                                      icon: isDineIn
                                          ? Icons.table_restaurant_rounded
                                          : Icons.shopping_bag_outlined,
                                      label: isDineIn
                                          ? (tableName.isNotEmpty ? 'Table: $tableName' : 'Dine In')
                                          : 'Parcel',
                                      color: const Color(0xFF3B82F6),
                                    ),
                                  ],
                                )),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(dateStr,
                                        style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: const Color(0xFF6B7280))),
                                    if (customerName.isNotEmpty &&
                                        customerName != 'Guest') ...[
                                      const SizedBox(height: 4),
                                      Text(customerName,
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF374151))),
                                    ],
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            _divider(),
                            const SizedBox(height: 10),

                            // ── Column headers ────────────────────────────
                            Row(children: [
                              Expanded(child: Text('Item',
                                  style: _headerStyle())),
                              Text('Qty',
                                  style: _headerStyle()),
                              const SizedBox(width: 12),
                              SizedBox(width: 80,
                                  child: Text('Amount',
                                      textAlign: TextAlign.right,
                                      style: _headerStyle())),
                            ]),
                            const SizedBox(height: 8),

                            // ── Item rows ─────────────────────────────────
                            ...items.map((item) {
                              final name    = (item['name']    ?? '').toString();
                              final variant = (item['variant'] ?? '').toString();
                              final qty     = (item['qty']     ?? 1) as num;
                              final price   = _toDouble(item['price']);
                              final lineTotal = qty * price;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF111827))),
                                        if (variant.isNotEmpty)
                                          Text(variant,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: const Color(0xFF9CA3AF))),
                                        Text('₹${price.toStringAsFixed(2)} each',
                                            style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: const Color(0xFF9CA3AF))),
                                      ],
                                    )),
                                    Text('×${qty.toInt()}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF6B7280))),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        '₹${lineTotal.toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1F2937)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            const SizedBox(height: 4),
                            _divider(),
                            const SizedBox(height: 12),

                            // ── Subtotal ──────────────────────────────────
                            _AmountRow(label: 'Subtotal',
                                value: '₹${subtotal.toStringAsFixed(2)}'),

                            // ── GST ───────────────────────────────────────
                            if (enableGst) ...[
                              const SizedBox(height: 6),
                              _AmountRow(
                                label: 'CGST (${gstPct.toStringAsFixed(1)}%)',
                                value: '₹${gstAmt.toStringAsFixed(2)}',
                                dimmed: true,
                              ),
                              const SizedBox(height: 6),
                              _AmountRow(
                                label: 'SGST (${sgstPct.toStringAsFixed(1)}%)',
                                value: '₹${sgstAmt.toStringAsFixed(2)}',
                                dimmed: true,
                              ),
                            ],

                            // ── Packaging ─────────────────────────────────
                            if (enablePkg) ...[
                              const SizedBox(height: 6),
                              _AmountRow(
                                label: 'Packaging Charge',
                                value: '₹${pkgCharge.toStringAsFixed(2)}',
                                dimmed: true,
                              ),
                            ],

                            const SizedBox(height: 12),
                            // Grand total divider
                            Container(height: 1.5,
                                color: const Color(0xFF065F46).withOpacity(0.3)),
                            const SizedBox(height: 12),

                            // ── Grand total ───────────────────────────────
                            Row(children: [
                              Expanded(child: Text('Grand Total',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16, fontWeight: FontWeight.w800,
                                      color: const Color(0xFF065F46)))),
                              Text('₹${totalAmount.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 18, fontWeight: FontWeight.w800,
                                      color: const Color(0xFF065F46))),
                            ]),

                            const SizedBox(height: 20),
                          ]),
                        ),

                        // ── Footer ────────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(20)),
                            border: Border(
                              top: BorderSide(
                                  color: const Color(0xFF065F46).withOpacity(0.15),
                                  width: 1),
                            ),
                          ),
                          child: Column(children: [
                            const Icon(Icons.favorite_rounded,
                                color: Color(0xFF065F46), size: 16),
                            const SizedBox(height: 6),
                            Text('Thank you for dining with us!',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: const Color(0xFF065F46))),
                            const SizedBox(height: 2),
                            Text('We hope to see you again soon',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF9CA3AF))),
                          ]),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Continue Shopping button ───────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          // Pop back to OrderPlacedScreen then to Menu
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CustomerMenuPage(restaurantId: restaurantId),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                      label: Text('Order More',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065F46),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: const Color(0xFFF0F0F0));

  TextStyle _headerStyle() => GoogleFonts.poppins(
      fontSize: 11, fontWeight: FontWeight.w600,
      color: const Color(0xFF9CA3AF));
}

// ─── Amount Row ───────────────────────────────────────────────────────────────
class _AmountRow extends StatelessWidget {
  final String label, value;
  final bool dimmed;
  const _AmountRow({required this.label, required this.value,
    this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: dimmed ? 12 : 13,
              fontWeight: dimmed ? FontWeight.w400 : FontWeight.w500,
              color: dimmed
                  ? const Color(0xFF6B7280) : const Color(0xFF374151)))),
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: dimmed ? 12 : 13,
              fontWeight: dimmed ? FontWeight.w400 : FontWeight.w600,
              color: dimmed
                  ? const Color(0xFF6B7280) : const Color(0xFF1F2937))),
    ]);
  }
}

// ─── Meta Chip ────────────────────────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}