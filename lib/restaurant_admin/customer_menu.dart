import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/restaurant_admin/track_order.dart';
import 'package:restaurant_admin_panel/data/models/cart_item.dart';
import 'account_page.dart';
import 'cart_page.dart';

Color hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  if (hex.length == 6) hex = "FF$hex";
  return Color(int.parse(hex, radix: 16));
}

class CustomerMenuPage extends StatefulWidget {
  final String restaurantId;
  const CustomerMenuPage({super.key, required this.restaurantId});

  @override
  State<CustomerMenuPage> createState() => _CustomerMenuPageState();
}

class _CustomerMenuPageState extends State<CustomerMenuPage> {
  String? _selectedCategoryId;
  final Map<String, int> _selectedVariantIndexByItemId = {};
  bool _unifiedCategoryListView = true;
  final Set<String> _collapsedCategoryIds = {};
  final List<CartItem> cart = [];

  String openingTime = "09:00 AM";
  String closingTime = "06:00 AM";

  // Restaurant info loaded from Firestore
  String _restaurantName = "";
  String _restaurantTagline = "";
  String? _restaurantLogo;

  static const Color _primaryColor = Color(0xFF7C3AED);

  // ─── Cart helpers ─────────────────────────────────────────────────────────────

  int getTotalCartQuantity() {
    int total = 0;
    for (var item in cart) {
      total += item.qty;
    }
    return total;
  }

  int getItemQuantity(String itemId, String variant) {
    int qty = 0;
    for (var item in cart) {
      if (item.itemId == itemId && item.variant == variant) qty += item.qty;
    }
    return qty;
  }

  // ─── Safe variant helpers ─────────────────────────────────────────────────────

  List<dynamic> _safeList(dynamic raw) {
    if (raw == null) return [];
    try {
      return List<dynamic>.from(raw as List);
    } catch (_) {
      return [];
    }
  }

  int _safeIndex(String itemId, List<dynamic> variants) {
    if (variants.isEmpty) return 0;
    final stored = _selectedVariantIndexByItemId[itemId] ?? 0;
    final clamped = stored.clamp(0, variants.length - 1);
    if (stored != clamped) _selectedVariantIndexByItemId[itemId] = clamped;
    return clamped;
  }

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  // ─── Restaurant open/close ────────────────────────────────────────────────────

  bool _isRestaurantOpen() {
    final now = DateTime.now();
    final cur = now.hour * 60 + now.minute;
    int parseTime(String t) {
      try {
        final parts = t.split(' ');
        final hm = parts[0].split(':');
        int h = int.parse(hm[0]);
        if (parts[1] == 'PM' && h != 12) h += 12;
        if (parts[1] == 'AM' && h == 12) h = 0;
        return h * 60 + int.parse(hm[1]);
      } catch (_) {
        return 0;
      }
    }
    return cur >= parseTime(openingTime) && cur <= parseTime(closingTime);
  }

  void _showRestaurantClosedPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(kIsWeb ? 8 : 8.sp),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
              ),
              child: Icon(Icons.access_time,
                  color: Colors.red, size: kIsWeb ? 24 : 24.sp),
            ),
            SizedBox(width: kIsWeb ? 12 : 12.sp),
            Text("Restaurant Closed",
                style: GoogleFonts.poppins(
                    fontSize: kIsWeb ? 18 : 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sorry, we're currently closed. Please come back during our operating hours.",
              style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 14 : 14.sp, color: Colors.black54),
            ),
            SizedBox(height: kIsWeb ? 16 : 16.sp),
            Container(
              padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule,
                      color: Colors.grey[600], size: kIsWeb ? 20 : 20.sp),
                  SizedBox(width: kIsWeb ? 8 : 8.sp),
                  Text("Hours: $openingTime – $closingTime",
                      style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 13 : 13.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Got it",
                style: GoogleFonts.poppins(
                    fontSize: kIsWeb ? 14 : 14.sp,
                    fontWeight: FontWeight.w500,
                    color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  // ─── Cart update ──────────────────────────────────────────────────────────────

  void _updateItemQuantity(
      String itemId,
      String variant,
      int change, {
        String? itemName,
        int? price,
        String? image,
      }) {
    setState(() {
      CartItem? existing;
      int idx = -1;
      for (int i = 0; i < cart.length; i++) {
        if (cart[i].itemId == itemId && cart[i].variant == variant) {
          existing = cart[i];
          idx = i;
          break;
        }
      }
      if (existing != null) {
        existing.qty += change;
        if (existing.qty <= 0)
          cart.removeAt(idx);
        else if (existing.qty > 99)
          existing.qty = 99;
      } else if (change > 0 && itemName != null && price != null) {
        cart.add(CartItem(
            itemId: itemId,
            name: itemName,
            variant: variant,
            price: price,
            qty: change,
            image: image));
      }
    });
  }

  // ─── Shared small widgets ─────────────────────────────────────────────────────

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(Icons.fastfood_rounded,
            color: Colors.grey[300], size: kIsWeb ? 36 : 36.sp),
      ),
    );
  }

  /// Fallback shown when logo URL is absent or fails to load
  Widget _logoFallback() {
    final initials = _restaurantName.isNotEmpty
        ? _restaurantName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    return Container(
      color: Colors.white.withOpacity(0.15),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 14 : 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
      ),
    );
  }

  Widget _vegBadge(bool isVeg) {
    return Container(
      width: kIsWeb ? 18 : 18.sp,
      height: kIsWeb ? 18 : 18.sp,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kIsWeb ? 3 : 3.sp),
        border: Border.all(
            color: isVeg ? Colors.green : Colors.green, width: 1.5),
      ),
      child: Center(
        child: Container(
          width: kIsWeb ? 8 : 8.sp,
          height: kIsWeb ? 8 : 8.sp,
          decoration: BoxDecoration(
            color: isVeg ? Colors.green : Colors.green,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
  Widget _buildVariantDropdown({
    required String itemId,
    required List<dynamic> variants,
    required int selectedIndex,
  }) {
    if (variants.isEmpty) return const SizedBox.shrink();

    final selected = variants[selectedIndex] as Map<String, dynamic>;
    final selectedName = (selected['name'] ?? '') as String;
    final selectedPrice = _toInt(selected['price']);

    // Single variant — light red read-only pill
    if (variants.length == 1) {
      if (selectedName.isEmpty) return const SizedBox.shrink();
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 10 : 10.w,
            vertical: kIsWeb ? 4 : 4.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEEE),
          borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20.sp),
          border: Border.all(color: Colors.grey.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedName,
              style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 10 : 10.sp,
                  color: Colors.black,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // Multiple variants — attractive custom dropdown
    return GestureDetector(
      onTap: () => _showVariantDropdownSheet(
        itemId: itemId,
        variants: variants,
        selectedIndex: selectedIndex,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 10 : 10.w,
            vertical: kIsWeb ? 5 : 5.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
          border: Border.all(
              color: _primaryColor.withOpacity(0.45), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Purple dot accent
            Container(
              width: kIsWeb ? 6 : 6.sp,
              height: kIsWeb ? 6 : 6.sp,
              decoration: const BoxDecoration(
                  color: _primaryColor, shape: BoxShape.circle),
            ),
            SizedBox(width: kIsWeb ? 6 : 6.w),
            // Selected name
            Text(
              selectedName,
              style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 11 : 11.sp,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500),
            ),
            SizedBox(width: kIsWeb ? 5 : 5.w),
            // Chevron
            Icon(Icons.keyboard_arrow_down_rounded,
                size: kIsWeb ? 16 : 16.sp,
                color: _primaryColor),
          ],
        ),
      ),
    );
  }

  // ─── Variant dropdown sheet ───────────────────────────────────────────────────
  // Attractive bottom sheet with radio-style rows showing name + price.

  void _showVariantDropdownSheet({
    required String itemId,
    required List<dynamic> variants,
    required int selectedIndex,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        int localIndex = selectedIndex;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      kIsWeb ? 20 : 20.w,
                      kIsWeb ? 20 : 20.h,
                      kIsWeb ? 20 : 20.w,
                      kIsWeb ? 4 : 4.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(kIsWeb ? 6 : 6.sp),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius:
                          BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                        ),
                        child: Icon(Icons.tune_rounded,
                            color: _primaryColor,
                            size: kIsWeb ? 18 : 18.sp),
                      ),
                      SizedBox(width: kIsWeb ? 10 : 10.w),
                      Text("Select Variant",
                          style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 18 : 18.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                    ],
                  ),
                ),

                // Divider
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: kIsWeb ? 20 : 20.w),
                  child: Divider(color: Colors.grey[100], height: 1),
                ),

                SizedBox(height: kIsWeb ? 8 : 8.h),

                // Variant rows
                ...variants.asMap().entries.map((entry) {
                  final index = entry.key;
                  final variant =
                  entry.value as Map<String, dynamic>;
                  final name = (variant['name'] ?? '') as String;
                  final price = _toInt(variant['price']);
                  final isSelected = index == localIndex;

                  return GestureDetector(
                    onTap: () {
                      setSheet(() => localIndex = index);
                      setState(() =>
                      _selectedVariantIndexByItemId[itemId] =
                          index);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 16 : 16.w,
                          vertical: kIsWeb ? 4 : 4.h),
                      padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 16 : 16.w,
                          vertical: kIsWeb ? 12 : 12.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primaryColor.withOpacity(0.06)
                            : Colors.grey[50],
                        borderRadius:
                        BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                        border: Border.all(
                          color: isSelected
                              ? _primaryColor.withOpacity(0.4)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Custom radio circle
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: kIsWeb ? 20 : 20.sp,
                            height: kIsWeb ? 20 : 20.sp,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? _primaryColor
                                    : Colors.grey[400]!,
                                width: isSelected ? 0 : 1.5,
                              ),
                              color: isSelected
                                  ? _primaryColor
                                  : Colors.white,
                            ),
                            child: isSelected
                                ? Icon(Icons.check_rounded,
                                size: kIsWeb ? 13 : 13.sp,
                                color: Colors.white)
                                : null,
                          ),

                          SizedBox(width: kIsWeb ? 12 : 12.w),

                          // Variant name
                          Expanded(
                            child: Text(name,
                                style: GoogleFonts.poppins(
                                    fontSize: kIsWeb ? 14 : 14.sp,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? _primaryColor
                                        : Colors.black87)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                SizedBox(height: kIsWeb ? 24 : 24.h),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── ADD / counter widget ──────────────────────────────────────────────────────

  Widget _buildAddOrCounterWidget(
      BuildContext context,
      QueryDocumentSnapshot item,
      String itemId,
      String variant,
      int price,
      ) {
    final qty = getItemQuantity(itemId, variant);
    final isOpen = true;

    if (qty > 0) {
      return Container(
        height: kIsWeb ? 34 : 34.h,
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
          border: Border.all(color: _primaryColor.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _updateItemQuantity(itemId, variant, -1,
                  itemName: item['name'], price: price, image: item['image']),
              child: Container(
                width: kIsWeb ? 32 : 32.w,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(kIsWeb ? 8 : 8.sp),
                    bottomLeft: Radius.circular(kIsWeb ? 8 : 8.sp),
                  ),
                ),
                child: Icon(Icons.remove,
                    size: kIsWeb ? 15 : 15.sp, color: _primaryColor),
              ),
            ),
            SizedBox(
              width: kIsWeb ? 34 : 34.w,
              child: Center(
                child: Text("$qty",
                    style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 13 : 13.sp,
                        fontWeight: FontWeight.w700,
                        color: _primaryColor)),
              ),
            ),
            GestureDetector(
              onTap: isOpen
                  ? () => _updateItemQuantity(itemId, variant, 1,
                  itemName: item['name'],
                  price: price,
                  image: item['image'])
                  : () => _showRestaurantClosedPopup(context),
              child: Container(
                width: kIsWeb ? 32 : 32.w,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(kIsWeb ? 8 : 8.sp),
                    bottomRight: Radius.circular(kIsWeb ? 8 : 8.sp),
                  ),
                ),
                child: Icon(Icons.add,
                    size: kIsWeb ? 15 : 15.sp, color: _primaryColor),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: isOpen
          ? () {
        _updateItemQuantity(itemId, variant, 1,
            itemName: item['name'], price: price, image: item['image']);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${item['name']} added to cart"),
          duration: const Duration(seconds: 2),
        ));
      }
          : () => _showRestaurantClosedPopup(context),
      child: Container(
        height: kIsWeb ? 34 : 34.h,
        padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 18 : 18.w),
        decoration: BoxDecoration(
          color: isOpen ? _primaryColor : Colors.grey[400],
          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
        ),
        child: Center(
          child: Text("ADD",
              style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 12 : 12.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
        ),
      ),
    );
  }

  Widget _buildMenuGridCard({
    required BuildContext context,
    required QueryDocumentSnapshot item,
    required String itemId,
    required List variants,
    required int selectedIndex,
    required dynamic selectedVariant,
    required dynamic price,
    required Color cardColor,
    required Color textColor,
    required Color cardInfoColor,
    required Color primaryColor,
  }) {
    final data = item.data() as Map<String, dynamic>;
    final bool isVeg = data['isVeg'] == true;
    final String? description = data['description'] as String?;

    final List<dynamic> v = _safeList(data['variants']);
    final int si = _safeIndex(itemId, v);
    final dynamic sv = v.isNotEmpty ? v[si] : null;
    final int safePrice = _toInt(sv?['price'] ?? data['price']);
    final String variantName = (sv?['name'] ?? '') as String;

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 5 : 5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image ──────────────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(kIsWeb ? 14 : 14.sp),
                bottomLeft: Radius.circular(kIsWeb ? 14 : 14.sp),
              ),
              child: SizedBox(
                width: kIsWeb ? 120 : 120.w,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item['image'] != null
                        ? Image.network(item['image'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder())
                        : _imagePlaceholder(),
                    Positioned(top: 8, left: 8, child: _vegBadge(isVeg)),
                  ],
                ),
              ),
            ),

            // ── Details ────────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: kIsWeb ? 14 : 14.w,
                    vertical: kIsWeb ? 10 : 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? "Item",
                      style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 14 : 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      SizedBox(height: kIsWeb ? 2 : 2.h),
                      Text(description,
                          style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 11 : 11.sp,
                              color: Colors.grey[500],
                              height: 1.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    SizedBox(height: kIsWeb ? 7 : 7.h),

                    // Attractive variant dropdown
                    _buildVariantDropdown(
                      itemId: itemId,
                      variants: v,
                      selectedIndex: si,
                    ),

                    SizedBox(height: kIsWeb ? 8 : 8.h),

                    // Price + ADD
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("₹$safePrice",
                            style: GoogleFonts.poppins(
                                fontSize: kIsWeb ? 15 : 15.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.red[600])),
                        _buildAddOrCounterWidget(
                            context, item, itemId, variantName, safePrice),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── List card — unified view ─────────────────────────────────────────────────

  Widget _buildMenuCard({
    required BuildContext context,
    required QueryDocumentSnapshot item,
    required String itemId,
    required List variants,
    required int selectedIndex,
    required dynamic selectedVariant,
    required dynamic price,
    required Color cardColor,
    required Color textColor,
    required Color cardInfoColor,
    required Color primaryColor,
  }) {
    final data = item.data() as Map<String, dynamic>;
    final bool isVeg = data['isVeg'] == true;
    final String? description = data['description'] as String?;

    final List<dynamic> v = _safeList(data['variants']);
    final int si = _safeIndex(itemId, v);
    final dynamic sv = v.isNotEmpty ? v[si] : null;
    final int safePrice = _toInt(sv?['price'] ?? data['price']);
    final String variantName = (sv?['name'] ?? '') as String;

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 3 : 3.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 10 : 10.w,
            vertical: kIsWeb ? 8 : 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                  child: SizedBox(
                    width: kIsWeb ? 72 : 72.w,
                    height: kIsWeb ? 72 : 72.h,
                    child: item['image'] != null
                        ? Image.network(item['image'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder())
                        : _imagePlaceholder(),
                  ),
                ),
                Positioned(top: 3, left: 3, child: _vegBadge(isVeg)),
              ],
            ),

            SizedBox(width: kIsWeb ? 10 : 10.w),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name + price in same row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(item['name'] ?? "Item",
                            style: GoogleFonts.poppins(
                                fontSize: kIsWeb ? 13 : 13.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(width: kIsWeb ? 8 : 8.w),
                      Text("₹$safePrice",
                          style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 14 : 14.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.red[600])),
                    ],
                  ),

                  if (description != null && description.isNotEmpty) ...[
                    SizedBox(height: kIsWeb ? 1 : 1.h),
                    Text(description,
                        style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 10 : 10.sp,
                            color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],

                  SizedBox(height: kIsWeb ? 5 : 5.h),

                  // Variant + ADD button in same row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Variant dropdown (flexible)
                      Expanded(
                        child: _buildVariantDropdown(
                          itemId: itemId,
                          variants: v,
                          selectedIndex: si,
                        ),
                      ),
                      SizedBox(width: kIsWeb ? 8 : 8.w),
                      // ADD button
                      _buildAddOrCounterWidget(
                          context, item, itemId, variantName, safePrice),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final exit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(kIsWeb ? 12 : 12.sp)),
            title: const Text("Exit Menu?"),
            content:
            const Text("Are you sure you want to close the menu?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel")),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Close")),
            ],
          ),
        );
        return exit ?? false;
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .doc(widget.restaurantId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading restaurant data',
                        style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 18 : 18.sp,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('${snap.error}',
                        style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 14 : 14.sp,
                            color: Colors.grey),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back')),
                  ],
                ),
              ),
            );
          }

          if (!snap.hasData) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading restaurant data...'),
                  ],
                ),
              ),
            );
          }

          final rawData = snap.data!.data();
          if (rawData == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.restaurant, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('Restaurant not found',
                        style: TextStyle(
                            fontSize: kIsWeb ? 18 : 18.sp,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('The restaurant document may have been deleted.',
                        style: TextStyle(
                            fontSize: kIsWeb ? 14 : 14.sp,
                            color: Colors.grey),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final data = rawData as Map<String, dynamic>;
          if (data['openingTime'] != null)
            openingTime = data['openingTime'] as String;
          if (data['closingTime'] != null)
            closingTime = data['closingTime'] as String;

          // Load restaurant name, tagline, logo from Firestore
          final String loadedName = (data['name'] ?? data['restaurantName'] ?? '') as String;
          final String loadedTagline = (data['tagline'] ?? data['description'] ?? '') as String;
          final String? loadedLogo = data['logo'] as String?;
          if (_restaurantName != loadedName ||
              _restaurantTagline != loadedTagline ||
              _restaurantLogo != loadedLogo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _restaurantName = loadedName;
                _restaurantTagline = loadedTagline;
                _restaurantLogo = loadedLogo;
              });
            });
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            body: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildContentArea()),
                _buildBottomNavigationBar(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFFC084FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 15 : 15.sp,
              vertical: kIsWeb ? 10 : 10.sp),
          child: Row(
            children: [
              // ── Logo from Firestore ─────────────────────────────────────
              Container(
                width: kIsWeb ? 44 : 44.sp,
                height: kIsWeb ? 44 : 44.sp,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                  child: _restaurantLogo != null && _restaurantLogo!.isNotEmpty
                      ? Image.network(
                    _restaurantLogo!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _logoFallback(),
                  )
                      : _logoFallback(),
                ),
              ),
              SizedBox(width: kIsWeb ? 10 : 10.sp),
              // ── Restaurant name + tagline ────────────────────────────────
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _restaurantName.isNotEmpty
                          ? _restaurantName
                          : "Loading...",
                      style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 16 : 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_restaurantTagline.isNotEmpty)
                      Text(
                        _restaurantTagline,
                        style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 10 : 10.sp,
                            color: Colors.white.withOpacity(0.8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() =>
                _unifiedCategoryListView = !_unifiedCategoryListView),
                child: _headerIconButton(
                  _unifiedCategoryListView
                      ? Icons.grid_view_rounded
                      : Icons.view_agenda_rounded,
                ),
              ),
              SizedBox(width: kIsWeb ? 8 : 8.sp),
              GestureDetector(
                onTap: cart.isEmpty
                    ? null
                    : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CartPage(
                        cart: cart,
                        restaurantId: widget.restaurantId),
                  ),
                ),
                child: _headerIconButton(Icons.shopping_cart,
                    badge: cart.isNotEmpty
                        ? "${getTotalCartQuantity()}"
                        : null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerIconButton(IconData icon, {String? badge}) {
    return Container(
      width: kIsWeb ? 40 : 40.sp,
      height: kIsWeb ? 40 : 40.sp,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20.sp),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: kIsWeb ? 20 : 20.sp, color: Colors.white),
          if (badge != null)
            Positioned(
              top: kIsWeb ? 2 : 2.sp,
              right: kIsWeb ? 2 : 2.sp,
              child: Container(
                width: kIsWeb ? 16 : 16.sp,
                height: kIsWeb ? 16 : 16.sp,
                decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius:
                    BorderRadius.circular(kIsWeb ? 8 : 8.sp)),
                child: Center(
                  child: Text(badge,
                      style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 10 : 10.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContentArea() => _unifiedCategoryListView
      ? _buildUnifiedListView()
      : _buildSeparateView();

  // ─── Bottom nav ───────────────────────────────────────────────────────────────

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 16 : 16.sp,
              vertical: kIsWeb ? 8 : 8.sp),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                  icon: Icons.home_rounded,
                  label: "Home",
                  isSelected: true,
                  onTap: () {}),
              _buildNavItem(
                  icon: Icons.inventory_2_outlined,
                  label: "Orders",
                  isSelected: false,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => TrackOrderPage(
                              restaurantId: widget.restaurantId)))),
              _buildNavItem(
                  icon: Icons.card_giftcard_outlined,
                  label: "Offers",
                  isSelected: false,
                  onTap: () {}),
              _buildNavItem(
                  icon: Icons.person_outline_rounded,
                  label: "Account",
                  isSelected: false,
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AccountPage(restaurantId: widget.restaurantId)));
                  },
                  showBadge: true,
                  badgeCount: "1"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool showBadge = false,
    String? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 12 : 12.sp,
            vertical: kIsWeb ? 8 : 8.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(icon,
                    size: kIsWeb ? 24 : 24.sp,
                    color: isSelected ? _primaryColor : Colors.grey[500]),
                if (showBadge && badgeCount != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: kIsWeb ? 14 : 14.sp,
                      height: kIsWeb ? 14 : 14.sp,
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius:
                          BorderRadius.circular(kIsWeb ? 7 : 7.sp)),
                      child: Center(
                        child: Text(badgeCount,
                            style: GoogleFonts.poppins(
                                fontSize: kIsWeb ? 8 : 8.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: kIsWeb ? 3 : 3.sp),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: kIsWeb ? 10 : 10.sp,
                    color: isSelected ? _primaryColor : Colors.grey[500],
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  // ─── Unified list view ────────────────────────────────────────────────────────

  Widget _buildUnifiedListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("categories")
          .where("restaurantId", isEqualTo: widget.restaurantId)
          .orderBy("position")
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return _errorWidget('Error loading categories', snap.error);
        if (!snap.hasData) return _loadingWidget('Loading categories...');

        final categories = snap.data!.docs;
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) =>
              setState(() => _selectedCategoryId = categories.first.id));
        }
        if (categories.isEmpty) return _emptyWidget('No Categories Found');

        return ListView.builder(
          padding: EdgeInsets.only(
              top: kIsWeb ? 4 : 4.h, bottom: kIsWeb ? 8 : 8.h),
          itemCount: categories.length,
          itemBuilder: (context, i) {
            final cat = categories[i];
            final isExpanded = !_collapsedCategoryIds.contains(cat.id);
            final bool isCatSelected = _selectedCategoryId == cat.id;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      // Toggle expand/collapse
                      if (isExpanded) {
                        _collapsedCategoryIds.add(cat.id);
                      } else {
                        _collapsedCategoryIds.remove(cat.id);
                      }
                      // Highlight this category as selected
                      _selectedCategoryId = cat.id;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(
                        horizontal: kIsWeb ? 16 : 16.w,
                        vertical: kIsWeb ? 2 : 2.h),
                    padding: EdgeInsets.symmetric(
                        horizontal: kIsWeb ? 14 : 14.sp,
                        vertical: kIsWeb ? 9 : 9.sp),
                    decoration: BoxDecoration(
                      color: isCatSelected
                          ? _primaryColor.withOpacity(0.08)
                          : Colors.grey[50],
                      borderRadius:
                      BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                      border: Border.all(
                        color: isCatSelected
                            ? _primaryColor.withOpacity(0.35)
                            : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Purple left bar when selected
                        if (isCatSelected) ...[
                          Container(
                            width: kIsWeb ? 3 : 3.w,
                            height: kIsWeb ? 18 : 18.h,
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: kIsWeb ? 8 : 8.w),
                        ],
                        Expanded(
                          child: Text(cat['name'] ?? "Category",
                              style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 14 : 14.sp,
                                  fontWeight: isCatSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isCatSelected
                                      ? _primaryColor
                                      : Colors.black87)),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: isCatSelected
                              ? _primaryColor
                              : Colors.black45,
                          size: kIsWeb ? 20 : 20.sp,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded) ...[
                  SizedBox(height: kIsWeb ? 2 : 2.h),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("menu_items")
                        .where("restaurantId",
                        isEqualTo: widget.restaurantId)
                        .where("categoryId", isEqualTo: cat.id)
                        .where("isAvailable", isEqualTo: true)
                        .orderBy("name")
                        .snapshots(),
                    builder: (context, menuSnap) {
                      if (menuSnap.hasError)
                        return _inlineError('Error loading items');
                      if (!menuSnap.hasData) return _inlineLoading();
                      final items = menuSnap.data!.docs;
                      if (items.isEmpty)
                        return _inlineEmpty(
                            'No available items in this category');

                      return Column(
                        children: items.map((item) {
                          final itemId = item.id;
                          final raw = (item.data()
                          as Map<String, dynamic>)['variants'];
                          final v = _safeList(raw);
                          final si = _safeIndex(itemId, v);
                          final sv = v.isNotEmpty ? v[si] : null;
                          final price =
                          sv != null ? sv['price'] : item['price'];
                          return _buildMenuCard(
                            context: context,
                            item: item,
                            itemId: itemId,
                            variants: v,
                            selectedIndex: si,
                            selectedVariant: sv,
                            price: price,
                            cardColor: Colors.white,
                            textColor: Colors.black87,
                            cardInfoColor: Colors.grey,
                            primaryColor: _primaryColor,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
                SizedBox(height: kIsWeb ? 4 : 4.h),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Separate / grid view ─────────────────────────────────────────────────────

  Widget _buildSeparateView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("categories")
          .where("restaurantId", isEqualTo: widget.restaurantId)
          .orderBy("position")
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return _errorWidget('Error loading categories', snap.error);
        if (!snap.hasData) return _loadingWidget('Loading categories...');

        final categories = snap.data!.docs;
        if (categories.isEmpty) return _emptyWidget('No Categories Found');
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) =>
              setState(() => _selectedCategoryId = categories.first.id));
        }

        return Column(
          children: [
            SizedBox(
              height: kIsWeb ? 56 : 56.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                    horizontal: kIsWeb ? 16 : 16.w,
                    vertical: kIsWeb ? 8 : 8.h),
                itemCount: categories.length,
                itemBuilder: (ctx, i) {
                  final cat = categories[i];
                  final isSelected = cat.id == _selectedCategoryId;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCategoryId = cat.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin:
                      EdgeInsets.only(right: kIsWeb ? 10 : 10.w),
                      padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 18 : 18.w,
                          vertical: kIsWeb ? 8 : 8.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primaryColor
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(
                            kIsWeb ? 24 : 24.sp),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat['name'] ?? "Category",
                              style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 13 : 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87)),
                          if (isSelected) ...[
                            SizedBox(width: kIsWeb ? 5 : 5.w),
                            Icon(Icons.check,
                                size: kIsWeb ? 14 : 14.sp,
                                color: Colors.white),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(child: _buildMenuItemsList()),
          ],
        );
      },
    );
  }

  Widget _buildMenuItemsList() {
    if (_selectedCategoryId == null) return _emptyWidget('Select a Category');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("menu_items")
          .where("restaurantId", isEqualTo: widget.restaurantId)
          .where("categoryId", isEqualTo: _selectedCategoryId)
          .where("isAvailable", isEqualTo: true)
          .orderBy("name")
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return _errorWidget('Error loading menu items', snap.error);
        if (!snap.hasData) return _loadingWidget('Loading menu items...');

        final items = snap.data!.docs;
        if (items.isEmpty) return _emptyWidget('No Menu Items Available');

        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: kIsWeb ? 8 : 8.h),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            final itemId = item.id;
            final raw =
            (item.data() as Map<String, dynamic>)['variants'];
            final v = _safeList(raw);
            final si = _safeIndex(itemId, v);
            final sv = v.isNotEmpty ? v[si] : null;
            final price = sv != null
                ? sv['price']
                : (item.data() as Map<String, dynamic>)['price'];

            return _buildMenuGridCard(
              context: context,
              item: item,
              itemId: itemId,
              variants: v,
              selectedIndex: si,
              selectedVariant: sv,
              price: price,
              cardColor: Colors.white,
              textColor: Colors.black87,
              cardInfoColor: Colors.grey,
              primaryColor: _primaryColor,
            );
          },
        );
      },
    );
  }

  // ─── Reusable state widgets ───────────────────────────────────────────────────

  Widget _loadingWidget(String msg) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 12),
      Text(msg,
          style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 14 : 14.sp, color: Colors.grey)),
    ]),
  );

  Widget _errorWidget(String msg, Object? error) => Center(
    child: Padding(
      padding: EdgeInsets.all(kIsWeb ? 24 : 24.sp),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(msg,
            style: GoogleFonts.poppins(
                fontSize: kIsWeb ? 16 : 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.red)),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text('$error',
              style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 12 : 12.sp,
                  color: Colors.red.withOpacity(0.7)),
              textAlign: TextAlign.center),
        ],
      ]),
    ),
  );

  Widget _emptyWidget(String msg) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.restaurant_menu,
          color: Colors.grey[300], size: kIsWeb ? 56 : 56.sp),
      const SizedBox(height: 12),
      Text(msg,
          style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 16 : 16.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[400])),
    ]),
  );

  Widget _inlineError(String msg) => Padding(
    padding: EdgeInsets.symmetric(
        horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 8 : 8.h),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 16),
      const SizedBox(width: 6),
      Text(msg,
          style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 12 : 12.sp, color: Colors.red)),
    ]),
  );

  Widget _inlineLoading() => Padding(
    padding: EdgeInsets.symmetric(
        horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 8 : 8.h),
    child: const Row(children: [
      SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2)),
      SizedBox(width: 8),
      Text('Loading...'),
    ]),
  );

  Widget _inlineEmpty(String msg) => Padding(
    padding: EdgeInsets.symmetric(
        horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 8 : 8.h),
    child: Row(children: [
      Icon(Icons.restaurant_menu, color: Colors.grey[400], size: 16),
      const SizedBox(width: 6),
      Text(msg,
          style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 12 : 12.sp, color: Colors.grey[400])),
    ]),
  );
}
