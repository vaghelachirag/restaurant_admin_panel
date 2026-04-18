import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // ── Token refresh state ─────────────────────────────────────────────────────
  bool _tokenReady = false;
  String? _tokenError;

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
    _localizationService.addListener(_onLanguageChanged);
    // ── FIX: Force-refresh the ID token so custom claims (restaurantId, role)
    //    are present before any Firestore read/write is attempted.
    _refreshTokenThenInit();
  }

  /// Force-refreshes the Firebase ID token to ensure custom claims are loaded,
  /// then kicks off the OneSignal player-ID fetch.
  Future<void> _refreshTokenThenInit() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Not signed in — let the stream surface the permission error naturally.
        if (mounted) setState(() => _tokenReady = true);
        return;
      }

      // forceRefresh: true guarantees we get the latest custom claims from the
      // server (e.g. restaurantId, role) that were set after login.
      final tokenResult = await user.getIdTokenResult(true);
      debugPrint('✅ Token claims: ${tokenResult.claims}');

      // Optional: surface a warning if the restaurantId claim is missing.
      final claimedRestaurantId = tokenResult.claims?['restaurantId'];
      if (claimedRestaurantId == null) {
        debugPrint(
          '⚠️ Token is missing "restaurantId" claim. '
              'Firestore rules will deny reads/writes. '
              'Ensure the custom token is minted with restaurantId.',
        );
      } else if (claimedRestaurantId != widget.restaurantId) {
        debugPrint(
          '⚠️ Token restaurantId "$claimedRestaurantId" does not match '
              'widget.restaurantId "${widget.restaurantId}".',
        );
      }

      if (mounted) setState(() => _tokenReady = true);
      await getPlayerId();
    } catch (e, st) {
      debugPrint('❌ Token refresh failed: $e\n$st');
      if (mounted) {
        setState(() {
          _tokenReady = true; // still show the UI; stream will show the error
          _tokenError = e.toString();
        });
      }
    }
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
  String _selectedFilterKey = 'All';

  List<QueryDocumentSnapshot> _filterOrders(
      List<QueryDocumentSnapshot> orders, String filterKey) {
    if (filterKey == 'All') return orders;

    return orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data["status"] ?? "pending").toString().toLowerCase();
      return status == filterKey.toLowerCase();
    }).toList();
  }

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
      await SessionManager.logout();
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

    // ── Wait for token refresh before starting the Firestore stream ────────────
    if (!_tokenReady) {
      return SafeArea(
        child: Scaffold(
          backgroundColor: Colors.white,
          body: _buildSkeletonLoading(isDesktop, isTablet),
        ),
      );
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('restaurants')
              .doc(widget.restaurantId)
              .collection('orders')
              .orderBy("createdAt", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final err = snapshot.error.toString();
              final isPermission = err.toLowerCase().contains('permission') ||
                  err.toLowerCase().contains('denied');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPermission ? Icons.lock_outline : Icons.error_outline,
                        size: 48,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isPermission
                            ? 'Permission denied.\nYour account token may be missing the restaurantId claim.\nPlease log out and log in again.'
                            : 'Error: $err',
                        textAlign: TextAlign.center,
                        style: _p(14, FontWeight.w500, const Color(0xFF555555)),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Log out & retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF070B2D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return _buildSkeletonLoading(isDesktop, isTablet);
            }

            final allOrders = snapshot.data!.docs;

            if (kIsWeb) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleNewOrders(allOrders);
              });
            }

            final filteredOrders =
            _filterOrders(allOrders, _selectedFilterKey);
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
                if (filteredOrders.isNotEmpty)
                  _buildPaginationBar(
                      filteredOrders.length, isDesktop, isTablet),
              ],
            );
          },
        ),
      ),
    );
  }

  TextStyle _p(double size, FontWeight weight, Color color) {
    return GoogleFonts.poppins(
        fontSize: size, fontWeight: weight, color: color);
  }

  /// Fetches the OneSignal Player ID and saves it to Firestore.
  /// Called only after the token has been refreshed.
  Future<void> getPlayerId() async {
    try {
      final String? existingId = OneSignal.User.pushSubscription.id;
      if (existingId != null && existingId.isNotEmpty) {
        debugPrint("✅ OneSignal Player ID (immediate): $existingId");
        if (mounted) setState(() => _playerId = existingId);
        await _savePlayerIdToFirestore(existingId);
      }

      OneSignal.User.pushSubscription.addObserver((state) async {
        final String? updatedId = state.current.id;
        if (updatedId != null &&
            updatedId.isNotEmpty &&
            updatedId != _playerId) {
          debugPrint("🔄 OneSignal Player ID (updated): $updatedId");
          if (mounted) setState(() => _playerId = updatedId);
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

  // ── Skeleton loading (same pattern as MenuCardSkeleton in menu_page) ────────
  Widget _buildSkeletonLoading(bool isDesktop, bool isTablet) {
    final sidePadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 14.0);
    final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header skeleton
        Container(
          padding: EdgeInsets.fromLTRB(sidePadding, isDesktop ? 20 : 14, sidePadding, 8),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(width: 180, height: 28, radius: 6),
              const SizedBox(height: 8),
              _SkeletonBox(width: 120, height: 14, radius: 4),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Filter tabs skeleton
        Padding(
          padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 10),
          child: Row(
            children: List.generate(5, (i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SkeletonBox(width: 80, height: 32, radius: 999),
            )),
          ),
        ),
        const SizedBox(height: 8),
        // Cards skeleton grid
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(sidePadding, 4, sidePadding, 24),
            child: crossAxisCount == 1
                ? ListView.separated(
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const _OrderCardSkeleton(),
            )
                : Column(
              children: List.generate(2, (row) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(crossAxisCount, (col) => [
                    if (col > 0) const SizedBox(width: 14),
                    const Expanded(child: _OrderCardSkeleton()),
                  ]).expand((w) => w).toList(),
                ),
              )),
            ),
          ),
        ),
      ],
    );
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
                      loc.todayOrders
                          .replaceAll('{count}', totalToday.toString()),
                      style:
                      _p(12, FontWeight.w400, const Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
        Text(label,
            style: _p(8.5, FontWeight.w400, const Color(0xFF9E9E9E))),
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
      {'key': 'Completed', 'label': loc.completed},
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
                  _currentPage = 1;
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
                        color: const Color(0xFFE8622A).withOpacity(0.2),
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
    final start =
    ((_currentPage - 1) * _pageSize + 1).clamp(1, totalItems);
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
              loc.noOrders
                  .replaceAll('{filter}', _selectedFilter.toLowerCase()),
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

    return LayoutBuilder(builder: (context, constraints) {
      final usable = constraints.maxWidth - (sidePadding * 2);
      final gapTotal = (crossAxisCount - 1) * 14.0;
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
                  Expanded(child: _buildOrderCard(order, data)),
                ];
              }).expand((w) => w).toList(),
            ),
          ),
        );
      }

      return SingleChildScrollView(
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
    final tableId = (data["tableId"] ?? "").toString();
    final tableName = (data["tableName"] ?? "").toString();
    final displayTable = tableName.isNotEmpty
        ? tableName
        : tableId.isNotEmpty
        ? tableId
        : tableNumber;

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
        (orderType.isEmpty && displayTable.isNotEmpty);

    final bool isCompleted = status.toLowerCase() == 'completed';
    final Color btnBg = _getStatusPillText(status);
    const Color btnFg = Colors.white;

    final displayedItems = items.take(3).toList();
    final extraCount = items.length - 3;

    Future<void> updateStatus(String nextStatus) async {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('orders')
          .doc(order.id)
          .update({"status": nextStatus});
    }

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
                            ? (displayTable.isNotEmpty
                            ? '${loc.table} $displayTable'
                            : loc.dineIn)
                            : loc.takeaway,
                        style:
                        _p(14, FontWeight.w700, const Color(0xFF232323)),
                      ),
                      if (isDineIn && displayTable.isNotEmpty)
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
                        '${quantity}x $itemName'
                            '${variant.isNotEmpty ? ' ($variant)' : ''}',
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
                child: GestureDetector(
                  onTap: () => _showFullOrderDialog(context, items, loc),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.moreItems
                            .replaceAll('{count}', extraCount.toString())
                            .replaceAll(
                            '{plural}', extraCount > 1 ? 's' : ''),
                        style: _p(
                            11, FontWeight.w600, const Color(0xFFE8622A)),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.expand_more_rounded,
                          size: 14, color: Color(0xFFE8622A)),
                    ],
                  ),
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
                if (isCompleted)
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showBillDialog(context, order.id, data),
                      icon: const Icon(Icons.receipt_long_rounded, size: 14),
                      label: Text(
                        'Generate Bill',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _p(10, FontWeight.w600, Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF065F46),
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () =>
                          updateStatus(_getNextStatusValue(status)),
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

  // ── Bill dialog ─────────────────────────────────────────────────────────────

  /// Shows a printable bill for a completed order.
  /// All GST / packaging values are read from the order document itself
  /// (they were persisted at order-creation time from the restaurant settings).
  void _showBillDialog(
      BuildContext context, String orderId, Map<String, dynamic> data) {
    // ── Order fields ──────────────────────────────────────────────────────────
    final items = (data['items'] as List?) ?? [];
    final customerName = (data['customerName'] ?? 'Guest').toString();
    final tableName = (data['tableName'] ?? '').toString();
    final tableId = (data['tableId'] ?? '').toString();
    final displayTable = tableName.isNotEmpty ? tableName : tableId;
    final orderType = (data['orderType'] ?? 'Dine In').toString();
    final tokenNumber = (data['tokenNumber'] ?? '').toString();
    final orderNumber =
    (data['orderNumber'] ?? '#${1000 + orderId.hashCode.abs() % 1000}')
        .toString();
    final createdAt = data['createdAt'] as Timestamp?;

    // ── Pricing fields (saved in order doc from cart_page) ────────────────────
    final subtotal = (data['subtotal'] ?? 0) as num;
    final bool enableGst = data['enableGst'] == true;
    final double gstPct =
        double.tryParse(data['gstPercentage']?.toString() ?? '0') ?? 0;
    final double sgstPct =
        double.tryParse(data['sgstPercentage']?.toString() ?? '0') ?? 0;
    final double gstAmt =
        double.tryParse(data['gstAmount']?.toString() ?? '0') ?? 0;
    final double sgstAmt =
        double.tryParse(data['sgstAmount']?.toString() ?? '0') ?? 0;
    final bool enablePackaging = data['enablePackagingCharge'] == true;
    final double packagingCharge =
        (data['packagingCharge'] as num?)?.toDouble() ?? 0;
    final totalAmount = (data['totalAmount'] ?? 0) as num;

    // ── Date formatting ───────────────────────────────────────────────────────
    String formattedDate = '';
    if (createdAt != null) {
      final dt = createdAt.toDate();
      formattedDate =
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF065F46),
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bill / Invoice',
                          style: _p(17, FontWeight.w700, Colors.white),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: const Icon(Icons.close,
                            color: Colors.white70, size: 20),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Bill Body ─────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order meta
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    orderNumber.startsWith('#')
                                        ? orderNumber
                                        : '#$orderNumber',
                                    style: _p(13, FontWeight.w700,
                                        const Color(0xFF1C1C1C)),
                                  ),
                                  if (tokenNumber.isNotEmpty)
                                    Text(
                                      'Token: $tokenNumber',
                                      style: _p(11, FontWeight.w400,
                                          const Color(0xFF6B7280)),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formattedDate,
                                  style: _p(11, FontWeight.w400,
                                      const Color(0xFF6B7280)),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: orderType
                                        .toLowerCase()
                                        .contains('dine')
                                        ? const Color(0xFFDBEAFE)
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    orderType,
                                    style: _p(
                                      10,
                                      FontWeight.w600,
                                      orderType
                                          .toLowerCase()
                                          .contains('dine')
                                          ? const Color(0xFF1D4ED8)
                                          : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Table / Customer
                        const SizedBox(height: 8),
                        if (displayTable.isNotEmpty)
                          _BillInfoRow(
                            label: 'Table',
                            value: displayTable,
                          ),
                        if (customerName.isNotEmpty &&
                            customerName != 'Guest')
                          _BillInfoRow(
                            label: 'Customer',
                            value: customerName,
                          ),

                        const SizedBox(height: 12),
                        Container(
                            height: 1, color: const Color(0xFFF0F0F0)),
                        const SizedBox(height: 10),

                        // Column header
                        Row(
                          children: [
                            Expanded(
                              child: Text('Item',
                                  style: _p(11, FontWeight.w600,
                                      const Color(0xFF9E9E9E))),
                            ),
                            Text('Qty',
                                style: _p(11, FontWeight.w600,
                                    const Color(0xFF9E9E9E))),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 72,
                              child: Text('Amount',
                                  textAlign: TextAlign.right,
                                  style: _p(11, FontWeight.w600,
                                      const Color(0xFF9E9E9E))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Item rows
                        ...items.map((item) {
                          final name = (item['name'] ?? '').toString();
                          final variant =
                          (item['variant'] ?? '').toString();
                          final qty = (item['qty'] ?? 1) as num;
                          final price = (item['price'] ?? 0) as num;
                          final lineTotal = qty * price;
                          return Padding(
                            padding:
                            const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: _p(12, FontWeight.w600,
                                              const Color(0xFF232323))),
                                      if (variant.isNotEmpty)
                                        Text(variant,
                                            style: _p(
                                                10,
                                                FontWeight.w400,
                                                const Color(0xFF9E9E9E))),
                                      Text(
                                          '₹${price.toStringAsFixed(2)} each',
                                          style: _p(
                                              10,
                                              FontWeight.w400,
                                              const Color(0xFF9E9E9E))),
                                    ],
                                  ),
                                ),
                                Text('×$qty',
                                    style: _p(12, FontWeight.w500,
                                        const Color(0xFF555555))),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    '₹${lineTotal.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: _p(12, FontWeight.w600,
                                        const Color(0xFF2F2F2F)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 8),
                        Container(
                            height: 1, color: const Color(0xFFF0F0F0)),
                        const SizedBox(height: 10),

                        // Subtotal
                        _BillAmountRow(
                          label: 'Subtotal',
                          value: '₹${subtotal.toStringAsFixed(2)}',
                        ),

                        // GST rows — shown only when enableGst is true in the order doc
                        if (enableGst) ...[
                          const SizedBox(height: 4),
                          _BillAmountRow(
                            label:
                            'CGST (${gstPct.toStringAsFixed(1)}%)',
                            value: '₹${gstAmt.toStringAsFixed(2)}',
                            dimmed: true,
                          ),
                          const SizedBox(height: 4),
                          _BillAmountRow(
                            label:
                            'SGST (${sgstPct.toStringAsFixed(1)}%)',
                            value: '₹${sgstAmt.toStringAsFixed(2)}',
                            dimmed: true,
                          ),
                        ],

                        // Packaging charge — shown only when enabled in the order doc
                        if (enablePackaging) ...[
                          const SizedBox(height: 4),
                          _BillAmountRow(
                            label: 'Packaging Charge',
                            value:
                            '₹${packagingCharge.toStringAsFixed(2)}',
                            dimmed: true,
                          ),
                        ],

                        const SizedBox(height: 10),
                        Container(
                            height: 1.5,
                            color: const Color(0xFF1C1C1C)),
                        const SizedBox(height: 10),

                        // Grand Total
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Grand Total',
                                style: _p(15, FontWeight.w700,
                                    const Color(0xFF1C1C1C)),
                              ),
                            ),
                            Text(
                              '₹${totalAmount.toStringAsFixed(2)}',
                              style: _p(16, FontWeight.w800,
                                  const Color(0xFF065F46)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            'Thank you for dining with us!',
                            style: _p(11, FontWeight.w400,
                                const Color(0xFF9E9E9E)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Footer actions ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, size: 16),
                          label: Text('Close',
                              style: _p(13, FontWeight.w500,
                                  const Color(0xFF374151))),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(
                                color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: integrate printing package (e.g. flutter_print / pdf)
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Print feature coming soon!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon:
                          const Icon(Icons.print_rounded, size: 16),
                          label: Text('Print Bill',
                              style: _p(
                                  13, FontWeight.w600, Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF065F46),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullOrderDialog(
      BuildContext context, List<dynamic> items, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      loc.ordersTitle,
                      style:
                      _p(16, FontWeight.w700, const Color(0xFF1C1C1C)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E8),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${items.length} items',
                        style: _p(
                            12, FontWeight.w600, const Color(0xFFE8622A)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF5F5F5)),
                  itemBuilder: (_, i) {
                    final item = items[i] as Map<String, dynamic>;
                    final name = (item['name'] ?? '').toString();
                    final qty = (item['qty'] ?? 1).toString();
                    final price = (item['price'] ?? 0) as num;
                    final variant = (item['variant'] ?? '').toString();
                    return Padding(
                      padding:
                      const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: _p(11, FontWeight.w600,
                                  const Color(0xFF888888)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${qty}x $name',
                                  style: _p(13, FontWeight.w600,
                                      const Color(0xFF2F2F2F)),
                                ),
                                if (variant.isNotEmpty)
                                  Text(
                                    variant,
                                    style: _p(11, FontWeight.w400,
                                        const Color(0xFF9E9E9E)),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${price.toStringAsFixed(2)}',
                            style: _p(13, FontWeight.w600,
                                const Color(0xFF505050)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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

// ── Skeleton widgets (mirrors MenuCardSkeleton pattern) ─────────────────────

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: order id + status pill
          Row(
            children: [
              _SkeletonBox(width: 90, height: 13, radius: 4),
              const Spacer(),
              _SkeletonBox(width: 64, height: 22, radius: 999),
            ],
          ),
          const SizedBox(height: 14),
          // Table + time row
          Row(
            children: [
              _SkeletonBox(width: 48, height: 48, radius: 12),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 100, height: 14, radius: 4),
                  const SizedBox(height: 6),
                  _SkeletonBox(width: 70, height: 12, radius: 4),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Items lines
          _SkeletonBox(width: double.infinity, height: 12, radius: 4),
          const SizedBox(height: 8),
          _SkeletonBox(width: 140, height: 12, radius: 4),
          const SizedBox(height: 16),
          // Action button
          _SkeletonBox(width: double.infinity, height: 38, radius: 10),
        ],
      ),
    );
  }
}

// ── Bill helper widgets ──────────────────────────────────────────────────────

/// Key → value info row (Table, Customer) inside the bill dialog.
class _BillInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _BillInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6B7280),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1C1C),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Amount row (Subtotal, GST, Grand Total) inside the bill dialog.
class _BillAmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool dimmed;

  const _BillAmountRow({
    required this.label,
    required this.value,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: dimmed ? 12 : 13,
              fontWeight: dimmed ? FontWeight.w400 : FontWeight.w500,
              color: dimmed
                  ? const Color(0xFF6B7280)
                  : const Color(0xFF555555),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: dimmed ? 12 : 13,
            fontWeight: dimmed ? FontWeight.w400 : FontWeight.w600,
            color: dimmed
                ? const Color(0xFF6B7280)
                : const Color(0xFF2F2F2F),
          ),
        ),
      ],
    );
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