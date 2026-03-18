import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {

  static const String keyLoggedIn = "isLoggedIn";
  static const String keyRole = "role";
  static const String keyRestaurantId = "restaurantId";

  static Future<void> saveLogin({
    required String role,
    String? restaurantId,
  }) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(keyLoggedIn, true);
    await prefs.setString(keyRole, role);

    if (restaurantId != null) {
      await prefs.setString(keyRestaurantId, restaurantId);
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyLoggedIn) ?? false;
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyRole);
  }

  static Future<String?> getRestaurantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyRestaurantId);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}