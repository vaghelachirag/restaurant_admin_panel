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
        bool _saving = false;

        Future<void> _doSave(StateSetter setDialogState) async {
          if (controller.text.trim().isEmpty) return;
          setDialogState(() => _saving = true);

          final snapshot = await FirebaseFirestore.instance
              .collection("categories")
              .where("restaurantId", isEqualTo: widget.restaurantId)
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
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                  horizontal: kIsWeb ? 4 : 4.w, vertical: kIsWeb ? 6 : 6.h),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420.w),
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
                      // ── Header ──────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(kIsWeb ? 24 : 24.sp)),
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
                                borderRadius:
                                BorderRadius.circular(kIsWeb ? 14 : 14.sp),
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
                      // ── Body ────────────────────────────────────────────
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
                              enabled: !_saving,
                              decoration: InputDecoration(
                                labelText: "Category name",
                                hintText: "e.g. Starters, Desserts",
                                prefixIcon: const Icon(Icons.label_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      kIsWeb ? 14 : 14.sp),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  _doSave(setDialogState),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Divider(height: 1),
                      // ── Footer ──────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed:
                              _saving ? null : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                              ),
                              child: const Text("Cancel"),
                            ),
                            SizedBox(width: kIsWeb ? 8 : 8.sp),
                            ElevatedButton.icon(
                              icon: _saving
                                  ? SizedBox(
                                width: kIsWeb ? 18 : 18.sp,
                                height: kIsWeb ? 18 : 18.sp,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary),
                                ),
                              )
                                  : Icon(Icons.check_rounded,
                                  size: kIsWeb ? 18 : 18.sp),
                              onPressed: _saving
                                  ? null
                                  : () => _doSave(setDialogState),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    horizontal: kIsWeb ? 18 : 18.w,
                                    vertical: kIsWeb ? 10 : 10.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      kIsWeb ? 14 : 14.sp),
                                ),
                              ),
                              label: Text(_saving ? "Saving…" : "Save"),
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
      },
    );
  }

  /// EDIT CATEGORY
  void editCategory(String id, String name) {
    TextEditingController controller = TextEditingController(text: name);

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;
        bool _saving = false;

        Future<void> _doUpdate(StateSetter setDialogState) async {
          if (controller.text.trim().isEmpty) return;
          setDialogState(() => _saving = true);

          await FirebaseFirestore.instance
              .collection("categories")
              .doc(id)
              .update({"name": controller.text.trim()});

          Navigator.pop(dialogContext);
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                  horizontal: kIsWeb ? 4 : 4.w, vertical: kIsWeb ? 6 : 6.h),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420.w),
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
                      // ── Header ──────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(kIsWeb ? 24 : 24.sp)),
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
                              padding: EdgeInsets.all(kIsWeb ? 8 : 8.sp),
                              decoration: BoxDecoration(
                                color: colorScheme.secondary.withOpacity(0.16),
                                borderRadius:
                                BorderRadius.circular(kIsWeb ? 14 : 14.sp),
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
                                  color: colorScheme.onSurface,
                                  fontSize: kIsWeb ? 18 : 18.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Body ────────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Rename this menu section.",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            SizedBox(height: kIsWeb ? 16 : 16.h),
                            TextField(
                              controller: controller,
                              autofocus: true,
                              enabled: !_saving,
                              decoration: InputDecoration(
                                labelText: "Category name",
                                prefixIcon: Icon(
                                  Icons.label_important_outline,
                                  color:
                                  colorScheme.onSurface.withOpacity(0.5),
                                ),
                                labelStyle:
                                theme.textTheme.bodySmall?.copyWith(
                                  color:
                                  colorScheme.onSurface.withOpacity(0.8),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      kIsWeb ? 14 : 14.sp),
                                  borderSide: BorderSide(
                                      color: colorScheme.outline
                                          .withOpacity(0.2)),
                                ),
                                filled: true,
                                fillColor:
                                colorScheme.surfaceVariant.withOpacity(0.3),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      kIsWeb ? 14 : 14.sp),
                                  borderSide: BorderSide(
                                      color: colorScheme.outline
                                          .withOpacity(0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      kIsWeb ? 14 : 14.sp),
                                  borderSide:
                                  BorderSide(color: colorScheme.primary),
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  _doUpdate(setDialogState),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Divider(height: 1),
                      // ── Footer ──────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                colorScheme.onSurface.withOpacity(0.7),
                              ),
                              child: const Text("Cancel"),
                            ),
                            SizedBox(width: kIsWeb ? 8 : 8.w),
                            ElevatedButton.icon(
                              icon: _saving
                                  ? SizedBox(
                                width: kIsWeb ? 18 : 18.sp,
                                height: kIsWeb ? 18 : 18.sp,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary),
                                ),
                              )
                                  : Icon(
                                Icons.check_circle_rounded,
                                size: kIsWeb ? 18 : 18.sp,
                                color: colorScheme.onPrimary,
                              ),
                              onPressed: _saving
                                  ? null
                                  : () => _doUpdate(setDialogState),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: EdgeInsets.symmetric(
                                    horizontal: kIsWeb ? 18 : 18.w,
                                    vertical: kIsWeb ? 10 : 10.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      kIsWeb ? 14 : 14.sp),
                                ),
                              ),
                              label: Text(_saving ? "Updating…" : "Update"),
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
          insetPadding: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 4 : 4.w, vertical: kIsWeb ? 6 : 6.h),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420.w),
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
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(kIsWeb ? 24 : 24.sp)),
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
                          padding: EdgeInsets.all(kIsWeb ? 8 : 8.sp),
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
                          icon: Icon(Icons.delete_outline_rounded,
                              size: kIsWeb ? 18 : 18.sp),
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: kIsWeb ? 18 : 18.w,
                                vertical: kIsWeb ? 10 : 10.h),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(kIsWeb ? 14 : 14.sp),
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
                  "Quantity",
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
                    "Categories",
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
                          "Add Category",
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
                          "No categories yet",
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
                                            width: 64,
                                            height: 64,
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
                                              size: 22,
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
                                                size: kIsWeb ? 20 : 20.sp,
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
                                                size: kIsWeb ? 20 : 20.sp,
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
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "$count items",
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
