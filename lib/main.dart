import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:restaurant_admin_panel/uttils/session_manager.dart';

import 'auth/login_page.dart';
import 'firebase_options.dart';
import 'restaurant_admin/restaurant_admin_page.dart';
import 'restaurant_admin/customer_menu.dart';
import 'super_admin/restaurants_page.dart';

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

class MyApp extends StatelessWidget {

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
  Widget build(BuildContext context) {

    return   ScreenUtilInit(
      child:   MaterialApp(
        debugShowCheckedModeBanner: false,

        onGenerateRoute: (settings) {

          Uri uri = Uri.parse(settings.name ?? "/");

          if (uri.pathSegments.length == 2 &&
              uri.pathSegments.first == "menu") {

            String restaurantId = uri.pathSegments[1];

            return MaterialPageRoute(
              builder: (_) => CustomerMenuPage(
                restaurantId: restaurantId,
              ),
            );
          }

          return MaterialPageRoute(
            builder: (_) {

              if (!loggedIn) {
                return const LoginPage();
              }

              if (role == "super_admin") {
                return const RestaurantListPage();
              }

              return RestaurantAdminPanel(
                restaurantId: restaurantId!,
              );
            },
          );
        },
      ));
  }
}