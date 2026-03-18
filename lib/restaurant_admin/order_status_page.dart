import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OrderStatusPage extends StatelessWidget {
  final String orderId;

  const OrderStatusPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Track Order"),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("orders")
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;

          int token = data["tokenNumber"] ?? 0;
          int total = data["totalAmount"] ?? 0;
          String status = data["status"] ?? "pending";

          return SingleChildScrollView(
            padding:  EdgeInsets.all(20.sp),
            child: Column(
              children: [

                /// SUCCESS MESSAGE
                Container(
                  padding:  EdgeInsets.all(20.sp),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16.sp),
                  ),
                  child: Column(
                    children:  [
                      Icon(Icons.check_circle,
                          color: Colors.green, size: 60.sp),
                      SizedBox(height: 10.h),
                      Text(
                        "Order Placed Successfully!",
                        style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        "Your order has been received",
                        style: TextStyle(color: Colors.grey),
                      )
                    ],
                  ),
                ),

                 SizedBox(height: 25.h),

                /// TOKEN CARD
                Container(
                  width: double.infinity,
                  padding:  EdgeInsets.all(25.sp),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade400,
                        Colors.orange.shade600
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                       Text(
                        "TOKEN NUMBER",
                        style: TextStyle(
                          color: Colors.white,
                          letterSpacing: 2,
                          fontSize: 18.sp
                        ),
                      ),
                       SizedBox(height: 10.h),
                      Text(
                        "$token",
                        style:  TextStyle(
                          fontSize: 50.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.sp),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(18.sp),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text(
                          "Total Amount",
                          style: TextStyle(fontSize: 16.sp),
                        ),
                        Text(
                          "₹$total",
                          style:  TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 30.h),

                /// STATUS TITLE
                 Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Order Status",
                    style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 20.h),
                statusTile("pending", status, "Order Received"),
                statusTile("preparing", status, "Preparing Food"),
                statusTile("ready", status, "Ready for Pickup"),
                statusTile("completed", status, "Completed"),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget statusTile(String step, String current, String title) {

    List orderSteps = ["pending", "preparing", "ready", "completed"];

    bool completed =
        orderSteps.indexOf(step) <= orderSteps.indexOf(current);

    return Card(
      margin:  EdgeInsets.only(bottom: 12.h),
      child: ListTile(
        leading: Icon(
          completed
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          color: completed ? Colors.green : Colors.grey,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight:
            completed ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}