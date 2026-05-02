import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';
import '../restaurant_admin/dashboard_page.dart' hide AppColors;
import '../restaurant_admin/manager_main_page.dart';
import '../super_admin/restaurants_page.dart';
import '../services/localization_service.dart';
import '../uttils/session_manager.dart';
import '../widgets/language_switcher.dart';

// ── New auth system imports ────────────────────────────────────────────────────
import 'auth_service.dart';
import 'models/app_user.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool loading         = false;
  bool obscurePassword = true;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ── Login — replaced to use new AppUser system ────────────────────────────
  Future<void> login() async {
    final l10n = AppLocalizations.of(context);

    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      _showSnack('${l10n.email} ${l10n.and} ${l10n.password}');
      return;
    }

    setState(() => loading = true);

    final AppUser? user = await _authService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    setState(() => loading = false);

    if (!mounted) return;

    if (user == null) {
      _showSnack(l10n.error);
      return;
    }

    // Save session locally
    await SessionManager.save(user);
    if (!mounted) return;
    // Navigate based on role
    _navigateByRole(user);
  }

  void _navigateByRole(AppUser user) {
    final l10n = AppLocalizations.of(context);

    switch (user.role) {
      case UserRole.superAdmin:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RestaurantListPage()),
        );

      case UserRole.admin:
        if (user.restaurantId == null) {
          _showSnack('Admin has no restaurant assigned. Contact super admin.');
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(restaurantId: user.restaurantId!),
          ),
        );

      case UserRole.manager:
        if (user.restaurantId == null || user.managerId == null) {
          _showSnack('Manager assignment is incomplete. Contact admin.');
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WaiterShell(
              restaurantId: user.restaurantId!,
              waiterId:     user.managerId!, // real managerId, not hardcoded "1"
            ),
          ),
        );

      case UserRole.unknown:
        _showSnack(l10n.error);
    }
  }

  // ── Snackbar — unchanged ──────────────────────────────────────────────────

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: AppColors.darkBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build — unchanged ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return kIsWeb ? _buildWebLayout() : _buildMobileLayout();
  }

  // ─── Logo helper – picks the right asset per platform ────────────────────

  Widget _buildLogo({
    required double size,
    required double borderRadius,
  }) {
    final String assetPath = kIsWeb
        ? 'assets/images/rasora_web.png'
        : 'assets/images/rasora_mobile.png';

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[LoginPage] Logo failed to load ($assetPath): $error');
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.shadowOrange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.shadowOrange,
            size: size * 0.55,
          ),
        );
      },
    );
  }

  // ─── WEB ──────────────────────────────────────────────────────────────────

  Widget _buildWebLayout() {
    return Scaffold(
      backgroundColor: AppColors.webBackground,
      body: Row(
        children: [
          // Left decorative panel
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.darkBackground, AppColors.mediumDark, AppColors.darkBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    top: -60,
                    left: -60,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -80,
                    right: -80,
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 200,
                    right: 60,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                  ),
                  // Content
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.shadowOrange.withOpacity(0.35),
                                  blurRadius: 32,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _buildLogo(size: 80, borderRadius: 20),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            "Restaurant\nManagement\nPortal",
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Manage orders, menus, and your restaurant\noperations from one unified dashboard.",
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.6),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 48),
                          _webFeaturePill(Icons.bolt_rounded, "Real-time order tracking"),
                          const SizedBox(height: 12),
                          _webFeaturePill(Icons.menu_book_rounded, "Menu management"),
                          const SizedBox(height: 12),
                          _webFeaturePill(Icons.analytics_rounded, "Sales analytics"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right form panel
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SizedBox(
                      width: 380,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Welcome back",
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkBackground,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Sign in to your account to continue",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 36),
                            _webTextField(
                              controller: emailController,
                              label: AppLocalizations.of(context).email,
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            _webTextField(
                              controller: passwordController,
                              label: AppLocalizations.of(context).password,
                              icon: Icons.lock_outline,
                              obscure: obscurePassword,
                              suffix: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: Colors.grey[400],
                                ),
                                onPressed: () => setState(
                                        () => obscurePassword = !obscurePassword),
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: loading ? null : login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                  AppColors.primary.withOpacity(0.6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: loading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : Text(
                                  AppLocalizations.of(context).loginButton,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const LanguageSwitcher(),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                "Admin • Manager • Super Admin",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _webFeaturePill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _webTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.darkBackground),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black),
        prefixIcon: Icon(icon, size: 18, color: Colors.black),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.lightGrey,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black26),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  // ─── MOBILE ───────────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.mobileBackground,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo
                      Center(
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowOrange.withOpacity(0.35),
                                blurRadius: 36,
                                spreadRadius: 2,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: _buildLogo(size: 110, borderRadius: 24),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Welcome text
                      Text(
                        "Welcome back",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkBackground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sign in to your account to continue",
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Email field
                      _mobileTextField(
                        controller: emailController,
                        label: AppLocalizations.of(context).email,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      _mobileTextField(
                        controller: passwordController,
                        label: AppLocalizations.of(context).password,
                        icon: Icons.lock_outline,
                        obscure: obscurePassword,
                        suffix: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: Colors.grey[400],
                          ),
                          onPressed: () =>
                              setState(() => obscurePassword = !obscurePassword),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Sign in button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: loading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                            AppColors.primary.withOpacity(0.6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            AppLocalizations.of(context).loginButton,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const LanguageSwitcher(),
                      const SizedBox(height: 12),

                      // Footer text
                      Center(
                        child: Text(
                          "Admin • Manager • Super Admin",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[400],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.darkBackground),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey[400]),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}