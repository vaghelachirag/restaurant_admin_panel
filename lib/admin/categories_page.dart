import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import '../uttils/responsive.dart';

class CategoriesPage extends StatefulWidget {
  final String restaurantId;

  const CategoriesPage({super.key, required this.restaurantId});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  XFile? pickedImage;
  Uint8List? imageBytes;
  final String apiKey = "a923bc17d28cd6fe1be417700456eb69";
  bool _isAddingCategory = false;
  bool _isEditingCategory = false;

  /// Pick Image
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

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
          filename: "category.jpg",
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

  /// Add Category
  void addCategory() {
    TextEditingController nameController = TextEditingController();
    TextEditingController positionController = TextEditingController(text: "0");

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isMobile = Responsive.isMobile(context);
        final screenWidth = Responsive.width(context);
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double dialogWidth = screenWidth * 0.9;
            double maxHeight = MediaQuery.of(context).size.height * 0.9;
            
            if (Responsive.isDesktop(context)) {
              dialogWidth = screenWidth > 1200 ? 600 : 500;
            } else if (Responsive.isTablet(context)) {
              dialogWidth = screenWidth * 0.8;
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobile ? 16.sp : 20.sp),
              ),
              backgroundColor: colorScheme.surface,
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  children: [
                    headerWidget(context, "Add New Category"),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.all(isMobile ? 16.sp : 24.sp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            imageUploadWidget(() async {
                              await pickImage();
                              setStateDialog(() {});
                            }),
                            SizedBox(height: isMobile ? 20.sp : 24.sp),
                            categoryNameField(nameController),
                            SizedBox(height: isMobile ? 16 : 20),
                            positionField(positionController),
                          ],
                        ),
                      ),
                    ),
                    footerButtons(
                      context: context,
                      nameController: nameController,
                      positionController: positionController,
                      restaurantId: widget.restaurantId,
                      uploadImage: uploadImageToImgBB,
                      isLoading: _isAddingCategory,
                      setLoading: (loading) {
                        setState(() {
                          _isAddingCategory = loading;
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

  /// Edit Category
  void editCategory(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    TextEditingController nameController = TextEditingController(text: data['name'] ?? '');
    TextEditingController positionController = TextEditingController(text: (data['position'] ?? 0).toString());
    
    String? imageUrl = (data['image'] ?? '') as String?;
    Uint8List? newImageBytes;

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isMobile = Responsive.isMobile(context);
        final screenWidth = Responsive.width(context);
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double dialogWidth = screenWidth * 0.9;
            double maxHeight = MediaQuery.of(context).size.height * 0.9;
            
            if (Responsive.isDesktop(context)) {
              dialogWidth = screenWidth > 1200 ? 600 : 500;
            } else if (Responsive.isTablet(context)) {
              dialogWidth = screenWidth * 0.8;
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobile ? 16.sp : 20.sp),
              ),
              backgroundColor: colorScheme.surface,
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  children: [
                    headerWidget(context, "Edit Category"),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.all(isMobile ? 16.sp : 24.sp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            imageUploadWidget(() async {
                              await pickImage();
                              setStateDialog(() {});
                            }, imageUrl: imageUrl),
                            SizedBox(height: isMobile ? 20.sp : 24.sp),
                            categoryNameField(nameController),
                            SizedBox(height: isMobile ? 16 : 20),
                            positionField(positionController),
                          ],
                        ),
                      ),
                    ),
                    footerButtons(
                      context: context,
                      nameController: nameController,
                      positionController: positionController,
                      restaurantId: widget.restaurantId,
                      uploadImage: uploadImageToImgBB,
                      categoryId: doc.id,
                      isLoading: _isEditingCategory,
                      setLoading: (loading) {
                        setState(() {
                          _isEditingCategory = loading;
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

  /// Delete Category
  void deleteCategory(String id, String categoryName) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 16.sp : 20.sp),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 8.sp : 10.sp),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(isMobile ? 10.sp : 12.sp),
              ),
              child: Icon(
                Icons.delete_outline,
                color: colorScheme.error,
                size: isMobile ? 20.sp : 24.sp,
              ),
            ),
            SizedBox(width: isMobile ? 10.sp : 12.sp),
            Expanded(
              child: Text(
                "Delete Category",
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
              "Are you sure you want to delete this category?",
              style: TextStyle(
                fontSize: isMobile ? 14.sp : 16.sp,
                color: colorScheme.onSurface,
              ),
            ),
            if (categoryName.isNotEmpty) ...[
              SizedBox(height: isMobile ? 8.sp : 12.sp),
              Container(
                padding: EdgeInsets.all(isMobile ? 12.sp : 16.sp),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(isMobile ? 10.sp : 12.sp),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.category,
                      color: colorScheme.onSurface.withOpacity(0.6),
                      size: isMobile ? 16.sp : 18.sp,
                    ),
                    SizedBox(width: isMobile ? 8.sp : 10.sp),
                    Expanded(
                      child: Text(
                        categoryName,
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
                fontSize: isMobile ? 12.sp : 13.sp,
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
                borderRadius: BorderRadius.circular(isMobile ? 10.sp : 12.sp),
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
                    .collection("categories")
                    .doc(id)
                    .delete();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Category deleted successfully"),
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
                      content: Text("Error deleting category: $e"),
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
                borderRadius: BorderRadius.circular(isMobile ? 10.sp : 12.sp),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: isMobile ? 110.sp : 140.sp,
            pinned: false,
            floating: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade50,
                      Colors.purple.shade50,
                      Colors.pink.shade50,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Container(
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade400, Colors.blue.shade600],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.category,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            "Categories",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16.sp : 24.sp),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("categories")
                    .where("restaurantId", isEqualTo: widget.restaurantId)
                    .orderBy("position", descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: isMobile ? 64.sp : 80.sp,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: isMobile ? 16.sp : 20.sp),
                          Text(
                            "No Categories Yet",
                            style: TextStyle(
                              fontSize: isMobile ? 18.sp : 22.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: isMobile ? 8.sp : 12.sp),
                          Text(
                            "Add your first category to get started",
                            style: TextStyle(
                              fontSize: isMobile ? 14.sp : 16.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final categories = snapshot.data!.docs;

                  return Column(
                    children: [
                      /// Add Category Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: addCategory,
                          icon: Icon(
                            Icons.add_circle_outline,
                            size: isMobile ? 20.sp : 24.sp,
                          ),
                          label: Text(
                            "Add New Category",
                            style: TextStyle(
                              fontSize: isMobile ? 14.sp : 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: EdgeInsets.symmetric(vertical: isMobile ? 12.sp : 16.sp),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isMobile ? 12.sp : 16.sp),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 20.sp : 24.sp),
                      /// Categories Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: Responsive.isDesktop(context) ? 4 : 
                                         Responsive.isTablet(context) ? 3 : 2,
                          crossAxisSpacing: isMobile ? 12.sp : 16.sp,
                          mainAxisSpacing: isMobile ? 12.sp : 16.sp,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final data = category.data() as Map<String, dynamic>;
                          final name = data['name'] ?? 'Unnamed Category';
                          final image = data['image'] ?? '';

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(isMobile ? 12.sp : 16.sp),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                /// Image or Icon
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(isMobile ? 12.sp : 16.sp),
                                      ),
                                      color: colorScheme.primaryContainer.withOpacity(0.1),
                                    ),
                                    child: image.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(isMobile ? 12.sp : 16.sp),
                                            ),
                                            child: Image.network(
                                              image,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.category,
                                                  size: isMobile ? 32.sp : 40.sp,
                                                  color: colorScheme.primary,
                                                );
                                              },
                                            ),
                                          )
                                        : Icon(
                                            Icons.category,
                                            size: isMobile ? 32.sp : 40.sp,
                                            color: colorScheme.primary,
                                          ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: EdgeInsets.all(isMobile ? 8.sp : 12.sp),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: isMobile ? 12.sp : 14.sp,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Spacer(),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              onPressed: () => editCategory(category),
                                              icon: Icon(
                                                Icons.edit,
                                                size: isMobile ? 16.sp : 18.sp,
                                                color: colorScheme.primary,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(
                                                minWidth: isMobile ? 32.sp : 36.sp,
                                                minHeight: isMobile ? 32.sp : 36.sp,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => deleteCategory(category.id, name),
                                              icon: Icon(
                                                Icons.delete,
                                                size: isMobile ? 16.sp : 18.sp,
                                                color: colorScheme.error,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(
                                                minWidth: isMobile ? 32.sp : 36.sp,
                                                minHeight: isMobile ? 32.sp : 36.sp,
                                              ),
                                            ),
                                          ],
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
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget headerWidget(BuildContext context, String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
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
          top: Radius.circular(isMobile ? 16 : 20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
            ),
            child: Icon(
              Icons.category,
              color: colorScheme.onPrimary,
              size: isMobile ? 20 : 24,
            ),
          ),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close,
              color: colorScheme.onPrimary,
              size: isMobile ? 20 : 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget imageUploadWidget(VoidCallback onTap, {String? imageUrl}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);
    
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isMobile ? 120.sp : 140.sp,
          height: isMobile ? 120.sp : 140.sp,
          decoration: BoxDecoration(
            color: pickedImage == null && imageUrl == null
                ? colorScheme.surfaceVariant.withOpacity(0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(isMobile ? 12.sp : 16.sp),
            border: Border.all(
              color: pickedImage == null && imageUrl == null
                  ? colorScheme.outline.withOpacity(0.3)
                  : colorScheme.primary,
              width: 2,
            ),
            boxShadow: (pickedImage == null && imageUrl == null)
                ? null
                : [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: pickedImage == null && imageUrl == null
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
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(isMobile ? 10.sp : 14.sp),
                  child: pickedImage != null
                      ? Image.memory(
                          imageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.category,
                              size: isMobile ? 32.sp : 40.sp,
                              color: colorScheme.primary,
                            );
                          },
                        ),
                ),
        ),
      ),
    );
  }

  Widget categoryNameField(TextEditingController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Category Name",
          style: TextStyle(
            fontSize: isMobile ? 14.sp : 16.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: isMobile ? 6.sp : 8.sp),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter category name",
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10.sp : 12.sp),
              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10.sp : 12.sp),
              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10.sp : 12.sp),
              borderSide: BorderSide(color: colorScheme.primary),
            ),
            prefixIcon: Icon(
              Icons.category,
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

  Widget positionField(TextEditingController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Position",
          style: TextStyle(
            fontSize: isMobile ? 14.sp : 16.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: isMobile ? 6.sp : 8.sp),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: "Enter position (0 for first)",
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10.sp : 12.sp),
              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10.sp : 12.sp),
              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10.sp : 12.sp),
              borderSide: BorderSide(color: colorScheme.primary),
            ),
            prefixIcon: Icon(
              Icons.sort,
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

  Widget footerButtons({
    required BuildContext context,
    required TextEditingController nameController,
    required TextEditingController positionController,
    required String restaurantId,
    required Future<String?> Function() uploadImage,
    String? categoryId,
    required bool isLoading,
    required Function(bool) setLoading,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(isMobile ? 16 : 20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                side: BorderSide(color: colorScheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                ),
              ),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                  fontSize: isMobile ? 14 : null,
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (nameController.text.isEmpty) {
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
                  String? imageUrl = await uploadImage();
                  final position = int.tryParse(positionController.text) ?? 0;

                  if (categoryId != null) {
                    // Edit existing category
                    await FirebaseFirestore.instance
                        .collection("categories")
                        .doc(categoryId)
                        .update({
                      "name": nameController.text.trim(),
                      "image": imageUrl ?? '',
                      "position": position,
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Category updated successfully!"),
                          backgroundColor: colorScheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  } else {
                    // Add new category
                    await FirebaseFirestore.instance
                        .collection("categories")
                        .add({
                      "name": nameController.text.trim(),
                      "image": imageUrl ?? '',
                      "restaurantId": restaurantId,
                      "position": position,
                      "createdAt": FieldValue.serverTimestamp(),
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Category added successfully!"),
                          backgroundColor: colorScheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error ${categoryId != null ? 'updating' : 'adding'} category: $e"),
                        backgroundColor: colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                } finally {
                  setLoading(false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                ),
              ),
              child: isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: isMobile ? 16 : 18,
                          height: isMobile ? 16 : 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: isMobile ? 8 : 10),
                        Text(
                          categoryId != null ? "Updating..." : "Adding...",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 14 : null,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      categoryId != null ? "Update Category" : "Save Category",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 14 : null,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}