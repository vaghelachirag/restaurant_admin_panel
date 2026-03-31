import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../uttils/session_manager.dart';
import 'dart:async';

class RestaurantOrdersPage extends StatefulWidget {
  final String restaurantId;

  const RestaurantOrdersPage({super.key, required this.restaurantId});

  @override
  State<RestaurantOrdersPage> createState() => _RestaurantOrdersPageState();
}

class _RestaurantOrdersPageState extends State<RestaurantOrdersPage> {

  String? _playerId;
  StreamSubscription<QuerySnapshot>? _newOrdersSubscription;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    getPlayerId();
  }

  @override
  void dispose() {
    _newOrdersSubscription?.cancel();
    super.dispose();
  }

  String _selectedFilter = 'All';

  List<QueryDocumentSnapshot> _filterOrders(
      List<QueryDocumentSnapshot> orders, String filter) {
    if (filter == 'All') return orders;

    return orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data["status"] ?? "pending").toString().toLowerCase();
      return status.toLowerCase() == filter.toLowerCase();
    }).toList();
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '0m ago';

    final now = DateTime.now();
    final orderTime = timestamp.toDate();
    final difference = now.difference(orderTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _getNextStatus(String currentStatus) {
    switch (currentStatus.toLowerCase()) {
      case 'pending':
        return 'Mark as Preparing';
      case 'preparing':
        return 'Mark as Ready';
      case 'ready':
        return 'Mark as Served';
      case 'served':
        return 'Mark as Completed';
      default:
        return 'Mark as Preparing';
    }
  }

  String _getNextStatusValue(String currentStatus) {
    switch (currentStatus.toLowerCase()) {
      case 'pending':
        return 'preparing';
      case 'preparing':
        return 'ready';
      case 'ready':
        return 'served';
      case 'served':
        return 'completed';
      default:
        return 'preparing';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final isTablet = width >= 768 && width < 1024;


    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("orders")
            .where("restaurantId", isEqualTo: widget.restaurantId)
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allOrders = snapshot.data!.docs;
          final filteredOrders = _filterOrders(allOrders, _selectedFilter);
          final counts = _buildStatusCounts(allOrders);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDesktop, isTablet),
              _buildFilterTabs(counts, isDesktop, isTablet),
              SizedBox(height: 20),
              Expanded(
                child: _buildOrdersGrid(filteredOrders, width, isDesktop, isTablet),
              ),
            ],
          );
        },
      ),
    );
  }

  TextStyle _p(double size, FontWeight weight, Color color) {
    return GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);
  }

  /// Fetches the OneSignal Player ID (push subscription ID) and saves it
  /// to Firestore under restaurants/{restaurantId}/onesignalPlayerId.
  /// Also listens for future subscription changes (e.g. re-subscribe).
  Future<void> getPlayerId() async {
    try {
      final String? existingId = OneSignal.User.pushSubscription.id;
      if (existingId != null && existingId.isNotEmpty) {
        debugPrint("✅ OneSignal Player ID (immediate): $existingId");
        setState(() => _playerId = existingId);
        await _savePlayerIdToFirestore(existingId);
      }

      OneSignal.User.pushSubscription.addObserver((state) async {
        final String? updatedId = state.current.id;
        if (updatedId != null && updatedId.isNotEmpty && updatedId != _playerId) {
          debugPrint("🔄 OneSignal Player ID (updated): $updatedId");
          setState(() => _playerId = updatedId);
          await _savePlayerIdToFirestore(updatedId);
        }
      });
    } catch (e, stackTrace) {
      debugPrint("❌ Error in getPlayerId: $e");
      debugPrint(stackTrace.toString());
    }
  }

  /// Persists the player ID to Firestore so the backend can send
  /// targeted push notifications to this device/restaurant.
  Future<void> _savePlayerIdToFirestore(String playerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .set(
        {'onesignalPlayerId': playerId},
        SetOptions(merge: true), // merge: true so other fields are untouched
      );
      debugPrint("✅ Player ID saved to Firestore: $playerId");
    } catch (e) {
      debugPrint("❌ Failed to save Player ID to Firestore: $e");
    }
  }

  Map<String, int> _buildStatusCounts(List<QueryDocumentSnapshot> allOrders) {
    int countStatus(String status) {
      return allOrders.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data["status"] ?? "").toString().toLowerCase() ==
            status.toLowerCase();
      }).length;
    }

    return {
      'All': allOrders.length,
      'Pending': countStatus('pending'),
      'Preparing': countStatus('preparing'),
      'Ready': countStatus('ready'),
      'Served': countStatus('served'),
      'Completed': countStatus('completed'),
    };
  }

  Widget _buildHeader(bool isDesktop, bool isTablet) {
    final sidePadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 14.0);
    return Container(
      padding: EdgeInsets.fromLTRB(
        sidePadding,
        isDesktop ? 20 : 14,
        sidePadding,
        8,
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Orders',
                style: _p(
                  isDesktop ? 24 : (isTablet ? 38 : 30),
                  FontWeight.w200,
                  const Color(0xFF1C1C1C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(
      Map<String, int> counts, bool isDesktop, bool isTablet) {
    final labels = ['All', 'Pending', 'Preparing', 'Ready', 'Served', 'Completed'];
    final sidePadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 14.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: labels.map((label) {
            final selected = _selectedFilter == label;
            final text = '$label (${counts[label] ?? 0})';
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => _selectedFilter = label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFE8622A) : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? const Color(0xFFE8622A) : const Color(0xFFDDDDDD),
                    ),
                    boxShadow: selected ? [
                      BoxShadow(
                        color: const Color(0xFFE8622A).withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ] : null,
                  ),
                  child: Text(
                    text,
                    style: _p(
                      13,
                      selected ? FontWeight.w600 : FontWeight.w500,
                      selected ? Colors.white : const Color(0xFF555555),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrdersGrid(
      List<QueryDocumentSnapshot> filteredOrders,
      double width,
      bool isDesktop,
      bool isTablet,
      ) {
    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No $_selectedFilter orders',
              style: _p(16, FontWeight.w500, const Color(0xFF777777)),
            ),
          ],
        ),
      );
    }

    final sidePadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 14.0);
    final availableWidth = width - (sidePadding * 2);
    final desiredCardWidth = isDesktop ? 335.0 : (isTablet ? 320.0 : availableWidth);
    final crossAxisCount = (availableWidth / desiredCardWidth).floor().clamp(1, 4);
    final cardWidth = (availableWidth - ((crossAxisCount - 1) * 14)) / crossAxisCount;
    final childAspectRatio = cardWidth / (isDesktop ? 290 : 300);

    return Padding(
      padding: EdgeInsets.fromLTRB(sidePadding, 4, sidePadding, 12),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          final data = order.data() as Map<String, dynamic>;
          return _buildOrderCard(order, data);
        },
      ),
    );
  }

  Widget _buildOrderCard(QueryDocumentSnapshot order, Map<String, dynamic> data) {
    final tableNumber = (data["tableNumber"] ?? "").toString();
    final status = (data["status"] ?? "pending").toString();
    final customerName = (data["customerName"] ?? "Guest").toString();
    final items = (data["items"] as List?) ?? [];
    final totalAmount = (data["totalAmount"] ?? 0) as num;
    final createdAt = data["createdAt"] as Timestamp?;
    final orderNumber =
    (data["orderNumber"] ?? "#${1000 + order.id.hashCode.abs() % 1000}")
        .toString();

    final bool isCompleted = status.toLowerCase() == 'completed';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Table + Status badge | Time
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: table name + badge
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        tableNumber.isNotEmpty ? 'Table $tableNumber' : 'Takeaway',
                        style: _p(15, FontWeight.w700, const Color(0xFF232323)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusPillBg(status),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _toTitle(status),
                          style: _p(10.5, FontWeight.w600, _getStatusPillText(status)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: time + order number stacked
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text(
                          _getTimeAgo(createdAt),
                          style: _p(12.5, FontWeight.w400, const Color(0xFF8B8B8B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      orderNumber.startsWith('#') ? orderNumber : '#$orderNumber',
                      style: _p(12.5, FontWeight.w400, const Color(0xFF8B8B8B)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Customer name with person icon
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  customerName,
                  style: _p(13, FontWeight.w400, const Color(0xFF757575)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Items list
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length > 3 ? 3 : items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final itemName = (item['name'] ?? '').toString();
                  final quantity = (item['qty'] ?? 1).toString();
                  final price = (item['price'] ?? 0) as num;
                  final variant = (item['variant'] ?? '').toString();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${quantity}x $itemName${variant.isNotEmpty ? '  ($variant)' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _p(12, FontWeight.w500, const Color(0xFF2F2F2F)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '₹${price.toStringAsFixed(2)}',
                          style: _p(12, FontWeight.w500, const Color(0xFF505050)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            if (items.length > 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '+${items.length - 3} more items',
                  style: _p(11.5, FontWeight.w500, const Color(0xFF969696)),
                ),
              ),

            Container(height: 1, color: const Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // Bottom row: total | Details [+ action button]
            Row(
              children: [
                Text(
                  '₹ ${totalAmount.toStringAsFixed(2)}',
                  style: _p(18, FontWeight.w700, Colors.red),
                ),
                const Spacer(),
                SizedBox(
                  height: 34,
                  child: OutlinedButton(
                    onPressed: () {
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(74, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      side: const BorderSide(color: Color(0xFFE2E2E2)),
                      backgroundColor: const Color(0xFFFFFFFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Details',
                      style: _p(10, FontWeight.w600, const Color(0xFF252525)),
                    ),
                  ),
                ),
                if (!isCompleted) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: () {
                        final nextStatus = _getNextStatusValue(status);
                        FirebaseFirestore.instance
                            .collection("orders")
                            .doc(order.id)
                            .update({"status": nextStatus});
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(126, 34),
                        elevation: 0,
                        backgroundColor: const Color(0xFF070B2D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _getNextStatus(status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _p(10, FontWeight.w600, Colors.white),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _toTitle(String value) {
    if (value.isEmpty) return value;
    final lower = value.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  Color _getStatusPillBg(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFEF3C7);   // amber yellow
      case 'preparing':
        return const Color(0xFFDBEAFE);   // sky blue
      case 'ready':
        return const Color(0xFFD1FAE5);   // mint green
      case 'served':
        return const Color(0xFFF3E8FF);   // soft purple
      case 'completed':
        return const Color(0xFFF3F4F6);   // light grey
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getStatusPillText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFB45309);   // dark amber
      case 'preparing':
        return const Color(0xFF1D4ED8);   // dark blue
      case 'ready':
        return const Color(0xFF065F46);   // dark green
      case 'served':
        return const Color(0xFF6B21A8);   // dark purple
      case 'completed':
        return const Color(0xFF374151);   // dark slate
      default:
        return const Color(0xFF374151);
    }
  }
}