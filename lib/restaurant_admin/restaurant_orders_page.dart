import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../uttils/session_manager.dart';
import '../widgets/WebAudioStub.dart';
import '../services/localization_service.dart';

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
  
  final LocalizationService _localizationService = LocalizationService();

  // ── Pagination ──────────────────────────────────────────────────────────────
  static const int _pageSize = 10;
  int _currentPage = 1; // 1-based

  Set<String> _knownOrderIds = {};
  bool _isFirstSnapshot = true;
  void _playNewOrderSound() {
    if (!kIsWeb) return;
    try {
      final audio = AudioElement('assets/sounds/new_order.mp3');
      audio.play();
    } catch (e) {
      debugPrint('🔇 Could not play new-order sound: $e');
    }
  }

  /// Called on every Firestore snapshot. Detects truly-new orders and plays sound.
  void _handleNewOrders(List<QueryDocumentSnapshot> docs) {
    if (_isFirstSnapshot) {
      // Seed the known-set without playing sound on page open.
      _knownOrderIds = docs.map((d) => d.id).toSet();
      _isFirstSnapshot = false;
      return;
    }

    final incoming = docs.map((d) => d.id).toSet();
    final newIds = incoming.difference(_knownOrderIds);

    if (newIds.isNotEmpty) {
      _playNewOrderSound();
    }

    _knownOrderIds = incoming;
  }

  @override
  void initState() {
    super.initState();
    getPlayerId();
    _localizationService.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _localizationService.removeListener(_onLanguageChanged);
    _newOrdersSubscription?.cancel();
    super.dispose();
  }

  String _selectedFilter = 'All';
  String _selectedFilterKey = 'All'; // Store the English key for filtering

  List<QueryDocumentSnapshot> _filterOrders(
      List<QueryDocumentSnapshot> orders, String filterKey) {
    if (filterKey == 'All') return orders;

    return orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data["status"] ?? "pending").toString().toLowerCase();
      return status.toLowerCase() == filterKey.toLowerCase();
    }).toList();
  }

  /// Returns the slice of [orders] for the current page.
  List<QueryDocumentSnapshot> _paginateOrders(
      List<QueryDocumentSnapshot> orders) {
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, orders.length);
    if (start >= orders.length) return [];
    return orders.sublist(start, end);
  }

  int _totalPages(int totalItems) =>
      (totalItems / _pageSize).ceil().clamp(1, 9999);

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
    final loc = AppLocalizations.of(context);
    switch (currentStatus.toLowerCase()) {
      case 'pending':
        return loc.markAsPreparing;
      case 'preparing':
        return loc.markAsReady;
      case 'ready':
        return loc.markAsServed;
      case 'served':
        return loc.markAsCompleted;
      default:
        return loc.markAsPreparing;
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
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.ordersLogout,
          style: _p(18, FontWeight.w600, const Color(0xFF1C1C1C)),
        ),
        content: Text(
          loc.logoutConfirmation,
          style: _p(14, FontWeight.w400, const Color(0xFF555555)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              loc.cancel,
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
              loc.ordersLogout,
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

    return SafeArea(
        child: Scaffold(
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

              // ── Sound detection (web only, runs on every snapshot) ────────────
              // Deferred to post-frame to avoid setState-during-build.
              if (kIsWeb) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _handleNewOrders(allOrders);
                });
              }

              final filteredOrders = _filterOrders(allOrders, _selectedFilterKey);
              final counts = _buildStatusCounts(allOrders);

              // Clamp current page whenever filtered list changes
              final totalPages = _totalPages(filteredOrders.length);
              if (_currentPage > totalPages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _currentPage = 1);
                });
              }

              final pageOrders = _paginateOrders(filteredOrders);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDesktop, isTablet, counts),
                  const SizedBox(height: 20),
                  _buildFilterTabs(counts, isDesktop, isTablet),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _buildOrdersGrid(
                        pageOrders, width, isDesktop, isTablet),
                  ),
                  // Pagination bar
                  if (filteredOrders.isNotEmpty)
                    _buildPaginationBar(
                        filteredOrders.length, isDesktop, isTablet),
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
    final loc = AppLocalizations.of(context);
    
    int countStatus(String status) {
      return allOrders.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data["status"] ?? "").toString().toLowerCase() ==
            status.toLowerCase();
      }).length;
    }

    return {
      loc.all: allOrders.length,
      loc.pending: countStatus('pending'),
      loc.preparing: countStatus('preparing'),
      loc.ready: countStatus('ready'),
      loc.served: countStatus('served'),
      loc.completed: countStatus('completed'),
    };
  }

  Widget _buildHeader(
      bool isDesktop, bool isTablet, Map<String, int> counts) {
    final loc = AppLocalizations.of(context);
    final sidePadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 14.0);
    final totalToday = counts[loc.all] ?? 0;

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
                      loc.ordersTitle,
                      style: _p(
                        isDesktop ? 24 : (isTablet ? 38 : 30),
                        FontWeight.w200,
                        const Color(0xFF1C1C1C),
                      ),
                    ),
                    Text(
                      loc.todayOrders.replaceAll('{count}', totalToday.toString()),
                      style: _p(12, FontWeight.w400, const Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ),

              // Status summary pills — all screen sizes, always scrollable
          /*    Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusPill(
                          '${counts['Pending'] ?? 0}',
                          'Pending',
                          const Color(0xFFB45309),
                          const Color(0xFFFEF3C7)),
                      const SizedBox(width: 6),
                      _buildStatusPill(
                          '${counts['Preparing'] ?? 0}',
                          'Preparing',
                          const Color(0xFF1D4ED8),
                          const Color(0xFFDBEAFE)),
                      const SizedBox(width: 6),
                      _buildStatusPill(
                          '${counts['Ready'] ?? 0}',
                          'Ready',
                          const Color(0xFF065F46),
                          const Color(0xFFD1FAE5)),
                      const SizedBox(width: 6),
                      _buildStatusPill(
                          '${counts['Served'] ?? 0}',
                          'Served',
                          const Color(0xFF6B21A8),
                          const Color(0xFFF3E8FF)),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ),*/
              !kIsWeb
              ? GestureDetector(
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
              ) : const SizedBox.shrink(),
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
    final loc = AppLocalizations.of(context);
    final filterLabels = [
      {'key': 'All', 'label': loc.all},
      {'key': 'Pending', 'label': loc.pending},
      {'key': 'Preparing', 'label': loc.preparing},
      {'key': 'Ready', 'label': loc.ready},
      {'key': 'Served', 'label': loc.served},
      {'key': 'Completed', 'label': loc.completed}
    ];
    final sidePadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 14.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filterLabels.map((filterData) {
            final key = filterData['key']!;
            final label = filterData['label']!;
            final selected = _selectedFilterKey == key;
            final text = '$label (${counts[label] ?? 0})';
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() {
                  _selectedFilter = label;
                  _selectedFilterKey = key;
                  _currentPage = 1; // reset to first page on filter change
                }),
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

  // ── Pagination bar ──────────────────────────────────────────────────────────

  Widget _buildPaginationBar(
      int totalItems, bool isDesktop, bool isTablet) {
    final loc = AppLocalizations.of(context);
    final sidePadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 14.0);
    final totalPages = _totalPages(totalItems);
    final start = ((_currentPage - 1) * _pageSize + 1).clamp(1, totalItems);
    final end = (_currentPage * _pageSize).clamp(1, totalItems);

    return Container(
      padding: EdgeInsets.fromLTRB(sidePadding, 8, sidePadding, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loc.showingResults
                  .replaceAll('{start}', start.toString())
                  .replaceAll('{end}', end.toString())
                  .replaceAll('{total}', totalItems.toString()),
              style: _p(11, FontWeight.w400, const Color(0xFF9E9E9E)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _PageBtn(
            icon: Icons.chevron_left_rounded,
            enabled: _currentPage > 1,
            onTap: () => setState(() => _currentPage--),
          ),
          const SizedBox(width: 4),
          ..._buildPageNumbers(totalPages),
          const SizedBox(width: 4),
          _PageBtn(
            icon: Icons.chevron_right_rounded,
            enabled: _currentPage < totalPages,
            onTap: () => setState(() => _currentPage++),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    int start = (_currentPage - 2).clamp(1, totalPages);
    int end = (start + 4).clamp(1, totalPages);
    start = (end - 4).clamp(1, totalPages);

    return List.generate(end - start + 1, (i) {
      final page = start + i;
      final isSelected = page == _currentPage;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _currentPage = page),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFE8622A)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFE8622A)
                    : const Color(0xFFDDDDDD),
              ),
            ),
            child: Text(
              '$page',
              style: _p(
                12,
                isSelected ? FontWeight.w700 : FontWeight.w400,
                isSelected ? Colors.white : const Color(0xFF555555),
              ),
            ),
          ),
        ),
      );
    });
  }

  // ── Order grid ──────────────────────────────────────────────────────────────

  Widget _buildOrdersGrid(
      List<QueryDocumentSnapshot> pageOrders,
      double width,
      bool isDesktop,
      bool isTablet,
      ) {
    if (pageOrders.isEmpty) {
      final loc = AppLocalizations.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              loc.noOrders.replaceAll('{filter}', _selectedFilter.toLowerCase()),
              style: _p(16, FontWeight.w500, const Color(0xFF777777)),
            ),
          ],
        ),
      );
    }

    final sidePadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 14.0);
    final availableWidth = width - (sidePadding * 2);
    final desiredCardWidth =
    isDesktop ? 335.0 : (isTablet ? 320.0 : availableWidth);
    final crossAxisCount =
    (availableWidth / desiredCardWidth).floor().clamp(1, 4);

    // Single-column → simple ListView (no horizontal scroll possible)
    if (crossAxisCount == 1) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(sidePadding, 4, sidePadding, 24),
        itemCount: pageOrders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = pageOrders[index];
          final data = order.data() as Map<String, dynamic>;
          return _buildOrderCard(order, data);
        },
      );
    }

    // Multi-column desktop/tablet layout.
    // ── FIX: LayoutBuilder derives card widths from the actual rendered
    //    constraints so cards never overflow horizontally on web when the
    //    browser window is resized. Cards use Expanded instead of a fixed
    //    SizedBox so they fill available space correctly.
    return LayoutBuilder(builder: (context, constraints) {
      final usable = constraints.maxWidth - (sidePadding * 2);
      final gapTotal = (crossAxisCount - 1) * 14.0;
      // cardWidth is computed but not directly used — Expanded handles sizing.
      // It's kept here for reference / future use.
      // ignore: unused_local_variable
      final cardWidth = (usable - gapTotal) / crossAxisCount;

      final rows = <Widget>[];
      for (int i = 0; i < pageOrders.length; i += crossAxisCount) {
        final rowItems = pageOrders.skip(i).take(crossAxisCount).toList();
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowItems.asMap().entries.map((e) {
                final order = e.value;
                final data = order.data() as Map<String, dynamic>;
                return [
                  if (e.key > 0) const SizedBox(width: 14),
                  // Expanded fills the row proportionally — no fixed width
                  // that could cause overflow when the window narrows.
                  Expanded(child: _buildOrderCard(order, data)),
                ];
              }).expand((w) => w).toList(),
            ),
          ),
        );
      }

      return SingleChildScrollView(
        // primary: false prevents this vertical scroll view from competing
        // with Flutter Web's root scrollable, which was causing an unwanted
        // horizontal scrollbar to appear on the page.
        primary: false,
        padding: EdgeInsets.fromLTRB(sidePadding, 4, sidePadding, 24),
        child: Column(
          children: rows
              .expand((r) => [r, const SizedBox(height: 14)])
              .toList()
            ..removeLast(),
        ),
      );
    });
  }

  Widget _buildOrderCard(
      QueryDocumentSnapshot order, Map<String, dynamic> data) {
    final loc = AppLocalizations.of(context);
    final tableNumber = (data["tableNumber"] ?? "").toString();
    final status = (data["status"] ?? "pending").toString();
    final customerName = (data["customerName"] ?? "Guest").toString();
    final items = (data["items"] as List?) ?? [];
    final totalAmount = (data["totalAmount"] ?? 0) as num;
    final createdAt = data["createdAt"] as Timestamp?;
    final orderNumber =
    (data["orderNumber"] ?? "#${1000 + order.id.hashCode.abs() % 1000}")
        .toString();

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
          mainAxisSize: MainAxisSize.min,
          children: [
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
                            ? (tableNumber.isNotEmpty
                            ? '${loc.table} $tableNumber'
                            : loc.dineIn)
                            : loc.takeaway,
                        style:
                        _p(14, FontWeight.w700, const Color(0xFF232323)),
                      ),
                      if (isDineIn)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusPillBg(status),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _toTitle(status),
                          style: _p(10, FontWeight.w600,
                              _getStatusPillText(status)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              _getTimeAgo(createdAt),
                              style: _p(11, FontWeight.w400,
                                  const Color(0xFF8B8B8B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        orderNumber.startsWith('#')
                            ? orderNumber
                            : '#$orderNumber',
                        style:
                        _p(11, FontWeight.w400, const Color(0xFF8B8B8B)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5),

            if (!isDineIn)
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      customerName == 'Guest' ? loc.guest : customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                      _p(12, FontWeight.w400, const Color(0xFF757575)),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 10),

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
                        style: _p(
                            11.5, FontWeight.w500, const Color(0xFF2F2F2F)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${price.toStringAsFixed(2)}',
                      style: _p(
                          11.5, FontWeight.w500, const Color(0xFF505050)),
                    ),
                  ],
                ),
              );
            }),

            if (extraCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  loc.moreItems
                      .replaceAll('{count}', extraCount.toString())
                      .replaceAll('{plural}', extraCount > 1 ? 's' : ''),
                  style:
                  _p(11, FontWeight.w500, const Color(0xFF969696)),
                ),
              ),

            const SizedBox(height: 6),
            Container(height: 1, color: const Color(0xFFF0F0F0)),
            const SizedBox(height: 10),

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
                            .update(
                            {"status": _getNextStatusValue(status)});
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: btnBg,
                        foregroundColor: btnFg,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 12),
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

// ── Helper widget: a single prev/next arrow button ──────────────────────────

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled
                ? const Color(0xFFDDDDDD)
                : const Color(0xFFEEEEEE),
          ),
          color: Colors.white,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? const Color(0xFF444444)
              : const Color(0xFFCCCCCC),
        ),
      ),
    );
  }
}