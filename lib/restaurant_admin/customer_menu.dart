import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/restaurant_admin/restrurant_offers_screen.dart';
import 'package:restaurant_admin_panel/restaurant_admin/track_order.dart';
import 'package:restaurant_admin_panel/data/models/cart_item.dart';
import 'package:restaurant_admin_panel/widgets/professional_loader.dart';
import 'package:restaurant_admin_panel/widgets/loading_card.dart';
import 'package:restaurant_admin_panel/widgets/keep_alive_wrapper.dart';
import 'package:restaurant_admin_panel/restaurant_admin/tabs/home_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_page.dart';
import 'cart_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'manager/call_waiter.dart';
import 'manager/waiter_assistance.dart';

// ─────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────
class _C {
  static const bg            = Color(0xFFF8F5F0);
  static const accent        = Color(0xFFE8420E);
  static const accentLight   = Color(0xFFFFF0EB);
  static const textPrimary   = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFF9CA3AF);
  static const vegGreen      = Color(0xFF16A34A);
  static const nonVegRed     = Color(0xFFDC2626);
  static const chipBg        = Color(0xFFF3F4F6);
  static const divider       = Color(0xFFE5E7EB);
  static const shadow        = Color(0x0D000000);
  static const shadowMd      = Color(0x18000000);
}

// ─────────────────────────────────────────────
// UTILITIES
// ─────────────────────────────────────────────
Color hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  if (hex.length == 6) hex = "FF$hex";
  return Color(int.parse(hex, radix: 16));
}

class _SessionStorage {
  static String? _memoryCache;
  static const _key = 'restaurant_customer_session_id';

  static Future<String> getOrCreate() async {
    if (_memoryCache != null) return _memoryCache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored != null && stored.isNotEmpty) {
        _memoryCache = stored;
        return stored;
      }
    } catch (_) {}
    final newId = _generateSessionId();
    _memoryCache = newId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, newId);
    } catch (_) {}
    return newId;
  }

  static String _generateSessionId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String h(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${h(bytes[0])}${h(bytes[1])}${h(bytes[2])}${h(bytes[3])}'
        '-${h(bytes[4])}${h(bytes[5])}'
        '-${h(bytes[6])}${h(bytes[7])}'
        '-${h(bytes[8])}${h(bytes[9])}'
        '-${h(bytes[10])}${h(bytes[11])}${h(bytes[12])}'
        '${h(bytes[13])}${h(bytes[14])}${h(bytes[15])}';
  }
}

// ─────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────
class CustomerMenuPage extends StatefulWidget {
  final String restaurantId;
  const CustomerMenuPage({super.key, required this.restaurantId});

  @override
  State<CustomerMenuPage> createState() => _CustomerMenuPageState();
}

class _CustomerMenuPageState extends State<CustomerMenuPage>
    with AutomaticKeepAliveClientMixin {

  // ── ValueNotifier-based state — NO full-page setState on variant/view change
  final ValueNotifier<String?>           _selectedCategoryIdNotifier = ValueNotifier(null);
  final ValueNotifier<Map<String, int>>  _variantIndexNotifier       = ValueNotifier({});
  final ValueNotifier<bool>              _listViewNotifier           = ValueNotifier(true);
  final ValueNotifier<List<CartItem>>    _cartNotifier               = ValueNotifier([]);
  final ValueNotifier<String?>           _lastAddedItemId            = ValueNotifier(null);
  final ValueNotifier<int>               _cartBounce                 = ValueNotifier(0);
  final ValueNotifier<String?>           _tableIdNotifier            = ValueNotifier(null);
  final ValueNotifier<String?>           _tableNameNotifier          = ValueNotifier(null);

  // Getters for convenience
  String? get _selectedCategoryId   => _selectedCategoryIdNotifier.value;
  set _selectedCategoryId(String? v) => _selectedCategoryIdNotifier.value = v;
  bool    get _unifiedCategoryListView => _listViewNotifier.value;
  List<CartItem> get cart              => _cartNotifier.value;
  String? get _preselectedTableId      => _tableIdNotifier.value;
  String? get _preselectedTableName    => _tableNameNotifier.value;

  // Plain state (changes here DO need a rebuild of a higher-level widget)
  final Set<String> _collapsedCategoryIds = {};
  int _selectedTabIndex = 0;
  late PageController _pageController;

  String openingTime = "09:00 AM";
  String closingTime = "06:00 PM";

  String  _restaurantName    = "";
  String  _restaurantTagline = "";
  String? _restaurantLogo;

  bool _isFirebaseReady      = false;
  bool _hasRestaurantIdError = false;

  String? _sessionId;
  String? _activeOrderId;
  bool    _orderLookupInProgress = false;

  static const Color _primaryColor = Color(0xFFE8420E);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.restaurantId.isEmpty) {
      _hasRestaurantIdError = true;
    } else {
      _isFirebaseReady = true;
    }
    _readTableFromUrl();
    _ensureSignedIn();
    _initSession();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cartNotifier.dispose();
    _lastAddedItemId.dispose();
    _cartBounce.dispose();
    _selectedCategoryIdNotifier.dispose();
    _variantIndexNotifier.dispose();
    _listViewNotifier.dispose();
    _tableIdNotifier.dispose();
    _tableNameNotifier.dispose();
    super.dispose();
  }

  // ── Auth / session ────────────────────────────────────────────────────────
  Future<void> _ensureSignedIn() async {
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        debugPrint('Signed in anonymously: ${FirebaseAuth.instance.currentUser?.uid}');
      } catch (e) {
        debugPrint('Anonymous sign-in failed: $e');
      }
    }
  }

  void _readTableFromUrl() {
    if (!kIsWeb) return;
    try {
      final fragment = Uri.base.fragment;
      if (!fragment.contains('?')) return;
      final queryString = fragment.split('?').last;
      final params = Uri.splitQueryString(queryString);
      final tableId = params['table'] ?? '';
      if (tableId.isEmpty) return;
      _tableIdNotifier.value = tableId;
      FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('tables')
          .doc(tableId)
          .get()
          .then((doc) {
        if (mounted) {
          final name = doc.exists
              ? ((doc.data()?['name'] as String?) ?? tableId)
              : tableId;
          _tableNameNotifier.value = name;
        }
      }).catchError((_) {
        if (mounted) _tableNameNotifier.value = tableId;
      });
    } catch (_) {}
  }

  Future<void> _initSession() async {
    final id = await _SessionStorage.getOrCreate();
    if (mounted) setState(() => _sessionId = id);
  }

  Future<String?> _getOrCreateActiveOrder() async {
    final tableId   = _preselectedTableId;
    final sessionId = _sessionId;
    if (tableId == null || tableId.isEmpty) return null;
    if (sessionId == null) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final uid = user.uid;
    if (mounted) setState(() => _orderLookupInProgress = true);
    try {
      final ordersRef = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('orders');

      final existing = await ordersRef
          .where('tableId',  isEqualTo: tableId)
          .where('userId',   isEqualTo: uid)
          .where('status',   whereNotIn: ['completed', 'cancelled'])
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final orderId = existing.docs.first.id;
        await ordersRef.doc(orderId).update({
          'sessionIds': FieldValue.arrayUnion([sessionId]),
          'updatedAt':  FieldValue.serverTimestamp(),
        });
        if (mounted) setState(() => _activeOrderId = orderId);
        return orderId;
      }

      final newRef     = ordersRef.doc();
      final newOrderId = newRef.id;
      await newRef.set({
        'orderId':      newOrderId,
        'restaurantId': widget.restaurantId,
        'tableId':      tableId,
        'tableName':    _preselectedTableName ?? tableId,
        'userId':       uid,
        'sessionIds':   [sessionId],
        'status':       'pending',
        'items':        [],
        'totalAmount':  0,
        'createdAt':    FieldValue.serverTimestamp(),
        'updatedAt':    FieldValue.serverTimestamp(),
      });
      debugPrint('Created new order: $newOrderId');
      if (mounted) setState(() => _activeOrderId = newOrderId);
      return newOrderId;
    } catch (e, st) {
      debugPrint('getOrCreateActiveOrder error: $e\n$st');
      return null;
    } finally {
      if (mounted) setState(() => _orderLookupInProgress = false);
    }
  }

  // ── Cart helpers ──────────────────────────────────────────────────────────
  int getTotalCartQuantity() => cart.fold(0, (s, i) => s + i.qty);

  int getItemQuantity(String itemId, String variant) {
    int qty = 0;
    for (var item in cart) {
      if (item.itemId == itemId && item.variant == variant) qty += item.qty;
    }
    return qty;
  }

  List<dynamic> _safeList(dynamic raw) {
    if (raw == null) return [];
    try { return List<dynamic>.from(raw as List); } catch (_) { return []; }
  }

  // Reads from _variantIndexNotifier — no setState
  int _safeIndex(String itemId, List<dynamic> variants) {
    if (variants.isEmpty) return 0;
    final stored  = _variantIndexNotifier.value[itemId] ?? 0;
    final clamped = stored.clamp(0, variants.length - 1);
    if (stored != clamped) {
      final updated = Map<String, int>.from(_variantIndexNotifier.value);
      updated[itemId] = clamped;
      _variantIndexNotifier.value = updated;
    }
    return clamped;
  }

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int)    return val;
    if (val is double) return val.toInt();
    if (val is num)    return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  bool _isRestaurantOpen() {
    final now = DateTime.now();
    final cur = now.hour * 60 + now.minute;
    int parseTime(String t) {
      try {
        t = t.trim();
        if (!t.contains(' ')) {
          final hm = t.split(':');
          return int.parse(hm[0]) * 60 + int.parse(hm[1]);
        }
        final parts = t.split(' '); final hm = parts[0].split(':');
        int h = int.parse(hm[0]);
        if (parts[1] == 'PM' && h != 12) h += 12;
        if (parts[1] == 'AM' && h == 12) h = 0;
        return h * 60 + int.parse(hm[1]);
      } catch (_) { return 0; }
    }
    final open  = parseTime(openingTime);
    final close = parseTime(closingTime);
    if (close < open) return cur >= open || cur <= close;
    return cur >= open && cur <= close;
  }

  String _formatDisplayTime(String t) {
    try {
      t = t.trim(); int h, m;
      if (!t.contains(' ')) {
        final hm = t.split(':'); h = int.parse(hm[0]); m = int.parse(hm[1]);
      } else {
        final parts = t.split(' '); final hm = parts[0].split(':');
        h = int.parse(hm[0]); m = int.parse(hm[1]);
        if (parts[1] == 'PM' && h != 12) h += 12;
        if (parts[1] == 'AM' && h == 12) h = 0;
      }
      final period = h >= 12 ? 'PM' : 'AM';
      final dh = h % 12 == 0 ? 12 : h % 12;
      return '$dh:${m.toString().padLeft(2, '0')} $period';
    } catch (_) { return t; }
  }

  void _updateItemQuantity(String itemId, String variant, int change,
      {String? itemName, int? price, String? image}) {
    final updated = List<CartItem>.from(_cartNotifier.value);
    CartItem? existing; int idx = -1;
    for (int i = 0; i < updated.length; i++) {
      if (updated[i].itemId == itemId && updated[i].variant == variant) {
        existing = updated[i]; idx = i; break;
      }
    }
    if (existing != null) {
      final newQty = existing.qty + change;
      if (newQty <= 0) {
        updated.removeAt(idx);
      } else {
        updated[idx] = CartItem(
          itemId: existing.itemId, name: existing.name,
          variant: existing.variant, price: existing.price,
          qty: newQty.clamp(1, 99), image: existing.image,
        );
      }
    } else if (change > 0 && itemName != null && price != null) {
      updated.add(CartItem(
          itemId: itemId, name: itemName, variant: variant,
          price: price, qty: change, image: image));
      _lastAddedItemId.value = itemId;
    }
    _cartNotifier.value = updated;
    _cartBounce.value   = _cartBounce.value + 1;
  }

  Future<void> _openCartPage(List<CartItem> cartItems) async {
    if (cartItems.isEmpty) return;
    if (mounted && _preselectedTableId != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Text('Preparing your order...',
              style: GoogleFonts.poppins(fontSize: kIsWeb ? 13 : 13.sp)),
        ]),
        duration: const Duration(seconds: 3),
        backgroundColor: _primaryColor,
      ));
    }
    final orderId = await _getOrCreateActiveOrder();
    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (!mounted) return;
    final mutableCart = List<CartItem>.from(cartItems);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CartPage(
        cart:                 mutableCart,
        restaurantId:         widget.restaurantId,
        preselectedTableId:   _preselectedTableId,
        preselectedTableName: _preselectedTableName,
        sessionId:            _sessionId,
        activeOrderId:        orderId,
      ),
    )).then((_) {
      if (mounted) {
        _cartNotifier.value = List.from(mutableCart);
        _cartBounce.value   = _cartBounce.value + 1;
        _activeOrderId      = null;
      }
    });
  }

  // ── Image helpers ─────────────────────────────────────────────────────────
  Widget _imagePlaceholder() => Container(
    color: _C.chipBg,
    child: Center(child: Icon(Icons.fastfood_rounded,
        color: Colors.grey[300], size: kIsWeb ? 36 : 36.sp)),
  );

  Widget _networkImage(String url, {BoxFit fit = BoxFit.cover}) =>
      Image.network(url, fit: fit,
        loadingBuilder: (_, child, prog) {
          if (prog == null) return child;
          return Container(color: const Color(0xFFEEEEEE),
              child: Center(child: SizedBox(
                width: kIsWeb ? 20 : 20.sp, height: kIsWeb ? 20 : 20.sp,
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: Colors.grey[400],
                    value: prog.expectedTotalBytes != null
                        ? prog.cumulativeBytesLoaded / prog.expectedTotalBytes!
                        : null),
              )));
        },
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );

  Widget _logoFallback() {
    final initials = _restaurantName.isNotEmpty
        ? _restaurantName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    return Container(
      color: Colors.white.withOpacity(0.15),
      child: Center(child: Text(initials,
          style: GoogleFonts.poppins(fontSize: kIsWeb ? 14 : 14.sp,
              fontWeight: FontWeight.bold, color: Colors.white))),
    );
  }

  Widget _vegBadge(bool isVeg) => Container(
    width: kIsWeb ? 18 : 18.sp, height: kIsWeb ? 18 : 18.sp,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kIsWeb ? 3 : 3.sp),
      border: Border.all(color: isVeg ? _C.vegGreen : _C.nonVegRed, width: 1.5),
    ),
    child: Center(child: Container(
      width: kIsWeb ? 8 : 8.sp, height: kIsWeb ? 8 : 8.sp,
      decoration: BoxDecoration(
          color: isVeg ? _C.vegGreen : _C.nonVegRed, shape: BoxShape.circle),
    )),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // VARIANT SELECTOR — inline chips, zero page rebuild on selection
  // Uses _variantIndexNotifier so only the chip row rebuilds, not the page.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildVariantDropdown({
    required String itemId,
    required List<dynamic> variants,
    required int selectedIndex,
  }) {
    if (variants.isEmpty) return const SizedBox.shrink();

    // Single variant with no name → hide
    if (variants.length == 1) {
      final name = (variants[0] as Map<String, dynamic>)['name'] as String? ?? '';
      if (name.isEmpty) return const SizedBox.shrink();
      // Single named variant: show as static pill
      return _staticVariantPill(name);
    }

    // Multiple variants: inline animated chip row
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: _variantIndexNotifier,
      builder: (_, map, __) {
        final current = (map[itemId] ?? selectedIndex).clamp(0, variants.length - 1);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: kIsWeb ? 34 : 32.h),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: variants.length,
            itemBuilder: (_, i) {
              final v     = variants[i] as Map<String, dynamic>;
              final name  = (v['name'] ?? '') as String;
              final isSel = i == current;

              return GestureDetector(
                onTap: () {
                  // ← Pure ValueNotifier update — zero setState on parent
                  final updated = Map<String, int>.from(_variantIndexNotifier.value);
                  updated[itemId] = i;
                  _variantIndexNotifier.value = updated;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  margin: EdgeInsets.only(right: kIsWeb ? 6 : 5.w),
                  padding: EdgeInsets.symmetric(
                      horizontal: kIsWeb ? 10 : 8.w,
                      vertical:   kIsWeb ? 5 : 4.h),
                  decoration: BoxDecoration(
                    color: isSel ? _C.accent : Colors.white,
                    borderRadius: BorderRadius.circular(kIsWeb ? 20 : 16.sp),
                    border: Border.all(
                      color: isSel ? _C.accent : _C.divider,
                      width: isSel ? 1.5 : 1,
                    ),
                    boxShadow: isSel
                        ? [BoxShadow(
                        color: _C.accent.withOpacity(0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3))]
                        : [BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: isSel
                          ? Padding(
                        key: const ValueKey('check'),
                        padding: EdgeInsets.only(right: kIsWeb ? 4 : 3.w),
                        child: Icon(Icons.check_rounded,
                            size: kIsWeb ? 11 : 10.sp,
                            color: Colors.white),
                      )
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 11 : 10.sp,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? Colors.white : _C.textSecondary),
                    ),
                  ]),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _staticVariantPill(String name) => Container(
    padding: EdgeInsets.symmetric(
        horizontal: kIsWeb ? 10 : 10.w, vertical: kIsWeb ? 5 : 5.h),
    decoration: BoxDecoration(
      color: _C.chipBg,
      borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20.sp),
      border: Border.all(color: _C.divider),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: kIsWeb ? 6 : 6.sp, height: kIsWeb ? 6 : 6.sp,
        decoration: const BoxDecoration(color: _C.textMuted, shape: BoxShape.circle),
      ),
      SizedBox(width: kIsWeb ? 5 : 5.w),
      Text(name, style: GoogleFonts.poppins(
          fontSize: kIsWeb ? 11 : 11.sp,
          color: _C.textSecondary,
          fontWeight: FontWeight.w500)),
    ]),
  );

  // ── Add / counter ─────────────────────────────────────────────────────────
  Widget _buildAddOrCounterWidget(BuildContext context,
      QueryDocumentSnapshot item, String itemId, String variant, int price) {
    final isOpen = _isRestaurantOpen();
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: _cartNotifier,
      builder: (context, cartItems, _) {
        int qty = 0;
        for (final c in cartItems) {
          if (c.itemId == itemId && c.variant == variant) { qty = c.qty; break; }
        }
        if (!isOpen && qty == 0) {
          return GestureDetector(
            onTap: () => _showRestaurantClosedPopup(context),
            child: Container(
              height: kIsWeb ? 34 : 34.h,
              padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 14 : 14.w),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_clock, size: kIsWeb ? 13 : 13.sp, color: Colors.grey[400]),
                SizedBox(width: kIsWeb ? 5 : 5.w),
                Text("CLOSED", style: GoogleFonts.poppins(
                    fontSize: kIsWeb ? 11 : 11.sp, color: Colors.grey[500],
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ]),
            ),
          );
        }
        if (qty > 0) {
          return _CounterWidget(
            qty: qty, primaryColor: _primaryColor,
            onDecrement: () => _updateItemQuantity(itemId, variant, -1,
                itemName: item['name'], price: price, image: item['image']),
            onIncrement: () => _updateItemQuantity(itemId, variant, 1,
                itemName: item['name'], price: price, image: item['image']),
          );
        }
        return _AddButtonWidget(
          itemId: itemId, primaryColor: _primaryColor,
          lastAddedNotifier: _lastAddedItemId,
          onTap: () => _updateItemQuantity(itemId, variant, 1,
              itemName: item['name'], price: price, image: item['image']),
          isOpen: true,
        );
      },
    );
  }

  void _showRestaurantClosedPopup(BuildContext context) {
    showDialog(context: context, barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp)),
        title: Row(children: [
          Container(padding: EdgeInsets.all(kIsWeb ? 8 : 8.sp),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp)),
              child: Icon(Icons.access_time,
                  color: Colors.red, size: kIsWeb ? 24 : 24.sp)),
          SizedBox(width: kIsWeb ? 12 : 12.sp),
          Text("Restaurant Closed", style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 18 : 18.sp,
              fontWeight: FontWeight.w600, color: Colors.black87)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Sorry, we're currently closed.",
                  style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 14 : 14.sp, color: Colors.black54)),
              SizedBox(height: kIsWeb ? 16 : 16.sp),
              Container(padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp)),
                  child: Row(children: [
                    Icon(Icons.schedule,
                        color: Colors.grey[600], size: kIsWeb ? 20 : 20.sp),
                    SizedBox(width: kIsWeb ? 8 : 8.sp),
                    Text("Hours: ${_formatDisplayTime(openingTime)} – ${_formatDisplayTime(closingTime)}",
                        style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 13 : 13.sp,
                            fontWeight: FontWeight.w500, color: Colors.black87)),
                  ])),
            ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text("Got it", style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 14 : 14.sp,
                  fontWeight: FontWeight.w500, color: _primaryColor))),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MENU CARDS
  // Price/variant driven by _variantIndexNotifier via ValueListenableBuilder
  // so only the card rebuilds on variant change, not the whole list.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMenuCard({
    required BuildContext context,
    required QueryDocumentSnapshot item,
    required String itemId,
    required List variants,
    required Color primaryColor,
  }) {
    final data = item.data() as Map<String, dynamic>;
    final bool isVeg  = data['isVeg'] == true;
    final String? desc = data['description'] as String?;
    final v = _safeList(data['variants']);

    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: _variantIndexNotifier,
      builder: (_, map, __) {
        final si       = (map[itemId] ?? 0).clamp(0, v.isEmpty ? 0 : v.length - 1);
        final sv       = v.isNotEmpty ? v[si] : null;
        final int safePrice = _toInt(sv?['price'] ?? data['price']);
        final String varName = (sv?['name'] ?? '') as String;

        return Container(
          margin: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 5 : 5.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
            boxShadow: [BoxShadow(color: _C.shadow, blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: EdgeInsets.all(kIsWeb ? 12 : 12.w),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Image
              Stack(clipBehavior: Clip.none, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                  child: SizedBox(
                    width: kIsWeb ? 88 : 82.w, height: kIsWeb ? 88 : 82.h,
                    child: item['image'] != null
                        ? _networkImage(item['image'] as String)
                        : _imagePlaceholder(),
                  ),
                ),
                Positioned(top: -4, left: -4, child: _vegBadge(isVeg)),
              ]),
              SizedBox(width: kIsWeb ? 12 : 10.w),
              // Content — vertical stack: name → desc → variants → price+ADD
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item['name'] ?? "Item",
                        style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 13 : 13.sp,
                            fontWeight: FontWeight.w700,
                            color: _C.textPrimary, height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (desc != null && desc.isNotEmpty) ...[
                      SizedBox(height: kIsWeb ? 2 : 2.h),
                      Text(desc,
                          style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 10 : 10.sp,
                              color: _C.textMuted, height: 1.3),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    // ── Variant chips — full width, scrollable ──────────────
                    if (v.isNotEmpty) ...[
                      SizedBox(height: kIsWeb ? 7 : 6.h),
                      _buildVariantDropdown(
                          itemId: itemId, variants: v, selectedIndex: si),
                    ],
                    SizedBox(height: kIsWeb ? 8 : 7.h),
                    // ── Price (left) + ADD/counter (right) ──────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero).animate(anim),
                                child: child,
                              )),
                          child: Text("₹$safePrice",
                              key: ValueKey(safePrice),
                              style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 15 : 15.sp,
                                  fontWeight: FontWeight.w800,
                                  color: _C.accent)),
                        ),
                        _buildAddOrCounterWidget(
                            context, item, itemId, varName, safePrice),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildMenuGridCard({
    required BuildContext context,
    required QueryDocumentSnapshot item,
    required String itemId,
    required List variants,
    required Color primaryColor,
  }) {
    final data = item.data() as Map<String, dynamic>;
    final bool isVeg  = data['isVeg'] == true;
    final String? desc = data['description'] as String?;
    final v = _safeList(data['variants']);

    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: _variantIndexNotifier,
      builder: (_, map, __) {
        final si       = (map[itemId] ?? 0).clamp(0, v.isEmpty ? 0 : v.length - 1);
        final sv       = v.isNotEmpty ? v[si] : null;
        final int safePrice = _toInt(sv?['price'] ?? data['price']);
        final String varName = (sv?['name'] ?? '') as String;

        return Container(
          margin: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 5 : 5.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
            boxShadow: [BoxShadow(color: _C.shadow, blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft:    Radius.circular(kIsWeb ? 16 : 16.sp),
                bottomLeft: Radius.circular(kIsWeb ? 16 : 16.sp),
              ),
              child: SizedBox(
                width: kIsWeb ? 110 : 100.w, height: kIsWeb ? 110 : 100.h,
                child: Stack(fit: StackFit.expand, children: [
                  item['image'] != null
                      ? _networkImage(item['image'] as String)
                      : _imagePlaceholder(),
                  Positioned(top: 8, left: 8, child: _vegBadge(isVeg)),
                ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: kIsWeb ? 14 : 14.w, vertical: kIsWeb ? 12 : 12.h),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item['name'] ?? "Item",
                          style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 14 : 14.sp,
                              fontWeight: FontWeight.w700,
                              color: _C.textPrimary, height: 1.3),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (desc != null && desc.isNotEmpty) ...[
                        SizedBox(height: kIsWeb ? 2 : 2.h),
                        Text(desc, style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 11 : 11.sp, color: _C.textMuted, height: 1.3),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                      SizedBox(height: kIsWeb ? 8 : 8.h),
                      _buildVariantDropdown(
                          itemId: itemId, variants: v, selectedIndex: si),
                      SizedBox(height: kIsWeb ? 8 : 8.h),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                            begin: const Offset(0, 0.3),
                                            end: Offset.zero).animate(anim),
                                        child: child,
                                      )),
                              child: Text("₹$safePrice",
                                  key: ValueKey(safePrice),
                                  style: GoogleFonts.poppins(
                                      fontSize: kIsWeb ? 15 : 15.sp,
                                      fontWeight: FontWeight.w800,
                                      color: _C.accent)),
                            ),
                            _buildAddOrCounterWidget(
                                context, item, itemId, varName, safePrice),
                          ]),
                    ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB BUILDERS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHomeTab() => HomeTab(
    restaurantId:                widget.restaurantId,
    unifiedCategoryListView:     _unifiedCategoryListView,
    selectedCategoryId:          _selectedCategoryId,
    collapsedCategoryIds:        _collapsedCategoryIds,
    onCategorySelected:          (id) => setState(() => _selectedCategoryId = id),
    onCategoryToggle: (id) => setState(() {
      if (_collapsedCategoryIds.contains(id)) {
        _collapsedCategoryIds.remove(id);
      } else {
        _collapsedCategoryIds.add(id);
      }
    }),
    selectedVariantIndexByItemId: _variantIndexNotifier.value,
    updateItemQuantity:           _updateItemQuantity,
    getItemQuantity:              getItemQuantity,
    primaryColor:                 _primaryColor,
  );

  Widget _buildOrdersTab()  => TrackOrderPage(restaurantId: widget.restaurantId);
  Widget _buildOffersTab()  => SpecialOffersScreen();
  Widget _buildAccountTab() => AccountPage(restaurantId: widget.restaurantId);
  Widget _buildAssistTab()  => CallWaiterPage(
    restaurantId:       widget.restaurantId,
    tableIdNotifier:   _tableIdNotifier,
    tableNameNotifier: _tableNameNotifier,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_hasRestaurantIdError || widget.restaurantId.isEmpty) {
      return Scaffold(
        backgroundColor: _C.bg,
        body: Center(child: Padding(padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.link_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Invalid Menu Link', style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 20 : 20.sp, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Please scan the QR code again or ask the restaurant for a valid link.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 14 : 14.sp, color: Colors.grey)),
            ]))),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        final exit = await showDialog<bool>(context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp)),
              title: const Text("Exit Menu?"),
              content: const Text("Are you sure you want to close the menu?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel")),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Close", style: TextStyle(color: Colors.white))),
              ],
            ));
        return exit ?? false;
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .doc(widget.restaurantId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const FullScreenLoader(
              type: LoaderType.foodLoader,
              message: 'Loading restaurant menu...',
              primaryColor: Color(0xFF7C3AED),
              secondaryColor: Color(0xFFEC4899),
            );
          }
          if (snap.hasError) {
            return Scaffold(appBar: AppBar(title: const Text('Error')),
                body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading restaurant data', style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 18 : 18.sp, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('${snap.error}', style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 14 : 14.sp, color: Colors.grey),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back')),
                    ])));
          }
          if (!snap.hasData || snap.data?.data() == null) {
            return Scaffold(appBar: AppBar(title: const Text('Not Found')),
                body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.restaurant, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('Restaurant not found', style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 18 : 18.sp, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('The restaurant link may be invalid or expired.',
                          style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 14 : 14.sp, color: Colors.grey),
                          textAlign: TextAlign.center),
                    ])));
          }

          final data = snap.data!.data() as Map<String, dynamic>;
          if (data['openingTime'] != null) openingTime = data['openingTime'] as String;
          if (data['closingTime'] != null) closingTime = data['closingTime'] as String;
          _restaurantName    = (data['name'] ?? data['restaurantName'] ?? '') as String;
          _restaurantTagline = (data['tagline'] ?? data['description'] ?? '') as String;
          _restaurantLogo    = (data['logoUrl'] ?? data['logo']) as String?;

          return Scaffold(
            backgroundColor: _C.bg,
            body: Column(children: [
              _buildHeader(),

              // ── Table banner ──────────────────────────────────────────────
              ValueListenableBuilder<String?>(
                valueListenable: _tableIdNotifier,
                builder: (_, tableId, __) {
                  if (tableId == null || tableId.isEmpty) return const SizedBox.shrink();
                  return ValueListenableBuilder<String?>(
                    valueListenable: _tableNameNotifier,
                    builder: (_, tableName, __) => Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 16 : 16.w,
                          vertical:   kIsWeb ? 9 : 9.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4ED),
                        border: Border(bottom: BorderSide(
                            color: _C.accent.withOpacity(0.2))),
                      ),
                      child: Row(children: [
                        const Icon(Icons.table_restaurant_rounded,
                            color: _C.accent, size: 15),
                        SizedBox(width: kIsWeb ? 8 : 8.w),
                        Expanded(child: Text(
                          'Ordering for: ${tableName ?? tableId}',
                          style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 12 : 12.sp,
                              fontWeight: FontWeight.w600, color: _C.accent),
                        )),
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF2ECC71), size: 14),
                        SizedBox(width: kIsWeb ? 4 : 4.w),
                        Text('Auto-selected', style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 10 : 10.sp,
                            color: const Color(0xFF2ECC71),
                            fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  );
                },
              ),

              Expanded(
                child: IndexedStack(index: _selectedTabIndex, children: [
                  // ── Home tab: smooth toggle between list and grid ──────────
                  ValueListenableBuilder<bool>(
                    valueListenable: _listViewNotifier,
                    builder: (_, isListView, __) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve:  Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                              parent: anim, curve: Curves.easeOut)),
                          child: child,
                        ),
                      ),
                      child: isListView
                          ? KeyedSubtree(
                          key: const ValueKey('list'),
                          child: _buildUnifiedListView())
                          : KeyedSubtree(
                          key: const ValueKey('grid'),
                          child: _buildSeparateView()),
                    ),
                  ),
                  KeepAliveWrapper(child: _buildOrdersTab()),
                  KeepAliveWrapper(child: _buildOffersTab()),
                  _buildAssistTab(),
                  KeepAliveWrapper(child: _buildAccountTab()),
                ]),
              ),
              _buildBottomNavigationBar(),
            ]),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER — grid toggle uses ValueListenableBuilder, no setState
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFFA855F7)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: SafeArea(bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 16 : 16.sp,
            vertical:   kIsWeb ? 10 : 10.sp),
        child: Row(children: [
          // Logo
          Container(
            width: kIsWeb ? 44 : 44.sp, height: kIsWeb ? 44 : 44.sp,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
              child: _restaurantLogo != null && _restaurantLogo!.isNotEmpty
                  ? _networkImage(_restaurantLogo!, fit: BoxFit.cover)
                  : _logoFallback(),
            ),
          ),
          SizedBox(width: kIsWeb ? 10 : 10.sp),
          // Name + tagline
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_restaurantName.isNotEmpty ? _restaurantName : "Loading...",
                style: GoogleFonts.poppins(
                    fontSize: kIsWeb ? 17 : 17.sp,
                    fontWeight: FontWeight.w700, color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_restaurantTagline.isNotEmpty)
              Text(_restaurantTagline,
                  style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 10 : 10.sp,
                      color: Colors.white.withOpacity(0.8)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),

          // Grid/List toggle — ValueListenableBuilder only rebuilds this button
          if (_selectedTabIndex == 0) ...[
            ValueListenableBuilder<bool>(
              valueListenable: _listViewNotifier,
              builder: (_, isListView, __) => GestureDetector(
                onTap: () => _listViewNotifier.value = !_listViewNotifier.value,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim, child: FadeTransition(opacity: anim, child: child)),
                  child: _headerIconButton(
                    isListView
                        ? Icons.grid_view_rounded
                        : Icons.view_agenda_rounded,
                    key: ValueKey(isListView),
                  ),
                ),
              ),
            ),
            SizedBox(width: kIsWeb ? 8 : 8.sp),
          ],

          // Animated cart
          ValueListenableBuilder<int>(
            valueListenable: _cartBounce,
            builder: (_, bounceCount, __) =>
                ValueListenableBuilder<List<CartItem>>(
                  valueListenable: _cartNotifier,
                  builder: (_, cartItems, __) {
                    final total = cartItems.fold<int>(0, (s, i) => s + i.qty);
                    return GestureDetector(
                      onTap: _orderLookupInProgress
                          ? null
                          : () => _openCartPage(cartItems),
                      child: _AnimatedCartBadge(
                          bounceCount:  bounceCount,
                          badge:        total > 0 ? '$total' : null,
                          primaryColor: _primaryColor),
                    );
                  },
                ),
          ),
        ]),
      ),
    ),
  );

  Widget _headerIconButton(IconData icon, {Key? key}) => Container(
    key: key,
    width: kIsWeb ? 40 : 40.sp, height: kIsWeb ? 40 : 40.sp,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
    ),
    child: Icon(icon, size: kIsWeb ? 20 : 20.sp, color: Colors.white),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM NAV
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNavigationBar() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(
          color: _C.shadowMd, blurRadius: 16, offset: const Offset(0, -3))],
    ),
    child: SafeArea(top: false,
      child: SizedBox(
        height: kIsWeb ? 60 : 60.h,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildNavItem(icon: Icons.home_rounded,          label: "Home",    index: 0),
          _buildNavItem(icon: Icons.inventory_2_outlined,  label: "Orders",  index: 1),
          _buildNavItem(icon: Icons.card_giftcard_outlined,label: "Offers",  index: 2),
          _buildNavItem(icon: Icons.support_agent_rounded, label: "Assist",  index: 3),
          _buildNavItem(icon: Icons.person_outline_rounded,label: "Account", index: 4),
        ]),
      ),
    ),
  );

  void _switchTab(int index) => setState(() => _selectedTabIndex = index);

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? (kIsWeb ? 10 : 10.sp) : 0,
                  vertical:   kIsWeb ? 4 : 4.sp),
              decoration: BoxDecoration(
                color: isSelected ? _C.accentLight : Colors.transparent,
                borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20.sp),
              ),
              child: Icon(icon,
                  size:  kIsWeb ? 22 : 22.sp,
                  color: isSelected ? _C.accent : Colors.grey[400]),
            ),
            SizedBox(height: kIsWeb ? 3 : 3.sp),
            Text(label, style: GoogleFonts.poppins(
                fontSize: kIsWeb ? 10 : 10.sp,
                color: isSelected ? _C.accent : Colors.grey[500],
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
          ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UNIFIED LIST VIEW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUnifiedListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('categories')
          .orderBy('position')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _errorWidget('Error loading categories', snap.error);
        if (snap.connectionState == ConnectionState.waiting) {
          return ListView.builder(
              padding: EdgeInsets.only(
                  top: kIsWeb ? 8 : 8.h, bottom: kIsWeb ? 8 : 8.h),
              itemCount: 3,
              itemBuilder: (_, __) => const CategoryCardSkeleton(
                  width: double.infinity, height: 80));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty)
          return _emptyWidget('No Categories Found');

        final categories = snap.data!.docs;
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedCategoryId = categories.first.id);
          });
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
              kIsWeb ? 12 : 12.w, kIsWeb ? 12 : 12.h,
              kIsWeb ? 12 : 12.w, kIsWeb ? 20 : 20.h),
          itemCount: categories.length,
          itemBuilder: (context, i) {
            final cat        = categories[i];
            final isExpanded = !_collapsedCategoryIds.contains(cat.id);

            return Container(
              margin: EdgeInsets.only(bottom: kIsWeb ? 16 : 16.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kIsWeb ? 18 : 18.sp),
                boxShadow: [BoxShadow(
                    color: _C.shadow, blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kIsWeb ? 18 : 18.sp),
                child: Column(children: [
                  // Category header
                  GestureDetector(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _collapsedCategoryIds.add(cat.id);
                      } else {
                        _collapsedCategoryIds.remove(cat.id);
                      }
                      _selectedCategoryId = cat.id;
                    }),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 16 : 16.sp,
                          vertical:   kIsWeb ? 14 : 14.sp),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_C.accentLight, _C.accentLight.withOpacity(0.3)],
                          begin: Alignment.centerLeft, end: Alignment.centerRight,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: kIsWeb ? 4 : 4.w, height: kIsWeb ? 20 : 20.h,
                          decoration: BoxDecoration(
                              color: _C.accent,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        SizedBox(width: kIsWeb ? 10 : 10.w),
                        Expanded(child: Text(cat['name'] ?? "Category",
                            style: GoogleFonts.poppins(
                                fontSize: kIsWeb ? 15 : 15.sp,
                                fontWeight: FontWeight.w700,
                                color: _C.textPrimary))),
                        AnimatedRotation(
                          turns:    isExpanded ? 0 : -0.5,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(Icons.keyboard_arrow_up_rounded,
                              color: _C.accent, size: kIsWeb ? 22 : 22.sp),
                        ),
                      ]),
                    ),
                  ),
                  // Items
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 280),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('restaurants')
                          .doc(widget.restaurantId)
                          .collection('menu_items')
                          .where('categoryId', isEqualTo: cat.id)
                          .where('isAvailable', isEqualTo: true)
                          .snapshots(),
                      builder: (context, menuSnap) {
                        if (menuSnap.hasError) return _inlineError('Error loading items');
                        if (menuSnap.connectionState == ConnectionState.waiting)
                          return _inlineLoading();
                        if (!menuSnap.hasData || menuSnap.data!.docs.isEmpty)
                          return _inlineEmpty('No available items in this category');
                        final items = menuSnap.data!.docs;
                        return Column(
                          children: items.asMap().entries.map((entry) {
                            final item   = entry.value;
                            final itemId = item.id;
                            final raw    = (item.data() as Map<String, dynamic>)['variants'];
                            final v      = _safeList(raw);
                            final isLast = entry.key == items.length - 1;
                            return Column(children: [
                              _buildMenuCard(
                                context: context, item: item, itemId: itemId,
                                variants: v, primaryColor: _primaryColor,
                              ),
                              if (!isLast)
                                Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: kIsWeb ? 16 : 16.w),
                                    child: Divider(height: 1, color: _C.divider)),
                            ]);
                          }).toList(),
                        );
                      },
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEPARATE / GRID VIEW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSeparateView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('categories')
          .orderBy('position')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _errorWidget('Error loading categories', snap.error);
        if (snap.connectionState == ConnectionState.waiting) {
          return ListView.builder(
              padding: EdgeInsets.only(
                  top: kIsWeb ? 4 : 4.h, bottom: kIsWeb ? 8 : 8.h),
              itemCount: 3,
              itemBuilder: (_, __) => const CategoryCardSkeleton(
                  width: double.infinity, height: 80));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty)
          return _emptyWidget('No Categories Found');

        final categories = snap.data!.docs;
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedCategoryId = categories.first.id);
          });
        }

        return Column(children: [
          ValueListenableBuilder<String?>(
            valueListenable: _selectedCategoryIdNotifier,
            builder: (context, selectedCatId, _) => SizedBox(
              height: kIsWeb ? 56 : 56.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                    horizontal: kIsWeb ? 16 : 16.w,
                    vertical:   kIsWeb ? 10 : 10.h),
                itemCount: categories.length,
                itemBuilder: (ctx, i) {
                  final cat   = categories[i];
                  final isSel = cat.id == selectedCatId;
                  return GestureDetector(
                    onTap: () => _selectedCategoryIdNotifier.value = cat.id,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: kIsWeb ? 8 : 8.w),
                      padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 16 : 16.w,
                          vertical:   kIsWeb ? 6 : 6.h),
                      decoration: BoxDecoration(
                        color: isSel ? _C.accent : _C.chipBg,
                        borderRadius: BorderRadius.circular(kIsWeb ? 24 : 24.sp),
                        border: Border.all(
                            color: isSel ? _C.accent : _C.divider),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(cat['name'] ?? "Category",
                            style: GoogleFonts.poppins(
                                fontSize: kIsWeb ? 13 : 13.sp,
                                fontWeight: FontWeight.w500,
                                color: isSel ? Colors.white : _C.textSecondary)),
                        if (isSel) ...[
                          SizedBox(width: kIsWeb ? 5 : 5.w),
                          Icon(Icons.check,
                              size: kIsWeb ? 14 : 14.sp, color: Colors.white),
                        ],
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(child: ValueListenableBuilder<String?>(
            valueListenable: _selectedCategoryIdNotifier,
            builder: (_, __, ___) => _buildMenuItemsList(),
          )),
        ]);
      },
    );
  }

  Widget _buildMenuItemsList() {
    if (_selectedCategoryId == null) return _emptyWidget('Select a Category');
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey(_selectedCategoryId),
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('menu_items')
          .where('categoryId', isEqualTo: _selectedCategoryId)
          .where('isAvailable', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _errorWidget('Error loading menu items', snap.error);
        if (snap.connectionState == ConnectionState.waiting) {
          return ListView.builder(
              padding: EdgeInsets.symmetric(vertical: kIsWeb ? 8 : 8.h),
              itemCount: 5,
              itemBuilder: (_, __) => const MenuCardSkeleton());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty)
          return _emptyWidget('No Menu Items Available');

        final items = snap.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
              kIsWeb ? 12 : 12.w, kIsWeb ? 10 : 10.h,
              kIsWeb ? 12 : 12.w, kIsWeb ? 16 : 16.h),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item   = items[i];
            final itemId = item.id;
            final raw    = (item.data() as Map<String, dynamic>)['variants'];
            final v      = _safeList(raw);
            return _buildMenuGridCard(
              context: context, item: item, itemId: itemId,
              variants: v, primaryColor: _primaryColor,
            );
          },
        );
      },
    );
  }

  // ── Inline state helpers ──────────────────────────────────────────────────
  Widget _loadingWidget(String msg) => Center(child: ProfessionalLoader(
    type: LoaderType.waveBounce, message: msg,
    primaryColor: _primaryColor, secondaryColor: const Color(0xFFEC4899),
    size: kIsWeb ? 60 : 60.w,
  ));

  Widget _errorWidget(String msg, Object? error) => Center(child: Padding(
    padding: EdgeInsets.all(kIsWeb ? 24 : 24.sp),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 48),
      const SizedBox(height: 12),
      Text(msg, style: GoogleFonts.poppins(
          fontSize: kIsWeb ? 16 : 16.sp, fontWeight: FontWeight.w600, color: Colors.red)),
      if (error != null) ...[
        const SizedBox(height: 6),
        Text('$error', style: GoogleFonts.poppins(
            fontSize: kIsWeb ? 12 : 12.sp, color: Colors.red.withOpacity(0.7)),
            textAlign: TextAlign.center),
      ],
    ]),
  ));

  Widget _emptyWidget(String msg) => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.restaurant_menu, color: Colors.grey[300], size: kIsWeb ? 56 : 56.sp),
    const SizedBox(height: 12),
    Text(msg, style: GoogleFonts.poppins(
        fontSize: kIsWeb ? 16 : 16.sp, fontWeight: FontWeight.w500,
        color: Colors.grey[400])),
  ]));

  Widget _inlineError(String msg) => Padding(
      padding: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 8 : 8.h),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 16),
        const SizedBox(width: 6),
        Text(msg, style: GoogleFonts.poppins(
            fontSize: kIsWeb ? 12 : 12.sp, color: Colors.red)),
      ]));

  Widget _inlineLoading() => Padding(
      padding: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 8 : 8.h),
      child: const Row(children: [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8), Text('Loading...'),
      ]));

  Widget _inlineEmpty(String msg) => Padding(
      padding: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 8 : 8.h),
      child: Row(children: [
        Icon(Icons.restaurant_menu, color: Colors.grey[400], size: 16),
        const SizedBox(width: 6),
        Text(msg, style: GoogleFonts.poppins(
            fontSize: kIsWeb ? 12 : 12.sp, color: Colors.grey[400])),
      ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED CART BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedCartBadge extends StatefulWidget {
  final int     bounceCount;
  final String? badge;
  final Color   primaryColor;
  const _AnimatedCartBadge({
    required this.bounceCount,
    required this.badge,
    required this.primaryColor,
  });
  @override
  State<_AnimatedCartBadge> createState() => _AnimatedCartBadgeState();
}

class _AnimatedCartBadgeState extends State<_AnimatedCartBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.90), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void didUpdateWidget(_AnimatedCartBadge old) {
    super.didUpdateWidget(old);
    if (old.bounceCount != widget.bounceCount) _ctrl.forward(from: 0);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
    child: Container(
      width: kIsWeb ? 40 : 40.sp, height: kIsWeb ? 40 : 40.sp,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20.sp),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.shopping_cart, size: kIsWeb ? 20 : 20.sp, color: Colors.white),
        if (widget.badge != null)
          Positioned(
            top: kIsWeb ? 2 : 2.sp, right: kIsWeb ? 2 : 2.sp,
            child: Container(
              width: kIsWeb ? 16 : 16.sp, height: kIsWeb ? 16 : 16.sp,
              decoration: BoxDecoration(color: Colors.red,
                  borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp)),
              child: Center(child: Text(widget.badge!,
                  style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 10 : 10.sp,
                      fontWeight: FontWeight.bold, color: Colors.white))),
            ),
          ),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD BUTTON WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _AddButtonWidget extends StatefulWidget {
  final String                 itemId;
  final Color                  primaryColor;
  final ValueNotifier<String?> lastAddedNotifier;
  final VoidCallback           onTap;
  final bool                   isOpen;
  const _AddButtonWidget({
    required this.itemId,
    required this.primaryColor,
    required this.lastAddedNotifier,
    required this.onTap,
    required this.isOpen,
  });
  @override
  State<_AddButtonWidget> createState() => _AddButtonWidgetState();
}

class _AddButtonWidgetState extends State<_AddButtonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    widget.lastAddedNotifier.addListener(_onAdded);
  }
  void _onAdded() {
    if (widget.lastAddedNotifier.value == widget.itemId) _ctrl.forward(from: 0);
  }
  @override
  void dispose() {
    widget.lastAddedNotifier.removeListener(_onAdded);
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
    child: GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: kIsWeb ? 34 : 34.h,
        padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 18 : 18.w),
        decoration: BoxDecoration(
          gradient: widget.isOpen
              ? const LinearGradient(
              colors: [Color(0xFFE8420E), Color(0xFFFF5722)],
              begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: widget.isOpen ? null : Colors.grey[300],
          borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
          boxShadow: widget.isOpen
              ? [BoxShadow(color: const Color(0xFFE8420E).withOpacity(0.30),
              blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Center(child: Text("ADD",
            style: GoogleFonts.poppins(
                fontSize: kIsWeb ? 12 : 12.sp,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8))),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTER WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _CounterWidget extends StatefulWidget {
  final int          qty;
  final Color        primaryColor;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  const _CounterWidget({
    required this.qty,
    required this.primaryColor,
    required this.onDecrement,
    required this.onIncrement,
  });
  @override
  State<_CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<_CounterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _numCtrl;
  late Animation<double>   _numScale;
  @override
  void initState() {
    super.initState();
    _numCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _numScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _numCtrl, curve: Curves.easeOut));
  }
  @override
  void didUpdateWidget(_CounterWidget old) {
    super.didUpdateWidget(old);
    if (old.qty != widget.qty) _numCtrl.forward(from: 0);
  }
  @override
  void dispose() { _numCtrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
    height: kIsWeb ? 34 : 34.h,
    decoration: BoxDecoration(
      color: widget.primaryColor.withOpacity(0.07),
      borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
      border: Border.all(color: widget.primaryColor.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(onTap: widget.onDecrement,
          child: Container(
            width: kIsWeb ? 32 : 32.w, height: double.infinity,
            decoration: BoxDecoration(
              color: widget.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.only(
                  topLeft:    Radius.circular(kIsWeb ? 10 : 10.sp),
                  bottomLeft: Radius.circular(kIsWeb ? 10 : 10.sp)),
            ),
            child: Icon(Icons.remove,
                size: kIsWeb ? 15 : 15.sp, color: widget.primaryColor),
          )),
      SizedBox(width: kIsWeb ? 34 : 34.w,
          child: Center(child: AnimatedBuilder(
            animation: _numScale,
            builder: (_, child) =>
                Transform.scale(scale: _numScale.value, child: child),
            child: Text("${widget.qty}", style: GoogleFonts.poppins(
                fontSize: kIsWeb ? 13 : 13.sp,
                fontWeight: FontWeight.w700,
                color: widget.primaryColor)),
          ))),
      GestureDetector(onTap: widget.onIncrement,
          child: Container(
            width: kIsWeb ? 32 : 32.w, height: double.infinity,
            decoration: BoxDecoration(
              color: widget.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.only(
                  topRight:    Radius.circular(kIsWeb ? 10 : 10.sp),
                  bottomRight: Radius.circular(kIsWeb ? 10 : 10.sp)),
            ),
            child: Icon(Icons.add,
                size: kIsWeb ? 15 : 15.sp, color: widget.primaryColor),
          )),
    ]),
  );
}