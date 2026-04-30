// lib/auth/auth_service.dart
//
// Drop-in replacement for your existing auth_service.dart.
// Returns AppUser instead of Map<String,dynamic> — strongly typed,
// no more null checks on string keys.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'models/app_user.dart';
import 'role_resolver.dart';

class AuthService {
  final FirebaseAuth   _auth     = FirebaseAuth.instance;
  final RoleResolver   _resolver = RoleResolver();

  // ── Login ─────────────────────────────────────────────────────────────────

  /// Sign in with email + password, then resolve role from Firestore.
  /// Returns [AppUser] on success, null on any failure.
  Future<AppUser?> login(String email, String password) async {
    try {
      // 1. Firebase Auth sign-in
      final credential = await _auth.signInWithEmailAndPassword(
        email:    email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) return null;

      debugPrint('AUTH: signed in uid=${user.uid}');

      // 2. Resolve role — checks user_access → users → manager scan
      final appUser = await _resolver.resolve(user);

      if (appUser == null) {
        debugPrint('AUTH: no role document found for uid=${user.uid}');
        await _auth.signOut(); // sign out — no role = no access
        return null;
      }

      debugPrint('AUTH: resolved role=${appUser.role} restaurantId=${appUser.restaurantId}');
      return appUser;
    } on FirebaseAuthException catch (e) {
      debugPrint('AUTH FirebaseAuthException: ${e.code} — ${e.message}');
      return null;
    } catch (e) {
      debugPrint('AUTH unexpected error: $e');
      return null;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _auth.signOut();
    debugPrint('AUTH: signed out');
  }

  // ── Auto-login (app restart) ──────────────────────────────────────────────

  /// Called on app start. If Firebase has a persisted session,
  /// resolve and return the AppUser — no password needed.
  Future<AppUser?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      await user.reload(); // ensure token is fresh
      return await _resolver.resolve(_auth.currentUser!);
    } catch (e) {
      debugPrint('AUTH: session restore failed: $e');
      return null;
    }
  }

  /// Stream of auth state changes — useful for StreamBuilder-based routing.
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}