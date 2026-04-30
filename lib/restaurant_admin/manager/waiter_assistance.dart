import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/localization_service.dart';

// ─── NOTE: No flutter_screenutil — plain pixel sizes throughout,
//     exactly like manager_main_page.dart. kIsWeb gates the two layouts.

TextStyle _p(double size, FontWeight w, Color c) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c);

class _C {
  static const bg          = Color(0xFFFFF3EE);
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
  static const amber       = Color(0xFFD97706);
  static const amberBg     = Color(0xFFFEF3C7);
  static const amberBorder = Color(0xFFFCD34D);
  static const blue        = Color(0xFF0EA5E9);
  static const blueBg      = Color(0xFFE0F2FE);
  static const purple      = Color(0xFF7C3AED);
  static const purpleBg    = Color(0xFFF3EEFF);
  static const red         = Color(0xFFE15757);
  static const redBg       = Color(0xFFFFEBEB);
}

// ════════════════════════════════════════════════════════════════════════════
// WaiterAssistancePage
// ════════════════════════════════════════════════════════════════════════════
class WaiterAssistancePage extends StatefulWidget {
  final String restaurantId;
  final ValueNotifier<String?>? tableIdNotifier;
  final ValueNotifier<String?>? tableNameNotifier;

  const WaiterAssistancePage({
    super.key,
    required this.restaurantId,
    this.tableIdNotifier,
    this.tableNameNotifier,
  });

  @override
  State<WaiterAssistancePage> createState() => _WaiterAssistancePageState();
}

class _WaiterAssistancePageState extends State<WaiterAssistancePage> {
  String? _selectedTableId;
  String? _selectedTableName;

  void _onTableIdChanged() {
    if (mounted) setState(() => _selectedTableId = widget.tableIdNotifier?.value);
  }
  void _onTableNameChanged() {
    if (mounted) setState(() => _selectedTableName = widget.tableNameNotifier?.value);
  }

  @override
  void initState() {
    super.initState();
    _selectedTableId   = widget.tableIdNotifier?.value;
    _selectedTableName = widget.tableNameNotifier?.value;
    widget.tableIdNotifier?.addListener(_onTableIdChanged);
    widget.tableNameNotifier?.addListener(_onTableNameChanged);
  }

  // ── Filter scroll controller (mirrors orders page behaviour) ──────────────
  final ScrollController _filterScrollCtrl = ScrollController();
  final ScrollController _listScrollCtrl   = ScrollController();

  @override
  void dispose() {
    widget.tableIdNotifier?.removeListener(_onTableIdChanged);
    widget.tableNameNotifier?.removeListener(_onTableNameChanged);
    _filterScrollCtrl.dispose();
    _listScrollCtrl.dispose();
    super.dispose();
  }

  String _filterStatus = 'all';
  String _filterType   = 'all';

  static const Map<String, Map<String, dynamic>> _typeConfig = {
    'call_waiter': {'icon': Icons.notifications_active_rounded, 'color': _C.purple, 'bg': _C.purpleBg},
    'water':       {'icon': Icons.water_drop_rounded,           'color': _C.blue,   'bg': _C.blueBg},
    'order':       {'icon': Icons.receipt_long_rounded,         'color': _C.orange, 'bg': _C.orangeLight},
    'bill':        {'icon': Icons.credit_card_rounded,          'color': _C.green,  'bg': _C.greenBg},
  };

  static const Map<String, Map<String, dynamic>> _statusConfig = {
    'pending':      {'color': _C.amber, 'bg': _C.amberBg},
    'acknowledged': {'color': _C.blue,  'bg': _C.blueBg},
    'completed':    {'color': _C.green, 'bg': _C.greenBg},
  };

  CollectionReference get _ref => FirebaseFirestore.instance
      .collection('restaurants').doc(widget.restaurantId)
      .collection('assistance_requests');

  Future<void> _updateStatus(String id, String s) async =>
      _ref.doc(id).update({'status': s, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> _deleteRequest(String id) async => _ref.doc(id).delete();

  Future<void> _clearCompleted() async {
    final snap = await _ref.where('status', isEqualTo: 'completed').get();
    for (final d in snap.docs) d.reference.delete();
  }

  void _confirmDelete(BuildContext ctx, String docId, String tableLabel) {
    final l10n = AppLocalizations.of(ctx);
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: _C.redBg, shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline, color: _C.red, size: 26),
            ),
            const SizedBox(height: 14),
            Text(l10n.waiterDeleteTitle, style: _p(17, FontWeight.w700, _C.textDark)),
            const SizedBox(height: 6),
            Text(l10n.waiterTableLabel(tableLabel), style: _p(12, FontWeight.w400, _C.textMid)),
            const SizedBox(height: 8),
            Text(l10n.waiterDeleteBody, textAlign: TextAlign.center,
                style: _p(12, FontWeight.w400, _C.textMid).copyWith(height: 1.5)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(l10n.waiterCancel,
                        style: _p(13, FontWeight.w600, _C.textMid))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () { Navigator.pop(ctx); _deleteRequest(docId); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: _C.red,
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(l10n.waiterDelete,
                        style: _p(13, FontWeight.w600, Colors.white))),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  String _formatTime(Timestamp? ts, AppLocalizations l10n) {
    if (ts == null) return '--:--';
    final dt   = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return l10n.waiterJustNow;
    if (diff.inMinutes < 60) return l10n.waiterMinutesAgo(diff.inMinutes);
    if (diff.inHours   < 24) return l10n.waiterHoursAgo(diff.inHours);
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n    = AppLocalizations.of(context);
    final isWeb   = MediaQuery.of(context).size.width >= 768;
    final sidePad = isWeb ? 28.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Compact action bar ─────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(sidePad, 8, sidePad, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _C.cardBorder)),
          ),
          child: Row(children: [
            // Summary chips — scrollable so they never overflow
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _SummaryChips(restaurantId: widget.restaurantId, l10n: l10n),
              ),
            ),
            const SizedBox(width: 8),
            // Pending badge (hidden when 0 — SizedBox.shrink)
            _PendingBadge(restaurantId: widget.restaurantId, l10n: l10n, compact: true),
            const SizedBox(width: 8),
            // Clear completed — icon only on mobile to save space
            GestureDetector(
              onTap: _clearCompleted,
              child: Container(
                height: 32,
                padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 12 : 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.cardBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cleaning_services_outlined,
                      size: 15, color: _C.textMid),
                  if (isWeb) ...[
                    const SizedBox(width: 6),
                    Text(l10n.waiterClearCompleted,
                        style: _p(12, FontWeight.w600, _C.textMid)),
                  ],
                ]),
              ),
            ),
          ]),
        ),

        // ── Filters row ────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
          ),
          padding: EdgeInsets.fromLTRB(sidePad, 8, sidePad, 10),
          child: _FiltersRow(
            filterStatus:    _filterStatus,
            filterType:      _filterType,
            typeConfig:      _typeConfig,
            l10n:            l10n,
            scrollController: _filterScrollCtrl,
            onStatusChanged: (v, idx) {
              setState(() { _filterStatus = v; });
              _scrollFilterTo(idx);
              _scrollListToTop();
            },
            onTypeChanged: (v, idx) {
              setState(() { _filterType = v; });
              _scrollFilterTo(idx);
              _scrollListToTop();
            },
          ),
        ),

        // ── Table banner ───────────────────────────────────────────────────
        if (_selectedTableId != null && _selectedTableId!.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(sidePad, 10, sidePad, 0),
            child: _TableBanner(
                tableName: _selectedTableName ?? _selectedTableId!,
                l10n: l10n, isWeb: isWeb),
          ),

        // ── Requests list / grid ───────────────────────────────────────────
        Expanded(
          child: _RequestStream(
            restaurantId:   widget.restaurantId,
            filterStatus:   _filterStatus,
            filterType:     _filterType,
            typeConfig:     _typeConfig,
            statusConfig:   _statusConfig,
            isWeb:          isWeb,
            listScrollCtrl: _listScrollCtrl,
            formatTime:     (ts) => _formatTime(ts, l10n),
            onStatusChange: _updateStatus,
            onDelete: (id, tbl) => _confirmDelete(context, id, tbl),
            l10n: l10n,
          ),
        ),
      ],
    );
  }

  void _scrollFilterTo(int idx) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_filterScrollCtrl.hasClients) return;
      const tabW = 110.0;
      final target = (idx * tabW)
          .clamp(0.0, _filterScrollCtrl.position.maxScrollExtent);
      _filterScrollCtrl.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _scrollListToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listScrollCtrl.hasClients) {
        _listScrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUMMARY CHIPS — compact inline stats for the action bar
// ════════════════════════════════════════════════════════════════════════════
class _SummaryChips extends StatelessWidget {
  final String restaurantId;
  final AppLocalizations l10n;
  const _SummaryChips({required this.restaurantId, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants').doc(restaurantId)
          .collection('assistance_requests').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        int p = 0, a = 0, c = 0;
        for (final d in docs) {
          final s = ((d.data() as Map<String, dynamic>)['status'] ?? '') as String;
          if (s == 'pending')           p++;
          else if (s == 'acknowledged') a++;
          else if (s == 'completed')    c++;
        }
        return Row(mainAxisSize: MainAxisSize.min, children: [
          _MiniChip(count: p, label: l10n.waiterSummaryPending,
              color: _C.amber, bg: _C.amberBg),
          const SizedBox(width: 6),
          _MiniChip(count: a, label: l10n.waiterSummaryAcknowledged,
              color: _C.blue, bg: _C.blueBg),
          const SizedBox(width: 6),
          _MiniChip(count: c, label: l10n.waiterSummaryCompleted,
              color: _C.green, bg: _C.greenBg),
        ]);
      },
    );
  }
}

class _MiniChip extends StatelessWidget {
  final int count; final String label;
  final Color color, bg;
  const _MiniChip({required this.count, required this.label,
    required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count', style: _p(13, FontWeight.w700, color)),
        const SizedBox(width: 4),
        Text(label, style: _p(11, FontWeight.w500, color.withOpacity(0.75))),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LIVE PENDING BADGE
// ════════════════════════════════════════════════════════════════════════════
class _PendingBadge extends StatelessWidget {
  final String restaurantId;
  final AppLocalizations l10n;
  final bool compact;
  const _PendingBadge({required this.restaurantId, required this.l10n,
    this.compact = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants').doc(restaurantId)
          .collection('assistance_requests')
          .where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _C.amberBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.amberBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7,
                decoration: const BoxDecoration(color: _C.amber, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(compact ? '$count' : l10n.waiterPendingBadge(count),
                style: _p(12, FontWeight.w700, _C.amber)),
          ]),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FILTERS ROW — 12px chips, plain pixels
// ════════════════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════════════════
// FILTERS ROW — auto-scroll on selection, mirrors orders page
// ════════════════════════════════════════════════════════════════════════════
class _FiltersRow extends StatelessWidget {
  final String filterStatus, filterType;
  final Map<String, Map<String, dynamic>> typeConfig;
  final AppLocalizations l10n;
  final ScrollController scrollController;
  final void Function(String val, int idx) onStatusChanged;
  final void Function(String val, int idx) onTypeChanged;
  const _FiltersRow({
    required this.filterStatus,
    required this.filterType,
    required this.typeConfig,
    required this.l10n,
    required this.scrollController,
    required this.onStatusChanged,
    required this.onTypeChanged,
  });

  static String _t(String k, AppLocalizations l) {
    switch (k) {
      case 'call_waiter': return l.waiterTypeCallWaiter;
      case 'water':       return l.waiterTypeWater;
      case 'order':       return l.waiterTypeOrder;
      case 'bill':        return l.waiterTypeBill;
      default:            return k;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Status chips: All(0), Pending(1), Acknowledged(2), Completed(3)
    // Type chips start at index 4 (after divider)
    final statusChips = [
      {'val': 'all',          'label': l10n.waiterFilterAll,          'color': null},
      {'val': 'pending',      'label': l10n.waiterFilterPending,      'color': _C.amber},
      {'val': 'acknowledged', 'label': l10n.waiterFilterAcknowledged, 'color': _C.blue},
      {'val': 'completed',    'label': l10n.waiterFilterCompleted,    'color': _C.green},
    ];

    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      child: Row(children: [
        // ── Status chips ─────────────────────────────────────────────────
        ...statusChips.asMap().entries.map((e) {
          final idx  = e.key;
          final chip = e.value;
          final val  = chip['val'] as String;
          final lbl  = chip['label'] as String;
          final col  = chip['color'] as Color?;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _Chip(
              label:      lbl,
              color:      col,
              isSelected: filterStatus == val,
              onTap: () => onStatusChanged(val, idx),
            ),
          );
        }),

        // ── Divider ───────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 1, height: 22,
          color: const Color(0xFFDDDDDD),
        ),

        // ── Type chips ────────────────────────────────────────────────────
        ...typeConfig.entries.toList().asMap().entries.map((e) {
          final idx  = e.key + 5; // offset past status chips + divider
          final key  = e.value.key;
          final conf = e.value.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _Chip(
              label:      _t(key, l10n),
              color:      conf['color'] as Color,
              isSelected: filterType == key,
              onTap: () => onTypeChanged(
                  filterType == key ? 'all' : key, idx),
            ),
          );
        }),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final bool isSelected; final Color? color;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.isSelected,
    this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = color ?? _C.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? active : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? active : const Color(0xFFD1D5DB),
              width: isSelected ? 1.5 : 1),
        ),
        child: Text(label,
            style: _p(12, FontWeight.w600,
                isSelected ? Colors.white : _C.textMid)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TABLE BANNER
// ════════════════════════════════════════════════════════════════════════════
class _TableBanner extends StatelessWidget {
  final String tableName; final AppLocalizations l10n; final bool isWeb;
  const _TableBanner({required this.tableName, required this.l10n,
    required this.isWeb});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 14 : 12, vertical: isWeb ? 10 : 9),
      decoration: BoxDecoration(
        color: _C.orangeLight,
        borderRadius: BorderRadius.circular(isWeb ? 10 : 8),
        border: Border.all(color: _C.orangeMid),
      ),
      child: Row(children: [
        const Icon(Icons.table_restaurant_rounded, color: _C.orange, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(l10n.waiterTableLabel(tableName),
            style: _p(13, FontWeight.w600, _C.orange))),
        const Icon(Icons.check_circle_rounded, color: _C.green, size: 14),
        const SizedBox(width: 4),
        Text(l10n.waiterAutoSelected,
            style: _p(isWeb ? 10 : 11, FontWeight.w500, _C.green)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// REQUEST STREAM
// ════════════════════════════════════════════════════════════════════════════
class _RequestStream extends StatelessWidget {
  final String restaurantId, filterStatus, filterType;
  final Map<String, Map<String, dynamic>> typeConfig, statusConfig;
  final bool isWeb;
  final ScrollController listScrollCtrl;
  final String Function(Timestamp?) formatTime;
  final Future<void> Function(String, String) onStatusChange;
  final void Function(String, String) onDelete;
  final AppLocalizations l10n;
  const _RequestStream({
    required this.restaurantId,
    required this.filterStatus,
    required this.filterType,
    required this.typeConfig,
    required this.statusConfig,
    required this.isWeb,
    required this.listScrollCtrl,
    required this.formatTime,
    required this.onStatusChange,
    required this.onDelete,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants').doc(restaurantId)
          .collection('assistance_requests')
          .orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _C.orange));
        }
        var docs = snapshot.data!.docs;
        if (filterStatus != 'all') {
          docs = docs.where((d) =>
          (d.data() as Map<String, dynamic>)['status'] == filterStatus).toList();
        }
        if (filterType != 'all') {
          docs = docs.where((d) =>
          (d.data() as Map<String, dynamic>)['type'] == filterType).toList();
        }
        if (docs.isEmpty) {
          return _EmptyState(filterStatus: filterStatus,
              filterType: filterType, isWeb: isWeb);
        }
        return LayoutBuilder(builder: (context, c) {
          final isWeb = c.maxWidth >= 768;
          final sidePad = isWeb ? 28.0 : 16.0;
          if (isWeb) {
            final cols = c.maxWidth >= 1200 ? 3 : 2;
            return Padding(
              padding: EdgeInsets.fromLTRB(sidePad, 14, sidePad, 14),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols, crossAxisSpacing: 14,
                    mainAxisSpacing: 14, childAspectRatio: 1.85),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc = docs[i]; final data = doc.data() as Map<String, dynamic>;
                  return _RequestCard(doc: doc, data: data, typeConfig: typeConfig,
                      statusConfig: statusConfig, formatTime: formatTime,
                      onStatusChange: onStatusChange, onDelete: onDelete,
                      isWeb: true, l10n: l10n);
                },
              ),
            );
          }
          return ListView.separated(
            controller: listScrollCtrl,
            padding: EdgeInsets.fromLTRB(sidePad, 10, sidePad, 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final doc = docs[i]; final data = doc.data() as Map<String, dynamic>;
              return _RequestCard(doc: doc, data: data, typeConfig: typeConfig,
                  statusConfig: statusConfig, formatTime: formatTime,
                  onStatusChange: onStatusChange, onDelete: onDelete,
                  isWeb: false, l10n: l10n);
            },
          );
        });
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// REQUEST CARD
// mainAxisSize: MainAxisSize.min + Expanded(child:SizedBox()) replaces
// Spacer() — prevents the RenderFlex unbounded height crash entirely.
// ALL sizes are plain pixels.
// ════════════════════════════════════════════════════════════════════════════
class _RequestCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final Map<String, Map<String, dynamic>> typeConfig, statusConfig;
  final String Function(Timestamp?) formatTime;
  final Future<void> Function(String, String) onStatusChange;
  final void Function(String, String) onDelete;
  final bool isWeb;
  final AppLocalizations l10n;
  const _RequestCard({required this.doc, required this.data,
    required this.typeConfig, required this.statusConfig,
    required this.formatTime, required this.onStatusChange,
    required this.onDelete, required this.isWeb, required this.l10n});

  static String _locType(String t, AppLocalizations l) {
    switch (t) {
      case 'call_waiter': return l.waiterTypeCallWaiter;
      case 'water':       return l.waiterTypeWater;
      case 'order':       return l.waiterTypeOrder;
      case 'bill':        return l.waiterTypeBill;
      default:            return t;
    }
  }
  static String _locStatus(String s, AppLocalizations l) {
    switch (s) {
      case 'pending':      return l.waiterStatusPending;
      case 'acknowledged': return l.waiterStatusAcknowledged;
      case 'completed':    return l.waiterStatusCompleted;
      default:             return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type       = (data['type']      ?? 'call_waiter') as String;
    final status     = (data['status']    ?? 'pending')     as String;
    final tableLabel = (data['tableName'] ?? data['tableId'] ?? 'Unknown') as String;
    final note       = (data['note']      ?? '') as String;
    final ts         = data['createdAt']  as Timestamp?;

    final tc = typeConfig[type]     ?? typeConfig['call_waiter']!;
    final sc = statusConfig[status] ?? statusConfig['pending']!;

    final Color typeColor   = tc['color'] as Color;
    final Color typeBg      = tc['bg']    as Color;
    final IconData typeIcon = tc['icon']  as IconData;
    final Color statusColor = sc['color'] as Color;
    final Color statusBg    = sc['bg']    as Color;

    String? nextStatus; String? nextLabel; IconData? nextIcon;
    if (status == 'pending') {
      nextStatus = 'acknowledged'; nextLabel = l10n.waiterActionAcknowledge;
      nextIcon = Icons.check_rounded;
    } else if (status == 'acknowledged') {
      nextStatus = 'completed'; nextLabel = l10n.waiterActionComplete;
      nextIcon = Icons.task_alt_rounded;
    }

    return Container(
      padding: EdgeInsets.all(isWeb ? 16 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 14 : 12),
        border: Border.all(
          color: status == 'pending' ? _C.amberBorder : const Color(0xFFE6E8EF),
          width: status == 'pending' ? 1.5 : 1,
        ),
        boxShadow: status == 'pending'
            ? [BoxShadow(color: _C.amber.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 3))]
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ← prevents unbounded flex
        children: [
          // ── Top row ──────────────────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: isWeb ? 42 : 38, height: isWeb ? 42 : 38,
              decoration: BoxDecoration(color: typeBg,
                  borderRadius: BorderRadius.circular(isWeb ? 11 : 10)),
              child: Icon(typeIcon, color: typeColor, size: isWeb ? 20 : 19),
            ),
            SizedBox(width: isWeb ? 12 : 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_locType(type, l10n),
                  style: _p(isWeb ? 14 : 13, FontWeight.w700, _C.textDark)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.table_restaurant_rounded, size: 12, color: _C.orange),
                const SizedBox(width: 4),
                Flexible(child: Text(tableLabel, overflow: TextOverflow.ellipsis,
                    style: _p(isWeb ? 12 : 12, FontWeight.w600, _C.orange))),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: statusBg,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_locStatus(status, l10n),
                    style: _p(isWeb ? 11 : 11, FontWeight.w700, statusColor)),
              ),
              const SizedBox(height: 4),
              Text(formatTime(ts),
                  style: _p(isWeb ? 11 : 11, FontWeight.w400, _C.textLight)),
            ]),
          ]),

          // ── Note ─────────────────────────────────────────────────────────
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 12 : 10, vertical: isWeb ? 8 : 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(isWeb ? 8 : 7),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.notes_rounded, size: 14, color: _C.textLight),
                const SizedBox(width: 6),
                Expanded(child: Text(note,
                    style: _p(isWeb ? 12 : 12, FontWeight.w400, _C.textMid),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ],

          // ── Action row ────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Row(children: [
            // Delete button
            SizedBox(
              height: isWeb ? 32 : 30,
              child: InkWell(
                onTap: () => onDelete(doc.id, tableLabel),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.delete_outline,
                      size: isWeb ? 16 : 16, color: _C.red),
                ),
              ),
            ),

            // Flex gap — NOT Spacer() (Spacer requires bounded height)
            const Expanded(child: SizedBox()),

            // Status advance
            if (nextStatus != null)
              SizedBox(
                height: isWeb ? 32 : 30,
                child: ElevatedButton.icon(
                  onPressed: () => onStatusChange(doc.id, nextStatus!),
                  icon: Icon(nextIcon, size: 14),
                  label: Text(nextLabel!,
                      style: _p(isWeb ? 12 : 12, FontWeight.w600, Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'pending' ? _C.dark : _C.green,
                    foregroundColor: Colors.white, elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: isWeb ? 14 : 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

            // Completed label
            if (status == 'completed') ...[
              Icon(Icons.check_circle_rounded,
                  color: _C.green, size: isWeb ? 18 : 17),
              const SizedBox(width: 6),
              Text(l10n.waiterDone,
                  style: _p(isWeb ? 12 : 12, FontWeight.w600, _C.green)),
            ],
          ]),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final String filterStatus, filterType; final bool isWeb;
  const _EmptyState({required this.filterStatus, required this.filterType,
    this.isWeb = true});

  @override
  Widget build(BuildContext context) {
    final l10n       = AppLocalizations.of(context);
    final isFiltered = filterStatus != 'all' || filterType != 'all';
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: isWeb ? 80 : 68, height: isWeb ? 80 : 68,
          decoration: BoxDecoration(color: _C.orangeLight,
              borderRadius: BorderRadius.circular(isWeb ? 18 : 16)),
          child: Icon(isFiltered
              ? Icons.filter_alt_off_outlined : Icons.support_agent_rounded,
              color: _C.orange, size: isWeb ? 36 : 30),
        ),
        SizedBox(height: isWeb ? 20 : 16),
        Text(isFiltered ? l10n.waiterNoRequestsFiltered : l10n.waiterNoRequests,
            style: _p(isWeb ? 18 : 16, FontWeight.w700, _C.textDark)),
        SizedBox(height: isWeb ? 8 : 6),
        Text(isFiltered ? l10n.waiterNoRequestsFilteredHint : l10n.waiterNoRequestsHint,
            textAlign: TextAlign.center,
            style: _p(isWeb ? 13 : 13, FontWeight.w400, _C.textMid).copyWith(height: 1.5)),
      ]),
    );
  }
}