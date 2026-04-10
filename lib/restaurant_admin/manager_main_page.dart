import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:restaurant_admin_panel/restaurant_admin/restaurant_orders_page.dart';

import 'table_management.dart';

// ─── Color palette (matches existing files) ──────────────────────────────────
class _C {
  static const bg          = Color(0xFFFFF3EE); // warm peach — matches dashboard
  static const orange      = Color(0xFFE8622A);
  static const orangeLight = Color(0xFFFFF0E8);
  static const orangeMid   = Color(0xFFFFD5C0);
  static const dark        = Color(0xFF070B2D);
  static const textDark    = Color(0xFF1A1A1A);
  static const textMid     = Color(0xFF666666);
  static const textLight   = Color(0xFF999999);
  static const cardBorder  = Color(0xFFEEEEEE);
  static const green       = Color(0xFF27AE60);
  static const greenBg     = Color(0xFFE8F8EF);
  static const red         = Color(0xFFE74C3C);
  static const redBg       = Color(0xFFFEEEEE);
  static const divider     = Color(0xFFEEEEEE);
  static const drawerBg    = Color(0xFFFFFFFF);       // white sidebar — matches dashboard
  static const drawerItem  = Color(0xFF374151);       // dark grey nav labels
  static const drawerSub   = Color(0xFF6B7280);       // muted grey sub-labels
  static const drawerActive = Color(0xFFE8622A);      // orange active
}

TextStyle _p(double size, FontWeight w, Color c) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c);

// ════════════════════════════════════════════════════════════════════════════
// MAIN SHELL — hosts the drawer + body
// ════════════════════════════════════════════════════════════════════════════
class WaiterShell extends StatefulWidget {
  final String restaurantId;
  final String waiterId;
  const WaiterShell({
    super.key,
    required this.restaurantId,
    required this.waiterId,
  });

  @override
  State<WaiterShell> createState() => _WaiterShellState();
}

class _WaiterShellState extends State<WaiterShell>
    with SingleTickerProviderStateMixin {


  late AnimationController _drawerCtrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;
  bool _drawerOpen = false;

  _NavItem _active = _NavItem.home;

  String _firstName  = '';
  String _lastName   = '';
  String _email      = '';
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _drawerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnim = CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeOutCubic);
    _fadeAnim  = CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeOut);
    _loadUser();
  }

  @override
  void dispose() {
    _drawerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.waiterId)
        .get();
    if (!mounted) return;
    final d = doc.data() ?? {};
    setState(() {
      _firstName = d['firstName'] ?? d['name']?.toString().split(' ').first ?? '';
      _lastName  = d['lastName']  ?? (d['name']?.toString().split(' ')?..removeAt(0))?.join(' ') ?? '';
      _email     = d['email'] ?? '';
      _photoUrl  = d['photoUrl'];
    });
  }

  // ── Drawer open / close ───────────────────────────────────────────────────
  void _openDrawer()  { setState(() => _drawerOpen = true);  _drawerCtrl.forward(); }
  void _closeDrawer() { _drawerCtrl.reverse().then((_) { if (mounted) setState(() => _drawerOpen = false); }); }
  void _toggleDrawer() => _drawerOpen ? _closeDrawer() : _openDrawer();

  void _navigate(_NavItem item) {
    _closeDrawer();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _active = item);
    });
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    _closeDrawer();
    await Future.delayed(const Duration(milliseconds: 300));
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfirmDialog(
        icon: Icons.logout_rounded,
        iconColor: _C.red,
        iconBg: _C.redBg,
        title: 'Log Out',
        message: 'Are you sure you want to log out?',
        confirmLabel: 'Log Out',
        confirmColor: _C.red,
      ),
    );
    if (ok != true) return;
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  // ── App bar title ─────────────────────────────────────────────────────────
  String get _pageTitle {
    switch (_active) {
      case _NavItem.home:            return 'Order Management';
      case _NavItem.tableManagement: return 'Table Management';
      case _NavItem.settings:        return 'Settings';
      case _NavItem.profile:         return 'My Profile';
    }
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    switch (_active) {
      case _NavItem.home:
        return RestaurantOrdersPage(restaurantId: widget.restaurantId);
      case _NavItem.tableManagement:
        return TableManagementPage(restaurantId: widget.restaurantId);
      case _NavItem.settings:
        return _SettingsPage(restaurantId: widget.restaurantId, waiterId: widget.waiterId);
      case _NavItem.profile:
        return _ProfilePage(
          waiterId: widget.waiterId,
          firstName: _firstName,
          lastName: _lastName,
          email: _email,
          photoUrl: _photoUrl,
          onUpdated: _loadUser,
        );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    const drawerW = 280.0;

    return Scaffold(
      backgroundColor:Colors.white,
      body: Stack(
        children: [
          // ── Main content ─────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _slideAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(drawerW * _slideAnim.value, 0),
              child: child,
            ),
            child: Column(
              children: [
                // ── Custom AppBar ──────────────────────────────────────────
                _AppBar(
                  title: _pageTitle,
                  firstName: _firstName,
                  photoUrl: _photoUrl,
                  onMenuTap: _toggleDrawer,
                ),
                // ── Page body ──────────────────────────────────────────────
                Expanded(child: _buildBody()),
              ],
            ),
          ),

          // ── Scrim ────────────────────────────────────────────────────────
          if (_drawerOpen)
            FadeTransition(
              opacity: _fadeAnim,
              child: GestureDetector(
                onTap: _closeDrawer,
                child: Container(color: Colors.black45),
              ),
            ),

          // ── Drawer panel ─────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _slideAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(drawerW * (_slideAnim.value - 1), 0),
              child: child,
            ),
            child: SizedBox(
              width: drawerW,
              child: _DrawerPanel(
                firstName: _firstName,
                lastName: _lastName,
                email: _email,
                photoUrl: _photoUrl,
                active: _active,
                onNavigate: _navigate,
                onLogout: _logout,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _NavItem { home, tableManagement, settings, profile }

// ════════════════════════════════════════════════════════════════════════════
// CUSTOM APP BAR
// ════════════════════════════════════════════════════════════════════════════
class _AppBar extends StatelessWidget {
  final String title;
  final String firstName;
  final String? photoUrl;
  final VoidCallback onMenuTap;

  const _AppBar({
    required this.title,
    required this.firstName,
    required this.photoUrl,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 14,
        left: 16,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF3EE), // warm peach — matches dashboard bg
        border: Border(bottom: BorderSide(color: _C.cardBorder)),
        boxShadow: [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(children: [
        // Hamburger
        GestureDetector(
          onTap: onMenuTap,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _C.orangeLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.menu_rounded, color: _C.orange, size: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: _p(17, FontWeight.w700, _C.textDark)),
            Text('Welcome back, $firstName 👋',
                style: _p(11, FontWeight.w400, _C.textLight)),
          ]),
        ),
        // Avatar
        _UserAvatar(photoUrl: photoUrl, name: firstName, radius: 19),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DRAWER PANEL
// ════════════════════════════════════════════════════════════════════════════
class _DrawerPanel extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String? photoUrl;
  final _NavItem active;
  final void Function(_NavItem) onNavigate;
  final VoidCallback onLogout;

  const _DrawerPanel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.photoUrl,
    required this.active,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: _C.drawerBg,
          border: Border(right: BorderSide(color: _C.cardBorder, width: 1)),
          boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 24, offset: Offset(4, 0))],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drawer header ──────────────────────────────────────────
              _DrawerHeader(
                firstName: firstName,
                lastName: lastName,
                email: email,
                photoUrl: photoUrl,
              ),

              const Divider(color: _C.cardBorder, height: 1, thickness: 1),
              const SizedBox(height: 10),

              // ── Nav items ──────────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _sectionLabel('MAIN MENU'),
                    const SizedBox(height: 4),
                    _DrawerItem(
                      icon: Icons.home_outlined,
                      label: 'Home',
                      sublabel: 'Order management',
                      item: _NavItem.home,
                      active: active,
                      onTap: () => onNavigate(_NavItem.home),
                    ),
                    _DrawerItem(
                      icon: Icons.table_restaurant_outlined,
                      label: 'Table Management',
                      sublabel: 'View & manage tables',
                      item: _NavItem.tableManagement,
                      active: active,
                      onTap: () => onNavigate(_NavItem.tableManagement),
                    ),
                    const SizedBox(height: 10),
                    _sectionLabel('ACCOUNT'),
                    const SizedBox(height: 4),
                    _DrawerItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      sublabel: 'Notifications, availability',
                      item: _NavItem.settings,
                      active: active,
                      onTap: () => onNavigate(_NavItem.settings),
                    ),
                    _DrawerItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                      sublabel: 'Edit your details',
                      item: _NavItem.profile,
                      active: active,
                      onTap: () => onNavigate(_NavItem.profile),
                    ),
                  ],
                ),
              ),

              // ── Divider ────────────────────────────────────────────────
              const Divider(color: _C.cardBorder, height: 1, thickness: 1),

              // ── Logout ─────────────────────────────────────────────────
              InkWell(
                onTap: onLogout,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                  child: Row(children: [
                    const Icon(Icons.logout_outlined, color: _C.drawerSub, size: 20),
                    const SizedBox(width: 13),
                    Text('Logout', style: _p(14, FontWeight.w400, _C.drawerSub)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 2),
    child: Text(label,
        style: _p(10, FontWeight.w600, _C.textLight)
            .copyWith(letterSpacing: 1.2)),
  );
}

// ── Drawer header ─────────────────────────────────────────────────────────────
class _DrawerHeader extends StatelessWidget {
  final String firstName, lastName, email;
  final String? photoUrl;
  const _DrawerHeader({
    required this.firstName, required this.lastName,
    required this.email, required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(children: [
        _UserAvatar(photoUrl: photoUrl, name: firstName, radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$firstName $lastName'.trim(),
                style: _p(14, FontWeight.w700, _C.textDark),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(email,
                style: _p(11, FontWeight.w400, _C.textLight),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _C.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: _C.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text('Available', style: _p(10, FontWeight.w600, _C.green)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Drawer item ───────────────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final _NavItem item;
  final _NavItem active;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon, required this.label, required this.sublabel,
    required this.item, required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = item == active;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? _C.orangeLight : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(
              icon,
              color: isActive ? _C.orange : _C.drawerSub,
              size: 20,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: _p(
                  14,
                  isActive ? FontWeight.w600 : FontWeight.w400,
                  isActive ? _C.orange : _C.drawerItem,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SETTINGS PAGE
// ════════════════════════════════════════════════════════════════════════════
class _SettingsPage extends StatefulWidget {
  final String restaurantId;
  final String waiterId;
  const _SettingsPage({required this.restaurantId, required this.waiterId});

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  // ── Local state ──────────────────────────────────────────────────────────
  bool _notificationSound = true;
  bool _orderAlerts       = true;
  bool _tableAlerts       = true;
  bool _isAvailable       = true;
  bool _breakMode         = false;
  bool _vibration         = true;
  String _language        = 'English';
  bool _saving            = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.waiterId)
        .get();
    if (!mounted) return;
    final d = doc.data() ?? {};
    setState(() {
      _notificationSound = d['notificationSound'] ?? true;
      _orderAlerts       = d['orderAlerts'] ?? true;
      _tableAlerts       = d['tableAlerts'] ?? true;
      _isAvailable       = d['isAvailable'] ?? true;
      _breakMode         = d['breakMode'] ?? false;
      _vibration         = d['vibration'] ?? true;
      _language          = d['language'] ?? 'English';
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.waiterId)
          .update({
        'notificationSound': _notificationSound,
        'orderAlerts':       _orderAlerts,
        'tableAlerts':       _tableAlerts,
        'isAvailable':       _isAvailable,
        'breakMode':         _breakMode,
        'vibration':         _vibration,
        'language':          _language,
        'updatedAt':         FieldValue.serverTimestamp(),
      });
      if (mounted) _snack('Settings saved!', _C.green, Icons.check_circle_rounded);
    } catch (e) {
      if (mounted) _snack('Failed to save: $e', _C.red, Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color bg, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: _p(13, FontWeight.w500, Colors.white))),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Availability ──────────────────────────────────────────────────
        _sectionCard(
          icon: Icons.person_pin_circle_rounded,
          iconColor: _C.green,
          iconBg: _C.greenBg,
          title: 'Availability',
          children: [
            _SettingSwitch(
              icon: Icons.check_circle_outline_rounded,
              iconColor: _C.green,
              label: 'Available',
              sublabel: 'Mark yourself as available to serve tables',
              value: _isAvailable,
              onChanged: (v) => setState(() { _isAvailable = v; if (v) _breakMode = false; }),
            ),
            _SettingSwitch(
              icon: Icons.free_breakfast_rounded,
              iconColor: _C.orange,
              label: 'Break Mode',
              sublabel: 'Temporarily stop receiving new orders',
              value: _breakMode,
              onChanged: (v) => setState(() { _breakMode = v; if (v) _isAvailable = false; }),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Notifications ─────────────────────────────────────────────────
        _sectionCard(
          icon: Icons.notifications_rounded,
          iconColor: _C.orange,
          iconBg: _C.orangeLight,
          title: 'Notifications',
          children: [
            _SettingSwitch(
              icon: Icons.volume_up_rounded,
              iconColor: _C.orange,
              label: 'Notification Sound',
              sublabel: 'Play sound for incoming alerts',
              value: _notificationSound,
              onChanged: (v) => setState(() => _notificationSound = v),
            ),
            _SettingSwitch(
              icon: Icons.vibration_rounded,
              iconColor: _C.textMid,
              label: 'Vibration',
              sublabel: 'Vibrate on new notifications',
              value: _vibration,
              onChanged: (v) => setState(() => _vibration = v),
            ),
            _SettingSwitch(
              icon: Icons.receipt_long_rounded,
              iconColor: _C.dark,
              label: 'Order Alerts',
              sublabel: 'Get notified when an order is placed',
              value: _orderAlerts,
              onChanged: (v) => setState(() => _orderAlerts = v),
            ),
            _SettingSwitch(
              icon: Icons.table_restaurant_rounded,
              iconColor: _C.green,
              label: 'Table Alerts',
              sublabel: 'Get notified when table status changes',
              value: _tableAlerts,
              onChanged: (v) => setState(() => _tableAlerts = v),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Language ──────────────────────────────────────────────────────
        _sectionCard(
          icon: Icons.language_rounded,
          iconColor: _C.dark,
          iconBg: const Color(0xFFECEDF8),
          title: 'Language',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEDF8),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.translate_rounded, color: _C.dark, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('App Language', style: _p(13, FontWeight.w600, _C.textDark)),
                    Text('Select your preferred language',
                        style: _p(11, FontWeight.w400, _C.textLight)),
                  ]),
                ),
                DropdownButton<String>(
                  value: _language,
                  underline: const SizedBox(),
                  style: _p(13, FontWeight.w500, _C.textDark),
                  items: ['English', 'Hindi', 'Gujarati', 'Marathi']
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) => setState(() => _language = v!),
                ),
              ]),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ── Save button ───────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : Text('Save Settings', style: _p(14, FontWeight.w700, Colors.white)),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Text(title, style: _p(14, FontWeight.w700, _C.textDark)),
          ]),
        ),
        Container(height: 1, color: _C.divider),
        ...children,
        const SizedBox(height: 4),
      ]),
    );
  }
}

// ── Settings switch row ───────────────────────────────────────────────────────
class _SettingSwitch extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch({
    required this.icon, required this.iconColor,
    required this.label, required this.sublabel,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: _p(13, FontWeight.w600, _C.textDark)),
            Text(sublabel, style: _p(11, FontWeight.w400, _C.textLight)),
          ]),
        ),
        CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeColor: _C.orange,
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PROFILE PAGE
// ════════════════════════════════════════════════════════════════════════════
class _ProfilePage extends StatefulWidget {
  final String waiterId;
  final String firstName;
  final String lastName;
  final String email;
  final String? photoUrl;
  final VoidCallback onUpdated;

  const _ProfilePage({
    required this.waiterId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.photoUrl,
    required this.onUpdated,
  });

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  final _oldPassCtrl  = TextEditingController();
  final _newPassCtrl  = TextEditingController();
  final _confPassCtrl = TextEditingController();
  final _leaveReasonCtrl = TextEditingController();

  File? _newPhoto;
  String? _photoUrl;
  bool _saving = false;
  bool _changingPass = false;
  bool _applyingLeave = false;
  DateTime? _leaveFrom;
  DateTime? _leaveTo;
  bool _obscureOld = true, _obscureNew = true, _obscureConf = true;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.firstName);
    _lastNameCtrl  = TextEditingController(text: widget.lastName);
    _emailCtrl     = TextEditingController(text: widget.email);
    _photoUrl      = widget.photoUrl;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose(); _emailCtrl.dispose();
    _oldPassCtrl.dispose(); _newPassCtrl.dispose(); _confPassCtrl.dispose();
    _leaveReasonCtrl.dispose();
    super.dispose();
  }

  // ── Pick photo ────────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _newPhoto = File(picked.path));
  }

  // ── Upload photo ──────────────────────────────────────────────────────────
  Future<String?> _uploadPhoto() async {
    if (_newPhoto == null) return null;
    final ref = FirebaseStorage.instance
        .ref('profile_photos/${widget.waiterId}.jpg');
    await ref.putFile(_newPhoto!);
    return await ref.getDownloadURL();
  }

  // ── Save profile ──────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      String? newUrl;
      if (_newPhoto != null) newUrl = await _uploadPhoto();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.waiterId)
          .update({
        'firstName':  _firstNameCtrl.text.trim(),
        'lastName':   _lastNameCtrl.text.trim(),
        if (newUrl != null) 'photoUrl': newUrl,
        'updatedAt':  FieldValue.serverTimestamp(),
      });
      if (newUrl != null) setState(() => _photoUrl = newUrl);
      widget.onUpdated();
      if (mounted) _snack('Profile updated!', _C.green, Icons.check_circle_rounded);
    } catch (e) {
      if (mounted) _snack('Error: $e', _C.red, Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Change password ───────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confPassCtrl.text) {
      _snack('Passwords do not match', _C.red, Icons.error_rounded); return;
    }
    if (_newPassCtrl.text.length < 6) {
      _snack('Password must be at least 6 characters', _C.red, Icons.error_rounded); return;
    }
    setState(() => _changingPass = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: _oldPassCtrl.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPassCtrl.text);
      _oldPassCtrl.clear(); _newPassCtrl.clear(); _confPassCtrl.clear();
      if (mounted) _snack('Password changed successfully!', _C.green, Icons.lock_rounded);
    } on FirebaseAuthException catch (e) {
      if (mounted) _snack(e.message ?? 'Error changing password', _C.red, Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _changingPass = false);
    }
  }

  // ── Apply for leave ───────────────────────────────────────────────────────
  Future<void> _applyLeave() async {
    if (_leaveFrom == null || _leaveTo == null) {
      _snack('Please select leave dates', _C.orange, Icons.warning_rounded); return;
    }
    if (_leaveTo!.isBefore(_leaveFrom!)) {
      _snack('End date must be after start date', _C.red, Icons.error_rounded); return;
    }
    setState(() => _applyingLeave = true);
    try {
      await FirebaseFirestore.instance.collection('leave_requests').add({
        'waiterId':     widget.waiterId,
        'fromDate':     Timestamp.fromDate(_leaveFrom!),
        'toDate':       Timestamp.fromDate(_leaveTo!),
        'reason':       _leaveReasonCtrl.text.trim(),
        'status':       'pending',
        'appliedAt':    FieldValue.serverTimestamp(),
      });
      setState(() { _leaveFrom = null; _leaveTo = null; });
      _leaveReasonCtrl.clear();
      if (mounted) _snack('Leave request submitted!', _C.green, Icons.check_circle_rounded);
    } catch (e) {
      if (mounted) _snack('Error: $e', _C.red, Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _applyingLeave = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _C.orange),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => isFrom ? _leaveFrom = picked : _leaveTo = picked);
  }

  void _snack(String msg, Color bg, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: _p(13, FontWeight.w500, Colors.white))),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _newPhoto != null || (_photoUrl != null && _photoUrl!.isNotEmpty);
    final initials = '${widget.firstName.isNotEmpty ? widget.firstName[0] : ''}${widget.lastName.isNotEmpty ? widget.lastName[0] : ''}'.toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [

        // ── Photo + basic info ────────────────────────────────────────────
        _profileCard(
          icon: Icons.person_rounded,
          title: 'Personal Information',
          children: [
            // Photo
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: _C.orangeLight,
                    backgroundImage: _newPhoto != null
                        ? FileImage(_newPhoto!) as ImageProvider
                        : (_photoUrl != null && _photoUrl!.isNotEmpty
                        ? NetworkImage(_photoUrl!) as ImageProvider
                        : null),
                    child: !hasPhoto
                        ? Text(initials, style: _p(28, FontWeight.w700, _C.orange))
                        : null,
                  ),
                  Positioned(
                    bottom: 2, right: 2,
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _C.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _profileField('First Name', _firstNameCtrl, Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _profileField('Last Name', _lastNameCtrl, Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _profileField('Email Address', _emailCtrl, Icons.email_outlined,
                enabled: false),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.orange, foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : Text('Save Profile', style: _p(13, FontWeight.w700, Colors.white)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Change password ───────────────────────────────────────────────
        _profileCard(
          icon: Icons.lock_rounded,
          title: 'Change Password',
          children: [
            _passField('Current Password', _oldPassCtrl, _obscureOld,
                    () => setState(() => _obscureOld = !_obscureOld)),
            const SizedBox(height: 12),
            _passField('New Password', _newPassCtrl, _obscureNew,
                    () => setState(() => _obscureNew = !_obscureNew)),
            const SizedBox(height: 12),
            _passField('Confirm New Password', _confPassCtrl, _obscureConf,
                    () => setState(() => _obscureConf = !_obscureConf)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _changingPass ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.dark, foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _changingPass
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : Text('Update Password',
                    style: _p(13, FontWeight.w700, Colors.white)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Apply for leave ───────────────────────────────────────────────
        _profileCard(
          icon: Icons.event_available_rounded,
          title: 'Apply for Leave',
          children: [
            Row(children: [
              Expanded(child: _datePicker('From Date', _leaveFrom,
                      () => _pickDate(true))),
              const SizedBox(width: 12),
              Expanded(child: _datePicker('To Date', _leaveTo,
                      () => _pickDate(false))),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _leaveReasonCtrl,
              maxLines: 3,
              style: _p(13, FontWeight.w400, _C.textDark),
              decoration: InputDecoration(
                hintText: 'Reason for leave (optional)',
                hintStyle: _p(13, FontWeight.w400, _C.textLight),
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.cardBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.cardBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.orange, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyingLeave ? null : _applyLeave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.green, foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _applyingLeave
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.send_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text('Submit Leave Request',
                      style: _p(13, FontWeight.w700, Colors.white)),
                ]),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _profileCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: _C.orangeLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _C.orange, size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: _p(14, FontWeight.w700, _C.textDark)),
        ]),
        const SizedBox(height: 16),
        Container(height: 1, color: _C.divider),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  Widget _profileField(String label, TextEditingController ctrl,
      IconData icon, {bool enabled = true}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _p(12, FontWeight.w500, _C.textMid)),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl,
        enabled: enabled,
        style: _p(13, FontWeight.w500, _C.textDark),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: _C.textLight),
          filled: true,
          fillColor: enabled ? const Color(0xFFF9F9F9) : const Color(0xFFF2F2F2),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.orange, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.cardBorder)),
        ),
      ),
    ]);
  }

  Widget _passField(String label, TextEditingController ctrl,
      bool obscure, VoidCallback toggle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _p(12, FontWeight.w500, _C.textMid)),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl,
        obscureText: obscure,
        style: _p(13, FontWeight.w500, _C.textDark),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              size: 18, color: _C.textLight),
          suffixIcon: GestureDetector(
            onTap: toggle,
            child: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 18, color: _C.textLight,
            ),
          ),
          filled: true,
          fillColor: const Color(0xFFF9F9F9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.orange, width: 1.5)),
        ),
      ),
    ]);
  }

  Widget _datePicker(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: _p(12, FontWeight.w500, _C.textMid)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.cardBorder),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: _C.textLight),
            const SizedBox(width: 10),
            Text(
              date != null
                  ? '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}'
                  : 'Select date',
              style: _p(13, FontWeight.w500,
                  date != null ? _C.textDark : _C.textLight),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════════════

// User avatar — shows photo or initials
class _UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  const _UserAvatar({required this.photoUrl, required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: _C.orangeLight,
      backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
          ? NetworkImage(photoUrl!) as ImageProvider
          : null,
      child: (photoUrl == null || photoUrl!.isEmpty)
          ? Text(initial, style: _p(radius * 0.75, FontWeight.w700, _C.orange))
          : null,
    );
  }
}

// Confirm dialog (logout, etc.)
class _ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, message, confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.title, required this.message,
    required this.confirmLabel, required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.08), blurRadius: 30)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title, style: _p(17, FontWeight.w700, _C.textDark)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: _p(12, FontWeight.w400, _C.textMid)),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('Cancel',
                      style: _p(13, FontWeight.w600, _C.textMid))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: confirmColor,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(confirmLabel,
                      style: _p(13, FontWeight.w600, Colors.white))),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}