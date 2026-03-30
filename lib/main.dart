import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/restaurant_admin/dashboard_page.dart';
import 'package:restaurant_admin_panel/uttils/session_manager.dart';

import 'auth/login_page.dart';
import 'firebase_options.dart';
import 'restaurant_admin/customer_menu.dart';
import 'super_admin/restaurants_page.dart';
import 'widgets/splash_screen.dart';

/// 🔍 Extract restaurantId from URL like: /#/menu/{id}
String? _getMenuRestaurantIdFromInitialUrl() {
  if (!kIsWeb) return null;

  final hash = Uri.base.fragment; // e.g. /menu/abc123
  final uri = Uri.tryParse(hash);
  if (uri == null) return null;

  final segments = uri.pathSegments;
  if (segments.length == 2 && segments.first == 'menu') {
    return segments[1];
  }
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final menuRestaurantId = _getMenuRestaurantIdFromInitialUrl();

  bool loggedIn = false;
  String? role;
  String? restaurantId;

  /// ✅ Only check session if NOT menu link
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

  /// 🎯 Decide admin target page
  Widget get _targetPage {
    if (!widget.loggedIn) return const LoginPage();

    if (widget.role == 'super_admin') {
      return const RestaurantListPage();
    }

    if (widget.restaurantId == null) return const LoginPage();

    return DashboardPage(restaurantId: widget.restaurantId!);
  }

  /// 🎨 Common App Wrapper
  Widget _buildApp({required Widget home}) {
    return ScreenUtilInit(
      designSize: const Size(1440, 900),
      minTextAdapt: true,
      splitScreenMode: true,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        home: home,
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

    /// 🔥 CASE 2: Admin App Flow
    return ScreenUtilInit(
      designSize: const Size(1440, 900),
      minTextAdapt: true,
      splitScreenMode: true,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        onGenerateRoute: (settings) {
          final routeName = settings.name ?? '/';
          final uri = Uri.parse(routeName);

          /// ✅ Handle in-app menu navigation
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
    );
  }
}