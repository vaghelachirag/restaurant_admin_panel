import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for atomically updating a running order in Firestore.
///
/// Responsibilities:
///   - Guard against editing locked orders (Ready / Completed)
///   - Merge item changes (qty updates, cancellations, additions)
///   - Recalculate order total
///   - Write a new KOT sub-document for every batch of added items
///   - Write an audit-log entry for every mutation
///   - Handle concurrency with a Firestore transaction
class OrderUpdateService {
  static final _db = FirebaseFirestore.instance;

  // ── Lifecycle helper ────────────────────────────────────────────────────────

  /// Returns true when the order may still be edited.
  static bool isEditable(String status) =>
      status == 'pending' || status == 'preparing';

  // ── Core update ─────────────────────────────────────────────────────────────

  /// Updates a running order atomically.
  ///
  /// [orderId]              — Firestore document ID of the order.
  /// [updatedExistingItems] — Full list of existing items with any qty / status
  ///                          mutations already applied. Each map MUST contain
  ///                          an `id` field that matches the original item.
  /// [newItems]             — Brand-new items to append to the order.
  /// [actorId]              — UID of the staff member making the change
  ///                          (falls back to FirebaseAuth current user, then
  ///                          the literal string 'staff').
  static Future<void> updateRunningOrder({
    required String orderId,
    required List<Map<String, dynamic>> updatedExistingItems,
    required List<Map<String, dynamic>> newItems,
    String? actorId,
  }) async {
    final actor =
        actorId ?? FirebaseAuth.instance.currentUser?.uid ?? 'staff';

    await _db.runTransaction((tx) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final snap = await tx.get(orderRef);

      if (!snap.exists) throw Exception('Order not found: $orderId');

      final data = snap.data()!;
      final status = (data['status'] as String? ?? 'pending');

      if (!isEditable(status)) {
        throw Exception(
          'Order cannot be edited — current status is "$status". '
              'Edits are only allowed while status is "pending" or "preparing".',
        );
      }

      // ── Build audit changes ──────────────────────────────────────────────
      //
      // Match by item `id` field instead of array index so that position
      // shifts (e.g. a middle item was previously removed) never produce
      // false qty-change audit entries.
      final existingSnapshot =
      List<Map<String, dynamic>>.from(
        (data['items'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      // Build a lookup map: itemId → snapshot data
      final existingById = <String, Map<String, dynamic>>{
        for (final item in existingSnapshot)
          if (item['id'] != null) item['id'] as String: item,
      };

      final changes = <Map<String, dynamic>>[];

      for (final after in updatedExistingItems) {
        final itemId = after['id'] as String?;
        if (itemId == null) continue;

        final before = existingById[itemId];
        if (before == null) continue;

        // Qty change
        final beforeQty = (before['qty'] ?? 1) as int;
        final afterQty = (after['qty'] ?? 1) as int;
        if (beforeQty != afterQty) {
          changes.add({
            'action': 'qty_updated',
            'item': before['name'],
            'from': beforeQty,
            'to': afterQty,
          });
        }

        // Cancellation
        final beforeStatus = (before['status'] ?? 'active') as String;
        final afterStatus = (after['status'] ?? 'active') as String;
        if (beforeStatus != afterStatus && afterStatus == 'cancelled') {
          changes.add({
            'action': 'item_cancelled',
            'item': before['name'],
          });
        }
      }

      for (final item in newItems) {
        changes.add({
          'action': 'item_added',
          'item': item['name'],
          'qty': item['qty'],
          'price': item['price'],
        });
      }

      // ── Merge items ──────────────────────────────────────────────────────
      final allItems = <Map<String, dynamic>>[
        ...updatedExistingItems,
        ...newItems.map(
              (i) => <String, dynamic>{...i, 'status': 'active'},
        ),
      ];

      // ── Recalculate total (active items only) ────────────────────────────
      double total = 0;
      for (final item in allItems) {
        if ((item['status'] ?? 'active') == 'active') {
          final price = (item['price'] ?? 0) as num;
          final qty = (item['qty'] ?? 1) as num;
          total += price * qty;
        }
      }

      // ── Write order update ───────────────────────────────────────────────
      tx.update(orderRef, {
        'items': allItems,
        'totalAmount': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── Write KOT (only when new items are added) ────────────────────────
      if (newItems.isNotEmpty) {
        final kotRef = orderRef.collection('kots').doc();
        tx.set(kotRef, {
          'items': newItems
              .map((i) => {
            'name': i['name'] ?? '',
            'variant': i['variant'] ?? '',
            'qty': i['qty'],
          })
              .toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'generatedBy': actor,
          'note': 'Additional order — KOT auto-generated',
        });
      }

      // ── Write audit log ──────────────────────────────────────────────────
      //
      // The auditLog subcollection MUST have a corresponding Firestore rule:
      //   match /auditLog/{logId} {
      //     allow read: if request.auth != null;
      //     allow create: if request.auth != null;
      //     allow update, delete: if false;
      //   }
      if (changes.isNotEmpty) {
        final logRef = orderRef.collection('auditLog').doc();
        tx.set(logRef, {
          'changes': changes,
          'by': actor,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ── Convenience: cancel a single item ──────────────────────────────────────

  /// Cancels a single item by [itemId] inside [orderId].
  ///
  /// This is a thin wrapper around [updateRunningOrder] for the common
  /// "waiter cancels one item" use-case.
  static Future<void> cancelItem({
    required String orderId,
    required String itemId,
    String? actorId,
  }) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final snap = await orderRef.get();
    if (!snap.exists) throw Exception('Order not found: $orderId');

    final items = List<Map<String, dynamic>>.from(
      (snap.data()!['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    final updated = items.map((item) {
      if (item['id'] == itemId) {
        return {...item, 'status': 'cancelled'};
      }
      return item;
    }).toList();

    await updateRunningOrder(
      orderId: orderId,
      updatedExistingItems: updated,
      newItems: const [],
      actorId: actorId,
    );
  }

  // ── Convenience: status change with audit ───────────────────────────────────

  /// Updates the order status and logs the change.
  ///
  /// Does NOT enforce [isEditable]; call sites are responsible for
  /// deciding which status transitions are legal.
  static Future<void> updateStatus({
    required String orderId,
    required String newStatus,
    String? actorId,
  }) async {
    final actor =
        actorId ?? FirebaseAuth.instance.currentUser?.uid ?? 'staff';

    await _db.runTransaction((tx) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found: $orderId');

      final oldStatus =
      (snap.data()!['status'] as String? ?? 'unknown');

      tx.update(orderRef, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Audit log — same subcollection rule applies (see comment above)
      final logRef = orderRef.collection('auditLog').doc();
      tx.set(logRef, {
        'changes': [
          {
            'action': 'status_changed',
            'from': oldStatus,
            'to': newStatus,
          },
        ],
        'by': actor,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }
}