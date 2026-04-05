import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/restaurant_admin/dashboard_page.dart';
import 'package:restaurant_admin_panel/uttils/session_manager.dart';
import 'package:restaurant_admin_panel/services/localization_service.dart';

import 'auth/login_page.dart';
import 'firebase_options.dart';
import 'restaurant_admin/customer_menu.dart';
import 'restaurant_admin/restaurant_orders_page.dart';
import 'super_admin/restaurants_page.dart';
import 'widgets/splash_screen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// 🔍 Extract restaurantId from URL like: /#/menu/{id}
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


Future<void> setupNotificationChannel() async {
  // OneSignal init — channel is already registered by MainActivity.kt
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("1dbbdcbd-590f-475c-88d0-7c6d953d63ca");

  // Request permission (Android 13+ / iOS)
  await OneSignal.Notifications.requestPermission(true);

  // Tap handler — fired when user taps a notification
  OneSignal.Notifications.addClickListener((OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    if (data != null && data['type'] == 'new_order') {

    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

  OneSignal.initialize("1dbbdcbd-590f-475c-88d0-7c6d953d63ca");

  OneSignal.Notifications.requestPermission(true);
 //

  if (kIsWeb) {
    // Running on Web
  } else {
    await setupNotificationChannel();
  }
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    event.notification.display();
  });


  final menuRestaurantId = _getMenuRestaurantIdFromInitialUrl();

  bool loggedIn = false;
  String? role;
  String? restaurantId;


  if (menuRestaurantId == null) {
    loggedIn = await SessionManager.isLoggedIn();
    role = await SessionManager.getRole();
    restaurantId = await SessionManager.getRestaurantId();
  }

  runApp(MyApp(
    loggedIn: loggedIn,
    role: role,
    restaurantId: restaurantId,
    menuRestaurantId: menuRestaurantId,
  ));
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

    if (widget.role == 'super_admin') {
      return const RestaurantListPage();
    }

    if (widget.role == 'manager') {
      if (widget.restaurantId == null) return const LoginPage();
      return RestaurantOrdersPage(
        restaurantId: widget.restaurantId!
      );
    }

    if (widget.restaurantId == null) return const LoginPage();
    return DashboardPage(restaurantId: widget.restaurantId!);
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
    /// 🔥 CASE 1: Customer Menu (LOCK FLOW)
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