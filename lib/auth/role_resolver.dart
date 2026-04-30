// lib/auth/role_resolver.dart
//
// RoleResolver — the single place that answers "who is this UID?"
//
// LOOKUP ORDER (fast → slow):
//   1. user_access/{uid}   ← flat index, O(1) lookup, works for ALL roles
//   2. users/{uid}         ← legacy fallback for super_admin / admin
//   3. Scan restaurants/{*}/managers/{uid} ← last resort if index missing
//
// WHY user_access collection?
//   Without it, manager lookups require scanning every restaurant's
//   managers subcollection — that is O(n) reads and cannot be secured cleanly.
//   user_access is a flat index: one read, any role, always O(1).
//
// Firestore structure this resolver expects:
//
//   user_access/{uid}
//     role: "super_admin" | "admin" | "manager"
//     restaurantId: "xxx"          // admin + manager
//     managerId: "yyy"             // manager only
//
//   users/{uid}                    // super_admin + admin (legacy / write-through)
//     role: "super_admin" | "admin"
//     restaurantId: "xxx"          // admin only
//
//   restaurants/{restaurantId}/managers/{managerId}
//     uid: "firebase-auth-uid"     // REQUIRED for reverse lookup
//     name: "..."
//     email: "..."

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'models/app_user.dart';

class RoleResolver {
  final FirebaseFirestore _db;

  RoleResolver({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Public entry point ────────────────────────────────────────────────────

  /// Resolve the role + metadata for the currently signed-in [user].
  /// Returns null if the user has no role document in Firestore.
  Future<AppUser?> resolve(User user) async {
    // 1. Try user_access index first (fastest, covers all roles)
    final fromIndex = await _resolveFromUserAccess(user);
    if (fromIndex != null) return fromIndex;

    // 2. Fallback: legacy users collection (super_admin / admin)
    final fromUsers = await _resolveFromUsersCollection(user);
    if (fromUsers != null) return fromUsers;

    // 3. Last resort: scan managers subcollections
    // Only runs if user_access is missing AND users collection has no doc.
    // Write the index on success so future logins skip this scan.
    final fromScan = await _resolveByManagerScan(user);
    if (fromScan != null) {
      await _writeUserAccessIndex(fromScan); // auto-heal missing index
    }
    return fromScan;
  }

  // ── Step 1: user_access flat index ───────────────────────────────────────

  Future<AppUser?> _resolveFromUserAccess(User user) async {
    try {
      final doc = await _db.collection('user_access').doc(user.uid).get();
      if (!doc.exists) return null;

      final data         = doc.data()!;
      final role         = AppUser.roleFromString(data['role'] as String?);
      final restaurantId = data['restaurantId'] as String?;
      final managerId    = data['managerId']    as String?;

      if (role == UserRole.unknown) return null;

      return AppUser(
        uid:          user.uid,
        email:        user.email ?? '',
        role:         role,
        restaurantId: restaurantId,
        managerId:    managerId,
        name:         data['name'] as String?,
      );
    } catch (e) {
      debugPrint('RoleResolver._resolveFromUserAccess error: $e');
      return null;
    }
  }

  // ── Step 2: legacy users collection ──────────────────────────────────────

  Future<AppUser?> _resolveFromUsersCollection(User user) async {
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      final data         = doc.data()!;
      final role         = AppUser.roleFromString(data['role'] as String?);
      final restaurantId = data['restaurantId'] as String?;

      if (role == UserRole.unknown) return null;

      // Auto-create the user_access index for next time
      final appUser = AppUser(
        uid:          user.uid,
        email:        user.email ?? '',
        role:         role,
        restaurantId: restaurantId,
        name:         data['name'] as String?,
      );
      await _writeUserAccessIndex(appUser);
      return appUser;
    } catch (e) {
      debugPrint('RoleResolver._resolveFromUsersCollection error: $e');
      return null;
    }
  }

  // ── Step 3: manager scan (last resort) ───────────────────────────────────

  Future<AppUser?> _resolveByManagerScan(User user) async {
    try {
      // collectionGroup query — searches ALL managers subcollections at once
      // Requires a Firestore index on: managers / uid (single field)
      final snap = await _db
          .collectionGroup('managers')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;

      final doc          = snap.docs.first;
      final data         = doc.data();
      // Parent path: restaurants/{restaurantId}/managers/{managerId}
      final restaurantId = doc.reference.parent.parent!.id;
      final managerId    = doc.id;

      return AppUser(
        uid:          user.uid,
        email:        user.email ?? '',
        role:         UserRole.manager,
        restaurantId: restaurantId,
        managerId:    managerId,
        name:         data['name'] as String?,
      );
    } catch (e) {
      debugPrint('RoleResolver._resolveByManagerScan error: $e');
      return null;
    }
  }

  // ── Index writer (auto-heal) ──────────────────────────────────────────────

  Future<void> _writeUserAccessIndex(AppUser u) async {
    try {
      await _db.collection('user_access').doc(u.uid).set({
        'role'        : _roleToString(u.role),
        'restaurantId': u.restaurantId,
        'managerId'   : u.managerId,
        'name'        : u.name,
        'email'       : u.email,
        'updatedAt'   : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('RoleResolver._writeUserAccessIndex error: $e');
    }
  }

  String _roleToString(UserRole r) => switch (r) {
    UserRole.superAdmin => 'super_admin',
    UserRole.admin      => 'admin',
    UserRole.manager    => 'manager',
    UserRole.unknown    => 'unknown',
  };
}