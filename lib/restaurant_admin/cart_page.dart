import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/data/models/cart_item.dart';
import 'package:restaurant_admin_panel/restaurant_admin/table_management.dart';
import '../core/constants/app_colors.dart';

import 'order_status_page.dart';

Color _hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  if (hex.length == 6) hex = "FF$hex";
  return Color(int.parse(hex, radix: 16));
}

class CartPage extends StatefulWidget {
  final List<CartItem> cart;
  final String restaurantId;
  final String? preselectedTableId;
  final String? preselectedTableName;
  final String? sessionId;
  final String? activeOrderId;

  const CartPage({
    super.key,
    required this.cart,
    required this.restaurantId,
    this.preselectedTableId,
    this.preselectedTableName,
    this.sessionId,
    this.activeOrderId,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final TextEditingController nameController        = TextEditingController();
  final TextEditingController mobileController      = TextEditingController();
  final TextEditingController instructionController = TextEditingController();

  String  orderType       = "Dine In";
  String? selectedTableId;
  String? selectedTableName;

  Map<String, dynamic>? _cachedRestaurantData;
  final TableService _tableService = TableService();

  @override
  void initState() {
    super.initState();
    if (widget.preselectedTableId != null &&
        widget.preselectedTableId!.isNotEmpty) {
      selectedTableId   = widget.preselectedTableId;
      selectedTableName = widget.preselectedTableName ?? widget.preselectedTableId;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    instructionController.dispose();
    super.dispose();
  }

  // ── Totals ────────────────────────────────────────────────────────────────
  int getTotal() => widget.cart.fold(0, (s, i) => s + i.price * i.qty);

  double _parseDouble(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString().trim()) ?? 0.0;
  }

  double getGSTAmount(double pct)  => getTotal() * pct / 100;
  double getSGSTAmount(double pct) => getTotal() * pct / 100;

  double getFinalTotal({
    required bool   enableGst,
    required double gstPct,
    required double sgstPct,
    required bool   enablePackaging,
    required double packagingCharge,
  }) {
    double total = getTotal().toDouble();
    if (enableGst) total += getGSTAmount(gstPct) + getSGSTAmount(sgstPct);
    if (enablePackaging) total += packagingCharge;
    return total;
  }

  // ── Place order ───────────────────────────────────────────────────────────
  Future<void> placeOrder({
    required bool   enableGst,
    required double gstPct,
    required double sgstPct,
    required bool   enablePackaging,
    required double packagingCharge,
  }) async {
    if (orderType == "Parcel" &&
        (nameController.text.isEmpty || mobileController.text.isEmpty)) {
      _snack("Please enter customer name and mobile for parcel order");
      return;
    }
    if (orderType == "Dine In" && selectedTableId == null) {
      _snack("Please select a table for dine in order");
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.cartAccent),
      ),
    );

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      await FirebaseAuth.instance.currentUser!.getIdToken(true);
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final double grandTotal = getFinalTotal(
        enableGst: enableGst, gstPct: gstPct, sgstPct: sgstPct,
        enablePackaging: enablePackaging, packagingCharge: packagingCharge,
      );

      final int tokenNumber = DateTime.now().millisecondsSinceEpoch % 10000;
      final db = FirebaseFirestore.instance;

      final orderRef = db
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('orders')
          .doc();
      final orderId = orderRef.id;

      await orderRef.set({
        "userId"                : uid,
        "restaurantId"          : widget.restaurantId,
        "tokenNumber"           : tokenNumber,
        "customerName"          : nameController.text.trim(),
        "mobile"                : mobileController.text.trim(),
        "orderType"             : orderType,
        "tableId"               : orderType == "Dine In" ? selectedTableId : null,
        "tableName"             : orderType == "Dine In" ? selectedTableName : null,
        "specialInstruction"    : instructionController.text.trim(),
        "status"                : "pending",
        "subtotal"              : getTotal(),
        "enableGst"             : enableGst,
        "gstPercentage"         : gstPct,
        "sgstPercentage"        : sgstPct,
        "gstAmount"             : enableGst ? getGSTAmount(gstPct).toStringAsFixed(2) : "0.00",
        "sgstAmount"            : enableGst ? getSGSTAmount(sgstPct).toStringAsFixed(2) : "0.00",
        "enablePackagingCharge" : enablePackaging,
        "packagingCharge"       : enablePackaging ? packagingCharge : 0,
        "totalAmount"           : grandTotal.round(),
        "createdAt"             : FieldValue.serverTimestamp(),
        "updatedAt"             : FieldValue.serverTimestamp(),
        "items"                 : widget.cart.map((e) => {
          "itemId"  : e.itemId,
          "name"    : e.name,
          "variant" : e.variant,
          "price"   : e.price,
          "qty"     : e.qty,
        }).toList(),
      });

      widget.cart.clear();

      if (mounted) {
        Navigator.pop(context); // close loader
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderPlacedScreen(
              orderId: orderId,
              restaurantId: widget.restaurantId,
            ),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) Navigator.pop(context);
      _snack('Order failed: ${e.message}', isError: true);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _snack('Something went wrong: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: isError ? Colors.red : AppColors.cartAccent,
    ));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text(
              'Error loading restaurant: ${snap.error}',
              style: GoogleFonts.poppins(),
            )),
          );
        }

        if (snap.hasData) {
          final rawData = snap.data!.data();
          if (rawData != null) _cachedRestaurantData = rawData as Map<String, dynamic>;
        }

        if (_cachedRestaurantData == null) {
          return const Scaffold(
            backgroundColor: AppColors.cartBackground,
            body: Center(child: CircularProgressIndicator(color: AppColors.cartAccent)),
          );
        }

        final data = _cachedRestaurantData!;

        // GST / packaging settings
        final bool   enableGst      = data['enableGst']            == true;
        final double gstPct         = _parseDouble(data['gstPercentage']);
        final double sgstPct        = _parseDouble(data['cessPercentage']);
        final bool   enablePackaging = data['enablePackagingCharge'] == true;
        final double pkgCharge      = _parseDouble(data['packagingCharge']);

        return Scaffold(
          backgroundColor: AppColors.cartBackground,
          // ── AppBar — same purple gradient as customer_menu header ──────────
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: EdgeInsets.all(kIsWeb ? 8 : 8.sp),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                ),
                child: Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: kIsWeb ? 20 : 20.sp),
              ),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.cartGradientStart, AppColors.cartGradientMid, AppColors.cartGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: Text(
              "Your Cart",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: kIsWeb ? 18 : 18.sp,
              ),
            ),
            centerTitle: false,
            // Item count badge
            actions: [
              if (widget.cart.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(right: kIsWeb ? 16 : 16.w),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 10 : 10.w,
                          vertical:   kIsWeb ? 4 : 4.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                      ),
                      child: Text(
                        '${widget.cart.length} item${widget.cart.length > 1 ? 's' : ''}',
                        style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 12 : 12.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Empty cart ─────────────────────────────────────────────────────
          body: widget.cart.isEmpty
              ? _buildEmptyCart()
              : SingleChildScrollView(
            padding: EdgeInsets.only(bottom: kIsWeb ? 120 : 120.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cart items list
                _sectionPadding(child: _buildCartItemsList()),

                // Order type toggle
                _sectionPadding(child: _buildOrderTypeSection()),

                // Table picker / preselected banner
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => SizeTransition(
                    sizeFactor: anim, axisAlignment: -1,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: orderType == "Dine In"
                      ? _sectionPadding(
                      key: const ValueKey('dine-in-table'),
                      child: _buildDineInSection())
                      : const SizedBox.shrink(
                      key: ValueKey('parcel-table-empty')),
                ),

                // Parcel info fields
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => SizeTransition(
                    sizeFactor: anim, axisAlignment: -1,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: orderType == "Parcel"
                      ? _sectionPadding(
                      key: const ValueKey('parcel-info'),
                      child: _buildParcelInfoSection())
                      : const SizedBox.shrink(
                      key: ValueKey('dine-in-empty')),
                ),

                // Order summary
                _sectionPadding(
                  child: _buildOrderSummary(
                    enableGst: enableGst, gstPct: gstPct,
                    sgstPct: sgstPct, enablePackaging: enablePackaging,
                    pkgCharge: pkgCharge,
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom bar ─────────────────────────────────────────────────────
          bottomNavigationBar: widget.cart.isEmpty
              ? null
              : _buildBottomBar(
              enableGst: enableGst, gstPct: gstPct, sgstPct: sgstPct,
              enablePackaging: enablePackaging, pkgCharge: pkgCharge),
        );
      },
    );
  }

  // ── Empty cart ─────────────────────────────────────────────────────────────
  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 40.0 : 40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  kIsWeb ? 96 : 96.w,
              height: kIsWeb ? 96 : 96.w,
              decoration: const BoxDecoration(
                  color: AppColors.cartAccentLight, shape: BoxShape.circle),
              child: Icon(Icons.shopping_cart_outlined,
                  size: kIsWeb ? 44 : 44.sp, color: AppColors.cartAccent),
            ),
            SizedBox(height: kIsWeb ? 20 : 20.h),
            Text("Your cart is empty",
                style: GoogleFonts.poppins(
                    fontSize: kIsWeb ? 18 : 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cartTextPrimary)),
            SizedBox(height: kIsWeb ? 6 : 6.h),
            Text("Add some delicious items to get started",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: kIsWeb ? 13 : 13.sp,
                    color: AppColors.cartTextSecondary)),
            SizedBox(height: kIsWeb ? 28 : 28.h),
            SizedBox(
              height: kIsWeb ? 48 : 48.h,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.restaurant_menu_rounded,
                    size: kIsWeb ? 18 : 18.sp),
                label: Text("Browse Menu",
                    style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 15 : 15.sp,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cartAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 28 : 28.w),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cart items list ─────────────────────────────────────────────────────────
  Widget _buildCartItemsList() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section heading
          Row(children: [
            Container(
              width: kIsWeb ? 4 : 4.w, height: kIsWeb ? 18 : 18.h,
              decoration: BoxDecoration(
                  color: AppColors.cartAccent,
                  borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(width: kIsWeb ? 10 : 10.w),
            Text("Cart Items",
                style: GoogleFonts.poppins(
                    fontSize: kIsWeb ? 15 : 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cartTextPrimary)),
            const Spacer(),
            Text('${widget.cart.length} item${widget.cart.length > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(
                    fontSize: kIsWeb ? 12 : 12.sp,
                    color: AppColors.cartTextSecondary,
                    fontWeight: FontWeight.w500)),
          ]),
          SizedBox(height: kIsWeb ? 14 : 14.h),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.cart.length,
            separatorBuilder: (_, __) => Divider(
                height: kIsWeb ? 16 : 16.h, color: AppColors.divider, thickness: 1),
            itemBuilder: (context, index) {
              final item = widget.cart[index];
              return _buildCartRow(item, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartRow(CartItem item, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
          child: Container(
            width:  kIsWeb ? 64 : 60.w,
            height: kIsWeb ? 64 : 60.w,
            color: AppColors.cartAccentLight,
            child: item.image != null
                ? Image.network(item.image!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                    Icons.restaurant_rounded,
                    color: AppColors.cartAccent, size: kIsWeb ? 26 : 26.sp))
                : Icon(Icons.restaurant_rounded,
                color: AppColors.cartAccent, size: kIsWeb ? 26 : 26.sp),
          ),
        ),
        SizedBox(width: kIsWeb ? 12 : 12.w),

        // Name / variant / price
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: kIsWeb ? 13 : 13.sp,
                      color: AppColors.cartTextPrimary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (item.variant != null && item.variant!.isNotEmpty) ...[
                SizedBox(height: kIsWeb ? 2 : 2.h),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: kIsWeb ? 7 : 7.w,
                      vertical:   kIsWeb ? 2 : 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.cartAccentLight,
                    borderRadius: BorderRadius.circular(kIsWeb ? 6 : 6.sp),
                  ),
                  child: Text(item.variant!,
                      style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 10 : 10.sp,
                          color: AppColors.cartAccent,
                          fontWeight: FontWeight.w500)),
                ),
              ],
              SizedBox(height: kIsWeb ? 4 : 4.h),
              Text("₹${item.price}",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: kIsWeb ? 14 : 14.sp,
                      color: AppColors.cartAccent)),
            ],
          ),
        ),

        // Controls column
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Delete
            GestureDetector(
              onTap: () => setState(() => widget.cart.removeAt(index)),
              child: Container(
                padding: EdgeInsets.all(kIsWeb ? 4 : 4.sp),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(kIsWeb ? 6 : 6.sp),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400,
                    size: kIsWeb ? 18 : 18.sp),
              ),
            ),
            SizedBox(height: kIsWeb ? 10 : 10.h),

            // Qty stepper
            Container(
              decoration: BoxDecoration(
                color: AppColors.cartAccentLight,
                borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                border: Border.all(
                    color: AppColors.cartAccent.withOpacity(0.25), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stepBtn(
                    icon: Icons.remove,
                    onTap: () {
                      if (item.qty > 1) setState(() => item.qty--);
                    },
                  ),
                  SizedBox(
                    width: kIsWeb ? 28 : 28.w,
                    child: Center(
                      child: Text(item.qty.toString(),
                          style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 13 : 13.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.cartAccent)),
                    ),
                  ),
                  _stepBtn(
                    icon: Icons.add,
                    onTap: () => setState(() => item.qty++),
                    filled: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepBtn({
    required IconData  icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  kIsWeb ? 28 : 28.w,
        height: kIsWeb ? 28 : 28.w,
        decoration: BoxDecoration(
          color: filled ? AppColors.cartAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(kIsWeb ? 6 : 6.sp),
        ),
        child: Icon(icon,
            color: filled ? Colors.white : AppColors.cartAccent,
            size: kIsWeb ? 15 : 15.sp),
      ),
    );
  }

  // ── Order type toggle ───────────────────────────────────────────────────────
  Widget _buildOrderTypeSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Order Type"),
          SizedBox(height: kIsWeb ? 12 : 12.h),
          Row(
            children: [
              _OrderTypeButton(
                label: "Dine In",
                icon: Icons.restaurant_rounded,
                selected: orderType == "Dine In",
                onTap: () => setState(() => orderType = "Dine In"),
              ),
              SizedBox(width: kIsWeb ? 12 : 12.w),
              _OrderTypeButton(
                label: "Parcel",
                icon: Icons.shopping_bag_outlined,
                selected: orderType == "Parcel",
                onTap: () => setState(() => orderType = "Parcel"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dine-in / table picker ──────────────────────────────────────────────────
  Widget _buildDineInSection() {
    // Preselected from QR → show locked banner
    if (widget.preselectedTableId != null &&
        widget.preselectedTableId!.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.successGreen,
          borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
          border: Border.all(color: AppColors.successBorder, width: 1.5),
        ),
        padding: EdgeInsets.all(kIsWeb ? 16 : 16.w),
        child: Row(children: [
          Container(
            padding: EdgeInsets.all(kIsWeb ? 10 : 10.w),
            decoration: const BoxDecoration(
                color: AppColors.successBg, shape: BoxShape.circle),
            child: Icon(Icons.table_restaurant_rounded,
                color: AppColors.cartVegGreen, size: kIsWeb ? 22 : 22.sp),
          ),
          SizedBox(width: kIsWeb ? 14 : 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Table Selected',
                    style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 13 : 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successText)),
                SizedBox(height: kIsWeb ? 2 : 2.h),
                Text(
                    widget.preselectedTableName ?? widget.preselectedTableId!,
                    style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 15 : 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.successTextDark)),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 10 : 10.w, vertical: kIsWeb ? 4 : 4.h),
            decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.cartVegGreen, size: 12),
              SizedBox(width: kIsWeb ? 4 : 4.w),
              Text('Auto',
                  style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 10 : 10.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cartAccent)),
            ]),
          ),
        ]),
      );
    }

    // Manual table picker
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Select Table"),
          SizedBox(height: kIsWeb ? 2 : 2.h),
          Text("Choose a table for dine in order",
              style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 12 : 12.sp, color: AppColors.cartTextSecondary)),
          SizedBox(height: kIsWeb ? 14 : 14.h),
          StreamBuilder<List<TableModel>>(
            stream: _tableService.watchTables(widget.restaurantId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: kIsWeb ? 20 : 20.h),
                    child: const CircularProgressIndicator(color: AppColors.cartAccent),
                  ),
                );
              }
              if (snap.hasError) {
                return Text('Error loading tables: ${snap.error}',
                    style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 12 : 12.sp, color: Colors.red));
              }
              final tables = snap.data ?? [];
              if (tables.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(kIsWeb ? 14 : 14.w),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                    border: Border.all(color: AppColors.cartAccent.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.cartAccent, size: kIsWeb ? 18 : 18.sp),
                    SizedBox(width: kIsWeb ? 8 : 8.w),
                    Expanded(
                      child: Text(
                          "No available tables. Please choose Parcel order.",
                          style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 12 : 12.sp,
                              color: AppColors.cartAccent)),
                    ),
                  ]),
                );
              }
              return Wrap(
                spacing: kIsWeb ? 8 : 8.w,
                runSpacing: kIsWeb ? 8 : 8.h,
                children: tables.map((table) {
                  final isSel = selectedTableId == table.tableId;
                  return GestureDetector(
                    onTap: () => setState(() {
                      selectedTableId   = table.tableId;
                      selectedTableName = table.name;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 16 : 16.w,
                          vertical:   kIsWeb ? 12 : 12.h),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.cartAccentLight : Colors.white,
                        borderRadius:
                        BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                        border: Border.all(
                          color: isSel ? AppColors.cartAccent : AppColors.cartDivider,
                          width: isSel ? 1.8 : 1,
                        ),
                        boxShadow: isSel
                            ? [BoxShadow(
                            color: AppColors.cartAccent.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3))]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.table_restaurant_rounded,
                              color: isSel ? AppColors.cartAccent : AppColors.cartTextSecondary,
                              size: kIsWeb ? 24 : 24.sp),
                          SizedBox(height: kIsWeb ? 4 : 4.h),
                          Text(table.name,
                              style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 12 : 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isSel ? AppColors.cartAccent : AppColors.cartTextPrimary),
                              textAlign: TextAlign.center),
                          SizedBox(height: kIsWeb ? 2 : 2.h),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.people_outline_rounded,
                                color: isSel ? AppColors.cartAccent : AppColors.cartTextMuted,
                                size: kIsWeb ? 11 : 11.sp),
                            SizedBox(width: kIsWeb ? 2 : 2.w),
                            Text('${table.capacity}',
                                style: GoogleFonts.poppins(
                                    fontSize: kIsWeb ? 10 : 10.sp,
                                    color: isSel ? AppColors.cartAccent : AppColors.cartTextMuted)),
                          ]),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Parcel info fields ──────────────────────────────────────────────────────
  Widget _buildParcelInfoSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Customer Information"),
          SizedBox(height: kIsWeb ? 2 : 2.h),
          Text("Required for parcel orders",
              style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 12 : 12.sp, color: AppColors.cartTextSecondary)),
          SizedBox(height: kIsWeb ? 14 : 14.h),
          _buildTextField(
            controller: nameController,
            label: "Customer Name",
            hint: "Enter customer name",
            icon: Icons.person_outline_rounded,
          ),
          SizedBox(height: kIsWeb ? 12 : 12.h),
          _buildTextField(
            controller: mobileController,
            label: "Mobile Number",
            hint: "Enter mobile number",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: kIsWeb ? 12 : 12.h),
          _buildTextField(
            controller: instructionController,
            label: "Special Instructions (Optional)",
            hint: "Example: Less spicy, No onion",
            icon: Icons.note_alt_outlined,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ── Order summary card ──────────────────────────────────────────────────────
  Widget _buildOrderSummary({
    required bool   enableGst,
    required double gstPct,
    required double sgstPct,
    required bool   enablePackaging,
    required double pkgCharge,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Order Summary"),
          SizedBox(height: kIsWeb ? 14 : 14.h),

          _SummaryRow(
            label: "Subtotal",
            value: "₹${getTotal()}",
            labelColor: AppColors.cartTextSecondary,
            valueColor: AppColors.cartTextPrimary,
          ),

          if (enableGst && gstPct > 0) ...[
            SizedBox(height: kIsWeb ? 10 : 10.h),
            _SummaryRow(
              label: "GST (${gstPct % 1 == 0 ? gstPct.toInt() : gstPct}%)",
              value: "₹${getGSTAmount(gstPct).toStringAsFixed(2)}",
              labelColor: AppColors.cartTextSecondary,
              valueColor: AppColors.cartTextPrimary,
            ),
          ],

          if (enableGst && sgstPct > 0) ...[
            SizedBox(height: kIsWeb ? 10 : 10.h),
            _SummaryRow(
              label: "SGST (${sgstPct % 1 == 0 ? sgstPct.toInt() : sgstPct}%)",
              value: "₹${getSGSTAmount(sgstPct).toStringAsFixed(2)}",
              labelColor: AppColors.cartTextSecondary,
              valueColor: AppColors.cartTextPrimary,
            ),
          ],

          if (enablePackaging && pkgCharge > 0) ...[
            SizedBox(height: kIsWeb ? 10 : 10.h),
            _SummaryRow(
              label: "Packaging Charge",
              value: "₹${pkgCharge.toStringAsFixed(2)}",
              labelColor: AppColors.cartTextSecondary,
              valueColor: AppColors.cartTextPrimary,
            ),
          ],

          SizedBox(height: kIsWeb ? 12 : 12.h),
          Divider(color: AppColors.cartDivider, thickness: 1),
          SizedBox(height: kIsWeb ? 12 : 12.h),

          _SummaryRow(
            label: "Total",
            value: "₹${getFinalTotal(
              enableGst: enableGst, gstPct: gstPct, sgstPct: sgstPct,
              enablePackaging: enablePackaging, packagingCharge: pkgCharge,
            ).toStringAsFixed(2)}",
            labelColor: AppColors.cartTextPrimary,
            valueColor: AppColors.cartAccent,
            fontSize: kIsWeb ? 16.0 : 16.0,
            valueFontWeight: FontWeight.w800,
            labelFontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ──────────────────────────────────────────────────────────────
  Widget _buildBottomBar({
    required bool   enableGst,
    required double gstPct,
    required double sgstPct,
    required bool   enablePackaging,
    required double pkgCharge,
  }) {
    final total = getFinalTotal(
      enableGst: enableGst, gstPct: gstPct, sgstPct: sgstPct,
      enablePackaging: enablePackaging, packagingCharge: pkgCharge,
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cartCardWhite,
        border: const Border(top: BorderSide(color: AppColors.cartDivider, width: 1)),
        boxShadow: [BoxShadow(
            color: AppColors.cartShadowMd, blurRadius: 16, offset: const Offset(0, -4))],
      ),
      padding: EdgeInsets.fromLTRB(
          kIsWeb ? 20 : 20.w, kIsWeb ? 12 : 12.h,
          kIsWeb ? 20 : 20.w, kIsWeb ? 18 : 18.h),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Total display
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Total",
                    style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 12 : 12.sp,
                        color: AppColors.cartTextSecondary,
                        fontWeight: FontWeight.w500)),
                SizedBox(height: kIsWeb ? 2 : 2.h),
                Text("₹${total.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 20 : 20.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.cartAccent)),
              ],
            ),
            SizedBox(width: kIsWeb ? 16 : 16.w),
            // Place Order button
            Expanded(
              child: SizedBox(
                height: kIsWeb ? 52 : 52.h,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.check_circle_outline_rounded,
                      size: kIsWeb ? 18 : 18.sp),
                  label: Text("Place Order",
                      style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 15 : 15.sp,
                          fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cartAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(kIsWeb ? 14 : 14.sp)),
                    shadowColor: AppColors.cartAccent.withOpacity(0.4),
                  ),
                  onPressed: () => placeOrder(
                    enableGst: enableGst, gstPct: gstPct, sgstPct: sgstPct,
                    enablePackaging: enablePackaging, packagingCharge: pkgCharge,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: AppColors.cartCardWhite,
      borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
      boxShadow: [BoxShadow(
          color: AppColors.cartShadow, blurRadius: 14, offset: const Offset(0, 4))],
    ),
    padding: EdgeInsets.all(kIsWeb ? 16 : 16.w),
    child: child,
  );

  Widget _sectionTitle(String text) => Text(
    text,
    style: GoogleFonts.poppins(
        fontSize: kIsWeb ? 15 : 15.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.cartTextPrimary),
  );

  Widget _sectionPadding({required Widget child, Key? key}) => Padding(
    key: key,
    padding: EdgeInsets.fromLTRB(
        kIsWeb ? 16 : 16.w, kIsWeb ? 12 : 12.h,
        kIsWeb ? 16 : 16.w, kIsWeb ? 0 : 0.h),
    child: child,
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(
          color: AppColors.cartTextPrimary, fontSize: kIsWeb ? 14 : 14.sp),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(
            color: AppColors.cartTextSecondary, fontSize: kIsWeb ? 13 : 13.sp),
        hintStyle: GoogleFonts.poppins(
            color: AppColors.cartTextMuted, fontSize: kIsWeb ? 13 : 13.sp),
        prefixIcon: Icon(icon, color: AppColors.cartTextSecondary, size: kIsWeb ? 20 : 20.sp),
        contentPadding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 14 : 14.w, vertical: kIsWeb ? 14 : 14.h),
        filled: true,
        fillColor: AppColors.cartBackground,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
            borderSide: const BorderSide(color: AppColors.cartDivider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
            borderSide: const BorderSide(color: AppColors.cartAccent, width: 1.8)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDER TYPE BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _OrderTypeButton extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final bool      selected;
  final VoidCallback onTap;

  const _OrderTypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 22 : 22.w,
            vertical:   kIsWeb ? 10 : 10.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.cartAccentLight : Colors.white,
          borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
          border: Border.all(
              color: selected ? AppColors.cartAccent : AppColors.cartDivider,
              width: selected ? 1.8 : 1),
          boxShadow: selected
              ? [BoxShadow(
              color: AppColors.cartAccent.withOpacity(0.15),
              blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size:  kIsWeb ? 16 : 16.sp,
              color: selected ? AppColors.cartAccent : AppColors.cartTextSecondary,),
          SizedBox(width: kIsWeb ? 6 : 6.w),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 13 : 13.sp,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.cartAccent : AppColors.cartTextSecondary)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY ROW
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String      label;
  final String      value;
  final Color       labelColor;
  final Color       valueColor;
  final FontWeight? labelFontWeight;
  final FontWeight? valueFontWeight;
  final double?     fontSize;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    this.labelFontWeight,
    this.valueFontWeight,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final double fs = fontSize ?? (kIsWeb ? 14.0 : 14.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: kIsWeb ? fs : fs.sp,
                color: labelColor,
                fontWeight: labelFontWeight ?? FontWeight.w400)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: kIsWeb ? fs : fs.sp,
                color: valueColor,
                fontWeight: valueFontWeight ?? FontWeight.w500)),
      ],
    );
  }
}