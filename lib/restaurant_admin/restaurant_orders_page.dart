import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RestaurantOrdersPage extends StatefulWidget {
  final String restaurantId;

  const RestaurantOrdersPage({super.key, required this.restaurantId});

  @override
  State<RestaurantOrdersPage> createState() => _RestaurantOrdersPageState();
}

class _RestaurantOrdersPageState extends State<RestaurantOrdersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade400, Colors.red.shade600],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        "Live Orders",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),

                    /// ACTIVE COUNT
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("orders")
                          .where("restaurantId", isEqualTo: widget.restaurantId)
                          .where("status",
                          whereIn: ["pending", "preparing", "ready"])
                          .snapshots(),
                      builder: (context, snapshot) {
                        int count =
                        snapshot.hasData ? snapshot.data!.docs.length : 0;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "$count Active",
                            style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),

              /// BODY
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("orders")
                      .where("restaurantId", isEqualTo: widget.restaurantId)
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {

                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final allOrders = snapshot.data!.docs;

                    final activeOrders = allOrders.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status =
                      (data["status"] ?? "pending").toString();
                      return status != "served";
                    }).toList();

                    /// SEARCH FILTER
                    List<QueryDocumentSnapshot> filteredOrders = activeOrders;
                    if (_searchQuery.isNotEmpty) {
                      final query = _searchQuery.toLowerCase();
                      filteredOrders = activeOrders.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data["customerName"] ?? "").toString().toLowerCase();
                        final mobile = (data["mobile"] ?? "").toString().toLowerCase();
                        final tokenNumber = (data["tokenNumber"] ?? "").toString().toLowerCase();
                        return name.contains(query) ||
                            mobile.contains(query) ||
                            tokenNumber.contains(query);
                      }).toList();
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Search by token, name or number",
                              prefixIcon: const Icon(Icons.search),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: filteredOrders.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No Active Orders",
                                    style: TextStyle(fontSize: 18),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  itemCount: filteredOrders.length,
                                  itemBuilder: (context, index) {
                              final order = filteredOrders[index];
                              final data =
                                  order.data() as Map<String, dynamic>;

                              final items = data["items"] ?? [];
                              final status =
                                  (data["status"] ?? "pending").toString();
                              final customerName =
                                  (data["customerName"] ?? "Guest")
                                      .toString();

                              final mobile =
                                  (data["mobile"] ?? "").toString();
                              final orderType =
                                  (data["orderType"] ?? "").toString();
                              final tableNumber =
                                  (data["tableNumber"] ?? (orderType == "Dine In" ? "1" : "")).toString();
                              final specialInstruction =
                                  (data["specialInstruction"] ?? "")
                                      .toString();

                              final totalAmount =
                                  (data["totalAmount"] ?? 0) as int;

                              /// TOKEN NUMBER
                              final tokenNumber =
                                  data["tokenNumber"] ?? 0;

                              final statusOptions = [
                                "pending",
                                "preparing",
                                "ready",
                                "served"
                              ];

                              return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      /// HEADER
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              /// TOKEN BADGE
                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 6),
                                                decoration:
                                                    BoxDecoration(
                                                  color: Colors.black,
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(8),
                                                ),
                                                child: Text(
                                                  "Token $tokenNumber",
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight
                                                              .bold),
                                                ),
                                              ),

                                              const Spacer(),

                                              /// STATUS
                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                decoration:
                                                    BoxDecoration(
                                                  color: _statusColor(
                                                          status)
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(8),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  style: TextStyle(
                                                      color:
                                                          _statusColor(
                                                              status),
                                                      fontWeight:
                                                          FontWeight
                                                              .bold),
                                                ),
                                              ),
                                            ],
                                          ),

                                          /// TABLE INFO SECTION
                                          if (orderType == "Dine In" && tableNumber.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 12,
                                                  vertical: 8),
                                              decoration:
                                                  BoxDecoration(
                                                color: Colors.blue
                                                    .shade50,
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(10),
                                                border: Border.all(
                                                  color: Colors.blue.shade200,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                      Icons.table_restaurant,
                                                      size: 20,
                                                      color: Colors.blue.shade700),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    "Table $tableNumber",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight
                                                              .bold,
                                                      fontSize: 16,
                                                      color: Colors.blue
                                                          .shade700,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: Colors.blue
                                                          .shade100,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(6),
                                                    ),
                                                    child: Text(
                                                      orderType,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                        color: Colors.blue
                                                            .shade800,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),

                                      const SizedBox(height: 10),

                                      /// CUSTOMER INFO (only for non-Dine In)
                                      if (orderType != "Dine In") ...[
                                        Text(
                                          customerName,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone,
                                                size: 16),
                                            const SizedBox(width: 5),
                                            Text(mobile)
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      ExpansionTile(
                                        tilePadding:
                                            EdgeInsets.zero,
                                        childrenPadding:
                                            const EdgeInsets.only(
                                                top: 8),
                                        title: const Text(
                                          "Show order details",
                                          style: TextStyle(
                                            fontWeight:
                                                FontWeight.w500,
                                          ),
                                        ),
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              /// ITEM LIST
                                              ...List.generate(
                                                  items.length,
                                                  (i) {
                                                final item =
                                                    items[i];
                                                final variant =
                                                    (item['variant'] ?? '')
                                                        .toString();

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets
                                                          .only(
                                                          bottom:
                                                              6),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child:
                                                            Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              "${item['qty']}x ${item['name']}",
                                                            ),
                                                            if (variant
                                                                .isNotEmpty)
                                                              Padding(
                                                                padding: const EdgeInsets.only(top: 2),
                                                                child: Text(
                                                                  variant,
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: Colors.grey.shade600,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      Text(
                                                        "₹${item['price']}",
                                                        style:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),

                                              const SizedBox(
                                                  height: 10),

                                              /// SPECIAL INSTRUCTION
                                              if (specialInstruction
                                                  .isNotEmpty) ...[
                                                Container(
                                                  width: double
                                                      .infinity,
                                                  padding:
                                                      const EdgeInsets
                                                          .all(8),
                                                  decoration:
                                                      BoxDecoration(
                                                    color: Colors
                                                        .orange
                                                        .shade50,
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                                8),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Icon(
                                                        Icons.notes,
                                                        size: 16,
                                                        color: Colors
                                                            .orange
                                                            .shade700,
                                                      ),
                                                      const SizedBox(
                                                          width:
                                                              6),
                                                      Expanded(
                                                        child: Text(
                                                          specialInstruction,
                                                          style:
                                                              const TextStyle(
                                                            fontSize:
                                                                12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(
                                                    height: 10),
                                              ],

                                              /// FOOTER: TOTAL + STATUS
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  /// TOTAL AMOUNT
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 16, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        const Text(
                                                          "Total:",
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 14,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                        Text(
                                                          "₹$totalAmount",
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 18,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  /// STATUS DROPDOWN
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(0.05),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: DropdownButtonFormField<
                                                        String>(
                                                      value: statusOptions.contains(
                                                              status)
                                                          ? status
                                                          : statusOptions
                                                              .first,
                                                      decoration: InputDecoration(
                                                        filled: true,
                                                        fillColor: Colors.grey.shade50,
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          borderSide: BorderSide(
                                                            color: Colors.grey.shade300,
                                                            width: 1,
                                                          ),
                                                        ),
                                                        enabledBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          borderSide: BorderSide(
                                                            color: Colors.grey.shade300,
                                                            width: 1,
                                                          ),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          borderSide: BorderSide(
                                                            color: _statusColor(status),
                                                            width: 2,
                                                          ),
                                                        ),
                                                        contentPadding: const EdgeInsets.symmetric(
                                                            horizontal: 16, vertical: 12),
                                                        prefixIcon: Icon(
                                                          Icons.sync_alt,
                                                          color: _statusColor(status),
                                                          size: 20,
                                                        ),
                                                      ),
                                                      style: TextStyle(
                                                        color: _statusColor(status),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                      dropdownColor: Colors.white,
                                                      icon: Icon(
                                                        Icons.keyboard_arrow_down,
                                                        color: _statusColor(status),
                                                      ),
                                                      items: statusOptions
                                                          .map(
                                                            (s) =>
                                                                DropdownMenuItem(
                                                              value: s,
                                                              child: Container(
                                                                padding: const EdgeInsets.symmetric(
                                                                    horizontal: 8, vertical: 4),
                                                                decoration: BoxDecoration(
                                                                  color: _statusColor(s)
                                                                      .withOpacity(0.1),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    Container(
                                                                      width: 8,
                                                                      height: 8,
                                                                      decoration: BoxDecoration(
                                                                        color: _statusColor(s),
                                                                        shape: BoxShape.circle,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 8),
                                                                    Text(
                                                                      s.toUpperCase(),
                                                                      style: TextStyle(
                                                                        color: _statusColor(s),
                                                                        fontWeight: FontWeight.bold,
                                                                        fontSize: 13,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          )
                                                          .toList(),
                                                      onChanged:
                                                          (value) {
                                                        if (value ==
                                                            null) {
                                                          return;
                                                        }

                                                        FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                "orders")
                                                            .doc(order
                                                                .id)
                                                            .update({
                                                          "status":
                                                              value
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "preparing":
        return Colors.orange;
      case "ready":
        return Colors.green;
      case "served":
        return Colors.blue;
      default:
        return Colors.red;
    }
  }
}