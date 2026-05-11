import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fcm_web_service_stub.dart'
if (dart.library.html) 'fcm_web_service_web.dart';  // ← this file was missing

class FcmWebService {
  FcmWebService._();

  static bool    _initialized      = false;
  static bool    _tokenSaved       = false;
  static bool    _foregroundSet    = false;
  static bool    _swMsgListenerSet = false;
  static String? _pendingOrderId;
  static String? _pendingRestaurantId;

  static const String _vapidKey = 'BMhRVrD4tQU9HvyThs6z5kmS3xIHZi7PDb35tIzdWddtSPXxe7GA6IMz9eqo3_yucYjHtww2gkRAfL2FlQ2BKPc';

  static void Function(String orderId, String restaurantId)? onNavigateToOrder;

  // ─────────────────────────────────────────────────────────────────────────
  //  INIT
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> init({
    required String orderId,
    required String restaurantId,
  }) async {
    if (_initialized) return;

    if (kIsWeb) {
      await _initWeb(orderId: orderId, restaurantId: restaurantId);
    } else {
      await _initNative(orderId: orderId, restaurantId: restaurantId);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  WEB INIT
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _initWeb({
    required String orderId,
    required String restaurantId,
  }) async {
    _log('initWeb() — orderId=$orderId mobile=${isMobileBrowser()} perm=${getNotificationPermission()}');

    _listenSwMessages();

    if (isMobileBrowser()) {
      if (getNotificationPermission() == 'granted') {
        _initialized = true;
        await _getTokenAndSave(orderId: orderId, restaurantId: restaurantId);
        _listenForeground();
      } else {
        _pendingOrderId      = orderId;
        _pendingRestaurantId = restaurantId;
        _log('Mobile browser — waiting for banner tap');
      }
      return;
    }

    // Desktop web
    _initialized = true;
    try {
      final token = await _requestPermissionAndGetToken();
      if (token == null) { _log('Desktop — permission denied'); return; }
      await _saveTokenToOrder(orderId: orderId, restaurantId: restaurantId, token: token);
      _listenForeground();
      _log('Desktop web ready ✅');
    } catch (e, st) {
      _log('initWeb error: $e\n$st');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  NATIVE INIT (Android / iOS)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _initNative({
    required String orderId,
    required String restaurantId,
  }) async {
    _log('initNative() — orderId=$orderId');

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        _log('Native permission denied');
        return;
      }

      // No vapidKey on native platforms
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) { _log('Native token null'); return; }

      _log('Native token: ${token.substring(0, 20)}...');

      await _saveTokenToOrder(
        orderId: orderId, restaurantId: restaurantId, token: token,
      );

      _tokenSaved  = true;
      _initialized = true;

      _listenForeground();

      // App brought from background by tapping notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final oid = message.data['orderId']      ?? '';
        final rid = message.data['restaurantId'] ?? '';
        _log('onMessageOpenedApp: $oid');
        if (oid.isNotEmpty && rid.isNotEmpty) onNavigateToOrder?.call(oid, rid);
      });

      // App launched from terminated state by tapping notification
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        final oid = initial.data['orderId']      ?? '';
        final rid = initial.data['restaurantId'] ?? '';
        _log('getInitialMessage: $oid');
        if (oid.isNotEmpty && rid.isNotEmpty) onNavigateToOrder?.call(oid, rid);
      }

      _log('Native FCM ready ✅');
    } catch (e, st) {
      _log('initNative error: $e\n$st');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SW MESSAGE LISTENER (web only)
  // ─────────────────────────────────────────────────────────────────────────
  static void _listenSwMessages() {
    if (!kIsWeb) return;
    if (_swMsgListenerSet) return;
    _swMsgListenerSet = true;

    listenToSwMessages((orderId, restaurantId) {
      _log('📲 NAVIGATE_TO_ORDER: $orderId');
      onNavigateToOrder?.call(orderId, restaurantId);
    });
    _log('SW message listener active ✅');
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  REQUEST FROM GESTURE (mobile browser banner button tap)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> requestFromGesture({
    required String orderId,
    required String restaurantId,
  }) async {
    if (!kIsWeb) return false;
    if (_tokenSaved) return true;

    _log('requestFromGesture()');
    try {
      final granted = await requestWebPermission();
      _log('requestPermission result: $granted');
      if (!granted) return false;

      _initialized = true;
      final saved = await _getTokenAndSave(
        orderId: orderId, restaurantId: restaurantId,
      );
      if (saved) {
        _listenForeground();
        _pendingOrderId      = null;
        _pendingRestaurantId = null;
      }
      return saved;
    } catch (e) {
      _log('requestFromGesture error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BANNER WIDGET (mobile browser only)
  // ─────────────────────────────────────────────────────────────────────────
  static Widget buildPermissionBanner({
    required BuildContext context,
    required String orderId,
    required String restaurantId,
    VoidCallback? onGranted,
  }) {
    if (!kIsWeb) return const SizedBox.shrink();
    if (!isMobileBrowser()) return const SizedBox.shrink();
    if (_tokenSaved) return const SizedBox.shrink();
    final perm = getNotificationPermission();
    if (perm == 'granted' || perm == 'denied') return const SizedBox.shrink();

    return _NotificationPermissionBanner(
      orderId: orderId, restaurantId: restaurantId, onGranted: onGranted,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  INTERNAL HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> _requestPermissionAndGetToken() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    _log('Firebase permission: ${settings.authorizationStatus}');
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) return null;
    return _getFcmToken();
  }

  static Future<String?> _getFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? _vapidKey : null,
      );
      _log('Token: ${token != null ? "${token.substring(0, 20)}..." : "NULL"}');
      return token;
    } catch (e) {
      _log('getToken ERROR: $e');
      return null;
    }
  }

  static Future<bool> _getTokenAndSave({
    required String orderId,
    required String restaurantId,
  }) async {
    final token = await _getFcmToken();
    if (token == null) { _log('Token null'); return false; }
    await _saveTokenToOrder(
      orderId: orderId, restaurantId: restaurantId, token: token,
    );
    _tokenSaved = true;
    return true;
  }

  static Future<void> _saveTokenToOrder({
    required String orderId,
    required String restaurantId,
    required String token,
  }) async {
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .collection('orders')
        .doc(orderId)
        .update({'browserToken': token});
    _log('Token saved to Firestore ✅');
  }

  static void _listenForeground() {
    if (_foregroundSet) return;
    _foregroundSet = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title        = message.notification?.title ?? 'Order Update';
      final body         = message.notification?.body  ?? '';
      final orderId      = message.data['orderId']      ?? '';
      final restaurantId = message.data['restaurantId'] ?? '';
      final status       = message.data['status']       ?? '';

      _log('📩 FOREGROUND: $title — $body');

      if (kIsWeb) {
        if (isMobileBrowser()) {
          postMessageToSw(
            title: title, body: body,
            orderId: orderId, restaurantId: restaurantId, status: status,
          );
        } else {
          showNativeNotification(title, body);
        }
      } else {
        // Native: FCM shows notification automatically when app is in background.
        // When app is in foreground, just update the UI via callback.
        if (orderId.isNotEmpty && restaurantId.isNotEmpty) {
          onNavigateToOrder?.call(orderId, restaurantId);
        }
      }
    });

    _log('Foreground listener set ✅');
  }

  static void _log(String msg) => debugPrint('[FCM] $msg');
}

// ─────────────────────────────────────────────────────────────────────────────
//  NOTIFICATION PERMISSION BANNER WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationPermissionBanner extends StatefulWidget {
  final String orderId, restaurantId;
  final VoidCallback? onGranted;

  const _NotificationPermissionBanner({
    required this.orderId,
    required this.restaurantId,
    this.onGranted,
  });

  @override
  State<_NotificationPermissionBanner> createState() =>
      _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState
    extends State<_NotificationPermissionBanner> {
  bool _loading   = false;
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC9A84C), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC9A84C).withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Bell icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFC9A84C).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFFC9A84C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get order updates',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFC9A84C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap Enable to get notified when your order is ready.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Enable button / loader
          _loading
              ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFC9A84C),
            ),
          )
              : GestureDetector(
            onTap: () async {
              setState(() => _loading = true);
              final granted = await FcmWebService.requestFromGesture(
                orderId: widget.orderId,
                restaurantId: widget.restaurantId,
              );
              if (!mounted) return;
              setState(() {
                _loading   = false;
                _dismissed = true;
              });
              if (granted && mounted) {
                widget.onGranted?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🔔 Notifications enabled!',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                    backgroundColor: const Color(0xFF065F46),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFC9A84C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Enable',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Dismiss X
          GestureDetector(
            onTap: () => setState(() => _dismissed = true),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}