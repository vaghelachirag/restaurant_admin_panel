import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

Color hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  if (hex.length == 6) {
    hex = "FF$hex";
  }
  return Color(int.parse(hex, radix: 16));
}

class TrackOrderPage extends StatefulWidget {
  final String restaurantId;

  const TrackOrderPage({super.key, required this.restaurantId});

  @override
  State<TrackOrderPage> createState() => _TrackOrderPageState();
}

class _TrackOrderPageState extends State<TrackOrderPage> {

  final TextEditingController tokenController = TextEditingController();
  String? token;

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
        
        final bgColor = hexToColor(theme['backgroundColor'] ?? "#FAF5EF");
        final textColor = hexToColor(theme['textColor'] ?? "#000000");
        final cardColor = hexToColor(theme['cardColor'] ?? "#FFFFFF");
        final cardInfoColor = hexToColor(theme['cardInfoColor'] ?? "#757575");
        final primaryColor = hexToColor(theme['primaryColor'] ?? "#4CAF50");
        
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
              "Track Order",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize:  kIsWeb ? 18 : 18.sp,
              ),
            ),
            centerTitle: false,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
            child: Column(
              children: [
                /// SEARCH CARD
                Container(
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
                        blurRadius:  kIsWeb ? 10 : 12.sp,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(kIsWeb ? 20 : 20.sp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Enter Token Number",
                        style: GoogleFonts.poppins(
                          fontSize:  kIsWeb ? 16 : 16.sp,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: kIsWeb ? 16 : 16.h),
                      TextField(
                        controller: tokenController,
                        style: GoogleFonts.poppins(
                          fontSize:  kIsWeb ? 16 : 16.sp,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          labelText: "Token Number",
                          labelStyle: GoogleFonts.poppins(
                            color: const Color(0xFF6B7280),
                            fontSize:  kIsWeb ? 14 : 14.sp,
                          ),
                          hintStyle: GoogleFonts.poppins(
                            color: const Color(0xFF9CA3AF),
                            fontSize:  kIsWeb ? 14 : 14.sp,
                          ),
                          prefixIcon: Icon(
                            Icons.confirmation_number_outlined,
                            color: const Color(0xFF6B7280),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                            borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: kIsWeb ? 16 : 16.sp),
                      SizedBox(
                        width: double.infinity,
                        height: kIsWeb ? 50 : 50.sp,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() {
                              token = tokenController.text.trim();
                            });
                          },
                          child: Text(
                            "Track Order",
                            style: GoogleFonts.poppins(
                              fontSize:  kIsWeb ? 16 : 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: kIsWeb ? 24 : 24.h),
                
                /// ORDER RESULTS
                if (token != null && token!.isNotEmpty)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("orders")
                        .where("restaurantId", isEqualTo: widget.restaurantId)
                        .where("tokenNumber", isEqualTo: int.tryParse(token!))
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          padding: EdgeInsets.all(kIsWeb ? 40 : 40.sp),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          padding: EdgeInsets.all( kIsWeb ? 20 : 20.sp),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade400,
                                size:  kIsWeb ? 48 : 48.sp,
                              ),
                              SizedBox(height: kIsWeb ? 12 : 12.h),
                              Text(
                                "Error loading order",
                                style: GoogleFonts.poppins(
                                  fontSize:  kIsWeb ? 16 : 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.data!.docs.isEmpty) {
                        return Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          padding: EdgeInsets.all( kIsWeb ? 20 : 20.sp),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                color: const Color(0xFF6B7280),
                                size:  kIsWeb ? 48 : 48.sp,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                "Order not found",
                                style: GoogleFonts.poppins(
                                  fontSize:  kIsWeb ? 16 : 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                              SizedBox(height: kIsWeb ? 8 : 8.h),
                              Text(
                                "Please check your token number and try again",
                                style: GoogleFonts.poppins(
                                  fontSize:  kIsWeb ? 14 : 14.sp,
                                  color: const Color(0xFF9CA3AF),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      var order = snapshot.data!.docs.first;
                      final orderData = order.data() as Map<String, dynamic>;
                      final status = orderData['status'] as String? ?? 'pending';
                      final tokenNumber = orderData['tokenNumber'] as int? ?? 0;
                      final totalAmount = orderData['totalAmount'] as int? ?? 0;
                      final customerName = orderData['customerName'] as String? ?? 'Guest';
                      final orderType = orderData['orderType'] as String? ?? 'Dine In';
                      final items = orderData['items'] as List<dynamic>? ?? [];
                      
                      return Container(
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
                              blurRadius: kIsWeb ? 12 : 12.sp,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// Header with gradient
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF7C3AED),
                                    Color(0xFFA855F7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              padding: EdgeInsets.all( kIsWeb ? 20 : 20.sp),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: kIsWeb ? 12 : 12.sp,
                                      vertical: kIsWeb ? 8 : 8.sp,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                    ),
                                    child: Text(
                                      "Token #$tokenNumber",
                                      style: GoogleFonts.poppins(
                                        fontSize:  kIsWeb ? 16 : 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Spacer(),
                                  _buildStatusChip(status),
                                ],
                              ),
                            ),
                            
                            Padding(
                              padding: EdgeInsets.all( kIsWeb ? 20 : 20.sp),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// Customer Info
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        color: const Color(0xFF6B7280),
                                        size: kIsWeb ? 20 : 20.sp,
                                      ),
                                      SizedBox(width: kIsWeb ? 8 : 8.w),
                                      Text(
                                        customerName,
                                        style: GoogleFonts.poppins(
                                          fontSize:  kIsWeb ? 16 : 16.sp,
                                          fontWeight: FontWeight.w500,
                                          color: textColor,
                                        ),
                                      ),
                                      Spacer(),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: kIsWeb ? 8 : 8.sp,
                                          vertical: kIsWeb ? 4 : 4.sp,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                        ),
                                        child: Text(
                                          orderType,
                                          style: GoogleFonts.poppins(
                                            fontSize: kIsWeb ? 12 : 12.sp,
                                            color: const Color(0xFF6B7280),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: kIsWeb ? 16 : 16.h),
                                  
                                  /// Order Items
                                  if (items.isNotEmpty) ...[
                                    Text(
                                      "Order Items",
                                      style: GoogleFonts.poppins(
                                        fontSize: kIsWeb ? 14 : 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    SizedBox(height: kIsWeb ? 12 : 12.h),
                                    ...items.map((item) => Padding(
                                      padding: EdgeInsets.only(bottom: kIsWeb ? 8 : 8.h),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: kIsWeb ? 4 : 4.w,
                                            height: kIsWeb ? 16 : 16.h,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF7C3AED),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          SizedBox(width: kIsWeb ? 12 : 12.w),
                                          Expanded(
                                            child: Text(
                                              "${item['name']} (${item['variant']}) x${item['qty']}",
                                              style: GoogleFonts.poppins(
                                                fontSize: kIsWeb ? 14 : 14.sp,
                                                color: const Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "₹${item['price'] * item['qty']}",
                                            style: GoogleFonts.poppins(
                                              fontSize: kIsWeb ? 14 : 14.sp,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF7C3AED),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                    SizedBox(height: kIsWeb ? 16 : 16.h),
                                  ],
                                  
                                  /// Total Amount
                                  Container(
                                    padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Total Amount",
                                          style: GoogleFonts.poppins(
                                            fontSize: kIsWeb ? 16 : 16.sp,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        Text(
                                          "₹$totalAmount",
                                          style: GoogleFonts.poppins(
                                            fontSize: kIsWeb ? 18 : 18.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF7C3AED),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String displayText;
    
    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF856404);
        displayText = 'Pending';
        break;
      case 'preparing':
        bgColor = const Color(0xFFCCE5FF);
        textColor = const Color(0xFF004085);
        displayText = 'Preparing';
        break;
      case 'ready':
        bgColor = const Color(0xFFD4EDDA);
        textColor = const Color(0xFF155724);
        displayText = 'Ready';
        break;
      case 'completed':
        bgColor = const Color(0xFFD1ECF1);
        textColor = const Color(0xFF0C5460);
        displayText = 'Completed';
        break;
      default:
        bgColor = const Color(0xFFF8F9FA);
        textColor = const Color(0xFF6B7280);
        displayText = status;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kIsWeb ? 12 : 12.sp,
        vertical: kIsWeb ? 6 : 6.sp,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20.sp),
      ),
      child: Text(
        displayText,
        style: GoogleFonts.poppins(
          fontSize: kIsWeb ? 12 : 12.sp,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  void showTrackOrderPopup(BuildContext context) {

    TextEditingController tokenController = TextEditingController();
    String? token;

    showDialog(
      context: context,
      builder: (context) {

        return StatefulBuilder(
          builder: (context, setStateDialog) {

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(kIsWeb ? 20 : 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    const Text(
                      "Track Your Order",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: tokenController,
                      decoration: const InputDecoration(
                        labelText: "Enter Token Number",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: () {
                        setStateDialog(() {
                          token = tokenController.text.trim();
                        });
                      },
                      child: const Text("Track"),
                    ),

                    const SizedBox(height: 15),

                    if (token != null)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection("orders")
                            .where("restaurantId",
                            isEqualTo: widget.restaurantId)
                            .where("tokenNumber", isEqualTo: token)
                            .snapshots(),
                        builder: (context, snapshot) {

                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }

                          if (snapshot.data!.docs.isEmpty) {
                            return const Text("Order not found");
                          }

                          var order = snapshot.data!.docs.first;

                          return Column(
                            children: [

                              Text(
                                "Token: ${order['tokenNumber']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text("Status: ${order['status']}"),

                              const SizedBox(height: 6),

                              Text("Total: ₹${order['total']}"),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}