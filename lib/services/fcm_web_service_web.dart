// fcm_web_service_web.dart
// Web-platform implementations using dart:html.
// This file is loaded only when dart.library.html is available (i.e. Flutter Web).
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// ─────────────────────────────────────────────────────────────────────────────
//  Notification permission
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the current Web Notification permission string:
/// 'default' | 'granted' | 'denied'
String? getNotificationPermission() {
  try {
    return html.Notification.permission;
  } catch (_) {
    return 'default';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mobile browser detection
// ─────────────────────────────────────────────────────────────────────────────

/// Returns true when running inside a mobile browser (Android or iOS).
/// Uses the User-Agent string — good enough for the banner-vs-desktop split.
bool isMobileBrowser() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('android') ||
      ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod');
}

// ─────────────────────────────────────────────────────────────────────────────
//  Native browser notification (desktop web)
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a Web Notification directly from the main thread.
/// Only works on desktop browsers where Notification permission is 'granted'.
void showNativeNotification(String title, String body) {
  try {
    if (html.Notification.supported &&
        html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    }
  } catch (e) {
    // Silently ignore — notifications are best-effort.
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Permission request (must be called from a user gesture)
// ─────────────────────────────────────────────────────────────────────────────

/// Asks the browser to grant Notification permission.
/// Must be triggered directly from a user gesture (e.g. a button tap).
/// Returns true if the user grants permission.
Future<bool> requestWebPermission() async {
  try {
    if (!html.Notification.supported) return false;
    final result = await html.Notification.requestPermission();
    return result == 'granted';
  } catch (_) {
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Service Worker message listener
// ─────────────────────────────────────────────────────────────────────────────

/// Listens for NAVIGATE_TO_ORDER messages posted by the Firebase Service Worker
/// (firebase-messaging-sw.js) and calls [onNavigate] with the extracted IDs.
///
/// Expected message shape:
/// ```json
/// { "type": "NAVIGATE_TO_ORDER", "orderId": "…", "restaurantId": "…" }
/// ```
void listenToSwMessages(
    void Function(String orderId, String restaurantId) onNavigate) {
  html.window.addEventListener('message', (html.Event rawEvent) {
    try {
      final event = rawEvent as html.MessageEvent;
      final data  = event.data;
      if (data == null) return;

      // dart:html wraps JS objects as JsObject or Map — handle both.
      final type         = _getField(data, 'type');
      final orderId      = _getField(data, 'orderId');
      final restaurantId = _getField(data, 'restaurantId');

      if (type == 'NAVIGATE_TO_ORDER' &&
          orderId != null &&
          restaurantId != null) {
        onNavigate(orderId, restaurantId);
      }
    } catch (_) {
      // Ignore malformed messages from other origins.
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Post message to Service Worker (mobile web foreground notifications)
// ─────────────────────────────────────────────────────────────────────────────

/// Sends a message to the active Firebase Service Worker so it can display
/// a notification while the app is in the foreground on a mobile browser.
///
/// The SW must handle this via a `message` event listener and call
/// `self.registration.showNotification(…)`.
void postMessageToSw({
  required String title,
  required String body,
  String orderId      = '',
  String restaurantId = '',
  String status       = '',
}) {
  try {
    final controller = html.window.navigator.serviceWorker?.controller;
    if (controller == null) return;

    controller.postMessage({
      'type':         'SHOW_NOTIFICATION',
      'title':        title,
      'body':         body,
      'orderId':      orderId,
      'restaurantId': restaurantId,
      'status':       status,
    });
  } catch (_) {
    // Silently ignore if the SW is not available.
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Safely reads a string field from a JS interop object or a Dart Map.
String? _getField(dynamic data, String key) {
  try {
    // dart:html MessageEvent.data is typically a plain JS object exposed as
    // a dynamic. Index access works for both JsObject and Map<String, dynamic>.
    final value = data[key];
    return value?.toString();
  } catch (_) {
    return null;
  }
}