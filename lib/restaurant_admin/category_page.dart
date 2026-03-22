import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryPage extends StatefulWidget {
  final String restaurantId;

  const CategoryPage({super.key, required this.restaurantId});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {

  void addCategory() {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Dialog(
          insetPadding:  EdgeInsets.symmetric(horizontal: kIsWeb ? 4 : 4.w, vertical: kIsWeb ? 6 : 6.h),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints:  BoxConstraints(maxWidth: 420.w),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kIsWeb ? 24 : 24.sp),
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: kIsWeb ? 24 : 24.sp,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(kIsWeb ? 24 : 24.sp)),
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.12),
                          colorScheme.primary.withOpacity(0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(kIsWeb ? 8 : 8.sp),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                          ),
                          child: Icon(
                            Icons.category_outlined,
                            color: colorScheme.primary,
                            size: kIsWeb ? 20 : 20.sp,
                          ),
                        ),
                         SizedBox(width: kIsWeb ? 12 : 12.w),
                         Expanded(
                          child: Text(
                            "Add Category",
                            style: TextStyle(
                              fontSize: kIsWeb ? 18 : 18.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Create a new section for your menu.",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                         SizedBox(height: kIsWeb ? 16 : 16.h),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: "Category name",
                            hintText: "e.g. Starters, Desserts",
                            prefixIcon: const Icon(Icons.label_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) async {
                            if (controller.text.trim().isEmpty) return;

                            final snapshot = await FirebaseFirestore.instance
                                .collection("categories")
                                .where(
                                  "restaurantId",
                                  isEqualTo: widget.restaurantId,
                                )
                                .orderBy("position", descending: true)
                                .limit(1)
                                .get();

                            final int position = snapshot.docs.isEmpty
                                ? 0
                                : ((snapshot.docs.first.data()["position"] as num?)?.toInt() ?? 0) + 1;

                            await FirebaseFirestore.instance.collection("categories").add({
                              "name": controller.text.trim(),
                              "restaurantId": widget.restaurantId,
                              "position": position,
                              "createdAt": FieldValue.serverTimestamp(),
                            });

                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                          ),
                          child: const Text("Cancel"),
                        ),
                        SizedBox(width: kIsWeb ? 8 : 8.sp),
                        ElevatedButton.icon(
                          icon: Icon(Icons.check_rounded, size: kIsWeb ? 18 : 18.sp),
                          onPressed: () async {
                            if (controller.text.trim().isEmpty) return;

                            final snapshot = await FirebaseFirestore.instance
                                .collection("categories")
                                .where(
                                  "restaurantId",
                                  isEqualTo: widget.restaurantId,
                                )
                                .orderBy("position", descending: true)
                                .limit(1)
                                .get();

                            final int position = snapshot.docs.isEmpty
                                ? 0
                                : ((snapshot.docs.first.data()["position"] as num?)?.toInt() ?? 0) + 1;

                            await FirebaseFirestore.instance.collection("categories").add({
                              "name": controller.text.trim(),
                              "restaurantId": widget.restaurantId,
                              "position": position,
                              "createdAt": FieldValue.serverTimestamp(),
                            });

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 18 : 18.w, vertical: kIsWeb ? 10 : 10.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                            ),
                          ),
                          label: const Text("Save"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// EDIT CATEGORY
  void editCategory(String id, String name) {

    TextEditingController controller =
    TextEditingController(text: name);

    showDialog(
      context: context,
      builder: (_) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Dialog(
          insetPadding:  EdgeInsets.symmetric(horizontal: kIsWeb ? 4 : 4.w, vertical: kIsWeb ? 6 : 6.h),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints:  BoxConstraints(maxWidth: 420.w),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kIsWeb ? 24 : 24.sp),
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: kIsWeb ? 24 : 24.sp,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(kIsWeb ? 24 : 24.sp)),
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.secondary.withOpacity(0.14),
                          colorScheme.secondary.withOpacity(0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding:  EdgeInsets.all(kIsWeb ? 8 : 8.sp),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: colorScheme.secondary,
                            size: kIsWeb ? 20 : 20.sp,
                          ),
                        ),
                         SizedBox(width: kIsWeb ? 12 : 12.w),
                         Expanded(
                          child: Text(
                            "Edit Category",
                            style: TextStyle(
                              fontSize: kIsWeb ? 18 : 18.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Rename this menu section.",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: kIsWeb ? 16 : 16.h),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: "Category name",
                            prefixIcon: const Icon(Icons.label_important_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) async {
                            await FirebaseFirestore.instance
                                .collection("categories")
                                .doc(id)
                                .update({"name": controller.text.trim()});

                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                          ),
                          child: const Text("Cancel"),
                        ),
                        SizedBox(width: kIsWeb ? 8 : 8.w),
                        ElevatedButton.icon(
                          icon:  Icon(Icons.check_circle_rounded, size: kIsWeb ? 18 : 18.sp),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection("categories")
                                .doc(id)
                                .update({"name": controller.text.trim()});

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding:  EdgeInsets.symmetric(horizontal: kIsWeb ? 18 : 18.w, vertical: kIsWeb ? 10 : 10.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                            ),
                          ),
                          label: const Text("Update"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
      builder: (_) {
        final theme = Theme.of(context);

        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: kIsWeb ? 4 : 4.w, vertical: kIsWeb ? 6 : 6.h),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints:  BoxConstraints(maxWidth: 420.w),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kIsWeb ? 24 : 24.sp),
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: kIsWeb ? 26 : 26.sp,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(kIsWeb ? 24 : 24.sp)),
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.shade50,
                          Colors.red.shade100.withOpacity(0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding:  EdgeInsets.all(kIsWeb ? 8 : 8.sp),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red.shade600,
                            size: kIsWeb ? 22 : 22.sp,
                          ),
                        ),
                        const SizedBox(width: 12),
                         Expanded(
                          child: Text(
                            "Delete Category",
                            style: TextStyle(
                              fontSize: kIsWeb ? 18 : 18.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Are you sure you want to delete "$name"?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "This action cannot be undone.",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade800,
                          ),
                          child: const Text("Cancel"),
                        ),
                         SizedBox(width: kIsWeb ? 8 : 8.w),
                        ElevatedButton.icon(
                          icon:  Icon(Icons.delete_outline_rounded, size: kIsWeb ? 18 : 18.sp),
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding:  EdgeInsets.symmetric(horizontal: kIsWeb ? 18 : 18.w, vertical: kIsWeb ? 10 : 10.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                            ),
                          ),
                          label: const Text("Delete"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                // Item Image (placeholder)
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
                // Item Details
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
                // Delete Icon
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
            // Quantity Label and Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Quantity",
                  style: GoogleFonts.poppins(
                    fontSize: kIsWeb ? 14 : 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: kIsWeb ? 8 : 8.h),
                // Quantity Selector
                Container(
                  height: kIsWeb ? 40 : 40.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Minus button
                      GestureDetector(
                        onTap: onQuantityDecrease,
                        child: Container(
                          width: kIsWeb ? 32 : 32.w,
                          height: kIsWeb ? 32 : 32.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(kIsWeb ? 6 : 6.sp),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Icon(
                            Icons.remove,
                            color: const Color(0xFF6B7280),
                            size: kIsWeb ? 16 : 16.sp,
                          ),
                        ),
                      ),
                      // Quantity display
                      Text(
                        quantity.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 16 : 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      // Plus button
                      GestureDetector(
                        onTap: onQuantityIncrease,
                        child: Container(
                          width: kIsWeb ? 32 : 32.w,
                          height: kIsWeb ? 32 : 32.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(kIsWeb ? 6 : 6.sp),
                          ),
                          child: Icon(
                            Icons.add,
                            color: Colors.white,
                            size: kIsWeb ? 16 : 16.sp,
                          ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;



    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addCategory,
        icon: const Icon(Icons.add),
        label: const Text("Add Category"),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withOpacity(0.06),
              colorScheme.primary.withOpacity(0.14),
              colorScheme.secondary.withOpacity(0.10),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:  EdgeInsets.all(kIsWeb ? 24 : 24.sp),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: kIsWeb ? 10 : 10.sp,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
                      ),
                      child:  Icon(
                        Icons.category,
                        color: Colors.white,
                        size: kIsWeb ? 28 : 28.sp,
                      ),
                    ),
                     SizedBox(width: kIsWeb ? 16 : 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Categories",
                            style: TextStyle(
                              fontSize: kIsWeb ? 24 : 24.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                           SizedBox(height: kIsWeb ? 4 : 4.h),
                          Text(
                            "Organize and prioritize your menu sections",
                            style: TextStyle(
                              fontSize: kIsWeb ? 14 : 14.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // BODY
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth > 900;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide
                            ? constraints.maxWidth * 0.2
                            : 16.w,
                        vertical: 16.h,
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection("categories")
                            .where(
                              "restaurantId",
                              isEqualTo: widget.restaurantId,
                            )
                            .orderBy("position")
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          List<QueryDocumentSnapshot> categories =
                              List.from(snapshot.data!.docs);

                          if (categories.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: kIsWeb ? 48 : 48.sp,
                                    color: Colors.grey.shade400,
                                  ),
                                   SizedBox(height: kIsWeb ? 12 : 12.h),
                                  Text(
                                    "No categories yet",
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 16 : 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Tap \"Add Category\" to create your first one.",
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 13 : 13.sp,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: categories.length,
                            onReorder: (oldIndex, newIndex) async {
                              if (newIndex > oldIndex) newIndex--;
                              final item = categories.removeAt(oldIndex);
                              categories.insert(newIndex, item);
                              await updateOrder(categories);
                            },
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final data =
                                  cat.data() as Map<String, dynamic>;
                              final int position = data["position"] is num
                                  ? (data["position"] as num).toInt()
                                  : index;

                              return Container(
                                key: ValueKey(cat.id),
                                margin:  EdgeInsets.symmetric(
                                  horizontal: 4.w,
                                  vertical: 6.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: kIsWeb ? 8 : 8.sp,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding:  EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 8.h,
                                  ),
                                  leading: ReorderableDragStartListener(
                                    index: index,
                                    child: Container(
                                      padding:  EdgeInsets.all(kIsWeb ? 8 : 8.sp),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius:
                                            BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                      ),
                                      child: Icon(
                                        Icons.drag_handle,
                                        color: Colors.orange.shade400,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    data['name'] ?? '',
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 16 : 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Position: ${position + 1}",
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 12 : 12.sp,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: Colors.blue.shade500,
                                        ),
                                        onPressed: () => editCategory(
                                          cat.id,
                                          data['name'] ?? '',
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red.shade400,
                                        ),
                                        onPressed: () => deleteCategory(
                                          cat.id,
                                          data['name'] ?? '',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
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