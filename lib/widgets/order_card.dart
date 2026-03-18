import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OrderCard extends StatelessWidget {

  final Map<String, dynamic> order;

  const OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {

    List items = order["items"];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// COUNTER NUMBER
            Text(
              "Counter #${order["counterNumber"] ?? ""}",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),

            const SizedBox(height: 5),

            Text("Customer: ${order["customerName"] ?? ""}"),
            Text("Type: ${order["orderType"] ?? ""}"),

            const SizedBox(height: 8),

            /// ITEMS LIST
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {

                  var item = items[index];

                  return Text(
                      "${item["qty"]} x ${item["name"]} (${item["variant"]})");
                },
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Total ₹${order["totalAmount"]}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            /// STATUS BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                ElevatedButton(
                  onPressed: () {},
                  child: const Text("Accept"),
                ),

                ElevatedButton(
                  onPressed: () {},
                  child: const Text("Preparing"),
                ),

                ElevatedButton(
                  onPressed: () {},
                  child: const Text("Ready"),
                ),

              ],
            )
          ],
        ),
      ),
    );
  }
}