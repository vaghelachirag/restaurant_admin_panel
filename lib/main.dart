import 'package:firebase_core/firebase_core.dart';
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
import 'super_admin/restaurants_page.dart';
import 'widgets/splash_screen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


String? _getMenuRestaurantIdFromInitialUrl() {
  if (!kIsWeb) return null;

  final hash = Uri.base.fragment;
  final uri = Uri.tryParse(hash);
  if (uri == null) return null;

  final segments = uri.pathSegments;
  if (segments.length == 2 && segments.first == 'menu') {
    return segments[1];
  }
  return null;
}

Future<void> _createAndroidNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'new_order_channel',                                  // id  ← matches index.js
    'New Orders',                                         // name
    description: 'Plays sound when a new order arrives',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('new_order'), // no extension
    playSound: true,
    enableVibration: true,
  );

  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

/// Initialises OneSignal once with all listeners.
/// Called from main() — only on mobile (Android / iOS).
Future<void> setupNotificationChannel() async {
  await _createAndroidNotificationChannel();

  // ── 2. Init OneSignal ────────────────────────────────────────────────────
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(AppConfig.oneSignalAppId);
  await OneSignal.Notifications.requestPermission(true);

  // ── 3. Display notifications while the app is in the foreground ──────────
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    event.notification.display();
  });

  // ── 4. Handle notification tap ───────────────────────────────────────────
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

/*  // Add this:
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );*/

  // OneSignal is fully initialised inside setupNotificationChannel().
  // Web does not support push notifications via OneSignal SDK.
  if (!kIsWeb) {
    await setupNotificationChannel();
  }


  final menuRestaurantId = _getMenuRestaurantIdFromInitialUrl();

  bool loggedIn = false;
  String? role;
  String? restaurantId;


  if (menuRestaurantId == null) {
    loggedIn = await SessionManager.isLoggedIn();
    role = await SessionManager.getRole();
    restaurantId = await SessionManager.getRestaurantId();
  }


  runApp(
      ProviderScope(
          child:MyApp(
            loggedIn: loggedIn,
            role: role,
            restaurantId: restaurantId,
            menuRestaurantId: menuRestaurantId,
          )));
}

class MyApp extends StatefulWidget {
  final bool loggedIn;
  final String? role;
  final String? restaurantId;
  final String? menuRestaurantId;

  const MyApp({
    super.key,
    required this.loggedIn,
    this.role,
    this.restaurantId,
    this.menuRestaurantId,
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
    if (mounted) {
      setState(() {});
    }
  }

  Widget get _targetPage {
    if (!widget.loggedIn) return const LoginPage();

    if (widget.role == AppConfig.superAdmin) {
      return const RestaurantListPage();
    }

    if (widget.role == AppConfig.manager) {
      if (widget.restaurantId == null) return const LoginPage();
      return WaiterShell(
        restaurantId: widget.restaurantId!, waiterId: '1SS',
      );
    }

    if (widget.restaurantId == null) return const LoginPage();
    return DashboardPage(
        restaurantId: widget.restaurantId!);
  }

  Widget _buildApp({required Widget home}) {
    return ScreenUtilInit(
      designSize: const Size(1440, 900),
      minTextAdapt: true,
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
          locale: _localizationService.currentLocale,
          home: home,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.menuRestaurantId != null) {
      return _buildApp(
        home: CustomerMenuPage(
          restaurantId: widget.menuRestaurantId!,
        ),
      );
    }

    return ScreenUtilInit(
      designSize: const Size(1440, 900),
      minTextAdapt: true,
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
          locale: _localizationService.currentLocale,
          onGenerateRoute: (settings) {
            final routeName = settings.name ?? '/';
            final uri = Uri.parse(routeName);

            if (uri.pathSegments.length == 2 &&
                uri.pathSegments.first == 'menu') {
              final id = uri.pathSegments[1];
              return MaterialPageRoute(
                builder: (_) => CustomerMenuPage(restaurantId: id),
              );
            }

            if (routeName == '/login') {
              return MaterialPageRoute(
                builder: (_) => const LoginPage(),
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