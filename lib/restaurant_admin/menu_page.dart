import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../uttils/responsive.dart';

class MenuPage extends StatefulWidget {
  final String restaurantId;

  const MenuPage({super.key, required this.restaurantId});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {

  XFile? pickedImage;
  Uint8List? imageBytes;

  final String apiKey = "a923bc17d28cd6fe1be417700456eb69";
  String? _selectedCategoryId;
  String _searchQuery = "";

  /// View mode: false = grid view, true = list view
  bool _isListView = false;

  /// Loading state for add menu item
  bool _isAddingMenuItem = false;

  /// Loading state for edit menu item
  bool _isEditingMenuItem = false;

  /// Pick Image
  Future<void> pickImage() async {

    final picker = ImagePicker();

    final XFile? image =
    await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {

      pickedImage = image;
      imageBytes = await image.readAsBytes();

      setState(() {});
    }
  }

  /// Upload Image
  Future<String?> uploadImageToImgBB() async {

    if (imageBytes == null) return null;

    try {

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("https://api.imgbb.com/1/upload?key=$apiKey"),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes!,
          filename: "menu.jpg",
        ),
      );

      var response = await request.send();

      var responseData = await response.stream.bytesToString();

      var jsonData = json.decode(responseData);

      return jsonData['data']['url'];

    } catch (e) {
      if (kDebugMode) {
        print("UPLOAD ERROR $e");
      }
      return null;
    }
  }

  /// Add Menu Item
  void addMenuItem() {

    TextEditingController nameController = TextEditingController();
    String? selectedCategoryId = _selectedCategoryId;

    List<Map<String, TextEditingController>> variants = [
      {
        "name": TextEditingController(),
        "price": TextEditingController(),
      }
    ];

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isMobile = Responsive.isMobile(context);
        final isTablet = Responsive.isTablet(context);
        final isDesktop = Responsive.isDesktop(context);
        final screenWidth = Responsive.width(context);

        return StatefulBuilder(
          builder: (context, setStateDialog) {

            double dialogWidth = screenWidth * 0.9;
            double maxHeight = MediaQuery.of(context).size.height * 0.9;

            if (isDesktop) {
              dialogWidth = screenWidth > 1200 ? 700 : 600;
            } else if (isTablet) {
              dialogWidth = screenWidth * 0.8;
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
              ),
              backgroundColor: colorScheme.surface,
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxHeight: maxHeight,
                ),
                child: Column(
                  children: [
                    headerWidget(context),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            imageUploadWidget(() async {
                              await pickImage();
                              setStateDialog(() {});
                            }),

                            SizedBox(height: kIsWeb ? 20 : 20.sp),

                            /// CATEGORY
                            categoryDropdown(
                              selectedCategoryId,
                              widget.restaurantId,
                                  (value) {
                                setStateDialog(() {
                                  selectedCategoryId = value;
                                });
                              },
                            ),

                            itemNameField(nameController),

                            SizedBox(height: kIsWeb ? 15 : 24.sp),

                            variantsWidget(
                              variants,
                                  () {
                                setStateDialog(() {});
                              },
                            ),

                          ],
                        ),
                      ),
                    ),
                    footerButtons(
                      context: context,
                      selectedCategoryId: selectedCategoryId,
                      nameController: nameController,
                      variants: variants,
                      restaurantId: widget.restaurantId,
                      uploadImage: uploadImageToImgBB,
                      isLoading: _isAddingMenuItem,
                      setLoading: (loading) {
                        setState(() {
                          _isAddingMenuItem = loading;
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget footerButtons({
    required BuildContext context,
    required String? selectedCategoryId,
    required TextEditingController nameController,
    required List<Map<String, TextEditingController>> variants,
    required String restaurantId,
    required Future<String?> Function() uploadImage,
    required bool isLoading,
    required Function(bool) setLoading,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return Container(
      padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(isMobile ? 16 : 20),
        ),
      ),
      child: Row(
        children: [

          /// Cancel Button
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: kIsWeb ? 12 : 12),
                side: BorderSide(color: colorScheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                ),
              ),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                  fontSize: kIsWeb ? 14 : 14.sp,
                ),
              ),
            ),
          ),

          SizedBox(width: kIsWeb ? 10 : 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLoading ? null : () async {

                if (selectedCategoryId == null ||
                    nameController.text.isEmpty) {

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Please fill all required fields"),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                      ),
                    ),
                  );
                  return;
                }

                setLoading(true);

                try {
                  /// Upload Image
                  String? imageUrl = await uploadImage();

                  /// Prepare Variants
                  List<Map<String, dynamic>> variantList = [];

                  for (var v in variants) {
                    variantList.add({
                      "name": v["name"]!.text,
                      "price": int.parse(v["price"]!.text),
                    });
                  }

                  /// Save to Firestore
                  await FirebaseFirestore.instance
                      .collection("menu_items")
                      .add({
                    "name": nameController.text,
                    "image": imageUrl,
                    "categoryId": selectedCategoryId,
                    "restaurantId": restaurantId,
                    "variants": variantList,
                    "isAvailable": true,
                    "createdAt": FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);

                  // Automatically select the category of the newly added item
                  setState(() {
                    _selectedCategoryId = selectedCategoryId;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Menu item added successfully!"),
                      backgroundColor: colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error adding menu item: $e"),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                      ),
                    ),
                  );
                } finally {
                  setLoading(false);
                }
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(vertical: kIsWeb ? 12 : 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                ),
              ),

              child: isLoading
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: kIsWeb ? 16 : 16,
                    height: kIsWeb ? 16 : 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: kIsWeb ? 8 : 8),
                  Text(
                    "Adding...",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: kIsWeb ? 14 : 14.sp,
                    ),
                  ),
                ],
              )
                  : Text(
                "Save Menu Item",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: kIsWeb ? 14 : 14.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget variantsWidget(
      List<Map<String, TextEditingController>> variants,
      VoidCallback refresh,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// Title
        Row(
          children: [
            Icon(
              Icons.list_alt,
              color: colorScheme.onSurface.withOpacity(0.7),
              size: kIsWeb ? 18 : 18.sp,
            ),
            SizedBox(width: kIsWeb ? 6 : 6.sp),
            Text(
              "Variants",
              style: TextStyle(
                fontSize: kIsWeb ? 14 : 14.sp,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),

        SizedBox(height: kIsWeb ? 10 : 10.sp),

        /// Variant List
        ...variants.asMap().entries.map((entry) {

          final index = entry.key;

          return Container(
            margin:  EdgeInsets.only(bottom: kIsWeb ? 12 : 12.sp),
            padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
              border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
            ),
            child: Row(
              children: [

                /// Variant Name
                Expanded(
                  child: TextField(
                    controller: variants[index]["name"],
                    decoration: InputDecoration(
                      labelText: "Variant Name",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:  EdgeInsets.symmetric(
                        horizontal: kIsWeb ? 12 : 12.sp,
                        vertical: kIsWeb ? 8 : 8.sp,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: kIsWeb ? 12 : 12.sp),

                /// Price
                SizedBox(
                  width: kIsWeb ? 100 : 100.sp,
                  child: TextField(
                    controller:
                    variants[index]["price"],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Price",
                      prefixText: "₹",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:  EdgeInsets.symmetric(
                        horizontal: kIsWeb ? 10 : 10.sp,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: kIsWeb ? 6 : 6.sp),

                /// Remove Button
                if (variants.length > 1)
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: colorScheme.error,
                    ),
                    onPressed: () {
                      variants.removeAt(index);
                      refresh();
                    },
                  ),
              ],
            ),
          );
        }),

        SizedBox(height: kIsWeb ? 10 : 10.sp),

        /// Add Variant Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              variants.add({
                "name": TextEditingController(),
                "price": TextEditingController(),
              });
              refresh();
            },
            icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
            label: Text(
              "Add Another Variant",
              style: TextStyle(color: colorScheme.primary),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: kIsWeb ? 12 : 12.sp),
              side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget itemNameField(TextEditingController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Item Name",
          style: TextStyle(
            fontSize: kIsWeb ? 12 : 14.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: kIsWeb ? 6 : 8.sp),

        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter item name",
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
              borderSide: BorderSide(color: colorScheme.primary),
            ),

            prefixIcon: Icon(
              Icons.restaurant,
              color: colorScheme.onSurface.withOpacity(0.5),
              size: kIsWeb ? 20 : 22.sp,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 16 : 20.sp,
              vertical: kIsWeb ? 12 : 16.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget categoryDropdown(
      String? selectedCategoryId,
      String restaurantId,
      Function(String?) onChanged,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Category",
          style: TextStyle(
            fontSize: kIsWeb ? 12 : 14.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: kIsWeb ? 6 : 8.sp),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("categories")
              .where("restaurantId", isEqualTo: restaurantId)
              .snapshots(),
          builder: (context, snapshot) {

            if (!snapshot.hasData) {
              return Container(
                height:  kIsWeb ? 40 : 50.sp,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                ),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: kIsWeb ? 2 : 2.sp),
                ),
              );
            }

            final categories = snapshot.data!.docs;

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCategoryId,
                  hint: Padding(
                    padding:  EdgeInsets.symmetric(horizontal: kIsWeb ? 8 : 12.sp, vertical: kIsWeb ? 8 : 8.sp),
                    child: Text(
                      "Select Category",
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  ),
                  isExpanded: true,
                  padding:  EdgeInsets.symmetric(horizontal: kIsWeb ? 8 : 12.sp, vertical: kIsWeb ? 5 : 8.sp),

                  items: categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.id,
                      child: Text(
                        cat['name'],
                        style:  TextStyle(fontSize: kIsWeb ? 12 : 15.sp),
                      ),
                    );
                  }).toList(),

                  onChanged: onChanged,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget imageUploadWidget(VoidCallback onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width:  kIsWeb ? 120 : 140.sp,
          height: kIsWeb ? 80 : 80.sp,
          decoration: BoxDecoration(
            color: pickedImage == null
                ? colorScheme.surfaceVariant.withOpacity(0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
            border: Border.all(
              color: pickedImage == null
                  ? colorScheme.outline.withOpacity(0.3)
                  : colorScheme.primary,
              width: 2,
            ),
            boxShadow: pickedImage == null
                ? null
                : [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: pickedImage == null
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size:kIsWeb ? 32 : 40.sp,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
              SizedBox(height: kIsWeb  ? 6 : 8.sp),
              Text(
                "Upload Image",
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: kIsWeb ? 12 : 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ) : ClipRRect(
              borderRadius: BorderRadius.circular(kIsWeb ?  10 : 14.sp),
              child: buildImage(imageBytes, colorScheme, isMobile)
          ),
        ),
      ),
    );
  }

  /// Delete Menu
  void deleteMenuItem(String id, String itemName) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 8.sp : 10.sp),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
              ),
              child: Icon(
                Icons.delete_outline,
                color: colorScheme.error,
                size: kIsWeb ? 20 : 20.sp,
              ),
            ),
            SizedBox(width: isMobile ? 10.sp : 12.sp),
            Expanded(
              child: Text(
                "Delete Menu Item",
                style: TextStyle(
                  fontSize: isMobile ? 16.sp : 18.sp,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Are you sure you want to delete this menu item?",
              style: TextStyle(
                fontSize: kIsWeb ? 14 : 14.sp,
                color: colorScheme.onSurface,
              ),
            ),
            if (itemName.isNotEmpty) ...[
              SizedBox(height: isMobile ? 8.sp : 12.sp),
              Container(
                padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.restaurant,
                      color: colorScheme.onSurface.withOpacity(0.6),
                      size: kIsWeb ? 16 : 16.sp,
                    ),
                    SizedBox(width: isMobile ? 8.sp : 10.sp),
                    Expanded(
                      child: Text(
                        itemName,
                        style: TextStyle(
                          fontSize: isMobile ? 14.sp : 15.sp,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: isMobile ? 12.sp : 16.sp),
            Text(
              "This action cannot be undone.",
              style: TextStyle(
                fontSize: kIsWeb ? 12 : 12.sp,
                color: colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16.sp : 20.sp,
                vertical: isMobile ? 10.sp : 12.sp,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
              ),
            ),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? 14.sp : null,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await FirebaseFirestore.instance
                    .collection("menu_items")
                    .doc(id)
                    .delete();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Menu item deleted successfully"),
                      backgroundColor: colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error deleting menu item: $e"),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16.sp : 20.sp,
                vertical: isMobile ? 10.sp : 12.sp,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
              ),
            ),
            child: Text(
              "Delete",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 14.sp : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// EDIT MENU ITEM
  void editMenuItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    TextEditingController nameController =
    TextEditingController(text: data['name'] ?? '');
    String? selectedCategoryId = data['categoryId'];

    String? imageUrl = (data['image'] ?? '') as String?;
    Uint8List? newImageBytes;

    List<Map<String, TextEditingController>> variantsControllers = [];
    final List variants = data['variants'] ?? [];

    if (variants.isEmpty) {
      variantsControllers = [
        {
          "name": TextEditingController(),
          "price": TextEditingController(),
        }
      ];
    } else {
      for (var v in variants) {
        variantsControllers.add({
          "name": TextEditingController(text: v['name']?.toString() ?? ''),
          "price":
          TextEditingController(text: v['price']?.toString() ?? ''),
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isTablet = Responsive.isTablet(context);
        final isDesktop = Responsive.isDesktop(context);
        final screenWidth = Responsive.width(context);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool isEditing = _isEditingMenuItem;
            // Responsive dialog sizing

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
              ),
              backgroundColor: colorScheme.surface,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 500,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(kIsWeb ?  16 : 20.sp),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primaryContainer,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(kIsWeb ? 16 : 20.sp),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(kIsWeb ? 8 : 10.sp),
                            decoration: BoxDecoration(
                              color: colorScheme.onPrimary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: colorScheme.onPrimary,
                              size: kIsWeb ? 20 : 20.sp,
                            ),
                          ),
                          SizedBox(width: kIsWeb ? 10 : 12.sp),
                          Expanded(
                            child: Text(
                              "Edit Menu Item",
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: kIsWeb ? 18 : 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// Content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Item Image",
                              style: TextStyle(
                                fontSize: kIsWeb ? 14 : 14.sp,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: kIsWeb ? 10 : 10.sp),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: kIsWeb ? 120 : 120.sp,
                                  height: kIsWeb ? 120 : 120.sp,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                                    border: Border.all(
                                      color: colorScheme.outline.withOpacity(0.3),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                    child: newImageBytes != null
                                        ? Image.memory(
                                      newImageBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )
                                        : (imageUrl != null && imageUrl.isNotEmpty
                                        ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFF3F4F6),
                                                Color(0xFFE5E7EB),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                  : null,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                colorScheme.onSurface.withOpacity(0.4),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFF3F4F6),
                                                Color(0xFFE5E7EB),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.broken_image,
                                            color: colorScheme.onSurface.withOpacity(0.4),
                                            size: kIsWeb ? 30 : 30.sp,
                                          ),
                                        );
                                      },
                                    )
                                        : Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFF3F4F6),
                                            Color(0xFFE5E7EB),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.restaurant,
                                        color: colorScheme.onSurface.withOpacity(0.4),
                                        size: kIsWeb ? 30 : 30.sp,
                                      ),
                                    )),
                                  ),
                                ),
                                SizedBox(width: kIsWeb ? 12 : 16.sp),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Upload or change dish image. This image is shown in customer menu.",
                                        style: TextStyle(
                                          fontSize: kIsWeb ? 12 : 12.sp,
                                          color: colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                      SizedBox(height: kIsWeb ? 10 : 10.sp),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final picker = ImagePicker();
                                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                          if (image != null) {
                                            final bytes = await image.readAsBytes();
                                            setStateDialog(() {
                                              newImageBytes = bytes;
                                            });
                                          }
                                        },
                                        icon: Icon(
                                          Icons.image_outlined,
                                          color: colorScheme.primary,
                                          size: kIsWeb ? 18 : 18.sp,
                                        ),
                                        label: Text(
                                          imageUrl != null && imageUrl.isNotEmpty
                                              ? "Change Image"
                                              : "Upload Image",
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                            fontSize: kIsWeb ? 12 : 12.sp,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: kIsWeb ? 16 : 20.sp,
                                            vertical: kIsWeb ? 10 : 12.sp,
                                          ),
                                          side: BorderSide(
                                            color: colorScheme.primary.withOpacity(0.5),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: kIsWeb ? 10 : 20.sp),
                            /// CATEGORY SELECTION
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection("categories")
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return Container(
                                    height: kIsWeb ? 50 : 50.sp,
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceVariant.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                    ),
                                    child:  Center(
                                      child: CircularProgressIndicator(strokeWidth: kIsWeb ? 2 : 2.sp),
                                    ),
                                  );
                                }

                                final categories = snapshot.data!.docs;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                    border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedCategoryId,
                                      hint: Padding(
                                        padding:  EdgeInsets.symmetric(horizontal: kIsWeb ? 12 : 12.sp, vertical: kIsWeb ? 8 : 8.sp),
                                        child: Text(
                                          "Select Category",
                                          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                                        ),
                                      ),
                                      isExpanded: true,
                                      padding:  EdgeInsets.symmetric(horizontal: kIsWeb ? 12 : 12.sp, vertical: kIsWeb ? 8 : 8.sp),

                                      items: categories.map((cat) {
                                        return DropdownMenuItem<String>(
                                          value: cat.id,
                                          child: Text(
                                              cat['name'],
                                              style:  TextStyle(fontSize: kIsWeb ? 12 : 15.sp)
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setStateDialog(() {
                                          selectedCategoryId = value;
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height:kIsWeb ? 20 : 20.sp),

                            /// ITEM NAME
                            Text(
                              "Item Name",
                              style: TextStyle(
                                fontSize: kIsWeb ? 14 : 16.sp,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: kIsWeb ? 8 : 8.sp),
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                hintText: "Enter item name",
                                filled: true,
                                fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                  borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12),
                                  borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                  borderSide: BorderSide(color: colorScheme.primary),
                                ),
                                prefixIcon: Icon(
                                  Icons.restaurant,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ),

                            SizedBox(height: kIsWeb ? 24 : 24.sp),

                            /// VARIANTS SECTION
                            Row(
                              children: [
                                Icon(
                                  Icons.list_alt,
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                  size:  kIsWeb ? 20 : 20.sp,
                                ),
                                SizedBox(width:  kIsWeb ? 8 : 8.sp),
                                Text(
                                  "Variants",
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 12 : 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: kIsWeb ? 12 : 12.sp),

                            /// VARIANTS LIST
                            ...variantsControllers.asMap().entries.map((entry) {
                              final index = entry.key;
                              return Container(
                                margin:  EdgeInsets.only(bottom: kIsWeb ? 12 : 12.sp),
                                padding:  EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                  border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller:
                                        variantsControllers[index]["name"],
                                        decoration: InputDecoration(
                                          labelText: "Variant Name",
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:  EdgeInsets.symmetric(
                                            horizontal:  kIsWeb ? 12 : 12.sp,
                                            vertical:  kIsWeb ? 8 : 8.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: kIsWeb ? 12 : 12.sp),
                                    SizedBox(
                                      width: kIsWeb ? 100 : 100.sp,
                                      child: TextField(
                                        controller:
                                        variantsControllers[index]["price"],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: "Price",
                                          prefixText: "₹",
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:  EdgeInsets.symmetric(
                                            horizontal: kIsWeb ? 10 : 10.sp,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: kIsWeb ? 10 : 10.sp),
                                    if (variantsControllers.length > 1)
                                      IconButton(
                                        icon: Icon(
                                          Icons.remove_circle_outline,
                                          color: colorScheme.error,
                                        ),
                                        onPressed: () {
                                          variantsControllers.removeAt(index);
                                          setStateDialog(() {});
                                        },
                                      ),
                                  ],
                                ),
                              );
                            }),
                            SizedBox(height: kIsWeb ? 12 : 12.sp),
                            /// ADD VARIANT BUTTON
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  variantsControllers.add({
                                    "name": TextEditingController(),
                                    "price": TextEditingController(),
                                  });
                                  setStateDialog(() {});
                                },
                                icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                                label: Text(
                                  "Add Another Variant",
                                  style: TextStyle(color: colorScheme.primary),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: kIsWeb ? 12 : 12.sp),
                                  side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    /// ACTIONS
                    Container(
                      padding:  EdgeInsets.all(kIsWeb ? 20 : 20.sp),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius:  BorderRadius.vertical(
                          bottom: Radius.circular(kIsWeb ? 20 : 20.sp),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:  EdgeInsets.symmetric(vertical: kIsWeb ? 14 : 12.sp),
                                side: BorderSide(color: colorScheme.outline),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: kIsWeb ? 12 : 12.sp),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isEditing ? null : () async {
                                if (selectedCategoryId == null ||
                                    nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text("Please fill all required fields"),
                                      backgroundColor: colorScheme.error,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setState(() {
                                  _isEditingMenuItem = true;
                                });
                                setStateDialog(() {
                                  isEditing = true;
                                });

                                try {
                                  /// Prepare variants
                                  final List<Map<String, dynamic>> updatedVariants = [];
                                  for (var v in variantsControllers) {
                                    final name = v["name"]!.text.trim();
                                    final priceText = v["price"]!.text.trim();
                                    if (name.isEmpty || priceText.isEmpty) continue;
                                    updatedVariants.add({
                                      "name": name,
                                      "price": int.tryParse(priceText) ?? 0,
                                    });
                                  }

                                  String? finalImageUrl = imageUrl;
                                  if (newImageBytes != null) {
                                    try {
                                      var request = http.MultipartRequest(
                                        'POST',
                                        Uri.parse("https://api.imgbb.com/1/upload?key=$apiKey"),
                                      );

                                      request.files.add(
                                        http.MultipartFile.fromBytes(
                                          'image',
                                          newImageBytes!,
                                          filename: "menu.jpg",
                                        ),
                                      );

                                      var response = await request.send();
                                      var responseData = await response.stream.bytesToString();
                                      var jsonData = json.decode(responseData);
                                      final uploadedUrl = jsonData['data']['url'];

                                      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                                        finalImageUrl = uploadedUrl;
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text("Failed to upload image"),
                                              backgroundColor: colorScheme.error,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (kDebugMode) {
                                        print("UPLOAD ERROR $e");
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text("Failed to upload image"),
                                            backgroundColor: colorScheme.error,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }

                                  await FirebaseFirestore.instance
                                      .collection("menu_items")
                                      .doc(doc.id)
                                      .update({
                                    "name": nameController.text.trim(),
                                    "categoryId": selectedCategoryId,
                                    "variants": updatedVariants,
                                    "image": finalImageUrl ?? imageUrl ?? '',
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text("Menu item updated successfully!"),
                                        backgroundColor: colorScheme.primary,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Error updating menu item: $e"),
                                        backgroundColor: colorScheme.error,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  setState(() {
                                    _isEditingMenuItem = false;
                                  });
                                  setStateDialog(() {
                                    isEditing = false;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12),
                                ),
                              ),
                              child: isEditing
                                  ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Updating...",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                                  : const Text(
                                "Update Menu Item",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
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
      },
    );
  }

  Future<void> toggleAvailability(String id, bool value) async {
    await FirebaseFirestore.instance
        .collection("menu_items")
        .doc(id)
        .update({"isAvailable": value});
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFF6F7FB),
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 28 : 16,
                isDesktop ? 20 : 14,
                isDesktop ? 28 : 16,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Home / Menu Items',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Menu Items',
                        style: TextStyle(
                          fontSize: isDesktop ? 42 : 30,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1C),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: addMenuItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF070B2D),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Add Menu Item',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 44,
                    width: isDesktop ? 400 : double.infinity,
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim().toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search menu items...',
                        hintStyle: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFFAAAAAA),
                          size: 20,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F3F6),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFF1F3F6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("categories")
                  .where("restaurantId", isEqualTo: widget.restaurantId)
                  .snapshots(),
              builder: (context, catSnapshot) {
                if (!catSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final categories = catSnapshot.data!.docs;
                final Map<String, String> categoryMap = {
                  for (final c in categories)
                    c.id: ((c.data() as Map<String, dynamic>)["name"] ?? "").toString(),
                };

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("menu_items")
                      .where("restaurantId", isEqualTo: widget.restaurantId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            "Failed to load menu: ${snapshot.error}",
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allItems = snapshot.data!.docs;
                    final items = allItems.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final desc =
                          (data['description'] ?? '').toString().toLowerCase();
                      final categoryId =
                          (data['categoryId'] ?? '').toString().toLowerCase();
                      final categoryName =
                          (categoryMap[categoryId] ?? '').toLowerCase();
                      if (_searchQuery.isEmpty) return true;
                      return name.contains(_searchQuery) ||
                          desc.contains(_searchQuery) ||
                          categoryName.contains(_searchQuery);
                    }).toList();

                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(28, 20, 28, 30),
                        child: Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? "No menu items"
                                : "No results for your search",
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      );
                    }

                    final isTablet = Responsive.isTablet(context);
                    final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 28 : 16,
                        10,
                        isDesktop ? 28 : 16,
                        30,
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: isDesktop ? 0.72 : 0.76,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final doc = items[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final List variants = (data['variants'] ?? []) as List;
                          final String name = (data['name'] ?? '').toString();
                          final String imageUrl = (data['image'] ?? '').toString();
                          final String description =
                              (data['description'] ?? '').toString();
                          final String categoryId =
                              (data['categoryId'] ?? '').toString();
                          final String categoryName =
                              (categoryMap[categoryId] ?? '').toString();
                          final num firstPrice = variants.isNotEmpty
                              ? (variants.first['price'] ?? 0) as num
                              : 0;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(14),
                                    ),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                              color: const Color(0xFFF3F4F6),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.fastfood_rounded,
                                                  color: Color(0xFFCCCCCC),
                                                  size: 36,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: const Color(0xFFF3F4F6),
                                            child: const Center(
                                              child: Icon(
                                                Icons.fastfood_rounded,
                                                color: Color(0xFFCCCCCC),
                                                size: 36,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1A1A1A),
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => editMenuItem(doc),
                                              child: Icon(
                                                Icons.edit_outlined,
                                                size: 17,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () =>
                                                  deleteMenuItem(doc.id, name),
                                              child: const Icon(
                                                Icons.delete_outline,
                                                size: 17,
                                                color: Color(0xFFEF4444),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (categoryName.isNotEmpty)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF2F3F5),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              categoryName,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF222B38),
                                              ),
                                            ),
                                          ),
                                        if (description.isNotEmpty)
                                          Text(
                                            description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6B7280),
                                              height: 1.4,
                                            ),
                                          ),
                                        const Spacer(),
                                        Text(
                                          '\$${firstPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFE8650A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }
}

Widget buildImage(Uint8List? imageBytes, ColorScheme colorScheme, bool isMobile) {
  if (imageBytes == null) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF3F4F6),
            Color(0xFFE5E7EB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  return Image.memory(
    imageBytes,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (context, error, stackTrace) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF3F4F6),
              Color(0xFFE5E7EB),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(
          Icons.broken_image,
          color: colorScheme.onSurface.withOpacity(0.4),
          size: isMobile ? 30 : 36,
        ),
      );
    },
  );
}

Widget headerWidget(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final isMobile = Responsive.isMobile(context);

  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(kIsWeb ? 16 : 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          colorScheme.primary,
          colorScheme.primaryContainer,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(kIsWeb ? 16 : 16)),
    ),
    child: Row(
      children: [
        Container(
          padding: EdgeInsets.all(kIsWeb ? 8 : 8),
          decoration: BoxDecoration(
            color: colorScheme.onPrimary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10),
          ),
          child: Icon(
            Icons.restaurant_menu,
            color: colorScheme.onPrimary,
            size: isMobile ? 20 : 24,
          ),
        ),

        SizedBox(width: kIsWeb ? 10 : 10),

        Expanded(
          child: Text(
            "Add New Menu Item",
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: kIsWeb ? 18 : 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.close,
            color: colorScheme.onPrimary,
          ),
        ),
      ],
    ),
  );
}