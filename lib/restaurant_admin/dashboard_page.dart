import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:restaurant_admin_panel/restaurant_admin/restaurant_orders_page.dart';

import '../uttils/session_manager.dart';
import 'category_page.dart';
import 'customer_menu.dart';
import 'menu_page.dart';
import 'qr_download_io.dart' if (dart.library.html) 'qr_download_web.dart' as qr_download;
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
  final String label;
  const _SItem(this.icon, this.label);
}

const _sItems = [
  _SItem(Icons.grid_view_rounded,    "Dashboard"),
  _SItem(Icons.receipt_long_rounded, "Orders"),
  _SItem(Icons.category_rounded,     "Categories"),
  _SItem(Icons.restaurant_menu,      "Menu Items"),
  _SItem(Icons.menu_book_rounded,    "Customer Menu"),
  _SItem(Icons.link_rounded,         "Menu Link"),
  _SItem(Icons.settings_rounded,     "Settings"),
];

// ════════════════════════════════════════════════════════════════════════════
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

  final List<FlSpot> _salesSpots = const [
    FlSpot(0, 4000), FlSpot(1, 3000), FlSpot(2, 5100),
    FlSpot(3, 2700), FlSpot(4, 6900), FlSpot(5, 7700), FlSpot(6, 5600),
  ];

  @override
  void initState() {
    super.initState();
    _listenOrders();
  }

  @override
  void dispose() {
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

  void _onNewOrder() {
    _newOrderCount++;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () async {
      if (!mounted || _newOrderCount == 0) return;
      await _audio.stop();
      await _audio.play(AssetSource('sounds/new_order.mp3'));
      _snack("$_newOrderCount New Order${_newOrderCount > 1 ? 's' : ''} Received",
          Icons.notifications_active_rounded, _C.green);
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
      if (mounted) _snack("QR saved!", Icons.check_circle_rounded, _C.green);
    } catch (e) {
      if (mounted) _snack("Error: $e", Icons.error_rounded, _C.red);
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
                  Expanded(child: Text("Menu QR & Link",
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
                  Expanded(child: _qrBtn("Copy Link", Icons.copy_rounded,
                      _C.orangeLight, _C.orange, () {
                        Clipboard.setData(ClipboardData(text: _link));
                        _snack("Copied!", Icons.check_circle_rounded, _C.orange);
                      })),
                  const SizedBox(width: 12),
                  Expanded(child: _qrBtn("Download QR", Icons.download_rounded,
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
            Text("Sign Out?", style: _p(17, FontWeight.w700, _C.textDark)),
            const SizedBox(height: 8),
            Text("You'll need to sign in again to access the panel.",
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
                  child: Center(child: Text("Cancel",
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
                  child: Center(child: Text("Sign Out",
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
      if (mounted) _snack("Logout error: $e", Icons.error_rounded, _C.red);
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
          _MobileBar(onLogout: _logout),
          Expanded(child: _buildSelectedContent(isMobile: true)),
        ])
            : Row(children: [
          _Sidebar(
              selected: _selectedIndex, onTap: _nav, onLogout: _logout),
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
          Row(children: [
            Text("Home", style: _p(12, FontWeight.w400, _C.textLight)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text("/", style: _p(12, FontWeight.w400, _C.textLight)),
            ),
            Text("Dashboard", style: _p(12, FontWeight.w400, _C.textMid)),
          ]),
          SizedBox(height: isMobile ? 10 : 12),

          // Page title
          Text("Dashboard",
              style: _p(isMobile ? 26 : 32, FontWeight.w700, _C.textDark)),
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

// ════════════════════════════════════════════════════════════════════════════
// SIDEBAR
// ════════════════════════════════════════════════════════════════════════════
class _Sidebar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  final VoidCallback onLogout;
  const _Sidebar(
      {required this.selected, required this.onTap, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: _C.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: _C.orange,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 11),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Restaurant",
                    style: _p(14, FontWeight.w700, _C.textDark)),
                Text("Admin Panel",
                    style: _p(10, FontWeight.w400, _C.textLight)),
              ]),
            ]),
          ),

          const Divider(color: Color(0xFFEEEEEE), height: 1),
          const SizedBox(height: 8),

          // Nav items
          Expanded(
            child: ListView.builder(
              itemCount: _sItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (_, i) {
                final active = i == selected;
                return GestureDetector(
                  onTap: () => onTap(i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 11),
                    decoration: BoxDecoration(
                      color: active ? _C.orangeLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(_sItems[i].icon,
                          color: active ? _C.orange : _C.textMid, size: 19),
                      const SizedBox(width: 11),
                      Text(_sItems[i].label,
                          style: _p(
                            13,
                            active ? FontWeight.w600 : FontWeight.w400,
                            active ? _C.orange : _C.textMid,
                          )),
                    ]),
                  ),
                );
              },
            ),
          ),

          const Divider(color: Color(0xFFEEEEEE), height: 1),

          // Logout
          GestureDetector(
            onTap: onLogout,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.logout_rounded, color: _C.textMid, size: 19),
                const SizedBox(width: 11),
                Text("Logout", style: _p(13, FontWeight.w400, _C.textMid)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MOBILE TOP BAR
// ════════════════════════════════════════════════════════════════════════════
class _MobileBar extends StatelessWidget {
  final VoidCallback onLogout;
  const _MobileBar({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: _C.orange, borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.local_fire_department_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Text("Restaurant", style: _p(14, FontWeight.w700, _C.textDark)),
        const Spacer(),
        GestureDetector(
          onTap: onLogout,
          child: Row(children: [
            const Icon(Icons.logout_rounded, color: _C.textMid, size: 17),
            const SizedBox(width: 6),
            Text("Logout", style: _p(12, FontWeight.w400, _C.textMid)),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// STAT CARDS  (live Firestore)
// ════════════════════════════════════════════════════════════════════════════
class _CardData {
  final String label, value, trend;
  final bool up;
  final IconData icon;
  final Color ic, ib;
  const _CardData(
      this.label, this.value, this.trend, this.up, this.icon, this.ic, this.ib);
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
              _CardData("Categories", cats.toString(),
                  "+8% from yesterday",   true,
                  Icons.folder_open_rounded, _C.blueIcon,   _C.blueIconBg),
              _CardData("Menu Items",  menus.toString(),
                  "-5% from yesterday",   false,
                  Icons.restaurant_menu,   _C.purpleIcon, _C.purpleIconBg),
              _CardData("Orders",      orders.toString(),
                  "+1.2% from yesterday", true,
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

// ════════════════════════════════════════════════════════════════════════════
// SALES CHART  (fl_chart)
// ════════════════════════════════════════════════════════════════════════════
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
        Text("Sales Details",
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
