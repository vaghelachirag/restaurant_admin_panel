// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FcmWebService {
  FcmWebService._();

  static bool    _initialized      = false;
  static bool    _tokenSaved       = false;
  static bool    _foregroundSet    = false;
  static bool    _swMsgListenerSet = false;
  static String? _pendingOrderId;
  static String? _pendingRestaurantId;

  // ── VAPID key ─────────────────────────────────────────────────────────────
  // Firebase Console → Project Settings → Cloud Messaging
  // → Web configuration → Web Push certificates → Key pair (~87 chars, starts B)
  static const String _vapidKey = 'BMhRVrD4tQU9HvyThs6z5kmS3xIHZi7PDb35tIzdWddtSPXxe7GA6IMz9eqo3_yucYjHtww2gkRAfL2FlQ2BKPc';

  // Navigation callback — set in OrderPlacedScreen.initState()
  // Called when customer taps notification while tab is open.
  static void Function(String orderId, String restaurantId)? onNavigateToOrder;

  // ─────────────────────────────────────────────────────────────────────────
  //  INIT — call after order placed in cart_page.dart
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> init({
    required String orderId,
    required String restaurantId,
  }) async {
    if (!kIsWeb) return;
    if (_initialized) return;

    _log('init() — orderId=$orderId mobile=${_isMobile()} perm=${_getPermission()}');

    _listenSwMessages();

    if (_isMobile()) {
      if (_getPermission() == 'granted') {
        _initialized = true;
        await _getTokenAndSave(orderId: orderId, restaurantId: restaurantId);
        _listenForeground();
      } else {
        _pendingOrderId      = orderId;
        _pendingRestaurantId = restaurantId;
        _log('Mobile — waiting for banner tap');
      }
      return;
    }

    _initialized = true;
    try {
      final token = await _requestPermissionAndGetToken();
      if (token == null) { _log('Desktop — permission denied'); return; }
      await _saveTokenToOrder(orderId: orderId, restaurantId: restaurantId, token: token);
      _listenForeground();
      _log('Desktop ready ✅');
    } catch (e, st) {
      _log('init error: $e\n$st');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SW MESSAGE LISTENER — handles NAVIGATE_TO_ORDER from notification click
  // ─────────────────────────────────────────────────────────────────────────
  static void _listenSwMessages() {
    if (_swMsgListenerSet) return;
    _swMsgListenerSet = true;

    html.window.addEventListener('message', (event) {
      try {
        final msgEvent = event as html.MessageEvent;
        dynamic data   = msgEvent.data;
        if (data is String) {
          try { data = jsonDecode(data); } catch (_) { return; }
        }
        if (data == null || data['type'] != 'NAVIGATE_TO_ORDER') return;

        final orderId      = data['orderId']?.toString()      ?? '';
        final restaurantId = data['restaurantId']?.toString() ?? '';
        if (orderId.isEmpty || restaurantId.isEmpty) return;

        _log('📲 NAVIGATE_TO_ORDER: $orderId');
        onNavigateToOrder?.call(orderId, restaurantId);
      } catch (e) {
        _log('_listenSwMessages error: $e');
      }
    });
    _log('SW message listener active ✅');
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  REQUEST FROM GESTURE — banner button onTap (mobile only)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> requestFromGesture({
    required String orderId,
    required String restaurantId,
  }) async {
    if (!kIsWeb) return false;
    if (_tokenSaved) return true;

    _log('requestFromGesture()');
    try {
      final result = await html.Notification.requestPermission();
      _log('requestPermission: $result');
      if (result != 'granted') return false;

      _initialized = true;
      final saved  = await _getTokenAndSave(orderId: orderId, restaurantId: restaurantId);
      if (saved) {
        _listenForeground();
        _pendingOrderId = _pendingRestaurantId = null;
      }
      return saved;
    } catch (e) {
      _log('requestFromGesture error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BANNER WIDGET
  // ─────────────────────────────────────────────────────────────────────────
  static Widget buildPermissionBanner({
    required BuildContext context,
    required String orderId,
    required String restaurantId,
    VoidCallback? onGranted,
  }) {
    if (!kIsWeb) return const SizedBox.shrink();
    if (!_isMobile()) return const SizedBox.shrink();
    if (_tokenSaved) return const SizedBox.shrink();
    final perm = _getPermission();
    if (perm == 'granted' || perm == 'denied') return const SizedBox.shrink();

    return _NotificationPermissionBanner(
      orderId: orderId, restaurantId: restaurantId, onGranted: onGranted,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  INTERNAL
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
      final token = await FirebaseMessaging.instance.getToken(vapidKey: _vapidKey);
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
    await _saveTokenToOrder(orderId: orderId, restaurantId: restaurantId, token: token);
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
    _log('Token saved ✅');
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

      _showForegroundNotification(
        title: title, body: body,
        orderId: orderId, restaurantId: restaurantId, status: status,
      );
    });
    _log('Foreground listener set ✅');
  }

  static void _showForegroundNotification({
    required String title,
    required String body,
    String orderId      = '',
    String restaurantId = '',
    String status       = '',
  }) {
    if (_isMobile()) {
      _postMessageToSW(title: title, body: body,
          orderId: orderId, restaurantId: restaurantId, status: status);
    } else {
      _showViaConstructor(title: title, body: body);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  POST MESSAGE TO SW
  //  Sends SHOW_NOTIFICATION to the SW which calls showNotification().
  //  The SW's onBackgroundMessage checks clients.matchAll() — since this
  //  tab is open it will skip showing a second notification automatically.
  // ─────────────────────────────────────────────────────────────────────────
  static void _postMessageToSW({
    required String title,
    required String body,
    String orderId      = '',
    String restaurantId = '',
    String status       = '',
  }) {
    try {
      final sw = html.window.navigator.serviceWorker;
      if (sw == null) { _showViaConstructor(title: title, body: body); return; }

      final String json = jsonEncode({
        'type':         'SHOW_NOTIFICATION',
        'title':        title,
        'body':         body,
        'icon':         '/icons/Icon-192.png',
        'orderId':      orderId,
        'restaurantId': restaurantId,
        'status':       status,
      });

      sw.ready.then((registration) {
        final worker = registration.active ?? sw.controller;
        if (worker == null) {
          _showViaConstructor(title: title, body: body);
          return;
        }
        worker.postMessage(json);
        _log('✅ SHOW_NOTIFICATION sent via SW');
      }).catchError((e) {
        _log('sw.ready error: $e');
        _showViaConstructor(title: title, body: body);
      });
    } catch (e) {
      _log('_postMessageToSW error: $e');
      _showViaConstructor(title: title, body: body);
    }
  }

  static void _showViaConstructor({required String title, required String body}) {
    try {
      if (!html.Notification.supported) return;
      if (_getPermission() != 'granted') return;
      html.Notification(title, body: body, icon: '/icons/Icon-192.png');
      _log('✅ Desktop notification shown');
    } catch (e) {
      _log('_showViaConstructor error: $e');
    }
  }

  static String? _getPermission() {
    try { return html.Notification.permission; } catch (_) { return 'default'; }
  }

  static bool _isMobile() {
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      return ua.contains('android') || ua.contains('iphone') ||
          ua.contains('ipad')    || ua.contains('mobile')  ||
          ua.contains('samsung');
    } catch (_) { return false; }
  }

  static void _log(String msg) => debugPrint('[FCM-Web] $msg');
}

// ─────────────────────────────────────────────────────────────────────────────
//  NOTIFICATION PERMISSION BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationPermissionBanner extends StatefulWidget {
  final String orderId, restaurantId;
  final VoidCallback? onGranted;
  const _NotificationPermissionBanner({
    required this.orderId, required this.restaurantId, this.onGranted,
  });
  @override
  State<_NotificationPermissionBanner> createState() =>
      _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState
    extends State<_NotificationPermissionBanner> {
  bool _loading = false, _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC9A84C), width: 1.2),
        boxShadow: [BoxShadow(
          color: const Color(0xFFC9A84C).withOpacity(0.12),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFC9A84C).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.notifications_active_rounded,
              color: Color(0xFFC9A84C), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Get order updates',
                style: GoogleFonts.poppins(fontSize: 13,
                    fontWeight: FontWeight.w700, color: const Color(0xFFC9A84C))),
            const SizedBox(height: 2),
            Text('Tap Enable to get notified when your order is ready.',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
          ]),
        ),
        const SizedBox(width: 8),
        _loading
            ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFFC9A84C)))
            : GestureDetector(
          onTap: () async {
            setState(() => _loading = true);
            final granted = await FcmWebService.requestFromGesture(
              orderId: widget.orderId, restaurantId: widget.restaurantId,
            );
            if (!mounted) return;
            setState(() { _loading = false; _dismissed = true; });
            if (granted && mounted) {
              widget.onGranted?.call();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('🔔 Notifications enabled!',
                    style: GoogleFonts.poppins(fontSize: 13)),
                backgroundColor: const Color(0xFF065F46),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFC9A84C),
                borderRadius: BorderRadius.circular(8)),
            child: Text('Enable',
                style: GoogleFonts.poppins(fontSize: 12,
                    fontWeight: FontWeight.w700, color: Colors.black)),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => setState(() => _dismissed = true),
          child: const Icon(Icons.close_rounded, size: 18, color: Colors.white38),
        ),
      ]),
    );
  }
}