import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/localization_service.dart';


class WaiterAssistancePage extends StatefulWidget {
  final String restaurantId;

  /// Passed from [CustomerMenuPage] so the QR-scanned table is pre-selected
  /// on this tab without the customer needing to pick it manually.
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
  // ── Theme ─────────────────────────────────────────────────────────────────
  static const Color _navy = Color(0xFF070B2D);
  static const Color _orange = Color(0xFFE0752D);
  static const Color _orangeLight = Color(0xFFFFF2E6);

  // ── Pre-selected table (synced from CustomerMenuPage via ValueNotifiers) ──
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
    // Seed from current notifier values already resolved by CustomerMenuPage
    _selectedTableId   = widget.tableIdNotifier?.value;
    _selectedTableName = widget.tableNameNotifier?.value;
    // Stay in sync whenever CustomerMenuPage updates them
    widget.tableIdNotifier?.addListener(_onTableIdChanged);
    widget.tableNameNotifier?.addListener(_onTableNameChanged);
  }

  @override
  void dispose() {
    widget.tableIdNotifier?.removeListener(_onTableIdChanged);
    widget.tableNameNotifier?.removeListener(_onTableNameChanged);
    super.dispose();
  }

  // ── Filter state ─────────────────────────────────────────────────────────
  String _filterStatus = 'all'; // all | pending | acknowledged | completed
  String _filterType = 'all';   // all | call_waiter | water | order | bill

  // ── Helpers ───────────────────────────────────────────────────────────────

  static const Map<String, Map<String, dynamic>> _typeConfig = {
    'call_waiter': {
      'label': 'Call Waiter',
      'icon': Icons.notifications_active_rounded,
      'color': Color(0xFF7C3AED),
      'bg': Color(0xFFF3EEFF),
    },
    'water': {
      'label': 'Water',
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF0EA5E9),
      'bg': Color(0xFFE0F2FE),
    },
    'order': {
      'label': 'Order',
      'icon': Icons.receipt_long_rounded,
      'color': Color(0xFFE0752D),
      'bg': Color(0xFFFFF2E6),
    },
    'bill': {
      'label': 'Bill',
      'icon': Icons.credit_card_rounded,
      'color': Color(0xFF059669),
      'bg': Color(0xFFD1FAE5),
    },
  };

  static const Map<String, Map<String, dynamic>> _statusConfig = {
    'pending': {
      'label': 'Pending',
      'color': Color(0xFFD97706),
      'bg': Color(0xFFFEF3C7),
    },
    'acknowledged': {
      'label': 'Acknowledged',
      'color': Color(0xFF0EA5E9),
      'bg': Color(0xFFE0F2FE),
    },
    'completed': {
      'label': 'Completed',
      'color': Color(0xFF059669),
      'bg': Color(0xFFD1FAE5),
    },
  };


  String _typeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'call_waiter': return l10n.waiterTypeCallWaiter;
      case 'water':       return l10n.waiterTypeWater;
      case 'order':       return l10n.waiterTypeOrder;
      case 'bill':        return l10n.waiterTypeBill;
      default:            return type;
    }
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':      return l10n.waiterStatusPending;
      case 'acknowledged': return l10n.waiterStatusAcknowledged;
      case 'completed':    return l10n.waiterStatusCompleted;
      default:             return status;
    }
  }

  String _nextActionLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':      return l10n.waiterActionAcknowledge;
      case 'acknowledged': return l10n.waiterActionComplete;
      default:             return '';
    }
  }

  String _formatTime(Timestamp? ts, AppLocalizations l10n) {
    if (ts == null) return '--:--';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.waiterJustNow;
    if (diff.inMinutes < 60) return l10n.waiterMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.waiterHoursAgo(diff.inHours);
    return '${dt.day}/${dt.month}';
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .collection('assistance_requests')
        .doc(docId)
        .update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteRequest(String docId) async {
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .collection('assistance_requests')
        .doc(docId)
        .delete();
  }

  void _confirmDelete(BuildContext context, String docId, String tableLabel) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Color(0xFFE15757), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.waiterDeleteTitle,
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827))),
                        Text(l10n.waiterTableLabel(tableLabel),
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: const Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close,
                        size: 20, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.waiterDeleteBody,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFF6B7280), height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(l10n.waiterCancel,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteRequest(docId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE15757),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(l10n.waiterDelete,
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDesktop = kIsWeb || MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 16,
              isDesktop ? 22 : 16,
              isDesktop ? 24 : 16,
              16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ─────────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    l10n.waiterAssistanceTitle,
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 24 : 20.sp,
                      fontWeight: FontWeight.w200,
                      color: const Color(0xFF0E1A2F),
                    ),
                  ),
                  const Spacer(),
                  // ── Live pending badge ─────────────────────────────────
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('restaurants')
                        .doc(widget.restaurantId)
                        .collection('assistance_requests')
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                          border:
                          Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD97706),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.waiterPendingBadge(count),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  // ── Clear completed button ─────────────────────────────
                  OutlinedButton.icon(
                    onPressed: () async {
                      final snap = await FirebaseFirestore.instance
                          .collection('restaurants')
                          .doc(widget.restaurantId)
                          .collection('assistance_requests')
                          .where('status', isEqualTo: 'completed')
                          .get();
                      for (final doc in snap.docs) {
                        doc.reference.delete();
                      }
                    },
                    icon: const Icon(Icons.cleaning_services_outlined,
                        size: 15, color: Color(0xFF6B7280)),
                    label: Text(
                      l10n.waiterClearCompleted,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B7280)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Summary cards ───────────────────────────────────────────
              _SummaryCards(restaurantId: widget.restaurantId),

              const SizedBox(height: 18),

              // ── Filters ─────────────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Status filters
                    _FilterChip(
                      label: l10n.waiterFilterAll,
                      isSelected: _filterStatus == 'all',
                      onTap: () => setState(() => _filterStatus = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.waiterFilterPending,
                      isSelected: _filterStatus == 'pending',
                      color: const Color(0xFFD97706),
                      onTap: () =>
                          setState(() => _filterStatus = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.waiterFilterAcknowledged,
                      isSelected: _filterStatus == 'acknowledged',
                      color: const Color(0xFF0EA5E9),
                      onTap: () =>
                          setState(() => _filterStatus = 'acknowledged'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.waiterFilterCompleted,
                      isSelected: _filterStatus == 'completed',
                      color: const Color(0xFF059669),
                      onTap: () =>
                          setState(() => _filterStatus = 'completed'),
                    ),
                    const SizedBox(width: 16),
                    Container(
                        width: 1, height: 24, color: const Color(0xFFE5E7EB)),
                    const SizedBox(width: 16),
                    // Type filters
                    ..._typeConfig.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: _RequestCard._localizedTypeLabel(e.key, AppLocalizations.of(context)),
                        isSelected: _filterType == e.key,
                        color: e.value['color'] as Color,
                        onTap: () => setState(() => _filterType ==
                            e.key
                            ? _filterType = 'all'
                            : _filterType = e.key),
                      ),
                    )),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Pre-selected table banner (mirrors CustomerMenuPage) ────
              if (_selectedTableId != null && _selectedTableId!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                      horizontal: kIsWeb ? 14 : 12.sp,
                      vertical: kIsWeb ? 10 : 8.sp),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(kIsWeb ? 10 : 8.sp),
                    border: Border.all(color: const Color(0xFFFFD5BC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.table_restaurant_rounded,
                          color: Color(0xFFE8622A), size: 16),
                      SizedBox(width: kIsWeb ? 8 : 8.w),
                      Expanded(
                        child: Text(
                          l10n.waiterTableLabel(_selectedTableName ?? _selectedTableId!),
                          style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 13 : 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE8622A),
                          ),
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF2ECC71), size: 14),
                      SizedBox(width: kIsWeb ? 4 : 4.w),
                      Text(
                        l10n.waiterAutoSelected,
                        style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 10 : 10.sp,
                          color: const Color(0xFF2ECC71),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: kIsWeb ? 12 : 10.sp),
              ],

              // ── Request list ────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('restaurants')
                      .doc(widget.restaurantId)
                      .collection('assistance_requests')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: _orange),
                      );
                    }

                    var docs = snapshot.data!.docs;

                    // Apply filters
                    if (_filterStatus != 'all') {
                      docs = docs
                          .where((d) =>
                      (d.data()
                      as Map<String, dynamic>)['status'] ==
                          _filterStatus)
                          .toList();
                    }
                    if (_filterType != 'all') {
                      docs = docs
                          .where((d) =>
                      (d.data()
                      as Map<String, dynamic>)['type'] ==
                          _filterType)
                          .toList();
                    }

                    if (docs.isEmpty) {
                      return _EmptyState(
                          filterStatus: _filterStatus,
                          filterType: _filterType);
                    }

                    if (isDesktop) {
                      // Desktop: Grid 2 or 3 columns
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final cols =
                          constraints.maxWidth >= 1200 ? 3 : 2;
                          return GridView.builder(
                            gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 2.4,
                            ),
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final doc = docs[i];
                              final data =
                              doc.data() as Map<String, dynamic>;
                              return _RequestCard(
                                doc: doc,
                                data: data,
                                typeConfig: _typeConfig,
                                statusConfig: _statusConfig,
                                formatTime: (ts) => _formatTime(ts, l10n),
                                onStatusChange: _updateStatus,
                                onDelete: (id) => _confirmDelete(
                                    context,
                                    id,
                                    (data['tableName'] ??
                                        data['tableId'] ??
                                        '')
                                    as String),
                              );
                            },
                          );
                        },
                      );
                    }

                    // Mobile: list
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return _RequestCard(
                          doc: doc,
                          data: data,
                          typeConfig: _typeConfig,
                          statusConfig: _statusConfig,
                          formatTime: (ts) => _formatTime(ts, l10n),
                          onStatusChange: _updateStatus,
                          onDelete: (id) => _confirmDelete(
                              context,
                              id,
                              (data['tableName'] ?? data['tableId'] ?? '')
                              as String),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary stat cards ───────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final String restaurantId;
  const _SummaryCards({required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .collection('assistance_requests')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        int pending = 0, acknowledged = 0, completed = 0;
        for (final d in docs) {
          final s = ((d.data() as Map<String, dynamic>)['status'] ?? '')
          as String;
          if (s == 'pending') pending++;
          else if (s == 'acknowledged') acknowledged++;
          else if (s == 'completed') completed++;
        }

        return Row(
          children: [
            _StatCard(
              label: l10n.waiterSummaryPending,
              count: pending,
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFD97706),
              bg: const Color(0xFFFEF3C7),
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: l10n.waiterSummaryAcknowledged,
              count: acknowledged,
              icon: Icons.directions_run_rounded,
              color: const Color(0xFF0EA5E9),
              bg: const Color(0xFFE0F2FE),
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: l10n.waiterSummaryCompleted,
              count: completed,
              icon: Icons.task_alt_rounded,
              color: const Color(0xFF059669),
              bg: const Color(0xFFD1FAE5),
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: l10n.waiterSummaryTotal,
              count: docs.length,
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF070B2D),
              bg: const Color(0xFFF0F1F5),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final Color bg;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 16 : 12.sp,
            vertical: kIsWeb ? 14 : 12.sp),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: kIsWeb ? 38 : 34.sp,
              height: kIsWeb ? 38 : 34.sp,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(kIsWeb ? 10 : 8.sp),
              ),
              child: Icon(icon, color: color, size: kIsWeb ? 18 : 16.sp),
            ),
            SizedBox(width: kIsWeb ? 12 : 8.sp),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 22 : 18.sp,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 11 : 10.sp,
                      color: color.withOpacity(0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? const Color(0xFF070B2D);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFD1D5DB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}

// ─── Request card ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final Map<String, Map<String, dynamic>> typeConfig;
  final Map<String, Map<String, dynamic>> statusConfig;
  final String Function(Timestamp?) formatTime;
  final Future<void> Function(String, String) onStatusChange;
  final void Function(String) onDelete;

  const _RequestCard({
    required this.doc,
    required this.data,
    required this.typeConfig,
    required this.statusConfig,
    required this.formatTime,
    required this.onStatusChange,
    required this.onDelete,
  });

  static String _localizedTypeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'call_waiter': return l10n.waiterTypeCallWaiter;
      case 'water':       return l10n.waiterTypeWater;
      case 'order':       return l10n.waiterTypeOrder;
      case 'bill':        return l10n.waiterTypeBill;
      default:            return type;
    }
  }

  static String _localizedStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':      return l10n.waiterStatusPending;
      case 'acknowledged': return l10n.waiterStatusAcknowledged;
      case 'completed':    return l10n.waiterStatusCompleted;
      default:             return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String type = (data['type'] ?? 'call_waiter') as String;
    final String status = (data['status'] ?? 'pending') as String;
    final String tableLabel =
    (data['tableName'] ?? data['tableId'] ?? 'Unknown') as String;
    final String note = (data['note'] ?? '') as String;
    final Timestamp? ts = data['createdAt'] as Timestamp?;

    final typeCfg = typeConfig[type] ?? typeConfig['call_waiter']!;
    final statusCfg = statusConfig[status] ?? statusConfig['pending']!;

    final Color typeColor = typeCfg['color'] as Color;
    final Color typeBg = typeCfg['bg'] as Color;
    final IconData typeIcon = typeCfg['icon'] as IconData;
    final String typeLabel = _localizedTypeLabel(type, l10n);

    final Color statusColor = statusCfg['color'] as Color;
    final Color statusBg = statusCfg['bg'] as Color;
    final String statusLabel = _localizedStatusLabel(status, l10n);

    // Next status action
    String? nextStatus;
    String? nextLabel;
    IconData? nextIcon;
    if (status == 'pending') {
      nextStatus = 'acknowledged';
      nextLabel = l10n.waiterActionAcknowledge;
      nextIcon = Icons.check_rounded;
    } else if (status == 'acknowledged') {
      nextStatus = 'completed';
      nextLabel = l10n.waiterActionComplete;
      nextIcon = Icons.task_alt_rounded;
    }

    return Container(
      padding: EdgeInsets.all(kIsWeb ? 18 : 14.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kIsWeb ? 14 : 12.sp),
        border: Border.all(
          color: status == 'pending'
              ? const Color(0xFFFCD34D)
              : const Color(0xFFE6E8EF),
          width: status == 'pending' ? 1.5 : 1,
        ),
        boxShadow: status == 'pending'
            ? [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: type icon + table + status + time ────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon
              Container(
                width: kIsWeb ? 44 : 40.sp,
                height: kIsWeb ? 44 : 40.sp,
                decoration: BoxDecoration(
                  color: typeBg,
                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                ),
                child: Icon(typeIcon, color: typeColor,
                    size: kIsWeb ? 22 : 20.sp),
              ),

              SizedBox(width: kIsWeb ? 12 : 10.sp),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 15 : 13.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: kIsWeb ? 2 : 2.sp),
                    Row(
                      children: [
                        const Icon(Icons.table_restaurant_rounded,
                            size: 12, color: Color(0xFFE0752D)),
                        const SizedBox(width: 4),
                        Text(
                          tableLabel,
                          style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 12 : 11.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE0752D),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status badge + time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: kIsWeb ? 10 : 8.sp,
                        vertical: kIsWeb ? 4 : 3.sp),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 11 : 10.sp,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  SizedBox(height: kIsWeb ? 4 : 4.sp),
                  Text(
                    formatTime(ts),
                    style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 11 : 10.sp,
                        color: const Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ],
          ),

          // ── Note ─────────────────────────────────────────────────────
          if (note.isNotEmpty) ...[
            SizedBox(height: kIsWeb ? 10 : 8.sp),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  horizontal: kIsWeb ? 12 : 10.sp,
                  vertical: kIsWeb ? 8 : 6.sp),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(kIsWeb ? 8 : 6.sp),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded,
                      size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 12 : 11.sp,
                          color: const Color(0xFF374151)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // ── Action buttons ────────────────────────────────────────────
          SizedBox(height: kIsWeb ? 12 : 10.sp),
          Row(
            children: [
              // Delete
              SizedBox(
                height: kIsWeb ? 32 : 30.sp,
                child: InkWell(
                  onTap: () => onDelete(doc.id),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: kIsWeb ? 10 : 8.sp),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.delete_outline,
                        size: kIsWeb ? 16 : 15.sp,
                        color: const Color(0xFFE15757)),
                  ),
                ),
              ),
              const Spacer(),
              // Status advance button
              if (nextStatus != null)
                SizedBox(
                  height: kIsWeb ? 32 : 30.sp,
                  child: ElevatedButton.icon(
                    onPressed: () => onStatusChange(doc.id, nextStatus!),
                    icon: Icon(nextIcon, size: kIsWeb ? 14 : 13.sp),
                    label: Text(
                      nextLabel!,
                      style: GoogleFonts.poppins(
                          fontSize: kIsWeb ? 12 : 11.sp,
                          fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == 'pending'
                          ? const Color(0xFF070B2D)
                          : const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 14 : 12.sp),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(kIsWeb ? 8 : 7.sp)),
                    ),
                  ),
                ),
              if (status == 'completed') ...[
                Icon(Icons.check_circle_rounded,
                    color: const Color(0xFF059669),
                    size: kIsWeb ? 18 : 16.sp),
                SizedBox(width: kIsWeb ? 6 : 5.sp),
                Text(
                  l10n.waiterDone,
                  style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 12 : 11.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF059669)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filterStatus;
  final String filterType;

  const _EmptyState({
    required this.filterStatus,
    required this.filterType,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bool isFiltered =
        filterStatus != 'all' || filterType != 'all';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: kIsWeb ? 80 : 68.sp,
            height: kIsWeb ? 80 : 68.sp,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2E6),
              borderRadius: BorderRadius.circular(kIsWeb ? 18 : 16.sp),
            ),
            child: Icon(
              isFiltered
                  ? Icons.filter_alt_off_outlined
                  : Icons.support_agent_rounded,
              color: const Color(0xFFE0752D),
              size: kIsWeb ? 36 : 30.sp,
            ),
          ),
          SizedBox(height: kIsWeb ? 20 : 16.sp),
          Text(
            isFiltered
                ? l10n.waiterNoRequestsFiltered
                : l10n.waiterNoRequests,
            style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 18 : 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: kIsWeb ? 8 : 6.sp),
          Text(
            isFiltered
                ? l10n.waiterNoRequestsFilteredHint
                : l10n.waiterNoRequestsHint,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 13 : 12.sp,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}