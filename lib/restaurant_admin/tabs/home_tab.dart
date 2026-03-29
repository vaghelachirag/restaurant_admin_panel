import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/widgets/professional_loader.dart';
import 'package:restaurant_admin_panel/widgets/loading_card.dart';
import '../customer_menu.dart';

class HomeTab extends StatefulWidget {
  final String restaurantId;
  final bool unifiedCategoryListView;
  final String? selectedCategoryId;
  final Set<String> collapsedCategoryIds;
  final Function(String) onCategorySelected;
  final Function(String) onCategoryToggle;
  final Map<String, int> selectedVariantIndexByItemId;
  final Function(String, String, int, {String? itemName, int? price, String? image}) updateItemQuantity;
  final Function(String, String) getItemQuantity;
  final Color primaryColor;

  const HomeTab({
    super.key,
    required this.restaurantId,
    required this.unifiedCategoryListView,
    required this.selectedCategoryId,
    required this.collapsedCategoryIds,
    required this.onCategorySelected,
    required this.onCategoryToggle,
    required this.selectedVariantIndexByItemId,
    required this.updateItemQuantity,
    required this.getItemQuantity,
    required this.primaryColor,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.unifiedCategoryListView ? _buildUnifiedListView() : _buildSeparateView();
  }

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
        if (!snap.hasData) {
          return ListView.builder(
            padding: EdgeInsets.only(
                top: kIsWeb ? 4 : 4.h, bottom: kIsWeb ? 8 : 8.h),
            itemCount: 3,
            itemBuilder: (context, index) => const CategoryCardSkeleton(
              width: double.infinity,
              height: 80,
            ),
          );
        }

        final categories = snap.data!.docs;
        if (categories.isEmpty) return _emptyWidget('No Categories Found');

        return ListView.builder(
          padding: EdgeInsets.only(
              top: kIsWeb ? 4 : 4.h, bottom: kIsWeb ? 8 : 8.h),
          itemCount: categories.length,
          itemBuilder: (context, i) {
            final cat = categories[i];
            final isExpanded = !widget.collapsedCategoryIds.contains(cat.id);
            final bool isCatSelected = widget.selectedCategoryId == cat.id;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    widget.onCategoryToggle(cat.id);
                    widget.onCategorySelected(cat.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(
                        horizontal: kIsWeb ? 16 : 16.w,
                        vertical: kIsWeb ? 2 : 2.h),
                    padding: EdgeInsets.symmetric(
                        horizontal: kIsWeb ? 14 : 14.sp,
                        vertical: kIsWeb ? 12 : 12.h),
                    decoration: BoxDecoration(
                      color: isCatSelected
                          ? widget.primaryColor.withOpacity(0.1)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                      border: Border.all(
                        color: isCatSelected
                            ? widget.primaryColor.withOpacity(0.3)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: isCatSelected ? widget.primaryColor : Colors.grey[600],
                          size: kIsWeb ? 20 : 20.sp,
                        ),
                        SizedBox(width: kIsWeb ? 8 : 8.w),
                        Expanded(
                          child: Text(
                            cat['name'] ?? 'Category',
                            style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 14 : 14.sp,
                              fontWeight: isCatSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isCatSelected ? widget.primaryColor : Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: kIsWeb ? 8 : 8.w,
                              vertical: kIsWeb ? 4 : 4.h),
                          decoration: BoxDecoration(
                            color: widget.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                          ),
                          child: FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection("menu_items")
                                .where("restaurantId", isEqualTo: widget.restaurantId)
                                .where("categoryId", isEqualTo: cat.id)
                                .where("isAvailable", isEqualTo: true)
                                .get(),
                            builder: (context, snapshot) {
                              final itemCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                              return Text(
                                '$itemCount items',
                                style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 10 : 10.sp,
                                  fontWeight: FontWeight.w500,
                                  color: widget.primaryColor,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded) _buildMenuItemsList(cat.id),
              ],
            );
          },
        );
      },
    );
  }

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
        if (!snap.hasData) {
          return Column(
            children: [
              SizedBox(
                height: kIsWeb ? 56 : 56.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: kIsWeb ? 16 : 16.w,
                    vertical: kIsWeb ? 8 : 8.h,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) => const CategoryCardSkeleton(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: kIsWeb ? 8 : 8.h),
                  itemCount: 5,
                  itemBuilder: (context, index) => const MenuCardSkeleton(),
                ),
              ),
            ],
          );
        }

        final categories = snap.data!.docs;
        if (categories.isEmpty) return _emptyWidget('No Categories Found');

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
                  final isSelected = cat.id == widget.selectedCategoryId;
                  return GestureDetector(
                    onTap: () => widget.onCategorySelected(cat.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin:
                      EdgeInsets.only(right: kIsWeb ? 10 : 10.w),
                      padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 18 : 18.w,
                          vertical: kIsWeb ? 8 : 8.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? widget.primaryColor
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(
                            kIsWeb ? 24 : 24.sp),
                      ),
                      child: Center(
                        child: Text(cat['name'] ?? 'Category',
                            style: GoogleFonts.poppins(
                                fontSize: kIsWeb ? 13 : 13.sp,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87)),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.selectedCategoryId != null)
              Expanded(child: _buildMenuItemsList(widget.selectedCategoryId!))
            else
              Expanded(
                child: Center(
                  child: Text('Select a category',
                      style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 16 : 16.sp,
                          color: Colors.grey[500])),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMenuItemsList(String categoryId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("menu_items")
          .where("restaurantId", isEqualTo: widget.restaurantId)
          .where("categoryId", isEqualTo: categoryId)
          .where("isAvailable", isEqualTo: true)
          .orderBy("name")
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return _errorWidget('Error loading menu items', snap.error);
        if (!snap.hasData) {
          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: kIsWeb ? 8 : 8.h),
            itemCount: 5,
            itemBuilder: (context, index) => const MenuCardSkeleton(),
          );
        }

        final items = snap.data!.docs;
        if (items.isEmpty) return _emptyWidget('No Menu Items Available');

        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: kIsWeb ? 8 : 8.h),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            final itemId = item.id;
            final data = item.data() as Map<String, dynamic>;
            final List<dynamic> variants = data['variants'] as List<dynamic>? ?? [];
            final int selectedIndex = widget.selectedVariantIndexByItemId[itemId] ?? 0;
            final dynamic selectedVariant = variants.isNotEmpty ? variants[selectedIndex] : null;
            final int price = selectedVariant?['price'] ?? data['price'] ?? 0;
            final String variantName = selectedVariant?['name'] ?? '';

            if (widget.unifiedCategoryListView) {
              return _buildMenuCard(
                context: context,
                item: item,
                itemId: itemId,
                variants: variants,
                selectedIndex: selectedIndex,
                selectedVariant: selectedVariant,
                price: price,
                cardColor: Colors.white,
                textColor: Colors.black87,
                cardInfoColor: Colors.grey[600]!,
                primaryColor: widget.primaryColor,
              );
            } else {
              return _buildMenuGridCard(
                context: context,
                item: item,
                itemId: itemId,
                variants: variants,
                selectedIndex: selectedIndex,
                selectedVariant: selectedVariant,
                price: price,
                cardColor: Colors.white,
                textColor: Colors.black87,
                cardInfoColor: Colors.grey[600]!,
                primaryColor: widget.primaryColor,
              );
            }
          },
        );
      },
    );
  }

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

    final List<dynamic> v = variants;
    final int si = selectedIndex;
    final dynamic sv = v.isNotEmpty ? v[si] : null;
    final int safePrice = sv?['price'] ?? data['price'] ?? 0;
    final String variantName = sv?['name'] ?? '';

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
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                  child: SizedBox(
                    width: kIsWeb ? 72 : 72.w,
                    height: kIsWeb ? 72 : 72.h,
                    child: item['image'] != null && item['image'].toString().isNotEmpty
                        ? Image.network(item['image'].toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder())
                        : _imagePlaceholder(),
                  ),
                ),
                Positioned(top: 3, left: 3, child: _vegBadge(isVeg)),
              ],
            ),

            SizedBox(width: kIsWeb ? 10 : 10.w),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(item['name']?.toString() ?? "Item",
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

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _buildVariantDropdown(
                          itemId: itemId,
                          variants: v,
                          selectedIndex: si,
                        ),
                      ),
                      SizedBox(width: kIsWeb ? 8 : 8.w),
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

    final List<dynamic> v = variants;
    final int si = selectedIndex;
    final dynamic sv = v.isNotEmpty ? v[si] : null;
    final int safePrice = sv?['price'] ?? data['price'] ?? 0;
    final String variantName = sv?['name'] ?? '';

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

            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: kIsWeb ? 14 : 14.w,
                    vertical: kIsWeb ? 10 : 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name']?.toString() ?? "Item",
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

                    _buildVariantDropdown(
                      itemId: itemId,
                      variants: v,
                      selectedIndex: si,
                    ),

                    SizedBox(height: kIsWeb ? 8 : 8.h),

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

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(Icons.fastfood_rounded,
            color: Colors.grey[300], size: kIsWeb ? 36 : 36.sp),
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
    final selectedPrice = selected['price'] ?? 0;

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

    return GestureDetector(
      onTap: () {
        // Show variant selection dialog
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 10 : 10.w,
            vertical: kIsWeb ? 5 : 5.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
          border: Border.all(
              color: widget.primaryColor.withOpacity(0.45), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: kIsWeb ? 6 : 6.sp,
              height: kIsWeb ? 6 : 6.sp,
              decoration: BoxDecoration(
                  color:  widget.primaryColor, shape: BoxShape.circle),
            ),
            SizedBox(width: kIsWeb ? 6 : 6.w),
            Text(
              selectedName,
              style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 11 : 11.sp,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500),
            ),
            SizedBox(width: kIsWeb ? 5 : 5.w),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: kIsWeb ? 16 : 16.sp,
                color: widget.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOrCounterWidget(
      BuildContext context,
      QueryDocumentSnapshot item,
      String itemId,
      String variant,
      int price,
      ) {
    final qty = widget.getItemQuantity(itemId, variant);
    final isOpen = true;

    if (qty > 0) {
      return Container(
        height: kIsWeb ? 34 : 34.h,
        decoration: BoxDecoration(
          color: widget.primaryColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
          border: Border.all(color: widget.primaryColor.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => widget.updateItemQuantity(itemId, variant, -1,
                  itemName: item['name']?.toString(), price: price, image: item['image']?.toString()),
              child: Container(
                width: kIsWeb ? 32 : 32.w,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(kIsWeb ? 8 : 8.sp),
                    bottomLeft: Radius.circular(kIsWeb ? 8 : 8.sp),
                  ),
                ),
                child: Icon(Icons.remove,
                    size: kIsWeb ? 15 : 15.sp, color: widget.primaryColor),
              ),
            ),
            SizedBox(
              width: kIsWeb ? 34 : 34.w,
              child: Center(
                child: Text("$qty",
                    style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 13 : 13.sp,
                        fontWeight: FontWeight.w700,
                        color: widget.primaryColor)),
              ),
            ),
            GestureDetector(
              onTap: isOpen
                  ? () => widget.updateItemQuantity(itemId, variant, 1,
                  itemName: item['name']?.toString(),
                  price: price,
                  image: item['image']?.toString())
                  : () {},
              child: Container(
                width: kIsWeb ? 32 : 32.w,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(kIsWeb ? 8 : 8.sp),
                    bottomRight: Radius.circular(kIsWeb ? 8 : 8.sp),
                  ),
                ),
                child: Icon(Icons.add,
                    size: kIsWeb ? 15 : 15.sp, color: widget.primaryColor),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: isOpen
          ? () {
        widget.updateItemQuantity(itemId, variant, 1,
            itemName: item['name']?.toString(), price: price, image: item['image']?.toString());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${item['name']?.toString() ?? 'Item'} added to cart"),
          duration: const Duration(seconds: 2),
        ));
      }
          : () {},
      child: Container(
        height: kIsWeb ? 34 : 34.h,
        padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 18 : 18.w),
        decoration: BoxDecoration(
          color: isOpen ? widget.primaryColor : Colors.grey[400],
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

  Widget _errorWidget(String msg, Object? error) => Center(
    child: Padding(
      padding: EdgeInsets.all(kIsWeb ? 24 : 24.sp),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        SizedBox(height: kIsWeb ? 12 : 12.h),
        Text(msg,
            style: GoogleFonts.poppins(
                fontSize: kIsWeb ? 16 : 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.red)),
        if (error != null) ...[
          SizedBox(height: kIsWeb ? 6 : 6.h),
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
      SizedBox(height: kIsWeb ? 12 : 12.h),
      Text(msg,
          style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 16 : 16.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[400])),
    ]),
  );
}
