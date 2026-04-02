import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import '../uttils/session_manager.dart';

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

  /// Shows a confirmation dialog and logs the user out
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: _p(18, FontWeight.w600, const Color(0xFF1C1C1C)),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: _p(14, FontWeight.w400, const Color(0xFF555555)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: _p(14, FontWeight.w500, const Color(0xFF555555)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF070B2D),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Logout',
              style: _p(14, FontWeight.w600, Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
       await SessionManager.logout(); // clear stored session
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final isTablet = width >= 768 && width < 1024;

    return SafeArea(child: Scaffold(
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
              _buildHeader(isDesktop, isTablet, counts),
              const SizedBox(height: 20),
              _buildFilterTabs(counts, isDesktop, isTablet),
              const SizedBox(height: 10),
              Expanded(
                child: _buildOrdersGrid(
                    filteredOrders, width, isDesktop, isTablet),
              ),
            ],
          );
        },
      ),
    ));
  }

  TextStyle _p(double size, FontWeight weight, Color color) {
    return GoogleFonts.poppins(
        fontSize: size, fontWeight: weight, color: color);
  }

  /// Fetches the OneSignal Player ID (push subscription ID) and saves it
  /// to Firestore under restaurants/{restaurantId}/onesignalPlayerId.
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
        if (updatedId != null &&
            updatedId.isNotEmpty &&
            updatedId != _playerId) {
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

  Future<void> _savePlayerIdToFirestore(String playerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .set(
        {'onesignalPlayerId': playerId},
        SetOptions(merge: true),
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

  Widget _buildHeader(
      bool isDesktop, bool isTablet, Map<String, int> counts) {
    final sidePadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 14.0);
    final today = DateTime.now();
    final totalToday = counts['All'] ?? 0;

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orders',
                      style: _p(
                        isDesktop ? 24 : (isTablet ? 38 : 30),
                        FontWeight.w200,
                        const Color(0xFF1C1C1C),
                      ),
                    ),
                    Text(
                      'Today — $totalToday orders',
                      style: _p(12, FontWeight.w400, const Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ),

              // Status summary pills — mobile/tablet only, scrollable so they never overflow
              if (!isDesktop)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusPill('${counts['Pending'] ?? 0}', 'Pending',
                          const Color(0xFFB45309), const Color(0xFFFEF3C7)),
                      const SizedBox(width: 6),
                      _buildStatusPill('${counts['Preparing'] ?? 0}', 'Preparing',
                          const Color(0xFF1D4ED8), const Color(0xFFDBEAFE)),
                      const SizedBox(width: 6),
                      _buildStatusPill('${counts['Ready'] ?? 0}', 'Ready',
                          const Color(0xFF065F46), const Color(0xFFD1FAE5)),
                      const SizedBox(width: 6),
                      _buildStatusPill('${counts['Served'] ?? 0}', 'Served',
                          const Color(0xFF6B21A8), const Color(0xFFF3E8FF)),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),

              // Logout button — mobile/tablet only (hidden on desktop/web)
              if (!isDesktop)
                GestureDetector(
                  onTap: _handleLogout,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: Color(0xFF444444),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Small coloured pill used in the header to show per-status count
  Widget _buildStatusPill(
      String count, String label, Color textColor, Color bgColor) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(count, style: _p(11, FontWeight.w700, textColor)),
        ),
        const SizedBox(height: 2),
        Text(label, style: _p(8.5, FontWeight.w400, const Color(0xFF9E9E9E))),
      ],
    );
  }

  Widget _buildFilterTabs(
      Map<String, int> counts, bool isDesktop, bool isTablet) {
    final labels = [
      'All',
      'Pending',
      'Preparing',
      'Ready',
      'Served',
      'Completed'
    ];
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
                    color: selected
                        ? const Color(0xFFE8622A)
                        : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFE8622A)
                          : const Color(0xFFDDDDDD),
                    ),
                    boxShadow: selected
                        ? [
                      BoxShadow(
                        color:
                        const Color(0xFFE8622A).withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                        : null,
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
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
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

    // Use ListView for single-column, custom multi-column layout for wider screens
    if (crossAxisCount == 1) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(sidePadding, 4, sidePadding, 24),
        itemCount: filteredOrders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          final data = order.data() as Map<String, dynamic>;
          return _buildOrderCard(order, data);
        },
      );
    }

    // Multi-column: build rows manually so each card sizes to its content
    final cardWidth = (availableWidth - ((crossAxisCount - 1) * 14)) / crossAxisCount;
    final rows = <Widget>[];
    for (int i = 0; i < filteredOrders.length; i += crossAxisCount) {
      final rowItems = filteredOrders.skip(i).take(crossAxisCount).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowItems.asMap().entries.map((e) {
              final order = e.value;
              final data = order.data() as Map<String, dynamic>;
              return [
                if (e.key > 0) const SizedBox(width: 14),
                SizedBox(width: cardWidth, child: _buildOrderCard(order, data)),
              ];
            }).expand((w) => w).toList(),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(sidePadding, 4, sidePadding, 24),
      child: Column(
        children: rows
            .expand((r) => [r, const SizedBox(height: 14)])
            .toList()
          ..removeLast(),
      ),
    );
  }

  Widget _buildOrderCard(
      QueryDocumentSnapshot order, Map<String, dynamic> data) {
    final tableNumber = (data["tableNumber"] ?? "").toString();
    final status = (data["status"] ?? "pending").toString();
    final customerName = (data["customerName"] ?? "Guest").toString();
    final items = (data["items"] as List?) ?? [];
    final totalAmount = (data["totalAmount"] ?? 0) as num;
    final createdAt = data["createdAt"] as Timestamp?;
    final orderNumber =
    (data["orderNumber"] ?? "#${1000 + order.id.hashCode.abs() % 1000}")
        .toString();

    // Determine order type
    final orderType = (data["orderType"] ?? "").toString().toLowerCase();
    final isDineIn = orderType == "dine in" ||
        orderType == "dine-in" ||
        orderType == "dinein" ||
        (orderType.isEmpty && tableNumber.isNotEmpty);

    final bool isCompleted = status.toLowerCase() == 'completed';
    final Color btnBg = _getStatusPillText(status);
    final Color btnFg = Colors.white;

    final displayedItems = items.take(3).toList();
    final extraCount = items.length - 3;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,   // ← shrink-wrap to content
          children: [
            // Row 1: Order type label + chips | time + order#
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        isDineIn
                            ? (tableNumber.isNotEmpty ? 'Table $tableNumber' : 'Dine In')
                            : 'Takeaway',
                        style: _p(14, FontWeight.w700, const Color(0xFF232323)),
                      ),
                      if (isDineIn)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Dine In',
                            style: _p(10, FontWeight.w600, const Color(0xFF2E7D32)),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusPillBg(status),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _toTitle(status),
                          style: _p(10, FontWeight.w600, _getStatusPillText(status)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text(
                          _getTimeAgo(createdAt),
                          style: _p(11, FontWeight.w400, const Color(0xFF8B8B8B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      orderNumber.startsWith('#') ? orderNumber : '#$orderNumber',
                      style: _p(11, FontWeight.w400, const Color(0xFF8B8B8B)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 5),

            // Takeaway only: show customer/person name
            if (!isDineIn)
              Row(
                children: [
                  Icon(Icons.person_outline, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _p(12, FontWeight.w400, const Color(0xFF757575)),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 10),

            // Items — no Expanded, natural height
            ...displayedItems.map((item) {
              final itemName = (item['name'] ?? '').toString();
              final quantity = (item['qty'] ?? 1).toString();
              final price = (item['price'] ?? 0) as num;
              final variant = (item['variant'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${quantity}x $itemName${variant.isNotEmpty ? ' ($variant)' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _p(11.5, FontWeight.w500, const Color(0xFF2F2F2F)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${price.toStringAsFixed(2)}',
                      style: _p(11.5, FontWeight.w500, const Color(0xFF505050)),
                    ),
                  ],
                ),
              );
            }),

            if (extraCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '+$extraCount more item${extraCount > 1 ? 's' : ''}',
                  style: _p(11, FontWeight.w500, const Color(0xFF969696)),
                ),
              ),

            const SizedBox(height: 6),
            Container(height: 1, color: const Color(0xFFF0F0F0)),
            const SizedBox(height: 10),

            // Bottom row: total | action button (no Details)
            Row(
              children: [
                Text(
                  '₹ ${totalAmount.toStringAsFixed(2)}',
                  style: _p(16, FontWeight.w700, Colors.red),
                ),
                const Spacer(),
                if (!isCompleted)
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection("orders")
                            .doc(order.id)
                            .update({"status": _getNextStatusValue(status)});
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: btnBg,
                        foregroundColor: btnFg,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _getNextStatus(status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _p(10, FontWeight.w600, btnFg),
                      ),
                    ),
                  ),
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
        return const Color(0xFFFEF3C7);
      case 'preparing':
        return const Color(0xFFDBEAFE);
      case 'ready':
        return const Color(0xFFD1FAE5);
      case 'served':
        return const Color(0xFFF3E8FF);
      case 'completed':
        return const Color(0xFFF3F4F6);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getStatusPillText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFB45309);
      case 'preparing':
        return const Color(0xFF1D4ED8);
      case 'ready':
        return const Color(0xFF065F46);
      case 'served':
        return const Color(0xFF6B21A8);
      case 'completed':
        return const Color(0xFF374151);
      default:
        return const Color(0xFF374151);
    }
  }
}