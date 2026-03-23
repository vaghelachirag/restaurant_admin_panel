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

  int getTotal() {
    int total = 0;
    for (var item in widget.cart) {
      total += item.price * item.qty;
    }
    return total;
  }

  double getGST() {
    return getTotal() * 0.025; // 2.5% GST
  }

  double getSGST() {
    return getTotal() * 0.025; // 2.5% SGST
  }

  double getTax() {
    return getGST() + getSGST();
  }

  double getFinalTotal() {
    return getTotal() + getTax();
  }

  Future<void> placeOrder() async {
    int tokenNumber = DateTime.now().millisecondsSinceEpoch % 10000;

    // For dine-in, customer details are optional and will be collected at restaurant
    // For parcel, customer details are required
    if (orderType == "Parcel" && (nameController.text.isEmpty || mobileController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter customer name and mobile number for parcel order")),
      );
      return;
    }

    int totalAmount = getFinalTotal().round();

    final orderRef =
    FirebaseFirestore.instance.collection("orders").doc();

    await orderRef.set({
      "restaurantId": widget.restaurantId,
      "tokenNumber": tokenNumber,
      "customerName": nameController.text,
      "mobile": mobileController.text,
      "orderType": orderType,
      "specialInstruction": instructionController.text,
      "status": "pending",
      "totalAmount": totalAmount,
      "createdAt": FieldValue.serverTimestamp(),
      "items": widget.cart.map((e) => {
        "itemId": e.itemId,
        "name": e.name,
        "variant": e.variant,
        "price": e.price,
        "qty": e.qty
      }).toList()
    });

    /// Get orderId from orderRef
    String orderId = orderRef.id;

    widget.cart.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrderStatusPage(orderId: orderId),
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
        if (!restaurantSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final rawData = restaurantSnapshot.data!.data();
        if (rawData == null) {
          return const Scaffold(
            body: Center(child: Text('Restaurant not found')),
          );
        }
        final data = rawData as Map<String, dynamic>;
        final theme = data['theme'] ?? {};
        final bgColor =
            _hexToColor(theme['backgroundColor'] ?? "#FAF5EF");
        final textColor =
            _hexToColor(theme['textColor'] ?? "#000000");
        final cardColor =
            _hexToColor(theme['cardColor'] ?? "#FFFFFF");
        final cardInfoColor =
            _hexToColor(theme['cardInfoColor'] ?? "#757575");
        final primaryColor =
            _hexToColor(theme['primaryColor'] ?? "#4CAF50");
        final categoryBgColor =
            _hexToColor(theme['categoryBackgroundColor'] ?? "#6D4C41");
        final categoryTextColor =
            _hexToColor(theme['categoryTextColor'] ?? "#FFFFFF");

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
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
                fontSize:  kIsWeb ? 18 : 18.sp,
              ),
            ),
            centerTitle: false,
          ),
          body: widget.cart.isEmpty
              ? Center(
                  child: Text(
                    "Cart is empty",
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 18 : 18.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      /// CART ITEMS (always shown)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(kIsWeb ? 16 : 16.sp, kIsWeb ? 16 : 16.sp, kIsWeb ? 16 : 16.sp, kIsWeb ? 8 : 8.sp),
                        itemCount: widget.cart.length,
                        itemBuilder: (context, index) {
                          final item = widget.cart[index];
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 6.w),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: kIsWeb ? 8 : 8.sp,
                                  offset: Offset(0.sp, kIsWeb ? 2 : 2.sp),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Product Image
                                      Container(
                                        width: kIsWeb ? 60 : 60.w,
                                        height: kIsWeb ? 60 : 60.h,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                                          child: item.image != null
                                              ? Image.network(
                                                  item.image!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[100],
                                                      child: Icon(
                                                        Icons.restaurant,
                                                        color: Colors.grey[400],
                                                        size: kIsWeb ? 30 : 30.sp,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  color: Colors.grey[100],
                                                  child: Icon(
                                                    Icons.restaurant,
                                                    color: Colors.grey[400],
                                                    size: kIsWeb ? 30 : 30.sp,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      SizedBox(width: kIsWeb ? 12 : 12.w),
                                      // Item Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: kIsWeb ? 16 : 16.sp,
                                                color: textColor,
                                              ),
                                            ),
                                            SizedBox(height: kIsWeb ? 4 : 4.h),
                                            Text(
                                              "${item.variant}",
                                              style: GoogleFonts.poppins(
                                                fontSize: kIsWeb ? 14 : 14.sp,
                                                color: const Color(0xFF6B7280),
                                              ),
                                            ),
                                            SizedBox(height: kIsWeb ? 4 : 4.h),
                                            Text(
                                              "₹ ${item.price}",
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: kIsWeb ? 16 : 16.sp,
                                                color: textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Delete Icon
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            widget.cart.removeAt(index);
                                          });
                                        },
                                        child: Icon(
                                          Icons.delete,
                                          color: Colors.red.shade400,
                                          size: kIsWeb ? 24 : 24.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: kIsWeb ? 16 : 16.h),
                                  // Quantity Selector
                                  Row(
                                    children: [
                                      Text(
                                        "Quantity",
                                        style: GoogleFonts.poppins(
                                          fontSize: kIsWeb ? 14 : 14.sp,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                      Spacer(),
                                      Container(
                                        height: kIsWeb ? 36 : 36.h,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Minus button
                                            GestureDetector(
                                              onTap: () {
                                                if (item.qty > 1) {
                                                  setState(() {
                                                    item.qty--;
                                                  });
                                                }
                                              },
                                              child: Container(
                                                width: kIsWeb ? 36 : 36.w,
                                                height: kIsWeb ? 36 : 36.h,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(kIsWeb ? 6 : 6.sp),
                                                  border: Border.all(
                                                    color: const Color(0xFFE5E7EB),
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.remove,
                                                  color: const Color(0xFF6B7280),
                                                  size: kIsWeb ? 18 : 18.sp,
                                                ),
                                              ),
                                            ),
                                            // Quantity display
                                            Container(
                                              width: kIsWeb ? 40 : 40.w,
                                              alignment: Alignment.center,
                                              child: Text(
                                                item.qty.toString(),
                                                style: GoogleFonts.poppins(
                                                  fontSize: kIsWeb ? 16 : 16.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor,
                                                ),
                                              ),
                                            ),
                                            // Plus button
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  item.qty++;
                                                });
                                              },
                                              child: Container(
                                                width: kIsWeb ? 36 : 36.w,
                                                height: kIsWeb ? 36 : 36.h,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF7C3AED),
                                                  borderRadius: BorderRadius.circular(kIsWeb ? 6 : 6.sp),
                                                ),
                                                child: Icon(
                                                  Icons.add,
                                                  color: Colors.white,
                                                  size: kIsWeb ? 18 : 18.sp,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      /// CUSTOMER INFO CARD (only show for parcel)
                      if (orderType == "Parcel")
                        Padding(
                          padding: EdgeInsets.fromLTRB(kIsWeb ? 16 : 16.sp, kIsWeb ? 8 : 8.sp, kIsWeb ? 16 : 16.sp, kIsWeb ? 8 : 8.sp),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: kIsWeb ? 10 : 10.sp,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Customer Details",
                                  style: GoogleFonts.poppins(
                                    fontSize: kIsWeb ? 16 : 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                 SizedBox(height: 12.h),
                                TextField(
                                  controller: nameController,
                                  style: GoogleFonts.poppins(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: "Customer Name",
                                    labelStyle: GoogleFonts.poppins(
                                      color: const Color(0xFF6B7280),
                                      fontSize: kIsWeb ? 14 : 14.sp,
                                    ),
                                    hintStyle: GoogleFonts.poppins(
                                      color: const Color(0xFF9CA3AF),
                                      fontSize: kIsWeb ? 13 : 13.sp,
                                    ),
                                    prefixIcon: Icon(Icons.person_outline, color: const Color(0xFF6B7280)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                                    ),
                                  ),
                                ),
                                SizedBox(height: kIsWeb ? 12 : 12.h),
                                TextField(
                                  controller: mobileController,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.poppins(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: "Mobile Number",
                                    labelStyle: GoogleFonts.poppins(
                                      color: const Color(0xFF6B7280),
                                      fontSize: kIsWeb ? 16 : 16.sp,
                                    ),
                                    hintStyle: GoogleFonts.poppins(
                                      color: const Color(0xFF9CA3AF),
                                      fontSize: kIsWeb ? 13 : 16.sp,
                                    ),
                                    prefixIcon: Icon(Icons.phone_outlined, color: const Color(0xFF6B7280)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                      borderSide: BorderSide(color: cardInfoColor.withOpacity(0.3)),
                                    ),
                                  ),
                                ),
                                 SizedBox(height: 12.h),
                                TextField(
                                  controller: instructionController,
                                  maxLines: 2,
                                  style: GoogleFonts.poppins(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: "Special Instruction (Optional)",
                                    hintText: "Example: Less spicy, No onion",
                                    labelStyle: GoogleFonts.poppins(
                                      color: const Color(0xFF6B7280),
                                      fontSize: kIsWeb ? 12 : 14.sp,
                                    ),
                                    hintStyle: GoogleFonts.poppins(
                                      color: const Color(0xFF9CA3AF),
                                      fontSize: kIsWeb ? 12 : 12.sp,
                                    ),
                                    prefixIcon: Icon(Icons.note_alt_outlined, color: const Color(0xFF6B7280)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                      borderSide: BorderSide(color: cardInfoColor.withOpacity(0.3)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      /// ORDER TYPE SELECTION
                      Padding(
                        padding: EdgeInsets.fromLTRB(kIsWeb ? 16 : 16.sp, kIsWeb ? 8 : 8.sp, kIsWeb ? 16 : 16.sp, kIsWeb ? 8 : 16.sp),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: kIsWeb ? 10 : 10.sp,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Order Type",
                                style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 16 : 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                               SizedBox(height: kIsWeb ? 12 : 12.h),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        orderType = "Dine In";
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: kIsWeb ? 20 : 20.w,
                                        vertical: kIsWeb ? 10 : 10.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: orderType == "Dine In" 
                                            ? const Color(0xFF7C3AED) 
                                            : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                                        border: Border.all(
                                          color: orderType == "Dine In"
                                              ? const Color(0xFF7C3AED)
                                              : const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: Text(
                                        "Dine In",
                                        style: GoogleFonts.poppins(
                                          fontSize: kIsWeb ? 14 : 14.sp,
                                          fontWeight: FontWeight.w500,
                                          color: orderType == "Dine In"
                                              ? Colors.white
                                              : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: kIsWeb ? 12 : 12.w),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        orderType = "Parcel";
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: kIsWeb ? 20 : 20.w,
                                        vertical: kIsWeb ? 10 : 10.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: orderType == "Parcel" 
                                            ? const Color(0xFF7C3AED) 
                                            : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                                        border: Border.all(
                                          color: orderType == "Parcel"
                                              ? const Color(0xFF7C3AED)
                                              : const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: Text(
                                        "Parcel",
                                        style: GoogleFonts.poppins(
                                          fontSize: kIsWeb ? 14 : 14.sp,
                                          fontWeight: FontWeight.w500,
                                          color: orderType == "Parcel"
                                              ? Colors.white
                                              : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (orderType == "Dine In") ...[
                                SizedBox(height: kIsWeb ? 12 : 12.h),
                                Container(
                                  padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                    border: Border.all(
                                      color: const Color(0xFF7C3AED).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: const Color(0xFF7C3AED),
                                        size: kIsWeb ? 20 : 20.sp,
                                      ),
                                      SizedBox(width: kIsWeb ? 8 : 8.w),
                                      Expanded(
                                        child: Text(
                                          "For dine-in orders, customer details will be collected at the restaurant",
                                          style: GoogleFonts.poppins(
                                            fontSize: kIsWeb ? 12 : 12.sp,
                                            color: const Color(0xFF7C3AED),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      /// ORDER SUMMARY
                      Padding(
                        padding: EdgeInsets.fromLTRB(kIsWeb ? 16 : 16.sp, kIsWeb ? 8 : 8.sp, kIsWeb ? 16 : 16.sp, kIsWeb ? 8 : 8.sp),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: kIsWeb ? 8 : 8.sp,
                                offset: Offset(0.sp, kIsWeb ? 2 : 2.sp),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Order Summary",
                                style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 16 : 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: kIsWeb ? 16 : 16.h),
                              // Subtotal
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Subtotal",
                                    style: GoogleFonts.poppins(
                                      fontSize: kIsWeb ? 14 : 14.sp,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                  Text(
                                    "₹ ${getTotal()}",
                                    style: GoogleFonts.poppins(
                                      fontSize: kIsWeb ? 14 : 14.sp,
                                      color: textColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: kIsWeb ? 12 : 12.h),
                              // Tax
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Tax",
                                    style: GoogleFonts.poppins(
                                      fontSize: kIsWeb ? 14 : 14.sp,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                  Text(
                                    "₹ ${getTax().toStringAsFixed(2)}",
                                    style: GoogleFonts.poppins(
                                      fontSize: kIsWeb ? 14 : 14.sp,
                                      color: textColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: kIsWeb ? 12 : 12.h),
                              // Divider
                              Divider(
                                color: const Color(0xFFE5E7EB),
                                thickness: 1,
                              ),
                              SizedBox(height: kIsWeb ? 12 : 12.h),
                              // Total
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Total",
                                    style: GoogleFonts.poppins(
                                      fontSize: kIsWeb ? 16 : 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    "₹ ${getFinalTotal().toStringAsFixed(2)}",
                                    style: GoogleFonts.poppins(
                                      fontSize: kIsWeb ? 16 : 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Add bottom padding to ensure content doesn't get hidden behind bottom navigation
                      SizedBox(height: 100.h),
                    ],
                  ),
                ),
          bottomNavigationBar: widget.cart.isEmpty
              ? null
              : Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: kIsWeb ? 16 : 16.sp,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding:  EdgeInsets.fromLTRB(kIsWeb ? 16 : 16.sp, kIsWeb ? 10 : 10.sp, kIsWeb ? 16 : 16.sp, kIsWeb ? 16 : 16.sp),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Total",
                                style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 14 : 14.sp,
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                "₹ ${getFinalTotal().toStringAsFixed(2)}",
                                style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 20 : 20.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: kIsWeb ? 12 : 12.w),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding:  EdgeInsets.symmetric(
                                vertical: kIsWeb ? 12 : 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            onPressed: placeOrder,
                            child: Text(
                              "Place Order",
                              style: GoogleFonts.poppins(
                                fontSize: kIsWeb ? 16 : 16.sp,
                                fontWeight: FontWeight.w600,
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
}