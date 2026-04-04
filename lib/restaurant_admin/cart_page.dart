import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/data/models/cart_item.dart';

import 'order_status_page.dart';

Color _hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  if (hex.length == 6) {
    hex = "FF$hex";
  }
  return Color(int.parse(hex, radix: 16));
}

class CartPage extends StatefulWidget {
  final List<CartItem> cart;
  final String restaurantId;

  const CartPage({
    super.key,
    required this.cart,
    required this.restaurantId,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController instructionController = TextEditingController();

  String orderType = "Dine In";

  Map<String, dynamic>? _cachedRestaurantData;

  int getTotal() {
    int total = 0;
    for (var item in widget.cart) {
      total += item.price * item.qty;
    }
    return total;
  }

  double _parseDouble(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString().trim()) ?? 0.0;
  }

  double getGSTAmount(double gstPct) => getTotal() * gstPct / 100;

  double getSGSTAmount(double sgstPct) => getTotal() * sgstPct / 100;

  double getFinalTotal({
    required bool enableGst,
    required double gstPct,
    required double sgstPct,
    required bool enablePackaging,
    required double packagingCharge,
  }) {
    double total = getTotal().toDouble();
    if (enableGst) {
      total += getGSTAmount(gstPct) + getSGSTAmount(sgstPct);
    }
    if (enablePackaging) {
      total += packagingCharge;
    }
    return total;
  }

  Future<void> placeOrder({
    required bool enableGst,
    required double gstPct,
    required double sgstPct,
    required bool enablePackaging,
    required double packagingCharge,
  }) async {
    int tokenNumber = DateTime.now().millisecondsSinceEpoch % 10000;

    if (orderType == "Parcel" &&
        (nameController.text.isEmpty || mobileController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Please enter customer name and mobile number for parcel order")),
      );
      return;
    }

    final double grandTotal = getFinalTotal(
      enableGst: enableGst,
      gstPct: gstPct,
      sgstPct: sgstPct,
      enablePackaging: enablePackaging,
      packagingCharge: packagingCharge,
    );

    final orderRef = FirebaseFirestore.instance.collection("orders").doc();

    await orderRef.set({
      "restaurantId": widget.restaurantId,
      "tokenNumber": tokenNumber,
      "customerName": nameController.text,
      "mobile": mobileController.text,
      "orderType": orderType,
      "specialInstruction": instructionController.text,
      "status": "pending",
      "subtotal": getTotal(),
      // GST fields (only meaningful when enableGst is true)
      "enableGst": enableGst,
      "gstPercentage": gstPct,
      "sgstPercentage": sgstPct,
      "gstAmount": enableGst ? getGSTAmount(gstPct).toStringAsFixed(2) : "0.00",
      "sgstAmount": enableGst ? getSGSTAmount(sgstPct).toStringAsFixed(2) : "0.00",
      // Packaging fields
      "enablePackagingCharge": enablePackaging,
      "packagingCharge": enablePackaging ? packagingCharge : 0,
      // Grand total
      "totalAmount": grandTotal.round(),
      "createdAt": FieldValue.serverTimestamp(),
      "items": widget.cart
          .map((e) => {
        "itemId": e.itemId,
        "name": e.name,
        "variant": e.variant,
        "price": e.price,
        "qty": e.qty
      })
          .toList()
    });

    String orderId = orderRef.id;
    widget.cart.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrderPlacedScreen(orderId: orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .snapshots(),
      builder: (context, restaurantSnapshot) {
        if (restaurantSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error loading restaurant: ${restaurantSnapshot.error}',
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }

        if (restaurantSnapshot.hasData) {
          final rawData = restaurantSnapshot.data!.data();
          if (rawData != null) {
            _cachedRestaurantData = rawData as Map<String, dynamic>;
          }
        }

        // Show loader only on the very first load (no cached data yet).
        if (_cachedRestaurantData == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = _cachedRestaurantData!;


        final theme = data['theme'] ?? {};
        final bgColor = _hexToColor(theme['backgroundColor'] ?? "#F8F9FA");
        final textColor = _hexToColor(theme['textColor'] ?? "#111827");
        final cardColor = _hexToColor(theme['cardColor'] ?? "#FFFFFF");
        final cardInfoColor =
        _hexToColor(theme['cardInfoColor'] ?? "#6B7280");


        final bool   enableGst      = data['enableGst']      == true;
        final double gstPct         = _parseDouble(data['gstPercentage']);   // e.g. "9" → 9.0
        final double sgstPct        = _parseDouble(data['cessPercentage']);  // e.g. "9" → 9.0
        final bool   enablePackaging = data['enablePackagingCharge'] == true;
        final double pkgCharge      = _parseDouble(data['packagingCharge']); // flat amount

        const Color primaryColor = Color(0xFF7C3AED);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF7C3AED),
                    Color(0xFFA855F7),
                    Color(0xFFC084FC),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: Text(
              "Your Cart",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: kIsWeb ? 18 : 18.sp,
              ),
            ),
            centerTitle: false,
          ),
          body: widget.cart.isEmpty
              ? Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: kIsWeb ? 40.0 : 40.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: kIsWeb ? 96 : 96.w,
                    height: kIsWeb ? 96 : 96.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: kIsWeb ? 44 : 44.sp,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  SizedBox(height: kIsWeb ? 20 : 20.h),
                  Text(
                    "Your cart is empty",
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 18 : 18.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: kIsWeb ? 6 : 6.h),
                  Text(
                    "Add some delicious items to get started",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 13 : 13.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: kIsWeb ? 28 : 28.h),
                  SizedBox(
                    height: kIsWeb ? 48 : 48.h,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                            horizontal: kIsWeb ? 36 : 36.w),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              kIsWeb ? 12 : 12.r),
                        ),
                      ),
                      child: Text(
                        "Browse Menu",
                        style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 15 : 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
              : SingleChildScrollView(
            padding: EdgeInsets.only(bottom: kIsWeb ? 100 : 100.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cart Items ────────────────────────────────────────
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    kIsWeb ? 16 : 16.w,
                    kIsWeb ? 16 : 16.h,
                    kIsWeb ? 16 : 16.w,
                    kIsWeb ? 4 : 4.h,
                  ),
                  itemCount: widget.cart.length,
                  itemBuilder: (context, index) {
                    final item = widget.cart[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: kIsWeb ? 10 : 10.h),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius:
                        BorderRadius.circular(kIsWeb ? 14 : 14.r),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: kIsWeb ? 8 : 8.r,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(kIsWeb ? 12 : 12.w),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Product image
                          ClipRRect(
                            borderRadius:
                            BorderRadius.circular(kIsWeb ? 10 : 10.r),
                            child: Container(
                              width: kIsWeb ? 64 : 64.w,
                              height: kIsWeb ? 64 : 64.w,
                              color: const Color(0xFFF3F4F6),
                              child: item.image != null
                                  ? Image.network(
                                item.image!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                    Icon(Icons.restaurant,
                                        color: Colors.grey[400],
                                        size: kIsWeb ? 28 : 28.sp),
                              )
                                  : Icon(Icons.restaurant,
                                  color: Colors.grey[400],
                                  size: kIsWeb ? 28 : 28.sp),
                            ),
                          ),
                          SizedBox(width: kIsWeb ? 12 : 12.w),

                          // Item name / variant / price
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: kIsWeb ? 14 : 14.sp,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: kIsWeb ? 2 : 2.h),
                                Text(
                                  item.variant ?? "",
                                  style: GoogleFonts.poppins(
                                    fontSize: kIsWeb ? 12 : 12.sp,
                                    color: cardInfoColor,
                                  ),
                                ),
                                SizedBox(height: kIsWeb ? 4 : 4.h),
                                Text(
                                  "₹${item.price}",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: kIsWeb ? 14 : 14.sp,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Delete icon
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    widget.cart.removeAt(index);
                                  });
                                },
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade400,
                                  size: kIsWeb ? 20 : 20.sp,
                                ),
                              ),
                              SizedBox(height: kIsWeb ? 10 : 10.h),

                              // Qty stepper
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (item.qty > 1) {
                                        setState(() => item.qty--);
                                      }
                                    },
                                    child: Container(
                                      width: kIsWeb ? 30 : 30.w,
                                      height: kIsWeb ? 30 : 30.w,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius:
                                        BorderRadius.circular(
                                            kIsWeb ? 6 : 6.r),
                                        border: Border.all(
                                            color: const Color(
                                                0xFFE5E7EB)),
                                      ),
                                      child: Icon(Icons.remove,
                                          color: cardInfoColor,
                                          size: kIsWeb ? 16 : 16.sp),
                                    ),
                                  ),
                                  Container(
                                    width: kIsWeb ? 32 : 32.w,
                                    alignment: Alignment.center,
                                    child: Text(
                                      item.qty.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: kIsWeb ? 14 : 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => item.qty++);
                                    },
                                    child: Container(
                                      width: kIsWeb ? 30 : 30.w,
                                      height: kIsWeb ? 30 : 30.w,
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius:
                                        BorderRadius.circular(
                                            kIsWeb ? 6 : 6.r),
                                      ),
                                      child: Icon(Icons.add,
                                          color: Colors.white,
                                          size: kIsWeb ? 16 : 16.sp),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(
                    kIsWeb ? 16 : 16.w,
                    kIsWeb ? 4 : 4.h,
                    kIsWeb ? 16 : 16.w,
                    kIsWeb ? 8 : 8.h,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius:
                      BorderRadius.circular(kIsWeb ? 14 : 14.r),
                      border: Border.all(
                          color: const Color(0xFFE5E7EB), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: kIsWeb ? 8 : 8.r,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(kIsWeb ? 16 : 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Order Type",
                          style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 15 : 15.sp,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: kIsWeb ? 12 : 12.h),
                        Row(
                          children: [
                            _OrderTypeButton(
                              label: "Dine In",
                              selected: orderType == "Dine In",
                              primaryColor: primaryColor,
                              textColor: textColor,
                              cardInfoColor: cardInfoColor,
                              onTap: () =>
                                  setState(() => orderType = "Dine In"),
                            ),
                            SizedBox(width: kIsWeb ? 12 : 12.w),
                            _OrderTypeButton(
                              label: "Parcel",
                              selected: orderType == "Parcel",
                              primaryColor: primaryColor,
                              textColor: textColor,
                              cardInfoColor: cardInfoColor,
                              onTap: () =>
                                  setState(() => orderType = "Parcel"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: orderType == "Parcel"
                      ? Padding(
                    key: const ValueKey('parcel-info'),
                    padding: EdgeInsets.fromLTRB(
                      kIsWeb ? 16 : 16.w,
                      kIsWeb ? 4 : 4.h,
                      kIsWeb ? 16 : 16.w,
                      kIsWeb ? 8 : 8.h,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius:
                        BorderRadius.circular(kIsWeb ? 14 : 14.r),
                        border: Border.all(
                            color: const Color(0xFFE5E7EB), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: kIsWeb ? 8 : 8.r,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(kIsWeb ? 16 : 16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Customer Information",
                            style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 15 : 15.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: kIsWeb ? 4 : 4.h),
                          Text(
                            "Required for parcel orders",
                            style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 12 : 12.sp,
                              color: cardInfoColor,
                            ),
                          ),
                          SizedBox(height: kIsWeb ? 14 : 14.h),
                          _buildTextField(
                            controller: nameController,
                            label: "Customer Name",
                            hint: "Enter customer name",
                            icon: Icons.person_outline,
                            primaryColor: primaryColor,
                            textColor: textColor,
                            cardInfoColor: cardInfoColor,
                          ),
                          SizedBox(height: kIsWeb ? 12 : 12.h),
                          _buildTextField(
                            controller: mobileController,
                            label: "Mobile Number",
                            hint: "Enter mobile number",
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            primaryColor: primaryColor,
                            textColor: textColor,
                            cardInfoColor: cardInfoColor,
                          ),
                          SizedBox(height: kIsWeb ? 12 : 12.h),
                          _buildTextField(
                            controller: instructionController,
                            label: "Special Instructions (Optional)",
                            hint: "Example: Less spicy, No onion",
                            icon: Icons.note_alt_outlined,
                            maxLines: 2,
                            primaryColor: primaryColor,
                            textColor: textColor,
                            cardInfoColor: cardInfoColor,
                          ),
                        ],
                      ),
                    ),
                  )
                      : const SizedBox.shrink(key: ValueKey('dine-in-empty')),
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(
                    kIsWeb ? 16 : 16.w,
                    kIsWeb ? 4 : 4.h,
                    kIsWeb ? 16 : 16.w,
                    kIsWeb ? 8 : 8.h,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius:
                      BorderRadius.circular(kIsWeb ? 14 : 14.r),
                      border: Border.all(
                          color: const Color(0xFFE5E7EB), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: kIsWeb ? 8 : 8.r,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(kIsWeb ? 16 : 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Order Summary",
                          style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 15 : 15.sp,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: kIsWeb ? 14 : 14.h),

                        // Subtotal
                        _SummaryRow(
                          label: "Subtotal",
                          value: "₹${getTotal()}",
                          labelColor: cardInfoColor,
                          valueColor: textColor,
                          valueFontWeight: FontWeight.w500,
                        ),
                        SizedBox(height: kIsWeb ? 10 : 10.h),


                        if (enableGst && gstPct > 0) ...[
                          _SummaryRow(
                            label:
                            "GST (${gstPct % 1 == 0 ? gstPct.toInt() : gstPct}%)",
                            value:
                            "₹${getGSTAmount(gstPct).toStringAsFixed(2)}",
                            labelColor: cardInfoColor,
                            valueColor: textColor,
                            valueFontWeight: FontWeight.w500,
                          ),
                          SizedBox(height: kIsWeb ? 10 : 10.h),
                        ],

                        // ── SGST row (cessPercentage, only when GST enabled) ─
                        if (enableGst && sgstPct > 0) ...[
                          _SummaryRow(
                            label:
                            "SGST (${sgstPct % 1 == 0 ? sgstPct.toInt() : sgstPct}%)",
                            value:
                            "₹${getSGSTAmount(sgstPct).toStringAsFixed(2)}",
                            labelColor: cardInfoColor,
                            valueColor: textColor,
                            valueFontWeight: FontWeight.w500,
                          ),
                          SizedBox(height: kIsWeb ? 10 : 10.h),
                        ],

                        // ── Packaging charge (only when enabled) ─────────────
                        if (enablePackaging && pkgCharge > 0) ...[
                          _SummaryRow(
                            label: "Packaging Charge",
                            value: "₹${pkgCharge.toStringAsFixed(2)}",
                            labelColor: cardInfoColor,
                            valueColor: textColor,
                            valueFontWeight: FontWeight.w500,
                          ),
                          SizedBox(height: kIsWeb ? 10 : 10.h),
                        ],

                        SizedBox(height: kIsWeb ? 4 : 4.h),
                        const Divider(
                            color: Color(0xFFE5E7EB), thickness: 1),
                        SizedBox(height: kIsWeb ? 12 : 12.h),

                        // Grand total
                        _SummaryRow(
                          label: "Total",
                          value: "₹${getFinalTotal(
                            enableGst: enableGst,
                            gstPct: gstPct,
                            sgstPct: sgstPct,
                            enablePackaging: enablePackaging,
                            packagingCharge: pkgCharge,
                          ).toStringAsFixed(2)}",
                          labelColor: textColor,
                          valueColor: primaryColor,
                          fontSize: kIsWeb ? 16.0 : 16.sp,
                          valueFontWeight: FontWeight.w700,
                          labelFontWeight: FontWeight.w600,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),


          bottomNavigationBar: widget.cart.isEmpty
              ? null
              : Container(
            decoration: BoxDecoration(
              color: cardColor,
              border: const Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: kIsWeb ? 16 : 16.r,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              kIsWeb ? 20 : 20.w,
              kIsWeb ? 12 : 12.h,
              kIsWeb ? 20 : 20.w,
              kIsWeb ? 18 : 18.h,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Total",
                        style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 12 : 12.sp,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: kIsWeb ? 2 : 2.h),
                      Text(
                        "₹${getFinalTotal(
                          enableGst: enableGst,
                          gstPct: gstPct,
                          sgstPct: sgstPct,
                          enablePackaging: enablePackaging,
                          packagingCharge: pkgCharge,
                        ).toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 18 : 18.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: kIsWeb ? 16 : 16.w),

                  Expanded(
                    child: SizedBox(
                      height: kIsWeb ? 50 : 50.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                kIsWeb ? 14 : 14.r),
                          ),
                        ),
                        onPressed: () => placeOrder(
                          enableGst: enableGst,
                          gstPct: gstPct,
                          sgstPct: sgstPct,
                          enablePackaging: enablePackaging,
                          packagingCharge: pkgCharge,
                        ),
                        child: Text(
                          "Place Order",
                          style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 15 : 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color primaryColor,
    required Color textColor,
    required Color cardInfoColor,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(
        color: textColor,
        fontSize: kIsWeb ? 14 : 14.sp,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(
          color: cardInfoColor,
          fontSize: kIsWeb ? 13 : 13.sp,
        ),
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFF9CA3AF),
          fontSize: kIsWeb ? 13 : 13.sp,
        ),
        prefixIcon: Icon(icon, color: cardInfoColor, size: kIsWeb ? 20 : 20.sp),
        contentPadding: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 14 : 14.w,
          vertical: kIsWeb ? 14 : 14.h,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.r),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.r),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.r),
          borderSide: BorderSide(color: primaryColor, width: 1.8),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _OrderTypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primaryColor;
  final Color textColor;
  final Color cardInfoColor;
  final VoidCallback onTap;

  const _OrderTypeButton({
    required this.label,
    required this.selected,
    required this.primaryColor,
    required this.textColor,
    required this.cardInfoColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 28 : 28.w,
          vertical: kIsWeb ? 10 : 10.h,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.r),
          border: Border.all(
            color: selected ? primaryColor : const Color(0xFFE5E7EB),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: kIsWeb ? 14 : 14.sp,
            fontWeight: FontWeight.w500,
            color: selected ? primaryColor : cardInfoColor,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final FontWeight? labelFontWeight;
  final FontWeight? valueFontWeight;
  final double? fontSize;

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
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: kIsWeb ? fs : fs.sp,
            color: labelColor,
            fontWeight: labelFontWeight ?? FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: kIsWeb ? fs : fs.sp,
            color: valueColor,
            fontWeight: valueFontWeight ?? FontWeight.w500,
          ),
        ),
      ],
    );
  }
}