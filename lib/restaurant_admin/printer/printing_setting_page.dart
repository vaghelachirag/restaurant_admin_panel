// lib/restaurant_admin/printer_settings_page.dart
//
// Printer settings screen — owner configures printer IP, type, and
// enables/disables printing. All saved to Firestore, read by kot-server.
//
// Firestore path: restaurants/{restaurantId}/settings/printer
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// ─── Color palette (matches your existing files) ──────────────────────────────
class _C {
  static const bg          = Color(0xFFFFF3EE);
  static const orange      = Color(0xFFE8622A);
  static const orangeLight = Color(0xFFFFF0E8);
  static const dark        = Color(0xFF070B2D);
  static const textDark    = Color(0xFF1A1A1A);
  static const textMid     = Color(0xFF666666);
  static const textLight   = Color(0xFF999999);
  static const cardBorder  = Color(0xFFEEEEEE);
  static const green       = Color(0xFF27AE60);
  static const greenBg     = Color(0xFFE8F8EF);
  static const red         = Color(0xFFE74C3C);
  static const redBg       = Color(0xFFFEEEEE);
  static const divider     = Color(0xFFF0F0F0);
}

TextStyle _p(double size, FontWeight w, Color c) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c);

// ─── Connection type options ──────────────────────────────────────────────────
enum _ConnType { lan, usb, windows }

class PrinterSettingsPage extends StatefulWidget {
  final String restaurantId;
  const PrinterSettingsPage({super.key, required this.restaurantId});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final _ipCtrl       = TextEditingController();
  final _nameCtrl     = TextEditingController(text: 'Kitchen Printer');
  final _usbCtrl      = TextEditingController(text: '/dev/usb/lp0');
  final _winCtrl      = TextEditingController(text: '//localhost/PrinterName');
  final _kotServerCtrl = TextEditingController(text: 'http://192.168.1.XX:3001');

  String       _printerType = 'EPSON';
  _ConnType    _connType    = _ConnType.lan;
  bool         _enabled     = true;
  bool         _saving      = false;
  bool         _testing     = false;
  bool?        _testResult;
  bool         _loading     = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _nameCtrl.dispose();
    _usbCtrl.dispose();
    _winCtrl.dispose();
    _kotServerCtrl.dispose();
    super.dispose();
  }

  // ── Build printer interface string from form ──────────────────────────────
  String get _interfaceString {
    switch (_connType) {
      case _ConnType.lan:
        final ip = _ipCtrl.text.trim();
        return ip.isEmpty ? '' : 'tcp://$ip';
      case _ConnType.usb:
        return _usbCtrl.text.trim();
      case _ConnType.windows:
        return _winCtrl.text.trim();
    }
  }

  // ── Parse saved interface back into form fields ───────────────────────────
  void _parseInterface(String iface) {
    if (iface.startsWith('tcp://')) {
      _connType = _ConnType.lan;
      _ipCtrl.text = iface.replaceFirst('tcp://', '');
    } else if (iface.startsWith('//')) {
      _connType = _ConnType.windows;
      _winCtrl.text = iface;
    } else if (iface.startsWith('/dev/')) {
      _connType = _ConnType.usb;
      _usbCtrl.text = iface;
    }
  }

  Future<void> _loadSettings() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('settings')
          .doc('printer')
          .get();

      if (snap.exists) {
        final d = snap.data()!;
        _nameCtrl.text   = d['name']        ?? 'Kitchen Printer';
        _printerType     = d['type']        ?? 'EPSON';
        _enabled         = d['enabled']     ?? true;
        _kotServerCtrl.text = d['kotServerUrl'] ?? 'http://192.168.1.XX:3001';
        _parseInterface(d['interface'] ?? '');
      }
    } catch (e) {
      debugPrint('Load printer settings error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    final iface = _interfaceString;
    if (iface.isEmpty) {
      _snack('Please enter the printer connection details', _C.red, Icons.error_rounded);
      return;
    }
    if (_kotServerCtrl.text.trim().isEmpty) {
      _snack('Please enter the KOT server URL', _C.red, Icons.error_rounded);
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('settings')
          .doc('printer')
          .set({
        'name':         _nameCtrl.text.trim(),
        'interface':    iface,
        'type':         _printerType,
        'enabled':      _enabled,
        'kotServerUrl': _kotServerCtrl.text.trim(),
        'updatedAt':    FieldValue.serverTimestamp(),
      });
      _snack('Printer settings saved!', _C.green, Icons.check_circle_rounded);
    } catch (e) {
      _snack('Save failed: $e', _C.red, Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testPrint() async {
    setState(() { _testing = true; _testResult = null; });
    try {
      final kotUrl = _kotServerCtrl.text.trim();
      if (kotUrl.isEmpty) {
        _snack('Enter KOT server URL first', _C.red, Icons.error_rounded);
        return;
      }
      final res = await http
          .get(Uri.parse('$kotUrl/test-print?restaurantId=${widget.restaurantId}'))
          .timeout(const Duration(seconds: 8));

      final ok = res.statusCode == 200;
      setState(() => _testResult = ok);
      _snack(
        ok ? 'Test print sent! Check the printer.' : 'Printer not reachable — check IP and connection',
        ok ? _C.green : _C.red,
        ok ? Icons.print_rounded : Icons.print_disabled_rounded,
      );
    } catch (e) {
      setState(() => _testResult = false);
      _snack('Cannot reach KOT server. Is it running?', _C.red, Icons.wifi_off_rounded);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _snack(String msg, Color bg, IconData icon) {
    if (!mounted) return;
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
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _C.orange)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        title: Text('Printer Settings', style: _p(17, FontWeight.w700, _C.textDark)),
        iconTheme: const IconThemeData(color: _C.textDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.cardBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── KOT Server URL ─────────────────────────────────────────────────
          _card(
            icon: Icons.dns_rounded,
            iconColor: _C.dark,
            iconBg: const Color(0xFFECEDF8),
            title: 'KOT Server',
            children: [
              _hint('The IP address of the PC or Raspberry Pi running kot-server.js on your local WiFi.'),
              const SizedBox(height: 10),
              _field('Server URL', _kotServerCtrl,
                  hint: 'http://192.168.1.10:3001',
                  icon: Icons.link_rounded),
              const SizedBox(height: 8),

              // Online status indicator
              if (_testResult != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _testResult! ? _C.greenBg : _C.redBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(_testResult! ? Icons.check_circle_rounded : Icons.error_rounded,
                        size: 16, color: _testResult! ? _C.green : _C.red),
                    const SizedBox(width: 8),
                    Text(
                      _testResult! ? 'Server reachable — printer working!' : 'Server not reachable',
                      style: _p(12, FontWeight.w600, _testResult! ? _C.green : _C.red),
                    ),
                  ]),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Printer connection ─────────────────────────────────────────────
          _card(
            icon: Icons.print_rounded,
            iconColor: _C.orange,
            iconBg: _C.orangeLight,
            title: 'Printer Connection',
            children: [
              // Enable toggle
              _switchRow(
                icon: Icons.power_settings_new_rounded,
                label: 'Enable KOT Printing',
                sublabel: 'Auto-print ticket on every new order',
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v), iconColor: null,
              ),

              const Divider(color: _C.divider, height: 1),
              const SizedBox(height: 12),

              // Printer name
              _field('Printer Label', _nameCtrl,
                  hint: 'Kitchen Printer', icon: Icons.label_outline_rounded),
              const SizedBox(height: 12),

              // Printer type
              Text('Printer Brand', style: _p(12, FontWeight.w500, _C.textMid)),
              const SizedBox(height: 6),
              Row(children: ['EPSON', 'STAR', 'TANCA'].map((t) {
                final sel = _printerType == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _printerType = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? _C.orange : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? _C.orange : _C.cardBorder),
                      ),
                      child: Text(t, style: _p(13, FontWeight.w600,
                          sel ? Colors.white : _C.textMid)),
                    ),
                  ),
                );
              }).toList()),

              const SizedBox(height: 14),

              // Connection type tabs
              Text('Connection Type', style: _p(12, FontWeight.w500, _C.textMid)),
              const SizedBox(height: 6),
              Row(children: [
                _connTab('LAN / WiFi',  _ConnType.lan,     Icons.wifi_rounded),
                const SizedBox(width: 8),
                _connTab('USB',         _ConnType.usb,     Icons.usb_rounded),
                const SizedBox(width: 8),
                _connTab('Windows',     _ConnType.windows, Icons.computer_rounded),
              ]),

              const SizedBox(height: 12),

              // Dynamic connection fields
              if (_connType == _ConnType.lan) ...[
                _hint('Enter the printer\'s IP address. Set a static IP on the printer for reliable connection.'),
                const SizedBox(height: 8),
                _field('Printer IP Address', _ipCtrl,
                    hint: '192.168.1.50',
                    icon: Icons.router_rounded,
                    keyboardType: TextInputType.number),
                _hint('Port is always 9100 for LAN printers — included automatically.'),
              ],

              if (_connType == _ConnType.usb) ...[
                _hint('Linux/Pi USB path. Run  ls /dev/usb/  to find your printer.'),
                const SizedBox(height: 8),
                _field('USB Device Path', _usbCtrl,
                    hint: '/dev/usb/lp0',
                    icon: Icons.usb_rounded),
              ],

              if (_connType == _ConnType.windows) ...[
                _hint('Windows shared printer path. Share the printer first in Windows settings.'),
                const SizedBox(height: 8),
                _field('Shared Printer Path', _winCtrl,
                    hint: '//localhost/EPSON_TM_T20',
                    icon: Icons.computer_rounded),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // ── Action buttons ─────────────────────────────────────────────────
          Row(children: [
            // Test print
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _testPrint,
                icon: _testing
                    ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _C.orange))
                    : const Icon(Icons.print_outlined, size: 18, color: _C.orange),
                label: Text('Test Print',
                    style: _p(13, FontWeight.w600, _C.orange)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: _C.orange),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Save
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.dark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Save Settings', style: _p(13, FontWeight.w700, Colors.white)),
              ),
            ),
          ]),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _connTab(String label, _ConnType type, IconData icon) {
    final sel = _connType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _connType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel ? _C.orangeLight : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? _C.orange : _C.cardBorder),
          ),
          child: Column(children: [
            Icon(icon, size: 18, color: sel ? _C.orange : _C.textMid),
            const SizedBox(height: 4),
            Text(label, style: _p(11, FontWeight.w600, sel ? _C.orange : _C.textMid)),
          ]),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {
    String hint = '',
    IconData icon = Icons.edit_outlined,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _p(12, FontWeight.w500, _C.textMid)),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: _p(13, FontWeight.w500, _C.textDark),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 17, color: _C.textLight),
          hintText: hint,
          hintStyle: _p(13, FontWeight.w400, _C.textLight),
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

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 2),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded, size: 13, color: _C.textLight),
      const SizedBox(width: 5),
      Expanded(child: Text(text, style: _p(11, FontWeight.w400, _C.textLight))),
    ]),
  );

  Widget _switchRow({
    required IconData icon,
    required Color? iconColor,
    required String label,
    required String sublabel,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: (iconColor ?? _C.orange).withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: iconColor ?? _C.orange, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,    style: _p(13, FontWeight.w600, _C.textDark)),
          Text(sublabel, style: _p(11, FontWeight.w400, _C.textLight)),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _C.orange,
        ),
      ]),
    );
  }

  Widget _card({
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: iconBg,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 18)),
            const SizedBox(width: 12),
            Text(title, style: _p(14, FontWeight.w700, _C.textDark)),
          ]),
        ),
        Container(height: 1, color: _C.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ]),
    );
  }
}