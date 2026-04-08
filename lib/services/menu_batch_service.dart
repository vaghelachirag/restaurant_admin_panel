import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/menu_item_model.dart';


/// Handles batch-writing menu items to Firestore.
/// Splits large batches into chunks of 500 (Firestore limit).
class MenuBatchService {
  final FirebaseFirestore _db;
  static const int _batchSize = 500;

  MenuBatchService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _menuRef(String restaurantId) =>
      _db.collection('menu_items');

  // ──────────────────────────────────────────────────────────
  //  Write Items
  // ──────────────────────────────────────────────────────────

  /// Writes all [items] (filtering out error rows) to Firestore.
  /// Returns the number of items successfully written.
  ///
  /// [onProgress] is called after each batch with cumulative count.
  Future<int> saveItems({
    required String restaurantId,
    required List<MenuItem> items,
    void Function(int saved, int total)? onProgress,
  }) async {
    final validItems = items.where((i) => !i.hasError).toList();
    if (validItems.isEmpty) return 0;

    int saved = 0;
    final chunks = _chunk(validItems, _batchSize);

    for (final chunk in chunks) {
      final batch = _db.batch();
      for (final item in chunk) {
        final ref = _menuRef(restaurantId).doc();
        batch.set(ref, item.toFirestoreMap());
      }
      await batch.commit();
      saved += chunk.length;
      onProgress?.call(saved, validItems.length);
    }

    return saved;
  }

  // ──────────────────────────────────────────────────────────
  //  Helper
  // ──────────────────────────────────────────────────────────

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}