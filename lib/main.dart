import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/restaurant_admin/dashboard_page.dart';
import 'package:restaurant_admin_panel/restaurant_admin/manager_main_page.dart';
import 'package:restaurant_admin_panel/uttils/appConfig.dart';
import 'package:restaurant_admin_panel/uttils/session_manager.dart';
import 'package:restaurant_admin_panel/services/localization_service.dart';

import 'auth/login_page.dart';
import 'firebase_options.dart';
import 'restaurant_admin/customer_menu.dart';
import 'restaurant_admin/order_status_page.dart'; // ← NEW
import 'super_admin/restaurants_page.dart';
import 'widgets/splash_screen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FCM BACKGROUND HANDLER — must be top-level function
//  On web, background is handled by firebase-messaging-sw.js.
//  This is only active on Android/iOS native builds.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

// ─────────────────────────────────────────────────────────────────────────────
//  URL PARSERS
// ─────────────────────────────────────────────────────────────────────────────

/// Existing — reads /#/menu/restaurantId (QR scan flow)
String? _getMenuRestaurantIdFromInitialUrl() {
  if (!kIsWeb) return null;
  final hash     = Uri.base.fragment;
  final uri      = Uri.tryParse(hash);
  if (uri == null) return null;
  final segments = uri.pathSegments;
  if (segments.length == 2 && segments.first == 'menu') {
    return segments[1];
  }
  return null;
}

/// NEW — reads /#/order/restaurantId/orderId
/// Used when customer taps a push notification while Chrome tab is CLOSED.
/// SW opens this URL → Flutter reads it → shows OrderPlacedScreen directly.
Map<String, String>? _getOrderFromInitialUrl() {
  if (!kIsWeb) return null;
  final hash     = Uri.base.fragment;
  final uri      = Uri.tryParse(hash);
  if (uri == null) return null;
  final segments = uri.pathSegments;
  if (segments.length == 3 && segments[0] == 'order') {
    return {
      'restaurantId': segments[1],
      'orderId':      segments[2],
    };
  }
  return null;
}

Future<void> _createAndroidNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'new_order_channel',
    'New Orders',
    description: 'Plays sound when a new order arrives',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('new_order'),
    playSound: true,
    enableVibration: true,
  );

  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> setupNotificationChannel() async {
  await _createAndroidNotificationChannel();

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(AppConfig.oneSignalAppId);
  await OneSignal.Notifications.requestPermission(true);

  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    event.notification.display();
  });

  OneSignal.Notifications.addClickListener((OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    if (data == null) return;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register FCM background handler — native only
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  if (!kIsWeb) {
    await setupNotificationChannel();
  }

  final menuRestaurantId = _getMenuRestaurantIdFromInitialUrl();
  final orderFromUrl     = _getOrderFromInitialUrl(); // ← NEW

  bool    loggedIn     = false;
  String? role;
  String? restaurantId;

  // Only read session if not arriving from menu QR or notification tap
  if (menuRestaurantId == null && orderFromUrl == null) {
    loggedIn     = await SessionManager.isLoggedIn();
    role         = await SessionManager.getRole();
    restaurantId = await SessionManager.getRestaurantId();
  }

  runApp(
    ProviderScope(
      child: MyApp(
        loggedIn:         loggedIn,
        role:             role,
        restaurantId:     restaurantId,
        menuRestaurantId: menuRestaurantId,
        orderFromUrl:     orderFromUrl, // ← NEW
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool                 loggedIn;
  final String?              role;
  final String?              restaurantId;
  final String?              menuRestaurantId;
  final Map<String, String>? orderFromUrl; // ← NEW

  const MyApp({
    super.key,
    required this.loggedIn,
    this.role,
    this.restaurantId,
    this.menuRestaurantId,
    this.orderFromUrl, // ← NEW
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _splashShown = false;
  final LocalizationService _localizationService = LocalizationService();

  @override
  void initState() {
    super.initState();
    _localizationService.init();
    _localizationService.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _localizationService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Widget get _targetPage {
    if (!widget.loggedIn) return const LoginPage();

    if (widget.role == AppConfig.superAdmin) {
      return const RestaurantListPage();
    }

    if (widget.role == AppConfig.manager) {
      if (widget.restaurantId == null) return const LoginPage();
      return WaiterShell(
        restaurantId: widget.restaurantId!,
        waiterId:     '1SS',
      );
    }

    if (widget.restaurantId == null) return const LoginPage();
    return DashboardPage(restaurantId: widget.restaurantId!);
  }

  Widget _buildApp({required Widget home}) {
    return ScreenUtilInit(
      designSize:      const Size(1440, 900),
      minTextAdapt:    true,
      splitScreenMode: true,
      child: InheritedLocalizations(
        service: _localizationService,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            textTheme: GoogleFonts.poppinsTextTheme(),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LocalizationService.supportedLocales,
          locale:           _localizationService.currentLocale,
          home:             home,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    // ── NEW: Notification tap — show order status page directly ───────────
    // Customer tapped push notification while Chrome was CLOSED.
    // SW opened /#/order/restaurantId/orderId
    // Flutter reads it here and shows OrderPlacedScreen immediately.
    if (widget.orderFromUrl != null) {
      return _buildApp(
        home: OrderPlacedScreen(
          orderId:      widget.orderFromUrl!['orderId']!,
          restaurantId: widget.orderFromUrl!['restaurantId']!,
        ),
      );
    }
    // ─────────────────────────────────────────────────────────────────────

    // Existing: QR scan menu URL
    if (widget.menuRestaurantId != null) {
      return _buildApp(
        home: CustomerMenuPage(
          restaurantId: widget.menuRestaurantId!,
        ),
      );
    }

    // Existing: admin/manager routing
    return ScreenUtilInit(
      designSize:      const Size(1440, 900),
      minTextAdapt:    true,
      splitScreenMode: true,
      child: InheritedLocalizations(
        service: _localizationService,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            textTheme: GoogleFonts.poppinsTextTheme(),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LocalizationService.supportedLocales,
          locale:           _localizationService.currentLocale,
          onGenerateRoute: (settings) {
            final routeName = settings.name ?? '/';
            final uri       = Uri.parse(routeName);

            if (uri.pathSegments.length == 2 &&
                uri.pathSegments.first == 'menu') {
              final id = uri.pathSegments[1];
              return MaterialPageRoute(
                builder: (_) => CustomerMenuPage(restaurantId: id),
              );
            }

            if (routeName == '/login') {
              return MaterialPageRoute(
                builder:  (_) => const LoginPage(),
                settings: settings,
              );
            }

            if (routeName == '/' && !_splashShown) {
              _splashShown = true;
              return MaterialPageRoute(
                builder: (_) => SplashScreen(nextPage: _targetPage),
              );
            }

            return MaterialPageRoute(builder: (_) => _targetPage);
          },
        ),
      ),
    );
  }
}