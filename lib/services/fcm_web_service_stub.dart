// fcm_web_service_stub.dart
// Stub implementations for native platforms (Android/iOS).
// All functions are no-ops — dart:html is not available here.

String? getNotificationPermission() => 'default';

bool isMobileBrowser() => false;

void showNativeNotification(String title, String body) {}

Future<bool> requestWebPermission() async => false;

void listenToSwMessages(
    void Function(String orderId, String restaurantId) onNavigate) {}

void postMessageToSw({
  required String title,
  required String body,
  String orderId = '',
  String restaurantId = '',
  String status = '',
}) {}