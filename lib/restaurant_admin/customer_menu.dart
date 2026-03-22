import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/restaurant_admin/track_order.dart';
import 'cart_page.dart';

Color hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  if (hex.length == 6) {
    hex = "FF$hex";
  }
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

  bool _unifiedCategoryListView = false;

  final Set<String> _collapsedCategoryIds = {};

  /// CART LIST
  final List<CartItem> cart = [];

  int getTotalCartQuantity() {
    int total = 0;
    for (var item in cart) {
      total += item.qty;
    }
    return total;
  }

  int getItemQuantity(String itemId, String variant) {
    int quantity = 0;
    for (var item in cart) {
      if (item.itemId == itemId && item.variant == variant) {
        quantity += item.qty;
      }
    }
    return quantity;
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
    return Card(
      color: cardColor,
      margin: EdgeInsets.symmetric(vertical: kIsWeb ? 4 : 4.sp),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWeb ? 10 : 10.sp),
        child: Row(
          children: [
            if (item['image'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                child: Image.network(
                  item['image'],
                  width: kIsWeb ? 80 : 80.w,
                  height: kIsWeb ? 80 : 80.h,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: kIsWeb ? 16 : 16.sp,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (variants.length > 1)
                    GestureDetector(
                      onTap: () => _showVariantPopup(
                        context,
                        item['name'],
                        variants,
                        selectedIndex,
                        itemId,
                        cardColor,
                        textColor,
                        cardInfoColor,
                        primaryColor,
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: kIsWeb ? 12 : 12.w, vertical: kIsWeb ? 8 : 8.h),
                        decoration: BoxDecoration(
                          color: cardInfoColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                          border: Border.all(
                            color: cardInfoColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              variants[selectedIndex]['name'],
                              style: GoogleFonts.poppins(
                                fontSize: kIsWeb ? 13 : 13.sp,
                                color: cardInfoColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: kIsWeb ? 16 : 16.sp,
                              color: cardInfoColor,
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (variants.isNotEmpty)
                    Text(
                      variants[0]['name'],
                      style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 13 : 13.sp,
                        fontWeight: FontWeight.bold,
                        color: cardInfoColor,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  "₹ $price",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: kIsWeb ? 16 : 16.sp,
                  ),
                ),
                SizedBox(height: 6.h),
                _buildAddOrCounterWidget(
                  context,
                  item,
                  itemId,
                  selectedVariant?['name'] ?? "",
                  price,
                  cardColor,
                  textColor,
                  cardInfoColor,
                  primaryColor,
                ),
              ],
            ),
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
      Color cardColor,
      Color textColor,
      Color cardInfoColor,
      Color primaryColor,
      ) {
    final itemQuantity = getItemQuantity(itemId, variant);

    if (itemQuantity > 0) {
      // Show counter widget
      return Container(
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Minus button
            GestureDetector(
              onTap: () {
                _updateItemQuantity(
                  itemId,
                  variant,
                  -1,
                  itemName: item['name'],
                  price: price,
                );
              },
              child: Container(
                width: kIsWeb ? 32 : 32.w,
                height: kIsWeb ? 32 : 32.h,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Icon(
                  Icons.remove,
                  color: primaryColor,
                  size: kIsWeb ? 16 : 16.sp,
                ),
              ),
            ),
            // Quantity display
            Container(
              width: kIsWeb ? 40 : 40.w,
              height: kIsWeb ? 32 : 32.h,
              alignment: Alignment.center,
              child: Text(
                "$itemQuantity",
                style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 14 : 14.sp,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
            // Plus button
            GestureDetector(
              onTap: () {
                _updateItemQuantity(
                  itemId,
                  variant,
                  1,
                  itemName: item['name'],
                  price: price,
                );
              },
              child: Container(
                width: kIsWeb ? 32 : 32.w,
                height: kIsWeb ? 32 : 32.h,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Icon(
                  Icons.add,
                  color: primaryColor,
                  size: kIsWeb ? 16 : 16.sp,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Show Add button
      return GestureDetector(
        onTap: () {
          _updateItemQuantity(
            itemId,
            variant,
            1,
            itemName: item['name'],
            price: price,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${item['name']} added to cart"),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "Add",
            style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 12 : 12.sp,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
  }

  void _updateItemQuantity(
      String itemId,
      String variant,
      int change, {
        String? itemName,
        int? price,
      }) {
    setState(() {
      // Find the cart item
      CartItem? existingItem;
      int itemIndex = -1;

      for (int i = 0; i < cart.length; i++) {
        if (cart[i].itemId == itemId && cart[i].variant == variant) {
          existingItem = cart[i];
          itemIndex = i;
          break;
        }
      }

      if (existingItem != null) {
        // Update existing item quantity
        existingItem.qty += change;

        if (existingItem.qty <= 0) {
          // Remove item if quantity is 0 or less
          cart.removeAt(itemIndex);
        } else if (existingItem.qty > 99) {
          // Limit to 99
          existingItem.qty = 99;
        }
      } else if (change > 0 && itemName != null && price != null) {
        // Add new item if change is positive and we have the required data
        cart.add(CartItem(
          itemId: itemId,
          name: itemName,
          variant: variant,
          price: price,
          qty: change,
        ));
      }
    });
  }

  void _showVariantPopup(
      BuildContext context,
      String itemName,
      List variants,
      int currentIndex,
      String itemId,
      Color cardColor,
      Color textColor,
      Color cardInfoColor,
      Color primaryColor,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Header with drag indicator
              Container(
                margin: EdgeInsets.only(top: kIsWeb ? 12 : 12.sp),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cardInfoColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(kIsWeb ? 2 : 2.sp),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(kIsWeb ? 20 : 20.sp),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Choose Variant",
                      style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 20 : 20.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      itemName,
                      style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 14 : 14.sp,
                        color: cardInfoColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    /// Variants list
                    ...variants.asMap().entries.map((entry) {
                      final index = entry.key;
                      final variant = entry.value;
                      final isSelected = index == currentIndex;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              currentIndex = index;
                            });
                            setState(() {
                              _selectedVariantIndexByItemId[itemId] = index;
                            });
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withOpacity(0.1)
                                  : cardInfoColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                              border: Border.all(
                                color: isSelected
                                    ? primaryColor
                                    : cardInfoColor.withOpacity(0.2),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                /// Radio button
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? primaryColor : cardInfoColor,
                                      width: 2,
                                    ),
                                    color: isSelected ? primaryColor : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? Icon(
                                    Icons.check,
                                    size: kIsWeb ? 32 : 32.sp,
                                    color: Colors.white,
                                  )
                                      : null,
                                ),
                                const SizedBox(width: 12),

                                /// Variant info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        variant['name'],
                                        style: GoogleFonts.poppins(
                                          fontSize: kIsWeb ? 16 : 16.sp,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected ? primaryColor : textColor,
                                        ),
                                      ),
                                      if (variant['price'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹${variant['price']}",
                                          style: GoogleFonts.poppins(
                                            fontSize: kIsWeb ? 14 : 14.sp,
                                            color: cardInfoColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                /// Selected indicator
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                    ),
                                    child: Text(
                                      "Selected",
                                      style: GoogleFonts.poppins(
                                        fontSize: kIsWeb ? 10 : 10.sp,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCounterPopup(
      BuildContext context,
      QueryDocumentSnapshot item,
      String itemId,
      String variant,
      int price,
      Color cardColor,
      Color textColor,
      Color cardInfoColor,
      Color primaryColor,
      ) {
    int quantity = 1;
    TextEditingController quantityController = TextEditingController(text: '1');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// Drag indicator
                  Container(
                    margin: EdgeInsets.only(top: kIsWeb ? 12 : 12.sp),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cardInfoColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(kIsWeb ? 2 : 2.sp),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(kIsWeb ? 20 : 20.sp),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Select Quantity",
                          style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 20 : 20.sp,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          item['name'],
                          style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 14 : 14.sp,
                            color: cardInfoColor,
                          ),
                        ),

                        if (variant.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            variant,
                            style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 12 : 12.sp,
                              color: cardInfoColor.withOpacity(0.8),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        /// Quantity Input
                        Container(
                          padding: EdgeInsets.all(kIsWeb ? 20 : 20.sp),
                          decoration: BoxDecoration(
                            color: cardInfoColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
                            border: Border.all(
                              color: cardInfoColor.withOpacity(0.2),
                            ),
                          ),
                          child: TextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 24 : 24.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            decoration: InputDecoration(
                              hintText: "Enter quantity",
                              hintStyle: GoogleFonts.poppins(
                                fontSize: kIsWeb ? 18 : 18.sp,
                                color: cardInfoColor.withOpacity(0.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                borderSide: BorderSide(
                                  color: cardInfoColor.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: kIsWeb ? 16 : 16.sp,
                                vertical: kIsWeb ? 16 : 16.sp,
                              ),
                            ),
                            onChanged: (value) {
                              final newQuantity = int.tryParse(value);
                              if (newQuantity != null && newQuantity >= 1 && newQuantity <= 99) {
                                setModalState(() {
                                  quantity = newQuantity;
                                });
                              }
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// Price display
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 16 : 16.sp, vertical: kIsWeb ? 12 : 12.sp),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total Price:",
                                style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 16 : 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                "₹ ${price * quantity}",
                                style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 18 : 18.sp,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// Add to cart button
                        SizedBox(
                          width: double.infinity,
                          height: kIsWeb ? 50 : 50.h,
                          child: ElevatedButton(
                            onPressed: () {
                              // Validate quantity from input field
                              final inputQuantity = int.tryParse(quantityController.text);
                              if (inputQuantity == null || inputQuantity < 1 || inputQuantity > 99) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Please enter a valid quantity (1-99)"),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }

                              cart.add(
                                CartItem(
                                  itemId: itemId,
                                  name: item['name'],
                                  variant: variant,
                                  price: price,
                                  qty: inputQuantity,
                                ),
                              );

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("${item['name']} x$inputQuantity added to cart"),
                                  duration: const Duration(seconds: 2),
                                ),
                              );

                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              "Add to Cart",
                              style: GoogleFonts.poppins(
                                fontSize: kIsWeb ? 16 : 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {

        bool? exit = await showDialog(
          context: context,
          builder: (context) {

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
              ),
              title: const Text("Exit Menu?"),
              content: const Text(
                "Are you sure you want to close the menu?",
              ),
              actions: [

                TextButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: const Text("Close"),
                ),

              ],
            );
          },
        );

        return exit ?? false;
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .doc(widget.restaurantId)
            .snapshots(),
        builder: (context, restaurantSnapshot) {
          print('DEBUG: Fetching restaurant with ID: ${widget.restaurantId}');

          if (restaurantSnapshot.hasError) {
            print('DEBUG: Restaurant snapshot error: ${restaurantSnapshot.error}');
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading restaurant data',
                      style: GoogleFonts.poppins(fontSize: kIsWeb ? 18 : 18.sp, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${restaurantSnapshot.error}',
                      style: GoogleFonts.poppins(fontSize: kIsWeb ? 14 : 14.sp, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!restaurantSnapshot.hasData) {
            print('DEBUG: Restaurant snapshot has no data');
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

          print('DEBUG: Restaurant snapshot has data');
          final rawData = restaurantSnapshot.data!.data();
          if (rawData == null) {
            print('DEBUG: Restaurant document data is null');
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body:  Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Restaurant not found',
                      style: TextStyle(fontSize: kIsWeb ? 18 : 18.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The restaurant document may have been deleted or you may not have permission to access it.',
                      style: TextStyle(fontSize: kIsWeb ? 14 : 14.sp, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          print('DEBUG: Restaurant data loaded successfully');
          final data = rawData as Map<String, dynamic>;

          final theme = data['theme'] ?? {};

          final bgColor = hexToColor(theme['backgroundColor'] ?? "#FAF5EF");
          final textColor = hexToColor(theme['textColor'] ?? "#000000");
          final cardColor = hexToColor(theme['cardColor'] ?? "#FFFFFF");
          final categoryBgColor =
          hexToColor(theme['categoryBackgroundColor'] ?? "#6D4C41");
          final categoryTextColor =
          hexToColor(theme['categoryTextColor'] ?? "#FFFFFF");
          final cardInfoColor =
          hexToColor(theme['cardInfoColor'] ?? "#757575");
          final primaryColor =
          hexToColor(theme['primaryColor'] ?? "#4CAF50");

          final logo = data['logo'];
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            floatingActionButton: cart.isEmpty
                ? null
                : FloatingActionButton.extended(
              backgroundColor: primaryColor,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CartPage(
                      cart: cart,
                      restaurantId: widget.restaurantId,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.shopping_cart,
                color: Colors.white,
              ),
              label: Text(
                "Cart (${getTotalCartQuantity()})",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: kIsWeb ? 16 : 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            /// Custom Header with Gradient Background
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  expandedHeight:  kIsWeb ? 80 : 80.sp,
                  pinned: false,
                  floating: false,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF7C3AED),
                            Color(0xFFA855F7),
                            Color(0xFFC084FC),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal:  kIsWeb ? 15 : 15.sp, vertical:  kIsWeb ? 10 : 10.sp),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              /// Top Row
                              Row(
                                children: [

                                  /// Logo
                                  if (logo != null && logo != "")
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                                      child: Image.network(
                                        logo,
                                        width: kIsWeb ? 50 : 50.sp,
                                        height: kIsWeb ? 50 : 50.sp,
                                        fit: BoxFit.cover,
                                      ),
                                    ),

                                  SizedBox(width: 8.sp),

                                  /// Restaurant Name
                                  Expanded(
                                    child: Text(
                                      data['name'] ?? "Restaurant",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: kIsWeb ? 18 : 18.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  /// Grid / List Toggle and Track Order
                                  Row(
                                    children: [
                                      /// Track Order Button
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TrackOrderPage(
                                                restaurantId: widget.restaurantId,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: kIsWeb ? 36 : 36.sp,
                                          height: kIsWeb ? 36 : 36.sp,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(18.sp),
                                          ),
                                          child: Icon(
                                            Icons.search_rounded,
                                            size: kIsWeb ? 18 : 18.sp,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),

                                      SizedBox(width: 8.sp),

                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _unifiedCategoryListView = false;
                                          });
                                        },
                                        child: Container(
                                          width: kIsWeb ? 36 : 36.sp,
                                          height: kIsWeb ? 36 : 36.sp,
                                          decoration: BoxDecoration(
                                            color: !_unifiedCategoryListView
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(18.sp),
                                          ),
                                          child: Icon(
                                            Icons.grid_view_rounded,
                                            size: kIsWeb ? 18 : 18.sp,
                                            color: !_unifiedCategoryListView
                                                ? const Color(0xFF7C3AED)
                                                : Colors.white,
                                          ),
                                        ),
                                      ),

                                      SizedBox(width: 8.sp),

                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _unifiedCategoryListView = true;
                                          });
                                        },
                                        child: Container(
                                          width: kIsWeb ? 36 : 36.sp,
                                          height: kIsWeb ? 36 : 36.sp,
                                          decoration: BoxDecoration(
                                            color: _unifiedCategoryListView
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(18.sp),
                                          ),
                                          child: Icon(
                                            Icons.view_agenda_rounded,
                                            size: kIsWeb ? 18 : 18.sp,
                                            color: _unifiedCategoryListView
                                                ? const Color(0xFF7C3AED)
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                /// Category Filter Section (only show in separate view)
                if (!_unifiedCategoryListView)
                  SliverToBoxAdapter(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("categories")
                          .where("restaurantId", isEqualTo: widget.restaurantId)
                          .orderBy("position")
                          .snapshots(),
                      builder: (context, categorySnapshot) {
                        print('DEBUG: Fetching categories for restaurant: ${widget.restaurantId}');

                        if (categorySnapshot.hasError) {
                          print('DEBUG: Categories snapshot error: ${categorySnapshot.error}');
                          return Padding(
                            padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                            child: Container(
                              padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red, size: 32),
                                  SizedBox(height: 8),
                                  Text(
                                    'Error loading categories',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${categorySnapshot.error}',
                                    style: GoogleFonts.poppins(
                                      fontSize: kIsWeb ? 12 : 12.sp,
                                      color: Colors.red.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (!categorySnapshot.hasData) {
                          print('DEBUG: Categories snapshot has no data');
                          return Padding(
                            padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                            child: const Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('Loading categories...'),
                                ],
                              ),
                            ),
                          );
                        }

                        final categories = categorySnapshot.data!.docs;
                        print('DEBUG: Found ${categories.length} categories');

                        // Auto-select first category if none is selected
                        if (_selectedCategoryId == null && categories.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              _selectedCategoryId = categories.first.id;
                              print('DEBUG: Auto-selected first category: ${categories.first.id}');
                            });
                          });
                        }

                        if (categories.isEmpty) {
                          print('DEBUG: No categories found for restaurant');
                          return Padding(
                            padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                            child: Container(
                              padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.category, color: Colors.orange, size: 32),
                                  SizedBox(height: 8),
                                  Text(
                                    'No Categories Found',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'This restaurant hasn\'t created any categories yet.',
                                    style: GoogleFonts.poppins(
                                      fontSize: kIsWeb ? 12 : 12.sp,
                                      color: Colors.orange.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Container(
                          margin: EdgeInsets.all(kIsWeb ? 8 : 8.sp),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                minHeight: kIsWeb ? 40 : 40.sp,
                                maxHeight: kIsWeb ? 40 : 40.sp
                            ),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                final bool isSelected = cat.id == _selectedCategoryId;

                                return Padding(
                                  padding: EdgeInsets.only(right: kIsWeb ? 8 : 8.sp),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedCategoryId = cat.id;
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:  kIsWeb ? 16 : 16.sp,
                                        vertical:  kIsWeb ? 8 : 8.sp,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF7C3AED) : Colors.white,
                                        borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20.sp),
                                        border: Border.all(color: const Color(0xFFE5E7EB)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isSelected)
                                            Padding(
                                              padding: EdgeInsets.only(right: 6.sp),
                                              child: Icon(Icons.check, size: kIsWeb ? 16 : 16.sp, color: Colors.white),
                                            ),
                                          Text(
                                            cat['name'],
                                            style: TextStyle(
                                              fontSize: kIsWeb ? 14 : 14.sp,
                                              fontWeight: FontWeight.w900,
                                              color: isSelected
                                                  ? Colors.white
                                                  : const Color(0xFF1F2937),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                SliverFillRemaining(
                  child: _unifiedCategoryListView
                      ? _buildUnifiedListView()
                      : _buildSeparateView(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnifiedListView() {
    print('DEBUG: Building unified list view for restaurant: ${widget.restaurantId}');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("categories")
          .where("restaurantId", isEqualTo: widget.restaurantId)
          .orderBy("position")
          .snapshots(),
      builder: (context, categorySnapshot) {
        print('DEBUG: Unified view - Fetching categories for restaurant: ${widget.restaurantId}');

        if (categorySnapshot.hasError) {
          print('DEBUG: Unified view - Categories snapshot error: ${categorySnapshot.error}');
          return Center(
            child: Container(
              padding: EdgeInsets.all(kIsWeb ? 24 : 24.sp),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Error loading categories',
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 18 : 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${categorySnapshot.error}',
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 14 : 14.sp,
                      color: Colors.red.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (!categorySnapshot.hasData) {
          print('DEBUG: Unified view - Categories snapshot has no data');
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading categories...'),
              ],
            ),
          );
        }

        final categories = categorySnapshot.data!.docs;
        print('DEBUG: Unified view - Found ${categories.length} categories');

        // Auto-select first category if none is selected (for unified view)
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedCategoryId = categories.first.id;
              print('DEBUG: Unified view - Auto-selected first category: ${categories.first.id}');
            });
          });
        }

        if (categories.isEmpty) {
          print('DEBUG: Unified view - No categories found');
          return Center(
            child: Container(
              padding: EdgeInsets.all(kIsWeb ? 32 : 32.sp),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category, color: Colors.orange, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No Categories Found',
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 20 : 20.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This restaurant hasn\'t created any categories yet.',
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 14 : 14.sp,
                      color: Colors.orange.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 8 : 8.h),
          itemCount: categories.length,
          itemBuilder: (context, catIndex) {
            final cat = categories[catIndex];
            final isExpanded = !_collapsedCategoryIds.contains(cat.id);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _collapsedCategoryIds.add(cat.id);
                      } else {
                        _collapsedCategoryIds.remove(cat.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4, right: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat['name'],
                            style: GoogleFonts.poppins(
                              fontSize: kIsWeb ? 18 : 18.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.black.withOpacity(0.6),
                          size: kIsWeb ? 25 : 25.sp,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("menu_items")
                        .where("restaurantId", isEqualTo: widget.restaurantId)
                        .where("categoryId", isEqualTo: cat.id)
                        .where("isAvailable", isEqualTo: true)
                        .orderBy("name")
                        .snapshots(),
                    builder: (context, menuSnapshot) {
                      print('DEBUG: Unified view - Fetching menu items for category: ${cat.id}');

                      if (menuSnapshot.hasError) {
                        print('DEBUG: Unified view - Menu items snapshot error: ${menuSnapshot.error}');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Error loading menu items',
                                    style: GoogleFonts.poppins(
                                      fontSize: kIsWeb ? 12 : 12.sp,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (!menuSnapshot.hasData) {
                        print('DEBUG: Unified view - Menu items snapshot has no data');
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 8),
                              Text('Loading menu items...'),
                            ],
                          ),
                        );
                      }

                      final items = menuSnapshot.data!.docs;
                      print('DEBUG: Unified view - Found ${items.length} menu items for category: ${cat.id}');

                      if (items.isEmpty) {
                        print('DEBUG: Unified view - No menu items found for category: ${cat.id}');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: EdgeInsets.all(kIsWeb ? 8 : 8.sp),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(kIsWeb ? 6 : 6.sp),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.restaurant_menu, color: Colors.grey, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "No available items in this category",
                                  style: GoogleFonts.poppins(
                                    fontSize: kIsWeb ? 12 : 12.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: items.map((item) {
                          final itemId = item.id;
                          final variants = (item.data() as Map<String, dynamic>)['variants'] ?? [];
                          final selectedIndex = _selectedVariantIndexByItemId[itemId] ?? 0;
                          final selectedVariant = variants.isNotEmpty ? variants[selectedIndex] : null;
                          final price = selectedVariant != null ? selectedVariant['price'] : item['price'];

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
                            cardInfoColor: Colors.grey,
                            primaryColor: const Color(0xFF7C3AED),
                          );
                        }).toList().cast<Widget>(),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSeparateView() {
    print('DEBUG: Building separate view for restaurant: ${widget.restaurantId}, category: ${_selectedCategoryId}');

    if (_selectedCategoryId == null) {
      print('DEBUG: No category selected in separate view');
      return Center(
        child: Container(
          padding: EdgeInsets.all(kIsWeb ? 32 : 32.sp),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.category, color: Colors.blue, size: 64),
              SizedBox(height: 16),
              Text(
                'Select a Category',
                style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 20 : 20.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please select a category from the options above to view menu items.',
                style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 14 : 14.sp,
                  color: Colors.blue.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("menu_items")
          .where("restaurantId", isEqualTo: widget.restaurantId)
          .where("categoryId", isEqualTo: _selectedCategoryId)
          .where("isAvailable", isEqualTo: true)
          .orderBy("name")
          .snapshots(),
      builder: (context, menuSnapshot) {
        print('DEBUG: Separate view - Fetching menu items for category: ${_selectedCategoryId}');

        if (menuSnapshot.hasError) {
          print('DEBUG: Separate view - Menu items snapshot error: ${menuSnapshot.error}');
          return Center(
            child: Container(
              padding: EdgeInsets.all(kIsWeb ? 24 : 24.sp),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Error loading menu items',
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 18 : 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${menuSnapshot.error}',
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 14 : 14.sp,
                      color: Colors.red.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (!menuSnapshot.hasData) {
          print('DEBUG: Separate view - Menu items snapshot has no data');
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading menu items...'),
              ],
            ),
          );
        }

        final items = menuSnapshot.data!.docs;
        print('DEBUG: Separate view - Found ${items.length} menu items');

        if (items.isEmpty) {
          print('DEBUG: Separate view - No menu items found for category: ${_selectedCategoryId}');
          return Center(
            child: Container(
              padding: EdgeInsets.all(kIsWeb ? 32 : 32.sp),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_menu, color: Colors.orange, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No Menu Items Available',
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 20 : 20.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No available menu items in this category.\nTry selecting a different category or check back later.',
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 14 : 14.sp,
                      color: Colors.orange.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final itemId = item.id;
            final variants = (item.data() as Map<String, dynamic>)['variants'] ?? [];
            final selectedIndex = _selectedVariantIndexByItemId[itemId] ?? 0;
            final selectedVariant = variants.isNotEmpty ? variants[selectedIndex] : null;
            final price = selectedVariant != null ? selectedVariant['price'] : item['price'];

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
              cardInfoColor: Colors.grey,
              primaryColor: const Color(0xFF7C3AED),
            );
          },
        );
      },
    );
  }

  void showTrackOrderPopup(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    TextEditingController tokenController = TextEditingController();
    String? token;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Material(
                borderRadius: BorderRadius.circular(kIsWeb ? 24 : 24.sp),
                elevation: 24,
                shadowColor: Colors.black26,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(kIsWeb ? 24 : 24.sp),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(kIsWeb ? 24 : 24.sp),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withOpacity(0.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.delivery_dining_rounded,
                                  size: kIsWeb ? 28 : 28.sp,
                                  color: colorScheme.primary,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  "Track your order",
                                  style: GoogleFonts.poppins(
                                    fontSize: kIsWeb ? 20 : 20.sp,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                  size: kIsWeb ? 22 : 22.sp,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Body
                        Padding(
                          padding:  EdgeInsets.all(24.sp),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "Enter your order token to see status and details.",
                                style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 14 : 14.sp,
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4.h,
                                ),
                              ),
                              SizedBox(height: 20.h),
                              TextField(
                                controller: tokenController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.poppins(
                                  fontSize: kIsWeb ? 16 : 16.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Token number",
                                  hintText: "e.g. 4521",
                                  prefixIcon: Icon(
                                    Icons.tag_rounded,
                                    size: kIsWeb ? 22 : 22.sp,
                                    color: colorScheme.primary,
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4.sp),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.3.sp),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  labelStyle: GoogleFonts.poppins(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              SizedBox(height: 20.h),
                              FilledButton(
                                onPressed: () {
                                  setStateDialog(() {
                                    token = tokenController.text.trim();
                                  });
                                },
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  "Track order",
                                  style: GoogleFonts.poppins(
                                    fontSize: kIsWeb ? 16 : 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (token != null && token!.isNotEmpty) ...[
                                SizedBox(height: 24.h),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection("orders")
                                      .where("restaurantId", isEqualTo: widget.restaurantId)
                                      .where("tokenNumber", isEqualTo: int.tryParse(token!) ?? token)
                                      .limit(1)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return Padding(
                                        padding:  EdgeInsets.symmetric(vertical: 24.h),
                                        child: Center(
                                          child: SizedBox(
                                            width: kIsWeb ? 32 : 32.sp,
                                            height: kIsWeb ? 32 : 32.sp,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return Container(
                                        padding: EdgeInsets.all(kIsWeb ? 20 : 20.sp),
                                        decoration: BoxDecoration(
                                          color: colorScheme.errorContainer.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.search_off_rounded,
                                              color: colorScheme.error,
                                              size: kIsWeb ? 24 : 24.sp,
                                            ),
                                            SizedBox(width: 12.w),
                                            Expanded(
                                              child: Text(
                                                "No order found for this token.",
                                                style: GoogleFonts.poppins(
                                                  fontSize: kIsWeb ? 14 : 14.sp,
                                                  color: colorScheme.onErrorContainer,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    var order = snapshot.data!.docs.first;
                                    final status = (order['status'] ?? 'pending').toString().toLowerCase();
                                    final statusColor = status == 'delivered'
                                        ? colorScheme.primary
                                        : status == 'cancelled'
                                        ? colorScheme.error
                                        : colorScheme.tertiary;
                                    return Container(
                                      padding:  EdgeInsets.all(20.sp),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
                                        borderRadius: BorderRadius.circular(16.sp),
                                        border: Border.all(
                                          color: colorScheme.outline.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:  EdgeInsets.symmetric(horizontal: 12.h, vertical: 6.w),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(10.sp),
                                                ),
                                                child: Text(
                                                  "Token #${order['tokenNumber']}",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: kIsWeb ? 15 : 15.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding:  EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                                                ),
                                                child: Text(
                                                  (order['status'] ?? 'Pending').toString(),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: kIsWeb ? 13 : 13.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 16.h),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Total amount",
                                                style: GoogleFonts.poppins(
                                                  fontSize: kIsWeb ? 13 : 13.sp,
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              Text(
                                                "₹${order['totalAmount'] ?? '—'}",
                                                style: GoogleFonts.poppins(
                                                  fontSize: kIsWeb ? 18 : 18.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}