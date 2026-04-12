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

  /// Atomically updates a running order.
  ///
  /// [orderId]              – Firestore document ID of the order.
  /// [updatedExistingItems] – Full list of the order's *existing* items, with
  ///                          any qty or status mutations already applied by the
  ///                          caller (UI working copy).
  /// [newItems]             – Brand-new items being added in this edit session;
  ///                          each map must include {name, variant, qty, price}.
  ///                          A KOT will be generated for these items.
  /// [actorId]              – UID of the user making the change (defaults to
  ///                          the currently signed-in Firebase user, or 'staff').
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
      final existingSnapshot =
          List<dynamic>.from(data['items'] ?? <dynamic>[]);
      final changes = <Map<String, dynamic>>[];

      for (int i = 0;
          i < updatedExistingItems.length && i < existingSnapshot.length;
          i++) {
        final before =
            Map<String, dynamic>.from(existingSnapshot[i] as Map);
        final after = updatedExistingItems[i];

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

        final beforeStatus =
            (before['status'] ?? 'active') as String;
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

  // ── Convenience: status change with audit ───────────────────────────────────

  /// Updates the order status and logs the change.
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
      if (!snap.exists) throw Exception('Order not found');
      final oldStatus =
          (snap.data()!['status'] as String? ?? 'unknown');
      tx.update(orderRef, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final logRef = orderRef.collection('auditLog').doc();
      tx.set(logRef, {
        'changes': [
          {'action': 'status_changed', 'from': oldStatus, 'to': newStatus},
        ],
        'by': actor,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }
}
