import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/category_model.dart';
import '../data/models/menu_item_model.dart';

class ResolvedCategories {
  final List<MenuItem> items;
  final Map<String, CategoryModel> categoryMap;
  const ResolvedCategories({required this.items, required this.categoryMap});
}

/// Handles all category reads and writes for a restaurant.
/// All paths use the subcollection:
///   restaurants/{restaurantId}/categories/{categoryId}
class CategoryService {
  CollectionReference _ref(String restaurantId) =>
      FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .collection('categories');

  // ── Fetch all categories for a restaurant ─────────────────────────────────

  Future<Map<String, CategoryModel>> fetchAll(String restaurantId) async {
    final snap = await _ref(restaurantId).get();
    final map = <String, CategoryModel>{};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] as String? ?? '').trim().toLowerCase();
      if (name.isNotEmpty) {
        map[name] = CategoryModel(
          id: doc.id,
          name: data['name'] as String? ?? '',
          position: (data['position'] as num?)?.toInt() ?? 0,
          restaurantId: restaurantId,
        );
      }
    }
    return map;
  }

  // ── Resolve categories for CSV upload ────────────────────────────────────
  // For each item, look up its categoryName in existingCategories.
  // If not found, create a new category document and assign its ID.

  Future<ResolvedCategories> resolveCategories({
    required String restaurantId,
    required List<MenuItem> items,
    required Map<String, CategoryModel> existingCategories,
  }) async {
    // Force-refresh token before any write
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await user.getIdToken(true);

    // Work on a mutable copy
    final catMap = Map<String, CategoryModel>.from(existingCategories);
    final updatedItems = <MenuItem>[];

    for (final item in items) {
      if (item.hasError) {
        updatedItems.add(item);
        continue;
      }

      final key = item.categoryName.trim().toLowerCase();
      if (key.isEmpty) {
        updatedItems.add(item.copyWith(
          hasError: true,
          errorMessage: 'Category name is empty for "${item.name}".',
        ));
        continue;
      }

      // Category already exists — reuse its ID
      if (catMap.containsKey(key)) {
        updatedItems.add(item.copyWith(categoryId: catMap[key]!.id));
        continue;
      }

      // Create a new category in the subcollection
      try {
        final ref = await _ref(restaurantId).add({
          'name': item.categoryName.trim(),
          'image': '',
          'restaurantId': restaurantId,
          'position': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final newCat = CategoryModel(
          id: ref.id,
          name: item.categoryName.trim(),
          position: 0,
          restaurantId: restaurantId,
        );
        catMap[key] = newCat;
        updatedItems.add(item.copyWith(categoryId: ref.id));
      } catch (e) {
        updatedItems.add(item.copyWith(
          hasError: true,
          errorMessage: 'Failed to create category "${item.categoryName}": $e',
        ));
      }
    }

    return ResolvedCategories(items: updatedItems, categoryMap: catMap);
  }
}