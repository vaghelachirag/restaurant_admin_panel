import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/menu_item_model.dart';


/// Handles batch-writing menu items to Firestore.
/// Splits large batches into chunks of 500 (Firestore limit).
class MenuBatchService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  static const int _batchSize = 500;

  MenuBatchService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference _menuRef(String restaurantId) =>
      _db.collection('restaurants').doc(restaurantId).collection('menu_items');

  Future<int> saveItems({
    required String restaurantId,
    required List<MenuItem> items,
    void Function(int saved, int total)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception(
        'Permission denied: no authenticated user. '
            'Please sign in as an admin before saving menu items.',
      );
    }

    // Force-refresh so Firestore receives a valid ID token immediately.
    await user.getIdToken(true);

    final validItems = items.where((i) => !i.hasError).toList();
    if (validItems.isEmpty) return 0;

    int saved = 0;
    final chunks = _chunk(validItems, _batchSize);

    for (final chunk in chunks) {
      final batch = _db.batch();
      for (final item in chunk) {
        final ref = _menuRef(restaurantId).doc();
        final data = {
          ...item.toFirestoreMap(),
          'restaurantId': restaurantId,
          'isAvailable': item.toFirestoreMap()['isAvailable'] ?? true,
          'createdAt': FieldValue.serverTimestamp(),
        };
        batch.set(ref, data);
      }
      await batch.commit();
      saved += chunk.length;
      onProgress?.call(saved, validItems.length);
    }

    return saved;
  }

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}