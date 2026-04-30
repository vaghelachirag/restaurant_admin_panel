import 'package:shared_preferences/shared_preferences.dart';
import '../auth/models/app_user.dart';

/// Persists the logged-in [AppUser] across app restarts using shared_preferences.
///
/// Usage:
///   await SessionManager.save(user);             // after successful login
///   final user = await SessionManager.restore(); // on splash screen
///   await SessionManager.logout();               // on logout
class SessionManager {
  SessionManager._();

  // ── Keys ──────────────────────────────────────────────────────────────────

  static const _kUid          = 'session_uid';
  static const _kEmail        = 'session_email';
  static const _kName         = 'session_name';
  static const _kRole         = 'session_role';
  static const _kRestaurantId = 'session_restaurant_id';
  static const _kManagerId    = 'session_manager_id';
  static const _kLoggedIn     = 'session_logged_in';

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Persists [user] to local storage. Call right after a successful login.
  static Future<void> save(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, true);
    await prefs.setString(_kUid,   user.uid);
    await prefs.setString(_kEmail, user.email);
    await prefs.setString(_kRole,  _roleToString(user.role));
    if (user.name         != null) await prefs.setString(_kName,         user.name!);
    if (user.restaurantId != null) await prefs.setString(_kRestaurantId, user.restaurantId!);
    if (user.managerId    != null) await prefs.setString(_kManagerId,    user.managerId!);
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  /// Returns the saved [AppUser], or null if no valid session exists.
  /// Call this in the splash screen to decide whether to skip login.
  static Future<AppUser?> restore() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final loggedIn = prefs.getBool(_kLoggedIn) ?? false;
      final uid      = prefs.getString(_kUid);
      final role     = prefs.getString(_kRole);

      if (!loggedIn || uid == null || role == null) return null;

      return AppUser(
        uid:          uid,
        email:        prefs.getString(_kEmail) ?? '',
        name:         prefs.getString(_kName),
        role:         _roleFromString(role),
        restaurantId: prefs.getString(_kRestaurantId),
        managerId:    prefs.getString(_kManagerId),
      );
    } catch (_) {
      await logout(); // corrupt data — force re-login
      return null;
    }
  }

  // ── Check ─────────────────────────────────────────────────────────────────

  /// Quick boolean check — does NOT validate the session server-side.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLoggedIn) ?? false;
  }

  // ── Convenience getters ───────────────────────────────────────────────────

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRole);
  }

  static Future<String?> getRestaurantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRestaurantId);
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  /// Removes the saved session. Call this on logout.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLoggedIn);
    await prefs.remove(_kUid);
    await prefs.remove(_kEmail);
    await prefs.remove(_kName);
    await prefs.remove(_kRole);
    await prefs.remove(_kRestaurantId);
    await prefs.remove(_kManagerId);
  }

  // ── Role serialization ────────────────────────────────────────────────────

  static String _roleToString(UserRole r) => switch (r) {
    UserRole.superAdmin => 'super_admin',
    UserRole.admin      => 'admin',
    UserRole.manager    => 'manager',
    UserRole.unknown    => 'unknown',
  };

  static UserRole _roleFromString(String s) => switch (s) {
    'super_admin' => UserRole.superAdmin,
    'admin'       => UserRole.admin,
    'manager'     => UserRole.manager,
    _             => UserRole.unknown,
  };
}