import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../uttils/responsive.dart';
import '../services/localization_service.dart';
import '../utils/snackbar_helper.dart';

class CategoryPage extends StatefulWidget {
  final String restaurantId;

  const CategoryPage({super.key, required this.restaurantId});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  XFile? pickedImage;
  Uint8List? imageBytes;
  final String apiKey = "a923bc17d28cd6fe1be417700456eb69";
  bool _isAddingCategory = false;
  bool _isEditingCategory = false;


  void addCategory() {
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final screenWidth = Responsive.width(context);
        
        double dialogWidth;
        if (Responsive.isDesktop(context)) {
          dialogWidth = screenWidth > 1400 ? 450 : 400;
        } else if (Responsive.isTablet(context)) {
          dialogWidth = screenWidth * 0.7;
        } else {
          dialogWidth = screenWidth * 0.9;
        }

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: Responsive.isMobile(context) ? 16 : 24,
            vertical: Responsive.isMobile(context) ? 24 : 40,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kIsWeb ? 16 : 14.sp),
          ),
          backgroundColor: colorScheme.surface,
          child: Container(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with title and close button
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(kIsWeb ? 24 : 20.sp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Dark blue square icon with plus sign
                          Container(
                            width: kIsWeb ? 48 : 40.sp,
                            height: kIsWeb ? 48 : 40.sp,
                            decoration: BoxDecoration(
                              color: const Color(0xFF070B2D),
                              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                            ),
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: kIsWeb ? 24 : 20.sp,
                            ),
                          ),
                          SizedBox(width: kIsWeb ? 16 : 12.sp),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context).addCategory,
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 20 : 18.sp,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: kIsWeb ? 4 : 2.sp),
                                Text(
                                  AppLocalizations.of(context).createNewSection,
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 14 : 12.sp,
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: colorScheme.onSurface.withOpacity(0.6),
                              size: kIsWeb ? 24 : 20.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 24 : 20.sp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).categoryName,
                        style: TextStyle(
                          fontSize: kIsWeb ? 14 : 12.sp,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: kIsWeb ? 8 : 6.sp),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).categoryPlaceholder,
                          filled: true,
                          fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                            borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                            borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                            borderSide: BorderSide(color: colorScheme.primary),
                          ),
                          prefixIcon: Icon(
                            Icons.folder,
                            color: colorScheme.onSurface.withOpacity(0.5),
                            size: kIsWeb ? 20 : 18.sp,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: kIsWeb ? 16 : 14.sp,
                            vertical: kIsWeb ? 14 : 12.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: kIsWeb ? 24 : 20.sp),
                // Footer buttons
                Padding(
                  padding: EdgeInsets.all(kIsWeb ? 24 : 20.sp),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: kIsWeb ? 14 : 12.sp),
                            side: BorderSide(color: colorScheme.outline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 8.sp),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context).cancel,
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                              fontSize: kIsWeb ? 14 : 12.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: kIsWeb ? 12 : 10.sp),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        color: colorScheme.onError,
                                        size: kIsWeb ? 20 : 18.sp,
                                      ),
                                      SizedBox(width: kIsWeb ? 12 : 8.sp),
                                      Text(AppLocalizations.of(context).pleaseEnterCategoryName),
                                    ],
                                  ),
                                  backgroundColor: colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                              return;
                            }

                            try {
                              await FirebaseFirestore.instance
                                  .collection("categories")
                                  .add({
                                "name": nameController.text.trim(),
                                "image": '',
                                "restaurantId": widget.restaurantId,
                                "position": 0,
                                "createdAt": FieldValue.serverTimestamp(),
                              });

                              Navigator.pop(context);
                              SnackBarHelper.showSuccess(context, AppLocalizations.of(context).categoryAddedSuccess);
                            } catch (e) {
                              SnackBarHelper.showError(context, "${AppLocalizations.of(context).errorAddingCategory}: $e");
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF070B2D),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: kIsWeb ? 14 : 12.sp),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 8.sp),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context).price,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: kIsWeb ? 14 : 12.sp,
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
  }

  Widget positionField(TextEditingController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).position,
          style: TextStyle(
            fontSize: kIsWeb ? 16 : 14.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: kIsWeb ? 8 : 6.sp),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).enterPosition,
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
              borderSide: BorderSide(color: colorScheme.primary),
            ),
            prefixIcon: Icon(
              Icons.sort,
              color: colorScheme.onSurface.withOpacity(0.5),
              size: kIsWeb ? 22 : 20.sp,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 20 : 16.sp,
              vertical: kIsWeb ? 16 : 12.sp,
            ),
          ),
        ),
      ],
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
          AppLocalizations.of(context).categoryName,
          style: TextStyle(
            fontSize: kIsWeb ? 16 : 14.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: kIsWeb ? 8 : 6.sp),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).enterCategoryName,
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
              borderSide: BorderSide(color: colorScheme.primary),
            ),
            prefixIcon: Icon(
              Icons.category,
              color: colorScheme.onSurface.withOpacity(0.5),
              size: kIsWeb ? 22 : 20.sp,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 20 : 16.sp,
              vertical: kIsWeb ? 16 : 12.sp,
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
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(kIsWeb ? 24 : 20),
        ),
      ),
      child: Column(
        children: [
          /// 🔄 Loading Indicator
          if (isLoading) ...[
            Container(
              padding: EdgeInsets.all(kIsWeb ? 16 : 14.sp),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: kIsWeb ? 20 : 18,
                    height: kIsWeb ? 20 : 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: kIsWeb ? 12 : 10.sp),
                  Expanded(
                    child: Text(
                      categoryId != null
                          ? AppLocalizations.of(context).updatingCategory
                          : AppLocalizations.of(context).addingCategory,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: kIsWeb ? 14 : 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: kIsWeb ? 16 : 12.sp),
          ],

          /// 🔘 Buttons Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 14 : 16,
                    ),
                    side: BorderSide(color: colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(isMobile ? 12 : 14),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).cancel,
                    style: TextStyle(
                      color: isLoading
                          ? colorScheme.onSurface.withOpacity(0.4)
                          : colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                      fontSize: isMobile ? 14 : kIsWeb ? 15 : null,
                    ),
                  ),
                ),
              ),

              SizedBox(width: isMobile ? 12 : 16),

              /// ✅ Save / Update Button
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    if (nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: colorScheme.onError,
                                size: kIsWeb ? 20 : 18.sp,
                              ),
                              SizedBox(width: kIsWeb ? 12 : 8.sp),
                              Text(AppLocalizations.of(context).pleaseFillAllRequiredFields),
                            ],
                          ),
                          backgroundColor: colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                      return;
                    }

                    setLoading(true);

                    try {
                      final imageUrl = await uploadImage();
                      final position =
                          int.tryParse(positionController.text) ?? 0;

                      if (categoryId != null) {
                        /// ✏️ Update
                        await FirebaseFirestore.instance
                            .collection("categories")
                            .doc(categoryId)
                            .update({
                          "name": nameController.text.trim(),
                          "image": imageUrl ?? '',
                          "position": position,
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          SnackBarHelper.showSuccess(context, AppLocalizations.of(context).categoryUpdatedSuccess);
                        }
                      } else {
                        /// ➕ Add
                        await FirebaseFirestore.instance
                            .collection("categories")
                            .add({
                          "name": nameController.text.trim(),
                          "image": imageUrl ?? '',
                          "restaurantId": restaurantId,
                          "position": position,
                          "createdAt":
                          FieldValue.serverTimestamp(),
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          SnackBarHelper.showSuccess(context, AppLocalizations.of(context).categoryAddedSuccess);
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        SnackBarHelper.showError(context, "${categoryId != null ? AppLocalizations.of(context).errorUpdatingCategory : AppLocalizations.of(context).errorAddingCategory}: $e");
                      }
                    } finally {
                      setLoading(false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLoading
                        ? colorScheme.primary.withOpacity(0.6)
                        : colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 14 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(isMobile ? 12 : 14),
                    ),
                  ),
                  child: isLoading
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: kIsWeb ? 20 : 18,
                        height: kIsWeb ? 20 : 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(
                            colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: kIsWeb ? 12 : 8),
                      Text(
                        categoryId != null
                            ? AppLocalizations.of(context).updatingCategory
                            : AppLocalizations.of(context).addingCategory,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile
                              ? 14
                              : kIsWeb
                              ? 15
                              : null,
                        ),
                      ),
                    ],
                  )
                      : Text(
                    categoryId != null
                        ? AppLocalizations.of(context).updateCategory
                        : AppLocalizations.of(context).saveCategory,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile
                          ? 14
                          : kIsWeb
                          ? 15
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSuccess(BuildContext context, String message, ColorScheme colorScheme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: colorScheme.onPrimary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(
      BuildContext context,
      String message,
      ColorScheme colorScheme,
      ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error,
              color: colorScheme.onError,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colorScheme.onError,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

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



  Widget imageUploadWidget(VoidCallback onTap, {String? imageUrl}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: kIsWeb ? 140 : 120.sp,
          height: kIsWeb ? 140 : 120.sp,
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
              SizedBox(height: kIsWeb ? 8 : 6.sp),
              Text(
                AppLocalizations.of(context).uploadImage,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: kIsWeb ? 14 : 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          )
              : ClipRRect(
            borderRadius: BorderRadius.circular(kIsWeb ? 14 : 10.sp),
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
                  size: kIsWeb ? 40 : 32.sp,
                  color: colorScheme.primary,
                );
              },
            ),
          ),
        ),
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
            padding: EdgeInsets.all(kIsWeb ? 10 : 8),
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
                fontSize: kIsWeb ? 20 : 18,
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

  /// EDIT CATEGORY
  void editCategory(String id, String name) {
    TextEditingController nameController = TextEditingController(text: name);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final screenWidth = Responsive.width(context);
        
        double dialogWidth;
        if (Responsive.isDesktop(context)) {
          dialogWidth = screenWidth > 1400 ? 450 : 400;
        } else if (Responsive.isTablet(context)) {
          dialogWidth = screenWidth * 0.7;
        } else {
          dialogWidth = screenWidth * 0.9;
        }

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: Responsive.isMobile(context) ? 16 : 24,
            vertical: Responsive.isMobile(context) ? 24 : 40,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kIsWeb ? 16 : 14.sp),
          ),
          backgroundColor: colorScheme.surface,
          child: Container(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with title and close button
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(kIsWeb ? 24 : 20.sp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Dark blue square icon with edit icon
                          Container(
                            width: kIsWeb ? 48 : 40.sp,
                            height: kIsWeb ? 48 : 40.sp,
                            decoration: BoxDecoration(
                              color: const Color(0xFF070B2D),
                              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: kIsWeb ? 24 : 20.sp,
                            ),
                          ),
                          SizedBox(width: kIsWeb ? 16 : 12.sp),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context).editCategory,
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 20 : 18.sp,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: kIsWeb ? 4 : 2.sp),
                                Text(
                                  AppLocalizations.of(context).updateNameOfSection,
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 14 : 12.sp,
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: colorScheme.onSurface.withOpacity(0.6),
                              size: kIsWeb ? 24 : 20.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 24 : 20.sp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).categoryName,
                        style: TextStyle(
                          fontSize: kIsWeb ? 14 : 12.sp,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: kIsWeb ? 8 : 6.sp),
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).categoryPlaceholder,
                          filled: true,
                          fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                            borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                            borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                            borderSide: BorderSide(color: colorScheme.primary),
                          ),
                          prefixIcon: Icon(
                            Icons.folder,
                            color: colorScheme.onSurface.withOpacity(0.5),
                            size: kIsWeb ? 20 : 18.sp,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: kIsWeb ? 16 : 14.sp,
                            vertical: kIsWeb ? 14 : 12.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: kIsWeb ? 24 : 20.sp),
                // Footer buttons
                Padding(
                  padding: EdgeInsets.all(kIsWeb ? 24 : 20.sp),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: kIsWeb ? 14 : 12.sp),
                            side: BorderSide(color: colorScheme.outline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 8.sp),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context).cancel,
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                              fontSize: kIsWeb ? 14 : 12.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: kIsWeb ? 12 : 10.sp),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        color: colorScheme.onError,
                                        size: kIsWeb ? 20 : 18.sp,
                                      ),
                                      SizedBox(width: kIsWeb ? 12 : 8.sp),
                                      Text(AppLocalizations.of(context).pleaseEnterCategoryName),
                                    ],
                                  ),
                                  backgroundColor: colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                              return;
                            }

                            try {
                              await FirebaseFirestore.instance
                                  .collection("categories")
                                  .doc(id)
                                  .update({
                                "name": nameController.text.trim(),
                              });

                              Navigator.pop(context);
                              SnackBarHelper.showSuccess(context, AppLocalizations.of(context).categoryUpdatedSuccess);
                            } catch (e) {
                              SnackBarHelper.showError(context, "${AppLocalizations.of(context).errorUpdatingCategory}: $e");
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF070B2D),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: kIsWeb ? 14 : 12.sp),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 8.sp),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context).languageSettings,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: kIsWeb ? 14 : 12.sp,
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
  }

  /// DELETE CATEGORY
  Future<void> deleteCategory(String id, String name) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final screenWidth = Responsive.width(context);
        
        double dialogWidth;
        if (Responsive.isDesktop(context)) {
          dialogWidth = screenWidth > 1400 ? 450 : 400;
        } else if (Responsive.isTablet(context)) {
          dialogWidth = screenWidth * 0.7;
        } else {
          dialogWidth = screenWidth * 0.9;
        }

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: Responsive.isMobile(context) ? 16 : 24,
            vertical: Responsive.isMobile(context) ? 24 : 40,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kIsWeb ? 16 : 14.sp),
          ),
          backgroundColor: colorScheme.surface,
          child: Container(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with title and close button
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(kIsWeb ? 24 : 20.sp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Purple square icon with delete icon
                          Container(
                            width: kIsWeb ? 48 : 40.sp,
                            height: kIsWeb ? 48 : 40.sp,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6),
                              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                            ),
                            child: Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: kIsWeb ? 24 : 20.sp,
                            ),
                          ),
                          SizedBox(width: kIsWeb ? 16 : 12.sp),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context).deleteCategory,
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 20 : 18.sp,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: kIsWeb ? 4 : 2.sp),
                                Text(
                                  AppLocalizations.of(context).removeThisSection,
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 14 : 12.sp,
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context, false),
                            icon: Icon(
                              Icons.close,
                              color: colorScheme.onSurface.withOpacity(0.6),
                              size: kIsWeb ? 24 : 20.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 24 : 20.sp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${AppLocalizations.of(context).areYouSureDelete} \"$name\"?",
                        style: TextStyle(
                          fontSize: kIsWeb ? 16 : 14.sp,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: kIsWeb ? 8 : 6.sp),
                      Text(
                        AppLocalizations.of(context).thisActionCannotBeUndone,
                        style: TextStyle(
                          fontSize: kIsWeb ? 14 : 12.sp,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: kIsWeb ? 24 : 20.sp),
                // Footer buttons
                Padding(
                  padding: EdgeInsets.all(kIsWeb ? 24 : 20.sp),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: kIsWeb ? 14 : 12.sp),
                            side: BorderSide(color: colorScheme.outline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 8.sp),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context).cancel,
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                              fontSize: kIsWeb ? 14 : 12.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: kIsWeb ? 12 : 10.sp),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: kIsWeb ? 14 : 12.sp),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 10 : 8.sp),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context).delete,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: kIsWeb ? 14 : 12.sp,
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

    if (shouldDelete != true) return;

    await FirebaseFirestore.instance.collection("categories").doc(id).delete();
  }

  Future<void> updateOrder(List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance.collection("categories");
    for (int i = 0; i < docs.length; i++) {
      batch.update(col.doc(docs[i].id), {"position": i});
    }
    await batch.commit();
  }

  /// Cart Item Card Widget
  Widget buildCartItemCard({
    required String itemName,
    required String variant,
    required int quantity,
    required int price,
    required VoidCallback onDelete,
    required VoidCallback onQuantityIncrease,
    required VoidCallback onQuantityDecrease,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: kIsWeb ? 8 : 8.sp,
            offset: Offset(0.sp, kIsWeb ? 2 : 2.sp),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: kIsWeb ? 60 : 60.w,
                  height: kIsWeb ? 60 : 60.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    color: const Color(0xFF6B7280),
                    size: kIsWeb ? 24 : 24.sp,
                  ),
                ),
                SizedBox(width: kIsWeb ? 12 : 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: kIsWeb ? 16 : 16.sp,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: kIsWeb ? 4 : 4.h),
                      Text(
                        "$quantity $variant",
                        style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 14 : 14.sp,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      SizedBox(height: kIsWeb ? 4 : 4.h),
                      Text(
                        "₹ $price",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: kIsWeb ? 16 : 16.sp,
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(
                    Icons.delete_outline,
                    color: const Color(0xFF7C3AED),
                    size: kIsWeb ? 24 : 24.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: kIsWeb ? 12 : 12.h),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).quantity,
                  style: GoogleFonts.poppins(
                    fontSize: kIsWeb ? 14 : 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: kIsWeb ? 8 : 8.h),
                Container(
                  height: kIsWeb ? 40 : 40.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: onQuantityDecrease,
                        child: Container(
                          width: kIsWeb ? 32 : 32.w,
                          height: kIsWeb ? 32 : 32.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius.circular(kIsWeb ? 6 : 6.sp),
                            border:
                            Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Icon(Icons.remove,
                              color: const Color(0xFF6B7280),
                              size: kIsWeb ? 16 : 16.sp),
                        ),
                      ),
                      Text(
                        quantity.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 16 : 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      GestureDetector(
                        onTap: onQuantityIncrease,
                        child: Container(
                          width: kIsWeb ? 32 : 32.w,
                          height: kIsWeb ? 32 : 32.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius:
                            BorderRadius.circular(kIsWeb ? 6 : 6.sp),
                          ),
                          child: Icon(Icons.add,
                              color: Colors.white,
                              size: kIsWeb ? 16 : 16.sp),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    AppLocalizations.of(context).categoriesTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w200,
                      color: const Color(0xFF0E1A2F),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: addCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF070B2D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context).addCategory,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("categories")
                      .where("restaurantId", isEqualTo: widget.restaurantId)
                      .orderBy("position")
                      .snapshots(),
                  builder: (context, catSnapshot) {
                    if (!catSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final categories = catSnapshot.data!.docs;
                    if (categories.isEmpty) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context).noCategoriesYet,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: const Color(0xFF808896),
                          ),
                        ),
                      );
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("menu_items")
                          .where("restaurantId",
                          isEqualTo: widget.restaurantId)
                          .snapshots(),
                      builder: (context, menuSnapshot) {
                        final Map<String, int> itemCounts = {};
                        if (menuSnapshot.hasData) {
                          for (final doc in menuSnapshot.data!.docs) {
                            final data =
                            doc.data() as Map<String, dynamic>;
                            final categoryId =
                            (data["categoryId"] ?? "").toString();
                            if (categoryId.isEmpty) continue;
                            itemCounts[categoryId] =
                                (itemCounts[categoryId] ?? 0) + 1;
                          }
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = 1;
                            if (constraints.maxWidth >= 1200) {
                              crossAxisCount = 4;
                            } else if (constraints.maxWidth >= 900) {
                              crossAxisCount = 3;
                            } else if (constraints.maxWidth >= 620) {
                              crossAxisCount = 2;
                            }

                            return GridView.builder(
                              itemCount: categories.length,
                              gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.72,
                              ),
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                final data =
                                cat.data() as Map<String, dynamic>;
                                final name =
                                (data["name"] ?? "").toString();
                                final count = itemCounts[cat.id] ?? 0;

                                return Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                    BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE6E8EF),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              color:
                                              const Color(0xFFFFF2E6),
                                              borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                            ),
                                            child: const Icon(
                                              Icons.folder_open_outlined,
                                              color: Color(0xFFE0752D),
                                              size: 34,
                                            ),
                                          ),
                                          const Spacer(),
                                          // ── Edit button ─────────────────
                                          SizedBox(
                                            width: kIsWeb ? 30 : 30.sp,
                                            height: kIsWeb ? 30 : 30.sp,
                                            child: InkWell(
                                              onTap: () =>
                                                  editCategory(cat.id, name),
                                              borderRadius:
                                              BorderRadius.circular(6),
                                              child: Icon(
                                                Icons.edit_outlined,
                                                size: kIsWeb ? 30 : 20.sp,
                                                color: const Color(0xFF6A7280),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: kIsWeb ? 6 : 6.sp),
                                          // ── Delete button ────────────────
                                          SizedBox(
                                            width: kIsWeb ? 30 : 30.sp,
                                            height: kIsWeb ? 30 : 30.sp,
                                            child: InkWell(
                                              onTap: () =>
                                                  deleteCategory(cat.id, name),
                                              borderRadius:
                                              BorderRadius.circular(6),
                                              child: Icon(
                                                Icons.delete_outline,
                                                size: kIsWeb ? 30 : 20.sp,
                                                color: const Color(0xFFE15757),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "$count ${AppLocalizations.of(context).items}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF8A93A3),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
    );
  }
}
