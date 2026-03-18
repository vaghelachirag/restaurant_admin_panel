import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'order_status_page.dart';

Color _hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  if (hex.length == 6) {
    hex = "FF$hex";
  }
  return Color(int.parse(hex, radix: 16));
}

class CartItem {
  String itemId;
  String name;
  String variant;
  int price;
  int qty;

  CartItem({
    required this.itemId,
    required this.name,
    required this.variant,
    required this.price,
    this.qty = 1,
  });
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

    int totalAmount = getTotal();

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
                fontSize: 18.sp,
              ),
            ),
            centerTitle: false,
          ),
          body: widget.cart.isEmpty
              ? Center(
                  child: Text(
                    "Cart is empty",
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
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
                        padding: EdgeInsets.fromLTRB(16.sp, 16.sp, 16.sp, 8.sp),
                        itemCount: widget.cart.length,
                        itemBuilder: (context, index) {
                          final item = widget.cart[index];
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 6.w),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16.sp),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8.sp,
                                  offset: Offset(0.sp, 2.sp),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.h,
                                vertical: 10.w,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  /// Left accent bar (theme purple gradient)
                                  Container(
                                    width: 4.w,
                                    height: 48.h,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF7C3AED),
                                          Color(0xFFA855F7),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(12.sp),
                                    ),
                                  ),
                                   SizedBox(width: 12.w),
                                  /// ITEM INFO
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16.sp,
                                            color: textColor,
                                          ),
                                        ),
                                         SizedBox(height: 2.h),
                                        Text(
                                          item.variant,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.sp,
                                            color: const Color(0xFF6B7280),
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          "₹ ${item.price}",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16.sp,
                                            color: const Color(0xFF7C3AED),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                   SizedBox(width: 8.w),
                                  /// QTY CONTROL
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(20.sp),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: Icon(
                                            Icons.remove_rounded,
                                            size: 20.sp,
                                            color: const Color(0xFF7C3AED),
                                          ),
                                          onPressed: () {
                                            if (item.qty > 1) {
                                              setState(() {
                                                item.qty--;
                                              });
                                            }
                                          },
                                        ),
                                        Text(
                                          item.qty.toString(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w500,
                                            color: textColor,
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: Icon(
                                            Icons.add_rounded,
                                            size: 20.sp,
                                            color: const Color(0xFF7C3AED),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              item.qty++;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red.shade400,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        widget.cart.removeAt(index);
                                      });
                                    },
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
                          padding: EdgeInsets.fromLTRB(16.sp, 8.sp, 16.sp, 8.sp),
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
                                  blurRadius: 10.sp,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(16.sp),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Customer Details",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16.sp,
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
                                      fontSize: 14.sp,
                                    ),
                                    hintStyle: GoogleFonts.poppins(
                                      color: const Color(0xFF9CA3AF),
                                      fontSize: 13.sp,
                                    ),
                                    prefixIcon: Icon(Icons.person_outline, color: const Color(0xFF6B7280)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                TextField(
                                  controller: mobileController,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.poppins(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: "Mobile Number",
                                    labelStyle: GoogleFonts.poppins(
                                      color: const Color(0xFF6B7280),
                                      fontSize: 14.sp,
                                    ),
                                    hintStyle: GoogleFonts.poppins(
                                      color: const Color(0xFF9CA3AF),
                                      fontSize: 13.sp,
                                    ),
                                    prefixIcon: Icon(Icons.phone_outlined, color: const Color(0xFF6B7280)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.sp),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.sp),
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
                                      fontSize: 14.sp,
                                    ),
                                    hintStyle: GoogleFonts.poppins(
                                      color: const Color(0xFF9CA3AF),
                                      fontSize: 13.sp,
                                    ),
                                    prefixIcon: Icon(Icons.note_alt_outlined, color: const Color(0xFF6B7280)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.sp),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.sp),
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
                        padding: EdgeInsets.fromLTRB(16.sp, 8.sp, 16.sp, 8.sp),
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
                                blurRadius: 10.sp,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(16.sp),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Order Type",
                                style: GoogleFonts.poppins(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                               SizedBox(height: 12.h),
                              Row(
                                children: [
                                  ChoiceChip(
                                    label: Text(
                                      "Dine In",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.sp,
                                        color: orderType == "Dine In"
                                            ? Colors.white
                                            : const Color(0xFF1F2937),
                                      ),
                                    ),
                                    selected: orderType == "Dine In",
                                    selectedColor: const Color(0xFF7C3AED),
                                    backgroundColor: const Color(0xFFF3F4F6),
                                    onSelected: (_) {
                                      setState(() {
                                        orderType = "Dine In";
                                      });
                                    },
                                  ),
                                  SizedBox(width: 8.w),
                                  ChoiceChip(
                                    label: Text(
                                      "Parcel",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.sp,
                                        color: orderType == "Parcel"
                                            ? Colors.white
                                            : const Color(0xFF1F2937),
                                      ),
                                    ),
                                    selected: orderType == "Parcel",
                                    selectedColor: const Color(0xFF7C3AED),
                                    backgroundColor: const Color(0xFFF3F4F6),
                                    onSelected: (_) {
                                      setState(() {
                                        orderType = "Parcel";
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (orderType == "Dine In") ...[
                                SizedBox(height: 12.h),
                                Container(
                                  padding: EdgeInsets.all(12.sp),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12.sp),
                                    border: Border.all(
                                      color: const Color(0xFF7C3AED).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: const Color(0xFF7C3AED),
                                        size: 20.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          "For dine-in orders, customer details will be collected at the restaurant",
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.sp,
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
                        blurRadius: 16.sp,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding:  EdgeInsets.fromLTRB(16.sp, 10.sp, 16.sp, 16.sp),
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
                                  fontSize: 14.sp,
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                "₹${getTotal()}",
                                style: GoogleFonts.poppins(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding:  EdgeInsets.symmetric(
                                vertical: 16.h,
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
                                fontSize: 16.sp,
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