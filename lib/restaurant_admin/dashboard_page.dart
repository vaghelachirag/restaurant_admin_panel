import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurant_admin_panel/restaurant_admin/restaurant_orders_page.dart';

import '../uttils/session_manager.dart';
import '../data/models/restaurant_model.dart';
import '../service/restaurant_service.dart';
import '../services/localization_service.dart';
import 'category_page.dart';
import 'customer_menu.dart';
import 'menu_page.dart';
import 'qr_download_io.dart' if (dart.library.html) 'qr_download_web.dart' as qr_download;
import 'manager_page.dart';
import 'settings_page.dart';

// ─── Design Tokens (matched exactly from Figma screenshot) ──────────────────
class _C {
  // Backgrounds
  static const bg           = Color(0xFFFFF3EE); // warm peach page background
  static const sidebar      = Color(0xFFFFFFFF); // pure white sidebar
  static const card         = Color(0xFFFFFFFF); // white cards

  // Brand orange (logo bg, active nav, buttons)
  static const orange       = Color(0xFFE8622A);
  static const orangeLight  = Color(0xFFFFF0E8); // active nav bg tint

  // Text
  static const textDark     = Color(0xFF1A1A1A); // headings / bold values
  static const textMid      = Color(0xFF666666); // nav labels, sub-labels
  static const textLight    = Color(0xFF999999); // breadcrumb, hints

  // Borders / dividers
  static const cardBorder   = Color(0xFFEEEEEE);

  // Trend colours
  static const green        = Color(0xFF2ECC71);
  static const red          = Color(0xFFE74C3C);

  // Stat-card icon colours (from screenshot)
  static const blueIcon     = Color(0xFF6C9EF8);   // Categories – folder icon
  static const purpleIcon   = Color(0xFFB06EE8);   // Menu Items – fork icon
  static const greenIcon    = Color(0xFF4ECBA0);   // Orders – bag icon

  static const blueIconBg   = Color(0xFFEEF3FE);
  static const purpleIconBg = Color(0xFFF5EDFB);
  static const greenIconBg  = Color(0xFFEBF9F5);

  // Sidebar active indicator line
  static const activeBar    = Color(0xFFE8622A);
}

// ─── Poppins text helpers ────────────────────────────────────────────────────
TextStyle _p(double size, FontWeight weight, Color color) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

// ─── Sidebar items ───────────────────────────────────────────────────────────
class _SItem {
  final IconData icon;
  final String key;
  const _SItem(this.icon, this.key);
}

List<_SItem> _getSidebarItems(BuildContext context) {
  final localizations = AppLocalizations.of(context);
  return [
    _SItem(Icons.space_dashboard_outlined,   localizations.translate("dashboard.title")),
    _SItem(Icons.shopping_bag_outlined,      localizations.translate("orders.title")),
    _SItem(Icons.folder_open_outlined,       localizations.translate("categories.title")),
    _SItem(Icons.restaurant_outlined,        localizations.translate("menu_items.title")),
    _SItem(Icons.storefront_outlined,        localizations.translate("customer_menu.title")),
    _SItem(Icons.language_outlined,          localizations.translate("menu_link.title")),
    _SItem(Icons.manage_accounts_outlined,   localizations.translate("managers.title")),
    _SItem(Icons.settings_outlined,          localizations.translate("settings.title")),
  ];
}

class DashboardPage extends StatefulWidget {
  final String restaurantId;
  const DashboardPage({super.key, required this.restaurantId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AudioPlayer _audio = AudioPlayer();
  int _newOrderCount = 0;
  Timer? _timer;
  int _selectedIndex = 0;
  RestaurantModel? _restaurant;
  bool _isLoading = true;

  final LocalizationService _localizationService = LocalizationService();

  final List<FlSpot> _salesSpots = const [
    FlSpot(0, 4000), FlSpot(1, 3000), FlSpot(2, 5100),
    FlSpot(3, 2700), FlSpot(4, 6900), FlSpot(5, 7700), FlSpot(6, 5600),
  ];

  @override
  void initState() {
    super.initState();
    _listenOrders();
    _loadRestaurantData();
    _localizationService.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _localizationService.removeListener(_onLanguageChanged);
    _timer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  void _listenOrders() {
    FirebaseFirestore.instance
        .collection("orders")
        .where("restaurantId", isEqualTo: widget.restaurantId)
        .snapshots()
        .listen((snap) {
      for (var c in snap.docChanges) {
        if (c.type == DocumentChangeType.added) _onNewOrder();
      }
    });
  }

  Future<void> _loadRestaurantData() async {
    try {
      final restaurant = await RestaurantService().fetchRestaurant(widget.restaurantId);
      if (mounted) {
        setState(() {
          _restaurant = restaurant;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onNewOrder() {
    _newOrderCount++;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () async {
      if (!mounted || _newOrderCount == 0) return;
      final loc = AppLocalizations.of(context);
      final count = _newOrderCount;
      await _audio.stop();
      await _audio.play(AssetSource('sounds/new_order.mp3'));
      if (!mounted) return;
      _snack(
        "$count ${loc.newOrder}${count > 1 ? 's' : ''} ${loc.received}",
        Icons.notifications_active_rounded,
        _C.green,
      );
      _newOrderCount = 0;
    });
  }

  void _snack(String msg, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _nav(int i) {
    if (i == 5) {
      _showQrDialog();
      return;
    }
    setState(() => _selectedIndex = i);
  }

  String get _link =>
      "https://restaurant-menu-system-fc074.web.app/#/menu/${widget.restaurantId}";

  Future<void> _downloadQR() async {
    try {
      final ok = QrValidator.validate(data: _link);
      if (ok.status == QrValidationStatus.error) throw Exception('Invalid QR data');
      final painter = QrPainter(
          data: _link, version: QrVersions.auto,
          color: const Color(0xFF000000), emptyColor: const Color(0xFFFFFFFF), gapless: true);
      final img = await painter.toImageData(300);
      final bytes = img?.buffer.asUint8List();
      if (bytes == null) throw Exception('Failed to generate QR');
      await qr_download.saveQrBytesToPlatform(bytes, 'menu_qr_${widget.restaurantId}.png');
      if (mounted) _snack(AppLocalizations.of(context).copied, Icons.check_circle_rounded, _C.green);
    } catch (e) {
      if (mounted) _snack("${AppLocalizations.of(context).error}: $e", Icons.error_rounded, _C.red);
    }
  }

  void _showQrDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1),
                  blurRadius: 40, offset: const Offset(0, 16))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _C.orangeLight,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.qr_code_2_rounded, color: _C.orange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(AppLocalizations.of(context).menuQrLink,
                      style: _p(17, FontWeight.w700, _C.textDark))),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded, color: _C.textLight, size: 22),
                  ),
                ]),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.cardBorder),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                      ],
                    ),
                    child: QrImageView(
                      data: _link, version: QrVersions.auto, size: 170,
                      eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF000000)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _C.cardBorder)),
                  child: SelectableText(_link,
                      style: _p(11, FontWeight.w400, _C.textMid)),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _qrBtn(AppLocalizations.of(context).copyLink, Icons.copy_rounded,
                      _C.orangeLight, _C.orange, () {
                        Clipboard.setData(ClipboardData(text: _link));
                        _snack(AppLocalizations.of(context).copied, Icons.check_circle_rounded, _C.orange);
                      })),
                  const SizedBox(width: 12),
                  Expanded(child: _qrBtn(AppLocalizations.of(context).downloadQr, Icons.download_rounded,
                      _C.orange, Colors.white, _downloadQR)),
                ]),
              ]),
        ),
      ),
    );
  }

  Widget _qrBtn(String label, IconData icon, Color bg, Color fg,
      VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: bg == _C.orangeLight
                  ? Border.all(color: _C.cardBorder)
                  : null),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: fg, size: 15),
            const SizedBox(width: 7),
            Text(label, style: _p(13, FontWeight.w600, fg)),
          ]),
        ),
      );

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 310, padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30)
              ]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                  color: Color(0xFFFEEEEE), shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded, color: _C.red, size: 24),
            ),
            const SizedBox(height: 14),
            Text(AppLocalizations.of(context).signOutQuestion, style: _p(17, FontWeight.w700, _C.textDark)),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).signOutDescription,
                textAlign: TextAlign.center,
                style: _p(12, FontWeight.w400, _C.textMid)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(AppLocalizations.of(context).cancel,
                      style: _p(13, FontWeight.w600, _C.textMid))),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                      color: _C.red,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(AppLocalizations.of(context).signOut,
                      style: _p(13, FontWeight.w600, Colors.white))),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await SessionManager.logout();
      await FirebaseAuth.instance.signOut();
      _timer?.cancel();
      PaintingBinding.instance.imageCache.clear();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    } catch (e) {
      if (mounted) _snack("${AppLocalizations.of(context).logoutError}: $e", Icons.error_rounded, _C.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    return Scaffold(
      backgroundColor: Colors.white
      ,
      body: SafeArea(
        child: isMobile
            ? Column(children: [
          _MobileBar(onLogout: _logout, restaurant: _restaurant, isLoading: _isLoading),
          Expanded(child: _buildSelectedContent(isMobile: true)),
        ])
            : Row(children: [
          _Sidebar(
              selected: _selectedIndex,
              onTap: _nav,
              onLogout: _logout,
              restaurant: _restaurant,
              isLoading: _isLoading),
          Expanded(child: _buildSelectedContent(isMobile: false)),
        ]),
      ),
    );
  }

  Widget _buildSelectedContent({required bool isMobile}) {
    switch (_selectedIndex) {
      case 1:
        return RestaurantOrdersPage(restaurantId: widget.restaurantId);
      case 2:
        return CategoryPage(restaurantId: widget.restaurantId);
      case 3:
        return MenuPage(restaurantId: widget.restaurantId);
      case 4:
        return CustomerMenuPage(restaurantId: widget.restaurantId);
      case 6:
        return ManagerPage(restaurantId: widget.restaurantId);
      case 7:
        return SettingsPage(restaurantId: widget.restaurantId);
      case 0:
      default:
        return _dashboardBody(isMobile: isMobile);
    }
  }

  Widget _dashboardBody({required bool isMobile}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          // Page title
          Text(AppLocalizations.of(context).dashboardTitle,
              style: _p(isMobile ? 26 : 24, FontWeight.w200, _C.textDark)),
          SizedBox(height: isMobile ? 18 : 24),

          // Stat cards
          _StatCards(restaurantId: widget.restaurantId, isMobile: isMobile),
          SizedBox(height: isMobile ? 20 : 26),

          // Sales chart
          _SalesChart(spots: _salesSpots, isMobile: isMobile),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
class _Sidebar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  final VoidCallback onLogout;
  final RestaurantModel? restaurant;
  final bool isLoading;
  const _Sidebar(
      {required this.selected,
        required this.onTap,
        required this.onLogout,
        this.restaurant,
        required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: _C.sidebar,
        border: Border(
          right: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _C.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? const Icon(Icons.storefront_rounded, color: Colors.white, size: 22)
                    : (restaurant?.logoUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    restaurant!.logoUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.storefront_rounded,
                          color: Colors.white, size: 22);
                    },
                  ),
                )
                    : const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isLoading ? AppLocalizations.of(context).restaurant : (restaurant?.name ?? AppLocalizations.of(context).restaurant),
                        style: _p(15, FontWeight.w700, _C.textDark),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    Text(AppLocalizations.of(context).adminPanel, style: _p(11, FontWeight.w400, _C.textLight)),
                  ],
                ),
              ),
            ]),
          ),

          const Divider(color: Color(0xFFEEEEEE), height: 1, thickness: 1),
          const SizedBox(height: 10),

          // ── Nav items ──────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              itemCount: _getSidebarItems(context).length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (_, i) {
                final items = _getSidebarItems(context);
                final active = i == selected;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: InkWell(
                    onTap: () => onTap(i),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: active ? _C.orangeLight : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(
                          items[i].icon,
                          color: active ? _C.orange : const Color(0xFF4B5563),
                          size: 20,
                        ),
                        const SizedBox(width: 13),
                        Text(
                          AppLocalizations.of(context).translate(items[i].key),
                          style: _p(
                            14,
                            active ? FontWeight.w600 : FontWeight.w400,
                            active ? _C.orange : const Color(0xFF374151),
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Download APK button ────────────────────────────────────────
          const _ApkDownloadButton(),

          const Divider(color: Color(0xFFEEEEEE), height: 1, thickness: 1),
          InkWell(
            onTap: onLogout,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              child: Row(children: [
                const Icon(Icons.logout_outlined,
                    color: Color(0xFF6B7280), size: 20),
                const SizedBox(width: 13),
                Text(AppLocalizations.of(context).logout,
                    style: _p(14, FontWeight.w400, const Color(0xFF6B7280))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── APK Download Button ─────────────────────────────────────────────────────
class _ApkDownloadButton extends StatefulWidget {
  const _ApkDownloadButton();

  @override
  State<_ApkDownloadButton> createState() => _ApkDownloadButtonState();
}

class _ApkDownloadButtonState extends State<_ApkDownloadButton> {
  bool _loading = false;

  Future<void> _downloadApk() async {
    setState(() => _loading = true);
    try {
      // Fetch latest APK info from Firestore: collection "app_releases", doc "latest"
      // Expected fields: apkUrl (String), version (String, optional)
      final doc = await FirebaseFirestore.instance
          .collection('app_releases')
          .doc('latest')
          .get();

      if (!doc.exists || doc.data() == null) {
        _showError('No APK release found. Please upload a release first.');
        return;
      }

      final data = doc.data()!;
      final String? apkUrl = data['apkUrl'] as String?;

      if (apkUrl == null || apkUrl.trim().isEmpty) {
        _showError('APK URL is missing in the release document.');
        return;
      }

      final uri = Uri.parse(apkUrl);
      if (!await canLaunchUrl(uri)) {
        _showError('Cannot open the download link.');
        return;
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);

      final version = data['version'] as String?;
      _showSuccess(version != null
          ? 'Downloading v$version…'
          : 'Download started!');
    } catch (e) {
      _showError('Download failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12))),
      ]),
      backgroundColor: _C.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(14),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.download_done_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12))),
      ]),
      backgroundColor: _C.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(14),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: InkWell(
        onTap: _loading ? null : _downloadApk,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _C.orangeLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.orange.withOpacity(0.25)),
          ),
          child: Row(children: [
            _loading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_C.orange),
              ),
            )
                : const Icon(Icons.android_rounded, color: _C.orange, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loading ? 'Fetching…' : 'Download App',
                    style: _p(13, FontWeight.w600, _C.orange),
                  ),
                  Text(
                    'Latest APK',
                    style: _p(10, FontWeight.w400, _C.orange.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            if (!_loading)
              const Icon(Icons.download_rounded, color: _C.orange, size: 16),
          ]),
        ),
      ),
    );
  }
}

class _MobileBar extends StatelessWidget {
  final VoidCallback onLogout;
  final RestaurantModel? restaurant;
  final bool isLoading;
  const _MobileBar({
    required this.onLogout,
    this.restaurant,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: _C.orange, borderRadius: BorderRadius.circular(10)),
          child: isLoading
              ? const Icon(Icons.storefront_rounded, color: Colors.white, size: 20)
              : (restaurant?.logoUrl != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              restaurant!.logoUrl!,
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 20);
              },
            ),
          )
              : const Icon(Icons.storefront_rounded,
              color: Colors.white, size: 20)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isLoading ? AppLocalizations.of(context).restaurant : (restaurant?.name ?? AppLocalizations.of(context).restaurant),
                style: _p(14, FontWeight.w700, _C.textDark),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            Text(AppLocalizations.of(context).adminPanel, style: _p(10, FontWeight.w400, _C.textLight)),
          ],
        ),
        const Spacer(),
        InkWell(
          onTap: onLogout,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              const Icon(Icons.logout_outlined,
                  color: Color(0xFF6B7280), size: 18),
              const SizedBox(width: 6),
              Text(AppLocalizations.of(context).logout,
                  style: _p(12, FontWeight.w400, const Color(0xFF6B7280))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _StatCards extends StatelessWidget {
  final String restaurantId;
  final bool isMobile;
  const _StatCards({required this.restaurantId, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("orders")
          .where("restaurantId", isEqualTo: restaurantId)
          .where("status", isEqualTo: "pending")
          .snapshots(),
      builder: (_, orderSnap) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("categories")
            .where("restaurantId", isEqualTo: restaurantId)
            .snapshots(),
        builder: (_, catSnap) => StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("menu_items")
              .where("restaurantId", isEqualTo: restaurantId)
              .snapshots(),
          builder: (_, menuSnap) {
            final orders = orderSnap.data?.docs.length ?? 0;
            final cats   = catSnap.data?.docs.length ?? 0;
            final menus  = menuSnap.data?.docs.length ?? 0;

            final cards = [
              _CardData(AppLocalizations.of(context).categories, cats.toString(),
                  "+8% ${AppLocalizations.of(context).fromYesterday}",   true,
                  Icons.folder_open_rounded, _C.blueIcon,   _C.blueIconBg),
              _CardData(AppLocalizations.of(context).menuItems,  menus.toString(),
                  "-5% ${AppLocalizations.of(context).fromYesterday}",   false,
                  Icons.restaurant_menu,   _C.purpleIcon, _C.purpleIconBg),
              _CardData(AppLocalizations.of(context).orders,      orders.toString(),
                  "+1.2% ${AppLocalizations.of(context).fromYesterday}", true,
                  Icons.shopping_bag_outlined, _C.greenIcon, _C.greenIconBg),
            ];

            if (isMobile) {
              return Column(
                children: cards
                    .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StatCard(d: c),
                ))
                    .toList(),
              );
            }
            return Row(
              children: cards
                  .mapIndexed((i, c) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: i < cards.length - 1 ? 16 : 0),
                  child: _StatCard(d: c),
                ),
              ))
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

extension _ListIndexed<T> on List<T> {
  Iterable<R> mapIndexed<R>(R Function(int i, T e) fn) =>
      asMap().entries.map((e) => fn(e.key, e.value));
}

class _CardData {
  final String label;
  final String value;
  final String trend;
  final bool up;
  final IconData icon;
  final Color ic;  // icon color
  final Color ib;  // icon background color

  const _CardData(
      this.label,
      this.value,
      this.trend,
      this.up,
      this.icon,
      this.ic,
      this.ib,
      );
}

class _StatCard extends StatelessWidget {
  final _CardData d;
  const _StatCard({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.label, style: _p(12, FontWeight.w400, _C.textLight)),
                const SizedBox(height: 6),
                Text(d.value, style: _p(30, FontWeight.w700, _C.textDark)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(
                    d.up
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: d.up ? _C.green : _C.red,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(d.trend,
                        style: _p(10, FontWeight.w500,
                            d.up ? _C.green : _C.red)),
                  ),
                ]),
              ]),
        ),
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
              color: d.ib, borderRadius: BorderRadius.circular(13)),
          child: Icon(d.icon, color: d.ic, size: 24),
        ),
      ]),
    );
  }
}

class _SalesChart extends StatelessWidget {
  final List<FlSpot> spots;
  final bool isMobile;
  const _SalesChart({required this.spots, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppLocalizations.of(context).salesDetails,
            style: _p(15, FontWeight.w600, _C.textDark)),
        SizedBox(height: isMobile ? 16 : 20),
        SizedBox(
          height: isMobile ? 200 : 260,
          child: LineChart(LineChartData(
            minY: 0, maxY: 9000,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 2000,
              getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: 2000,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: _p(10, FontWeight.w400, _C.textLight),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (ss) => ss
                    .map((s) => LineTooltipItem(
                  s.y.toInt().toString(),
                  GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: _C.orange,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 4.5,
                    color: _C.orange,
                    strokeWidth: 2.5,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      _C.orange.withOpacity(0.18),
                      _C.orange.withOpacity(0.0)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          )),
        ),
      ]),
    );
  }
}