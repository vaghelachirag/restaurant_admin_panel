import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:restaurant_admin_panel/restaurant_admin/dashboard_page.dart';
import '../core/constants/app_colors.dart';
import '../restaurant_admin/restaurant_admin_page.dart';
import '../super_admin/restaurants_page.dart';
import '../uttils/session_manager.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService authService = AuthService();

  bool loading = false;
  bool obscurePassword = true;

  Future<void> login() async {

    setState(() {
      loading = true;
    });

    Map<String, dynamic>? userData = await authService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    setState(() {
      loading = false;
    });

    if (userData != null) {

      String role = userData['role'];
      String? restaurantId = userData['restaurantId'];

      await SessionManager.saveLogin(role: role, restaurantId: restaurantId,);

      if (!mounted) return;

      if (role == "super_admin") {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RestaurantListPage(),
          ),
        );

      } else if (role == "admin") {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              restaurantId: restaurantId!,
            ),
          ),
        );

      }

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Failed")),
      );

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: kIsWeb ? 420 : 420.w),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 32 : 32.w,
                vertical: kIsWeb ? 40 : 40.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo and Title
                  Container(
                    width: kIsWeb ? 80 : 80.w,
                    height: kIsWeb ? 80 : 80.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(kIsWeb ? 20 : 20.r),
                    ),
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      size: kIsWeb ? 40 : 40.w,
                      color: AppColors.primary,
                    ),
                  ),
                  
                  SizedBox(height: kIsWeb ? 24 : 24.h),
                  
                  Text(
                    "Restaurant Admin",
                    style: TextStyle(
                      fontSize: kIsWeb ? 28 : 28.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  
                  SizedBox(height: kIsWeb ? 8 : 8.h),
                  
                  Text(
                    "Sign in to manage your restaurant",
                    style: TextStyle(
                      fontSize: kIsWeb ? 14 : 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  SizedBox(height: kIsWeb ? 40 : 40.h),
                  
                  // Email Field
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: kIsWeb ? 14 : 14.sp),
                    decoration: InputDecoration(
                      labelText: "Email Address",
                      labelStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: kIsWeb ? 14 : 14.sp,
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppColors.primary,
                        size: kIsWeb ? 20 : 20.w,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.r),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.r),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: kIsWeb ? 16 : 16.w,
                        vertical: kIsWeb ? 16 : 16.h,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: kIsWeb ? 20 : 20.h),
                  
                  // Password Field
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: TextStyle(fontSize: kIsWeb ? 14 : 14.sp),
                    decoration: InputDecoration(
                      labelText: "Password",
                      labelStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: kIsWeb ? 14 : 14.sp,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: AppColors.primary,
                        size: kIsWeb ? 20 : 20.w,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey[600],
                          size: kIsWeb ? 20 : 20.w,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.r),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.r),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: kIsWeb ? 16 : 16.w,
                        vertical: kIsWeb ? 16 : 16.h,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: kIsWeb ? 32 : 32.h),
                  
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: kIsWeb ? 50 : 50.h,
                    child: ElevatedButton(
                      onPressed: loading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.r),
                        ),
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                      ),
                      child: loading
                          ? SizedBox(
                              width: kIsWeb ? 20 : 20.w,
                              height: kIsWeb ? 20 : 20.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.white,
                              ),
                            )
                          : Text(
                              "Sign In",
                              style: TextStyle(
                                fontSize: kIsWeb ? 16 : 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  
                  SizedBox(height: kIsWeb ? 24 : 24.h),
                  
                  // Additional Info
                  Center(
                    child: Text(
                      "Admin & Super Admin Access",
                      style: TextStyle(
                        fontSize: kIsWeb ? 12 : 12.sp,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}