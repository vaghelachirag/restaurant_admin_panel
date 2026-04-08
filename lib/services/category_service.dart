import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/category_model.dart';
import '../data/models/menu_item_model.dart';

/// Handles all Firestore interactions for categories:
///  - Fetch all categories for a restaurant (single read, cached)
///  - Resolve category name → categoryId (creating new ones as needed)
class CategoryService {
  final FirebaseFirestore _db;

  CategoryService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _catRef(String restaurantId) =>
      _db.collection('categories');

  // ──────────────────────────────────────────────────────────
  //  Fetch (single read → Map<name, CategoryModel>)
  // ──────────────────────────────────────────────────────────

  /// Returns a name-keyed map of all existing categories for [restaurantId].
  /// Keys are lower-cased for case-insensitive lookup.
  Future<Map<String, CategoryModel>> fetchAll(String restaurantId) async {
    final snap = await _catRef(restaurantId)
        .where('restaurantId', isEqualTo: restaurantId)
        .get();
    final map = <String, CategoryModel>{};
    for (final doc in snap.docs) {
      final cat = CategoryModel.fromFirestore(doc);
      map[cat.name.toLowerCase()] = cat;
    }
    return map;
  }

  // ──────────────────────────────────────────────────────────
  //  Resolve Categories for a batch of MenuItems
  // ──────────────────────────────────────────────────────────

  /// Given a list of [items] (each with only categoryName set),
  /// resolves or creates categories and returns updated items + updated map.
  Future<({List<MenuItem> items, Map<String, CategoryModel> categoryMap})>
  resolveCategories({
    required String restaurantId,
    required List<MenuItem> items,
    required Map<String, CategoryModel> existingCategories,
  }) async {
    // Work on a mutable copy of the map
    final catMap = Map<String, CategoryModel>.from(existingCategories);

    // Collect unique category names that need creation
    final missingNames = <String>{};
    for (final item in items) {
      if (item.hasError) continue;
      final key = item.categoryName.toLowerCase().trim();
      if (key.isNotEmpty && !catMap.containsKey(key)) {
        missingNames.add(item.categoryName.trim());
      }
    }

    // Create missing categories (batched)
    if (missingNames.isNotEmpty) {
      await _createCategories(
        restaurantId: restaurantId,
        names: missingNames.toList(),
        catMap: catMap,
        existingCount: catMap.length,
      );
    }

    // Assign categoryId + categoryName to each item
    final resolved = items.map((item) {
      if (item.hasError) return item;
      final key = item.categoryName.toLowerCase().trim();
      final cat = catMap[key];
      if (cat == null) {
        return item.copyWith(
          hasError: true,
          errorMessage: 'Could not resolve category "${item.categoryName}".',
        );
      }
      return item.copyWith(
        categoryId: cat.id,
        categoryName: cat.name, // use canonical Firestore name
      );
    }).toList();

    return (items: resolved, categoryMap: catMap);
  }

  // ──────────────────────────────────────────────────────────
  //  Internal: Create new categories via WriteBatch
  // ──────────────────────────────────────────────────────────

  Future<void> _createCategories({
    required String restaurantId,
    required List<String> names,
    required Map<String, CategoryModel> catMap,
    required int existingCount,
  }) async {
    // Firestore batch limit = 500; categories are usually well below that
    final batch = _db.batch();
    int position = existingCount;

    for (final name in names) {
      final ref = _catRef(restaurantId).doc(); // auto-id
      final cat = CategoryModel(
        id: ref.id,
        name: name,
        position: position++,
        restaurantId: restaurantId,
        createdAt: DateTime.now(),
      );
      batch.set(ref, cat.toFirestoreMap());
      catMap[name.toLowerCase()] = cat;
    }

    await batch.commit();
  }
}