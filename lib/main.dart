import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/restaurant_admin/dashboard_page.dart';
import 'package:restaurant_admin_panel/uttils/session_manager.dart';

import 'auth/login_page.dart';
import 'firebase_options.dart';
import 'restaurant_admin/restaurant_admin_page.dart';
import 'restaurant_admin/customer_menu.dart';
import 'super_admin/restaurants_page.dart';
import 'widgets/splash_screen.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  bool loggedIn = await SessionManager.isLoggedIn();
  String? role = await SessionManager.getRole();
  String? restaurantId = await SessionManager.getRestaurantId();


  runApp(MyApp(
    loggedIn: loggedIn,
    role: role,
    restaurantId: restaurantId,
  ));
}

class MyApp extends StatefulWidget {

  final bool loggedIn;
  final String? role;
  final String? restaurantId;

  const MyApp({
    super.key,
    required this.loggedIn,
    this.role,
    this.restaurantId,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _splashShown = false;

  @override
  Widget build(BuildContext context) {

    return   ScreenUtilInit(
      child:   MaterialApp(
        theme: ThemeData(
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        debugShowCheckedModeBanner: false,
        onGenerateRoute: (settings) {

          final routeName = settings.name ?? '/';
          final uri = Uri.parse(routeName);

          if (uri.pathSegments.length == 2 &&
              uri.pathSegments.first == "menu") {

            String restaurantId = uri.pathSegments[1];

            return MaterialPageRoute(
              builder: (_) => CustomerMenuPage(
                restaurantId: restaurantId,
              ),
            );
          }

          final Widget targetPage = () {
            if (!widget.loggedIn) return const LoginPage();
            if (widget.role == "super_admin") {
              return const RestaurantListPage();
            }

            if (widget.restaurantId == null) {
              return const LoginPage();
            }

            return DashboardPage(
              restaurantId: widget.restaurantId!,
            );
          }();

          // Show splash only on app startup (root route).
          if (routeName == '/' && !_splashShown) {
            _splashShown = true;
            return MaterialPageRoute(
              builder: (_) => SplashScreen(nextPage: targetPage),
            );
          }

          return MaterialPageRoute(builder: (_) => targetPage);
        },
      ));
  }
}