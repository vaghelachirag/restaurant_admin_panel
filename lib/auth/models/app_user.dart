// lib/auth/models/app_user.dart
//
// Central user model returned after every login.
// Contains everything the app needs to route and identify the user.

enum UserRole { superAdmin, admin, manager, unknown }

class AppUser {
  final String uid;
  final String email;
  final UserRole role;
  final String? restaurantId; // null for super_admin
  final String? managerId;    // only for manager role
  final String? name;

  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.restaurantId,
    this.managerId,
    this.name,
  });

  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isAdmin      => role == UserRole.admin;
  bool get isManager    => role == UserRole.manager;

  /// Convert Firestore role string → enum
  static UserRole roleFromString(String? r) => switch (r?.toLowerCase().trim()) {
    'super_admin' => UserRole.superAdmin,
    'admin'       => UserRole.admin,
    'manager'     => UserRole.manager,
    _             => UserRole.unknown,
  };

  @override
  String toString() =>
      'AppUser(uid: $uid, role: $role, restaurantId: $restaurantId)';
}