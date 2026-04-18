import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles in-flight order updates (item qty changes, cancellations, KOT).
/// All Firestore writes use the subcollection path:
///   restaurants/{restaurantId}/orders/{orderId}
class OrderUpdateService {
  static const _editableStatuses = ['pending', 'preparing'];

  /// Returns true if an order in [status] can still be edited by the customer.
  static bool isEditable(String status) =>
      _editableStatuses.contains(status.toLowerCase());

  /// Updates an existing running order:
  ///  - overwrites the `items` array with [updatedExistingItems]
  ///  - appends [newItems] and creates a KOT subcollection doc if non-empty
  ///
  /// Throws if the user is not authenticated or the write fails.
  static Future<void> updateRunningOrder({
    required String restaurantId,
    required String orderId,
    required List<Map<String, dynamic>> updatedExistingItems,
    required List<Map<String, dynamic>> newItems,
  }) async {
    // Force-refresh token so Firestore receives request.auth on every write.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated.');
    await user.getIdToken(true);

    final db = FirebaseFirestore.instance;

    // Subcollection path — consistent with cart_page, restaurant_orders_page, etc.
    final orderRef = db
        .collection('restaurants')
        .doc(restaurantId)
        .collection('orders')
        .doc(orderId);

    // Merge existing (possibly with cancellations) + new items
    final allItems = [
      ...updatedExistingItems,
      ...newItems,
    ];

    final batch = db.batch();

    // 1. Update order items + timestamp
    batch.update(orderRef, {
      'items': allItems,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. If there are new items, create a KOT record for the kitchen
    if (newItems.isNotEmpty) {
      final kotRef = orderRef.collection('kots').doc();
      batch.set(kotRef, {
        'items': newItems,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      });
    }

    await batch.commit();
  }
}