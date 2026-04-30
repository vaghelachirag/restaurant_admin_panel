// lib/auth/migration/migrate_user_access.dart
//
// ONE-TIME migration script.
// Run this ONCE from a super_admin screen to build the user_access index
// from your existing users collection and managers subcollections.
//
// After running, every login will use user_access (O(1) lookup).
// Safe to run multiple times — uses SetOptions(merge: true).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserAccessMigration {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<MigrationResult> run() async {
    int created = 0;
    int failed  = 0;
    final errors = <String>[];

    debugPrint('MIGRATION: Starting user_access index build…');

    // ── 1. Migrate users collection (super_admin + admin) ──────────────────
    try {
      final usersSnap = await _db.collection('users').get();
      for (final doc in usersSnap.docs) {
        try {
          final data = doc.data();
          await _db.collection('user_access').doc(doc.id).set({
            'role'        : data['role'],
            'restaurantId': data['restaurantId'],
            'managerId'   : null,
            'email'       : data['email'],
            'name'        : data['name'],
            'updatedAt'   : FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          created++;
          debugPrint('MIGRATION: users → user_access [${doc.id}] role=${data['role']}');
        } catch (e) {
          failed++;
          errors.add('users/${doc.id}: $e');
        }
      }
    } catch (e) {
      errors.add('Failed to read users collection: $e');
    }

    // ── 2. Migrate managers subcollections ─────────────────────────────────
    try {
      final restaurantsSnap = await _db.collection('restaurants').get();
      for (final restaurant in restaurantsSnap.docs) {
        final restaurantId = restaurant.id;
        try {
          final managersSnap = await _db
              .collection('restaurants')
              .doc(restaurantId)
              .collection('managers')
              .get();

          for (final managerDoc in managersSnap.docs) {
            try {
              final data = managerDoc.data();
              final uid  = data['uid'] as String?;

              if (uid == null || uid.isEmpty) {
                errors.add(
                  'restaurants/$restaurantId/managers/${managerDoc.id}: '
                      'missing uid field — skipped',
                );
                failed++;
                continue;
              }

              await _db.collection('user_access').doc(uid).set({
                'role'        : 'manager',
                'restaurantId': restaurantId,
                'managerId'   : managerDoc.id,
                'email'       : data['email'],
                'name'        : data['name'],
                'updatedAt'   : FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              created++;
              debugPrint(
                'MIGRATION: managers → user_access [$uid] '
                    'restaurant=$restaurantId manager=${managerDoc.id}',
              );
            } catch (e) {
              failed++;
              errors.add('restaurants/$restaurantId/managers/${managerDoc.id}: $e');
            }
          }
        } catch (e) {
          errors.add('restaurants/$restaurantId/managers: $e');
        }
      }
    } catch (e) {
      errors.add('Failed to read restaurants collection: $e');
    }

    debugPrint('MIGRATION: Done. created=$created failed=$failed');
    return MigrationResult(created: created, failed: failed, errors: errors);
  }
}

class MigrationResult {
  final int          created;
  final int          failed;
  final List<String> errors;

  const MigrationResult({
    required this.created,
    required this.failed,
    required this.errors,
  });

  bool get success => failed == 0;

  @override
  String toString() =>
      'MigrationResult(created=$created, failed=$failed, errors=$errors)';
}