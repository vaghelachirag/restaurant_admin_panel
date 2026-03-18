import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class MenuItemsPage extends StatefulWidget {
  final String restaurantId;

  const MenuItemsPage({
    super.key,
    required this.restaurantId,
  });

  @override
  State<MenuItemsPage> createState() => _MenuItemsPageState();
}

class _MenuItemsPageState extends State<MenuItemsPage> {
  String? _selectedCategoryId;

  /// Image upload (same API as add menu page)
  final String _imgbbApiKey = "a923bc17d28cd6fe1be417700456eb69";

  Future<String?> _uploadImageToImgBB(Uint8List bytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("https://api.imgbb.com/1/upload?key=$_imgbbApiKey"),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: "menu.jpg",
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData) as Map<String, dynamic>;

      return jsonData['data']?['url'] as String?;
    } catch (e) {
      debugPrint("UPLOAD ERROR $e");
      return null;
    }
  }

  /// EDIT MENU ITEM
  void _editMenuItem(DocumentSnapshot doc) {
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
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final media = MediaQuery.of(dialogContext);
            final maxDialogHeight = media.size.height * 0.9;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 700,
                constraints: BoxConstraints(
                  maxHeight: maxDialogHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// HEADER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade400, Colors.orange.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              "Edit Menu Item",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// CONTENT
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// IMAGE
                            Text(
                              "Item Image",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.grey.shade100,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: newImageBytes != null
                                        ? Image.memory(
                                            newImageBytes!,
                                            fit: BoxFit.cover,
                                          )
                                        : (imageUrl != null && imageUrl!.isNotEmpty
                                            ? Image.network(
                                                imageUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.restaurant,
                                                    color: Colors.grey.shade400,
                                                    size: 36,
                                                  );
                                                },
                                              )
                                            : Icon(
                                                Icons.restaurant,
                                                color: Colors.grey.shade400,
                                                size: 36,
                                              )),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Upload or change the dish image. This image is shown in the customer menu.",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final picker = ImagePicker();
                                          final picked = await picker.pickImage(
                                            source: ImageSource.gallery,
                                          );
                                          if (picked != null) {
                                            final bytes = await picked.readAsBytes();
                                            setStateDialog(() {
                                              newImageBytes = bytes;
                                            });
                                          }
                                        },
                                        icon: Icon(
                                          Icons.image_outlined,
                                          color: Colors.orange.shade400,
                                        ),
                                        label: Text(
                                          imageUrl != null && imageUrl!.isNotEmpty
                                              ? "Change Image"
                                              : "Upload Image",
                                          style: TextStyle(
                                            color: Colors.orange.shade400,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          side: BorderSide(
                                            color: Colors.orange.shade300,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            /// CATEGORY
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection("categories")
                                  .where("restaurantId",
                                      isEqualTo: widget.restaurantId)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                final categories = snapshot.data!.docs;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    value: selectedCategoryId,
                                    hint: const Text("Select Category"),
                                    items: categories.map((cat) {
                                      return DropdownMenuItem<String>(
                                        value: cat.id,
                                        child: Text(cat['name']),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setStateDialog(() {
                                        selectedCategoryId = value;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      labelText: "Category",
                                      labelStyle: TextStyle(color: Colors.grey.shade600),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.all(16),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            /// ITEM NAME
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: TextField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  labelText: "Item Name",
                                  labelStyle: TextStyle(color: Colors.grey.shade600),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            Text(
                              "Variants",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 12),

                            Column(
                              children: List.generate(
                                variantsControllers.length,
                                (index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: TextField(
                                              controller:
                                                  variantsControllers[index]["name"],
                                              decoration: InputDecoration(
                                                labelText: "Variant Name",
                                                labelStyle: TextStyle(color: Colors.grey.shade600),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.all(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 100,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: TextField(
                                              controller:
                                                  variantsControllers[index]["price"],
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: "Price",
                                                prefixText: "₹",
                                                labelStyle: TextStyle(color: Colors.grey.shade600),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.all(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (variantsControllers.length > 1)
                                          IconButton(
                                            icon: Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.red.shade400,
                                            ),
                                            onPressed: () {
                                              variantsControllers.removeAt(index);
                                              setStateDialog(() {});
                                            },
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 12),

                            /// ADD VARIANT BUTTON
                            Container(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  variantsControllers.add({
                                    "name": TextEditingController(),
                                    "price": TextEditingController(),
                                  });
                                  setStateDialog(() {});
                                },
                                icon: Icon(Icons.add_circle_outline, color: Colors.orange.shade400),
                                label: Text(
                                  "Add Another Variant",
                                  style: TextStyle(color: Colors.orange.shade400),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: BorderSide(color: Colors.orange.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (selectedCategoryId == null ||
                                    nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text("Please fill all required fields"),
                                      backgroundColor: Colors.red.shade400,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                  return;
                                }

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
                                  final uploadedUrl = await _uploadImageToImgBB(newImageBytes!);
                                  if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                                    finalImageUrl = uploadedUrl;
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text("Failed to upload image"),
                                          backgroundColor: Colors.red.shade400,
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
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text("Menu item updated successfully!"),
                                      backgroundColor: Colors.green.shade400,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade500,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Update Menu Item",
                                style: TextStyle(
                                  color: Colors.white,
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

  Future<void> _toggleAvailability(String id, bool value) async {
    await FirebaseFirestore.instance
        .collection("menu_items")
        .doc(id)
        .update({"isAvailable": value});
  }

  Future<void> _deleteItem(String id) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.red.shade600,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Delete Menu Item",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Are you sure you want to delete this menu item?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Delete",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldDelete != true) return;

    await FirebaseFirestore.instance
        .collection("menu_items")
        .doc(id)
        .delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Menu item deleted successfully!"),
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              /// HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double width = constraints.maxWidth;
                    double iconSize = width * 0.02 + 18;
                    double titleSize = width * 0.015 + 14;
                    double subtitleSize = width * 0.008 + 10;

                    return Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(width * 0.012),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange.shade400, Colors.orange.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(width * 0.01 + 10),
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            color: Colors.white,
                            size: iconSize,
                          ),
                        ),
                        SizedBox(width: width * 0.01 + 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Menu Items",
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              SizedBox(height: width * 0.003),
                              Text(
                                "Manage your restaurant menu items",
                                style: TextStyle(
                                  fontSize: subtitleSize,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: width * 0.008 + 10,
                            vertical: width * 0.004 + 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection("menu_items")
                                .where("restaurantId", isEqualTo: widget.restaurantId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: width * 0.005 + 6,
                                    height: width * 0.005 + 6,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: width * 0.004 + 4),
                                  Text(
                                    "$count Items",
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: subtitleSize,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              /// CATEGORY FILTER
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("categories")
                      .where("restaurantId", isEqualTo: widget.restaurantId)
                      .orderBy("position")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator(),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          snapshot.hasData && snapshot.data!.docs.isEmpty
                              ? "No Categories"
                              : "Loading...",
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }

                    final categories = snapshot.data!.docs;

                    _selectedCategoryId ??= categories.first.id;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Filter by Category",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 56,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final bool isSelected = cat.id == _selectedCategoryId;

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        cat['name'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isSelected ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? Colors.white : Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  selected: isSelected,
                                  selectedColor: Colors.orange.shade500,
                                  backgroundColor: Colors.orange.shade50,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedCategoryId = cat.id;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              /// MENU ITEMS
              Expanded(
                child: _selectedCategoryId == null
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(constraints.maxWidth * 0.1),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(constraints.maxWidth * 0.05),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        Icons.category,
                                        size: constraints.maxWidth * 0.08,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    SizedBox(height: constraints.maxWidth * 0.03),
                                    Text(
                                      "Select a Category",
                                      style: TextStyle(
                                        fontSize: constraints.maxWidth * 0.04,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    SizedBox(height: constraints.maxWidth * 0.02),
                                    Text(
                                      "Choose a category to view menu items",
                                      style: TextStyle(
                                        fontSize: constraints.maxWidth * 0.025,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection("menu_items")
                            .where("restaurantId", isEqualTo: widget.restaurantId)
                            .where("categoryId", isEqualTo: _selectedCategoryId)
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

                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData) {
                            return const Center(child: Text("No menu data"));
                          }

                          final items = snapshot.data!.docs;

                          if (items.isEmpty) {
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(constraints.maxWidth * 0.1),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(constraints.maxWidth * 0.05),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Icon(
                                              Icons.restaurant_menu,
                                              size: constraints.maxWidth * 0.08,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                          SizedBox(height: constraints.maxWidth * 0.03),
                                          Text(
                                            "No Menu Items",
                                            style: TextStyle(
                                              fontSize: constraints.maxWidth * 0.04,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          SizedBox(height: constraints.maxWidth * 0.02),
                                          Text(
                                            "Add menu items to this category",
                                            style: TextStyle(
                                              fontSize: constraints.maxWidth * 0.025,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              int crossAxisCount = 1;
                              if (constraints.maxWidth > 1200) {
                                crossAxisCount = 3; // Large desktop
                              } else if (constraints.maxWidth > 800) {
                                crossAxisCount = 2; // Tablet/Small desktop
                              }

                              return GridView.builder(
                                padding: const EdgeInsets.all(24),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                  childAspectRatio: crossAxisCount == 1 ? 2.2 : 1.5,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final doc = items[index];
                                  final data = doc.data() as Map<String, dynamic>;

                                  final String name = (data['name'] ?? '').toString();
                                  final String? imageUrl = (data['image'] ?? '') as String?;
                                  final List variants = (data['variants'] ?? []) as List;
                                  final bool isAvailable = (data['isAvailable'] ?? true) as bool;

                                  return _modernMenuItemCard(
                                    doc: doc,
                                    name: name,
                                    imageUrl: imageUrl,
                                    isAvailable: isAvailable,
                                    variants: variants,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            // TODO: Add menu item functionality
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _modernMenuItemCard({
    required DocumentSnapshot doc,
    required String name,
    required String? imageUrl,
    required bool isAvailable,
    required List variants,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        double padding = width * 0.04;
        double titleSize = width * 0.045;
        double subtitleSize = width * 0.035;
        double iconSize = width * 0.06;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isAvailable ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              children: [
                /// IMAGE
                Container(
                  width: width * 0.25,
                  height: width * 0.25,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade200, Colors.grey.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                padding: EdgeInsets.all(width * 0.05),
                                child: Icon(
                                  Icons.restaurant,
                                  color: Colors.grey.shade400,
                                  size: iconSize,
                                ),
                              );
                            },
                          )
                        : Container(
                            padding: EdgeInsets.all(width * 0.05),
                            child: Icon(
                              Icons.restaurant,
                              color: Colors.grey.shade400,
                              size: iconSize,
                            ),
                          ),
                  ),
                ),

                SizedBox(width: width * 0.03),

                /// CONTENT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// NAME AND STATUS
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: width * 0.02,
                              vertical: width * 0.01,
                            ),
                            decoration: BoxDecoration(
                              color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(width * 0.03),
                              border: Border.all(
                                color: isAvailable ? Colors.green.shade200 : Colors.red.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: width * 0.015,
                                  height: width * 0.015,
                                  decoration: BoxDecoration(
                                    color: isAvailable ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: width * 0.01),
                                Text(
                                  isAvailable ? "Available" : "Unavailable",
                                  style: TextStyle(
                                    fontSize: subtitleSize * 0.8,
                                    fontWeight: FontWeight.w600,
                                    color: isAvailable ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: width * 0.02),

                      /// VARIANTS
                      if (variants.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Variants",
                                style: TextStyle(
                                  fontSize: subtitleSize * 0.9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: width * 0.015),
                              Expanded(
                                child: Wrap(
                                  spacing: width * 0.02,
                                  runSpacing: width * 0.01,
                                  children: variants.map<Widget>((v) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: width * 0.02,
                                        vertical: width * 0.01,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(width * 0.02),
                                        border: Border.all(color: Colors.orange.shade200),
                                      ),
                                      child: Text(
                                        "${v['name']} - ₹${v['price']}",
                                        style: TextStyle(
                                          fontSize: subtitleSize * 0.8,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(height: width * 0.02),

                      /// ACTIONS
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(width * 0.03),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () => _editMenuItem(doc),
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white,
                                  size: iconSize * 0.7,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: width * 0.02),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red.shade400, Colors.red.shade600],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(width * 0.03),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () => _deleteItem(doc.id),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: iconSize * 0.7,
                                ),
                              ),
                            ),
                          ),
                        ],
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
}

