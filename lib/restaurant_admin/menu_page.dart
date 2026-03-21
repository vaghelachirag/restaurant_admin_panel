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

                            SizedBox(height: kIsWeb ? 16 : 16.sp),

                            /// ITEM NAME
                            itemNameField(nameController),

                            SizedBox(height: kIsWeb ? 24 : 24.sp),

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
      padding: EdgeInsets.all(kIsWeb ? 16 : 16),
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
                  borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10),
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
                        borderRadius: BorderRadius.circular(8),
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
                        borderRadius: BorderRadius.circular(8),
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
                        borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10),
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
            margin:  EdgeInsets.only(bottom: 12.sp),
            padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10),
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
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:  EdgeInsets.symmetric(
                        horizontal: 12.sp,
                        vertical: 8.sp,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: kIsWeb ? 12 : 12.sp),

                /// Price
                SizedBox(
                  width: kIsWeb ? 80 : 80.sp,
                  child: TextField(
                    controller: variants[index]["price"],
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10.sp : 12.sp,
                        vertical: isMobile ? 6.sp : 8.sp,
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
            icon: Icon(
              Icons.add_circle_outline,
              color: colorScheme.primary,
              size: kIsWeb ? 18 : 18.sp,
            ),
            label: Text(
              "Add Another Variant",
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: kIsWeb ? 12 : 12.sp,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isMobile ? 10.sp : 12.sp, horizontal: kIsWeb ? 10 : 10.sp),
              side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
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
    final isMobile = Responsive.isMobile(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Item Name",
          style: TextStyle(
            fontSize: kIsWeb ? 14 : 14.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: isMobile ? 6.sp : 8.sp),

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
              size: isMobile ? 20.sp : 22.sp,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16.sp : 20.sp,
              vertical: isMobile ? 12.sp : 16.sp,
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
            fontSize: kIsWeb ? 14 : 14.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: isMobile ? 6.sp : 8.sp),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("categories")
              .where("restaurantId", isEqualTo: restaurantId)
              .snapshots(),
          builder: (context, snapshot) {

            if (!snapshot.hasData) {
              return Container(
                height: 50,
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
                        style:  TextStyle(fontSize: kIsWeb ? 15 : 15.sp),
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
          width: isMobile ? 120.sp : 140.sp,
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
                size: isMobile ? 32.sp : 40.sp,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
              SizedBox(height: isMobile ? 6.sp : 8.sp),
              Text(
                "Upload Image",
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: isMobile ? 12.sp : 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ) : ClipRRect(
            borderRadius: BorderRadius.circular(isMobile ? 10.sp : 14.sp),
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
                        borderRadius: BorderRadius.circular(8),
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
                        borderRadius: BorderRadius.circular(8),
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
        final isMobile = Responsive.isMobile(context);
        final isTablet = Responsive.isTablet(context);
        final isDesktop = Responsive.isDesktop(context);
        final screenWidth = Responsive.width(context);
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool isEditing = _isEditingMenuItem;
            // Responsive dialog sizing
            double dialogWidth = screenWidth * 0.9;
            double maxHeight = MediaQuery.of(context).size.height * 0.85;
            
            if (isDesktop) {
              dialogWidth = screenWidth > 1200 ? 600 : 500;
            } else if (isTablet) {
              dialogWidth = screenWidth * 0.8;
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
              ),
              backgroundColor: colorScheme.surface,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: maxHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isMobile ? 16.sp : 20.sp),
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
                          top: Radius.circular(isMobile ? 16.sp : 20.sp),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isMobile ? 8.sp : 10.sp),
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
                          SizedBox(width: isMobile ? 10.sp : 12.sp),
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
                                SizedBox(width: isMobile ? 12.sp : 16.sp),
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
                                            horizontal: isMobile ? 16.sp : 20.sp,
                                            vertical: isMobile ? 10.sp : 12.sp,
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

                            SizedBox(height: kIsWeb ? 20 : 20.sp),
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
                                            style:  TextStyle(fontSize: kIsWeb ? 15 : 15.sp)
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
                            SizedBox(height: 20.sp),

                            /// ITEM NAME
                            Text(
                              "Item Name",
                              style: TextStyle(
                                fontSize: kIsWeb ? 16 : 16.sp,
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

                             SizedBox(height: 24.sp),

                            /// VARIANTS SECTION
                            Row(
                              children: [
                                Icon(
                                  Icons.list_alt,
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                  size: 20.sp,
                                ),
                                 SizedBox(width: 8.sp),
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
                                margin:  EdgeInsets.only(bottom: 12.sp),
                                padding:  EdgeInsets.all(16.sp),
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
                                            horizontal: 12.sp,
                                            vertical: 8.sp,
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
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.sp),
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
                                  padding:  EdgeInsets.symmetric(vertical: 12.sp),
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
                      padding:  EdgeInsets.all(20.sp),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius:  BorderRadius.vertical(
                          bottom: Radius.circular(20.sp),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:  EdgeInsets.symmetric(vertical: 14.sp),
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
                                        borderRadius: BorderRadius.circular(8),
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
                                              borderRadius: BorderRadius.circular(8),
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
                                            borderRadius: BorderRadius.circular(8),
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
                                        borderRadius: BorderRadius.circular(8),
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
                                          borderRadius: BorderRadius.circular(8),
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = Responsive.width(context);
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: kIsWeb ? 110 : 110.sp,
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
                    padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Top Navigation Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            /// Back Arrow
                            Container(
                              width: kIsWeb ? 40 : 40.sp,
                              height: kIsWeb ? 40 : 40.sp,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Colors.white,
                                  size: kIsWeb ? 20 : 20.sp,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              )
                            ),
                            /// Menu Icon
                            Container(
                              width: kIsWeb ? 40 : 40.sp,
                              height: kIsWeb ? 40 : 40.sp,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                              ),
                              child: Icon(
                                Icons.restaurant,
                                color: Colors.white,
                                size: kIsWeb ? 20 : 20.sp,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: kIsWeb ? 10 : 10.sp),
                        /// Title and Subtitle
                        Text(
                          "Menu Items",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: kIsWeb ? 16 : 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          /// CATEGORY FILTER
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("categories")
                  .where("restaurantId", isEqualTo: widget.restaurantId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                    child: const LinearProgressIndicator(),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                    child: Text(
                      snapshot.hasData && snapshot.data!.docs.isEmpty
                          ? "No Categories"
                          : "Loading...",
                      style: TextStyle(fontSize: kIsWeb ? 14 : 14.sp),
                    ),
                  );
                }

                final rawCategories = snapshot.data!.docs;
                final categories = List<QueryDocumentSnapshot>.from(rawCategories)
                  ..sort((a, b) {
                    final posA = (a.data() as Map<String, dynamic>)["position"] as num?;
                    final posB = (b.data() as Map<String, dynamic>)["position"] as num?;
                    return ((posA ?? 0).toInt()).compareTo((posB ?? 0).toInt());
                  });

                // Auto-select first category if none is selected
                if (_selectedCategoryId == null && categories.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _selectedCategoryId = categories.first.id;
                    });
                  });
                }

                return Container(
                  margin: EdgeInsets.fromLTRB(
                    isMobile ? 16.sp : 24.sp,
                    isMobile ? 20.sp : 24.sp,
                    isMobile ? 16.sp : 24.sp,
                    isMobile ? 8.sp : 12.sp
                  ),
                  child: SizedBox(
                    height: kIsWeb ? 50 : 50.sp,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length + 1, // +1 for ellipsis
                      itemBuilder: (context, index) {
                        if (index == categories.length) {
                          // Ellipsis button
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16.sp : 20.sp,
                                vertical: isMobile ? 12.sp : 14.sp,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20.sp),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.more_horiz,
                                color: const Color(0xFF6B7280),
                                size: kIsWeb ? 20 : 20.sp,
                              ),
                            ),
                          );
                        }

                        final cat = categories[index];
                        final bool isSelected = cat.id == _selectedCategoryId;

                        return Padding(
                          padding:  EdgeInsets.only(right: 8.sp),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategoryId = cat.id;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16.sp : 20.sp,
                                vertical: isMobile ? 12.sp : 14.sp,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ?  Color(0xFF7C3AED) : Colors.white,
                                borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20.sp),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    Padding(
                                      padding: EdgeInsets.only(right: isMobile ? 6 : 8),
                                      child: Icon(
                                        Icons.check,
                                        size: kIsWeb ? 16 : 16.sp,
                                        color: Colors.white,
                                      ),
                                    ),
                                  Text(
                                    cat['name'],
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 14 : 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? Colors.white : const Color(0xFF1F2937),
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

          /// MENU ITEMS
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (_selectedCategoryId == null) {
                  return SizedBox(
                    height: MediaQuery.of(context).size.height - 300, // Give it a fixed height
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 32.sp : 48),
                        margin: EdgeInsets.all(kIsWeb ? 24 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: kIsWeb ? 20 : 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(kIsWeb ? 24 : 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20),
                              ),
                              child: Icon(
                                Icons.category,
                                size: kIsWeb ? 48 : 48.sp,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                            SizedBox(height: kIsWeb ? 16 : 16.sp),
                            Text(
                              "Select a Category",
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            SizedBox(height: kIsWeb ? 8 : 8.sp),
                            Text(
                              "Choose a category to view menu items",
                              style: TextStyle(
                                fontSize: kIsWeb ? 14 : 14.sp,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("menu_items")
                      .where("restaurantId", isEqualTo: widget.restaurantId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(kIsWeb ? 16 : 16),
                          child: Text(
                            "Failed to load menu: ${snapshot.error}",
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: Text("No menu data"));
                    }

                    final allItems = snapshot.data!.docs;

                    // Filter items by selected category on client side
                    final items = allItems.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data["categoryId"] == _selectedCategoryId;
                    }).toList();

                    if (items.isEmpty) {
                      return Center(
                        child: Container(
                          padding: EdgeInsets.all(kIsWeb ? 32 : 32.sp),
                          margin: EdgeInsets.all(kIsWeb ? 24 : 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: kIsWeb ? 20 : 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(kIsWeb ? 24 : 24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20),
                                ),
                                child: Icon(
                                  Icons.restaurant_menu,
                                  size: kIsWeb ? 48 : 48.sp,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                              SizedBox(height: kIsWeb ? 16 : 16.sp),
                              Text(
                                "No Menu Items",
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 22,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              SizedBox(height: kIsWeb ? 8 : 8.sp),
                              Text(
                                "Add menu items to this category",
                                style: TextStyle(
                                  fontSize: kIsWeb ? 14 : 14.sp,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // List view - redesigned to match image
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 16 : 24, 
                        isMobile ? 8 : 12, 
                        isMobile ? 16 : 24, 
                        100 // Bottom padding for FAB
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final doc = items[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final List variants = (data['variants'] ?? []) as List;
                        final String name = (data['name'] ?? '').toString();
                        final String? imageUrl = (data['image'] ?? '') as String?;
                        final bool isAvailable = (data['isAvailable'] ?? true) as bool;

                        return Container(
                          margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: kIsWeb ? 10 : 10.sp,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(kIsWeb ? 16 : 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// Item Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          width: kIsWeb ? 80 : 80.sp,
                                          height: kIsWeb ? 80 : 80.sp,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              width: kIsWeb ? 80 : 80.sp,
                                              height: kIsWeb ? 80 : 80.sp,
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
                                                    const Color(0xFF7C3AED).withOpacity(0.6),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: kIsWeb ? 80 : 80.sp,
                                              height: kIsWeb ? 80 : 80.sp,
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
                                                color: const Color(0xFF7C3AED).withOpacity(0.6),
                                                size: kIsWeb ? 32 : 32.sp,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          width: kIsWeb ? 80 : 80.sp,
                                          height: kIsWeb ? 80 : 80.sp,
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
                                            Icons.fastfood_rounded,
                                            color: const Color(0xFF7C3AED),
                                            size: kIsWeb ? 32 : 32.sp,
                                          ),
                                        ),
                                ),
                                SizedBox(width: kIsWeb ? 16 : 16.sp),
                                
                                /// Item Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      /// Item Name and Availability
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: kIsWeb ? 16 : 16.sp,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF1F2937),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: kIsWeb ? 4 : 4.sp),
                                      
                                      /// Availability Status
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isMobile ? 8 : 10,
                                          vertical: isMobile ? 4 : 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isAvailable
                                              ? const Color(0xFF10B981).withOpacity(0.1)
                                              : const Color(0xFFEF4444).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
                                        ),
                                        child: Text(
                                          isAvailable ? "Available" : "Not available",
                                          style: TextStyle(
                                            fontSize: kIsWeb ? 12 : 12.sp,
                                            color: isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      
                                      SizedBox(height: kIsWeb ? 8 : 8.sp),
                                      
                                      /// Variants Section
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Variants:",
                                            style: TextStyle(
                                              fontSize: kIsWeb ? 12 : 12.sp,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF6B7280),
                                            ),
                                          ),
                                          SizedBox(height: kIsWeb ? 6 : 6.sp),
                                          Wrap(
                                            spacing: isMobile ? 6 : 8,
                                            runSpacing: isMobile ? 4 : 6,
                                            children: variants.map<Widget>((v) {
                                              return Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: isMobile ? 8 : 10,
                                                  vertical: isMobile ? 4 : 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEDE9FE),
                                                  borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
                                                ),
                                                child: Text(
                                                  "${v['name']} ₹${v['price']}",
                                                  style: TextStyle(
                                                    fontSize: kIsWeb ? 11 : 11.sp,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(0xFF7C3AED),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                /// Action Buttons
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    /// Toggle Switch
                                    Transform.scale(
                                      scale: isMobile ? 0.8 : 1.0,
                                      child: Switch(
                                        value: isAvailable,
                                        activeColor: const Color(0xFF10B981),
                                        onChanged: (value) {
                                          toggleAvailability(doc.id, value);
                                        },
                                      ),
                                    ),
                                    
                                    SizedBox(height: kIsWeb ? 8 : 8.sp),
                                    
                                    /// Edit Icon
                                    GestureDetector(
                                      onTap: () => editMenuItem(doc),
                                      child: Container(
                                        padding: EdgeInsets.all(kIsWeb ? 8 : 8.sp),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                                        ),
                                        child: Icon(
                                          Icons.edit,
                                          color: const Color(0xFF7C3AED),
                                          size: kIsWeb ? 16 : 16.sp,
                                        ),
                                      ),
                                    ),
                                    
                                    SizedBox(height: kIsWeb ? 6 : 6.sp),
                                    
                                    /// Delete Icon
                                    GestureDetector(
                                      onTap: () => deleteMenuItem(doc.id, name),
                                      child: Container(
                                        padding: EdgeInsets.all(kIsWeb ? 8 : 8.sp),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                                        ),
                                        child: Icon(
                                          Icons.delete,
                                          color: const Color(0xFFEF4444),
                                          size: kIsWeb ? 16 : 16.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              childCount: 1,
            ),
          ),
                                  ],
      ),
      /// ADD ITEM BUTTON
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: isMobile ? 20 : 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF7C3AED),
              Color(0xFFA855F7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.3),
              blurRadius: kIsWeb ? 12 : 12.sp,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: addMenuItem,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: Icon(
            Icons.add,
            color: Colors.white,
            size: kIsWeb ? 24 : 24.sp,
          ),
          label: Text(
            "Add Item",
            style: TextStyle(
              color: Colors.white,
              fontSize: kIsWeb ? 14 : 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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


