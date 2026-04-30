import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';


class CallWaiterPage extends StatefulWidget {
  final String restaurantId;

  /// Passed from CustomerMenuPage so the QR-scanned table is pre-selected.
  final ValueNotifier<String?>? tableIdNotifier;
  final ValueNotifier<String?>? tableNameNotifier;

  const CallWaiterPage({
    super.key,
    required this.restaurantId,
    this.tableIdNotifier,
    this.tableNameNotifier,
  });

  @override
  State<CallWaiterPage> createState() => _CallWaiterPageState();
}

class _CallWaiterPageState extends State<CallWaiterPage>
    with SingleTickerProviderStateMixin {

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFF1A1A2E);
  static const Color _orange   = Color(0xFFE0752D);
  static const Color _surface  = Color(0xFFF8F9FA);
  static const Color _border   = Color(0xFFE5E7EB);

  // ── Request type config ────────────────────────────────────────────────────
  static const List<_RequestType> _types = [
    _RequestType(
      key: 'call_waiter', label: 'Call Waiter',
      icon: Icons.notifications_active_rounded,
      color: Color(0xFF7C3AED), bg: Color(0xFFF3EEFF),
    ),
    _RequestType(
      key: 'water', label: 'Water',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF0EA5E9), bg: Color(0xFFE0F2FE),
    ),
    _RequestType(
      key: 'order', label: 'Order',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFE0752D), bg: Color(0xFFFFF2E6),
    ),
    _RequestType(
      key: 'bill', label: 'Bill',
      icon: Icons.credit_card_rounded,
      color: Color(0xFF059669), bg: Color(0xFFD1FAE5),
    ),
  ];

  // ── Status timeline steps (mirrors the mockup's tracker) ──────────────────
  static const List<_StatusStep> _steps = [
    _StatusStep(key: 'pending',      label: 'Request Sent'),
    _StatusStep(key: 'acknowledged', label: 'Assigned'),
    _StatusStep(key: 'on_the_way',   label: 'On the way'),
    _StatusStep(key: 'completed',    label: 'Completed'),
  ];

  static const Map<String, int> _statusIndex = {
    'pending':      0,
    'acknowledged': 1,
    'on_the_way':   2,
    'completed':    3,
  };

  // ── Local state ────────────────────────────────────────────────────────────
  String? _selectedTableId;
  String? _selectedTableName;
  String  _selectedType    = 'call_waiter';
  bool    _sending         = false;
  String? _activeRequestId; // non-null → show status tracker

  final TextEditingController _noteCtrl = TextEditingController();

  late AnimationController _successCtrl;
  late Animation<double>   _successAnim;

  // ── Notifier wiring ────────────────────────────────────────────────────────
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

    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _successAnim = CurvedAnimation(
        parent: _successCtrl, curve: Curves.elasticOut);

    // Restore tracker if this table already has an active request
    _checkActiveRequest();
  }

  @override
  void dispose() {
    widget.tableIdNotifier?.removeListener(_onTableIdChanged);
    widget.tableNameNotifier?.removeListener(_onTableNameChanged);
    _noteCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  // ── Firestore helpers ──────────────────────────────────────────────────────

  CollectionReference get _requestsRef => FirebaseFirestore.instance
      .collection('restaurants')
      .doc(widget.restaurantId)
      .collection('assistance_requests');

  /// Restore status-tracker if there is already a live request for this table.
  /// Customers are unauthenticated — query by tableId only.
  Future<void> _checkActiveRequest() async {
    final tableId = _selectedTableId;
    if (tableId == null || tableId.isEmpty) return;
    try {
      final snap = await _requestsRef
          .where('tableId', isEqualTo: tableId)
          .where('status',  whereIn: ['pending', 'acknowledged', 'on_the_way'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (!mounted) return;
      if (snap.docs.isNotEmpty) {
        setState(() => _activeRequestId = snap.docs.first.id);
      }
    } catch (_) {
      // Index may not be ready on first deploy — silent fallback to form
    }
  }

  /// Write a new assistance_request document.
  /// Customers are unauthenticated — no userId required.
  /// Firestore rule: allow create: if true
  Future<void> _sendRequest() async {
    final tableId = _selectedTableId;
    if (tableId == null || tableId.isEmpty) {
      _snack('No table detected. Please scan the QR code again.', error: true);
      return;
    }

    setState(() => _sending = true);
    try {
      final ref = _requestsRef.doc();
      await ref.set({
        'type':      _selectedType,
        'tableId':   tableId,
        'tableName': _selectedTableName ?? tableId,
        'status':    'pending',
        'note':      _noteCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // userId is optional — only present if customer is signed in
        'userId':    FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      _noteCtrl.clear();
      setState(() => _activeRequestId = ref.id);
      _successCtrl.forward(from: 0);
    } catch (e) {
      _snack('Failed to send request. Please try again.', error: true);
      debugPrint('❌ assistance_request create error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _sendAnother() {
    setState(() {
      _activeRequestId = null;
      _selectedType    = 'call_waiter';
    });
    _successCtrl.reset();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.poppins(fontSize: kIsWeb ? 13 : 13.sp)),
      backgroundColor: error ? Colors.red[600] : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build root ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: _activeRequestId != null
            ? _buildStatusView()
            : _buildRequestForm(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REQUEST FORM
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRequestForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: kIsWeb ? 24 : 20.w,
        vertical:   kIsWeb ? 24 : 20.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Need Assistance?',
            style: GoogleFonts.poppins(
              fontSize:   kIsWeb ? 24 : 20.sp,
              fontWeight: FontWeight.w700,
              color:      const Color(0xFF111827),
            ),
          ),
          SizedBox(height: kIsWeb ? 4 : 3.h),
          Text(
            "Select what you need and we'll notify your waiter right away.",
            style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 13 : 12.sp,
              color:    const Color(0xFF6B7280),
              height:   1.5,
            ),
          ),
          SizedBox(height: kIsWeb ? 18 : 14.h),

          // Table banner
          _buildTableBanner(),
          SizedBox(height: kIsWeb ? 22 : 18.h),

          // 2×2 type grid
          _buildTypeGrid(),
          SizedBox(height: kIsWeb ? 20 : 18.h),

          // Note field
          _buildNoteField(),
          SizedBox(height: kIsWeb ? 24 : 20.h),

          // Send button
          _buildSendButton(),
          SizedBox(height: kIsWeb ? 16 : 12.h),
        ],
      ),
    );
  }

  // ── Table banner ───────────────────────────────────────────────────────────
  Widget _buildTableBanner() {
    if (_selectedTableId == null || _selectedTableId!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 14 : 12.sp, vertical: kIsWeb ? 10 : 8.sp),
        decoration: BoxDecoration(
          color:        const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(kIsWeb ? 10 : 8.sp),
          border:       Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFD97706), size: 16),
          SizedBox(width: kIsWeb ? 8 : 8.w),
          Expanded(
            child: Text(
              'No table detected. Please scan the table QR code.',
              style: GoogleFonts.poppins(
                fontSize:   kIsWeb ? 12 : 11.sp,
                fontWeight: FontWeight.w500,
                color:      const Color(0xFFD97706),
              ),
            ),
          ),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 14 : 12.sp, vertical: kIsWeb ? 10 : 8.sp),
      decoration: BoxDecoration(
        color:        const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(kIsWeb ? 10 : 8.sp),
        border:       Border.all(color: const Color(0xFFFFD5BC)),
      ),
      child: Row(children: [
        const Icon(Icons.table_restaurant_rounded,
            color: Color(0xFFE8622A), size: 16),
        SizedBox(width: kIsWeb ? 8 : 8.w),
        Expanded(
          child: Text(
            'Table: ${_selectedTableName ?? _selectedTableId}',
            style: GoogleFonts.poppins(
              fontSize:   kIsWeb ? 13 : 12.sp,
              fontWeight: FontWeight.w600,
              color:      const Color(0xFFE8622A),
            ),
          ),
        ),
        const Icon(Icons.check_circle_rounded,
            color: Color(0xFF2ECC71), size: 14),
        SizedBox(width: kIsWeb ? 4 : 4.w),
        Text('Auto-selected',
            style: GoogleFonts.poppins(
              fontSize:   kIsWeb ? 10 : 10.sp,
              color:      const Color(0xFF2ECC71),
              fontWeight: FontWeight.w500,
            )),
      ]),
    );
  }

  // ── 2×2 type grid ──────────────────────────────────────────────────────────
  Widget _buildTypeGrid() {
    return GridView.count(
      crossAxisCount:   2,
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      crossAxisSpacing: kIsWeb ? 14 : 12.w,
      mainAxisSpacing:  kIsWeb ? 14 : 12.h,
      childAspectRatio: kIsWeb ? 1.9 : 1.65,
      children: _types.map((t) => _TypeCard(
        type:       t,
        isSelected: _selectedType == t.key,
        onTap:      () => setState(() => _selectedType = t.key),
      )).toList(),
    );
  }

  // ── Note field ─────────────────────────────────────────────────────────────
  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add a note',
          style: GoogleFonts.poppins(
            fontSize:   kIsWeb ? 13 : 12.sp,
            fontWeight: FontWeight.w600,
            color:      const Color(0xFF374151),
          ),
        ),
        SizedBox(height: kIsWeb ? 8 : 6.h),
        Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
            border:       Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _noteCtrl,
            maxLines:   3,
            maxLength:  200,
            style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 13 : 13.sp,
              color:    const Color(0xFF111827),
            ),
            decoration: InputDecoration(
              hintText: 'Add note (optional)',
              hintStyle: GoogleFonts.poppins(
                fontSize: kIsWeb ? 13 : 13.sp,
                color:    const Color(0xFF9CA3AF),
              ),
              border:         InputBorder.none,
              contentPadding: EdgeInsets.all(kIsWeb ? 14 : 12.sp),
              counterStyle: GoogleFonts.poppins(
                fontSize: kIsWeb ? 10 : 10.sp,
                color:    const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Send button ────────────────────────────────────────────────────────────
  Widget _buildSendButton() {
    final bool disabled = _sending || (_selectedTableId == null);
    return SizedBox(
      width:  double.infinity,
      height: kIsWeb ? 52 : 50.h,
      child: ElevatedButton(
        onPressed: disabled ? null : _sendRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor:         _primary,
          disabledBackgroundColor: const Color(0xFF9CA3AF),
          foregroundColor:         Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp)),
        ),
        child: _sending
            ? SizedBox(
            width: kIsWeb ? 20 : 20.sp, height: kIsWeb ? 20 : 20.sp,
            child: const CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_rounded, size: 18),
            SizedBox(width: kIsWeb ? 8 : 8.w),
            Text(
              'Send Request',
              style: GoogleFonts.poppins(
                fontSize:   kIsWeb ? 15 : 14.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STATUS TRACKER VIEW  (after submit)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStatusView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _requestsRef.doc(_activeRequestId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _orange));
        }
        if (!snap.data!.exists) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _sendAnother());
          return const SizedBox.shrink();
        }

        final data   = snap.data!.data() as Map<String, dynamic>;
        final status = (data['status']    ?? 'pending')     as String;
        final type   = (data['type']      ?? 'call_waiter') as String;
        final note   = (data['note']      ?? '')            as String;
        final table  = (data['tableName'] ?? data['tableId'] ?? '') as String;
        final bool   isDone = status == 'completed';

        final typeCfg = _types.firstWhere(
                (t) => t.key == type, orElse: () => _types.first);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 24 : 20.w,
            vertical:   kIsWeb ? 24 : 20.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header row ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDone ? 'Request Completed!' : 'Request Sent!',
                          style: GoogleFonts.poppins(
                            fontSize:   kIsWeb ? 22 : 19.sp,
                            fontWeight: FontWeight.w700,
                            color:      const Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: kIsWeb ? 3 : 2.h),
                        Text(
                          isDone
                              ? 'Your waiter has completed your request.'
                              : 'Your waiter has been notified.',
                          style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 12 : 11.sp,
                            color:    const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ScaleTransition(
                    scale: _successAnim,
                    child: Container(
                      width:  kIsWeb ? 52 : 48.sp,
                      height: kIsWeb ? 52 : 48.sp,
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFFEF3C7),
                        borderRadius:
                        BorderRadius.circular(kIsWeb ? 14 : 12.sp),
                      ),
                      child: Icon(
                        isDone
                            ? Icons.check_circle_rounded
                            : Icons.notifications_active_rounded,
                        color: isDone
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                        size: kIsWeb ? 28 : 26.sp,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: kIsWeb ? 20 : 16.h),

              // ── Request summary card ─────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(kIsWeb ? 16 : 14.sp),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(kIsWeb ? 14 : 12.sp),
                  border:       Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withOpacity(0.04),
                      blurRadius: 8, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width:  kIsWeb ? 48 : 44.sp,
                      height: kIsWeb ? 48 : 44.sp,
                      decoration: BoxDecoration(
                        color:        typeCfg.bg,
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                      ),
                      child: Icon(typeCfg.icon,
                          color: typeCfg.color,
                          size:  kIsWeb ? 24 : 22.sp),
                    ),
                    SizedBox(width: kIsWeb ? 14 : 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typeCfg.label,
                            style: GoogleFonts.poppins(
                              fontSize:   kIsWeb ? 15 : 14.sp,
                              fontWeight: FontWeight.w700,
                              color:      const Color(0xFF111827),
                            ),
                          ),
                          Row(children: [
                            const Icon(Icons.table_restaurant_rounded,
                                size: 12, color: Color(0xFFE0752D)),
                            const SizedBox(width: 4),
                            Text(table,
                                style: GoogleFonts.poppins(
                                  fontSize:   kIsWeb ? 12 : 11.sp,
                                  color:      const Color(0xFFE0752D),
                                  fontWeight: FontWeight.w500,
                                )),
                          ]),
                          if (note.isNotEmpty) ...[
                            SizedBox(height: kIsWeb ? 4 : 3.h),
                            Text('"$note"',
                                style: GoogleFonts.poppins(
                                  fontSize:  kIsWeb ? 11 : 11.sp,
                                  color:     const Color(0xFF6B7280),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: kIsWeb ? 18 : 16.h),

              // ── Status badge (mirrors mockup "Status / Waiter notified") ─
              _StatusBadgeCard(status: status),

              SizedBox(height: kIsWeb ? 18 : 16.h),

              // ── Timeline ─────────────────────────────────────────────
              Text(
                'Request Timeline',
                style: GoogleFonts.poppins(
                  fontSize:   kIsWeb ? 13 : 12.sp,
                  fontWeight: FontWeight.w600,
                  color:      const Color(0xFF374151),
                ),
              ),
              SizedBox(height: kIsWeb ? 10 : 8.h),
              _StatusTimeline(
                steps:         _steps,
                statusIndex:   _statusIndex,
                currentStatus: status,
              ),

              SizedBox(height: kIsWeb ? 28 : 24.h),

              // ── Send another ──────────────────────────────────────────
              SizedBox(
                width:  double.infinity,
                height: kIsWeb ? 48 : 46.h,
                child: OutlinedButton.icon(
                  onPressed: _sendAnother,
                  icon: const Icon(
                      Icons.add_circle_outline_rounded, size: 18),
                  label: Text(
                    'Send Another Request',
                    style: GoogleFonts.poppins(
                      fontSize:   kIsWeb ? 14 : 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side:  const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(kIsWeb ? 12 : 10.sp)),
                  ),
                ),
              ),
              SizedBox(height: kIsWeb ? 16 : 12.h),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _RequestType {
  final String   key;
  final String   label;
  final IconData icon;
  final Color    color;
  final Color    bg;
  const _RequestType({
    required this.key, required this.label,
    required this.icon, required this.color, required this.bg,
  });
}

class _StatusStep {
  final String key;
  final String label;
  const _StatusStep({required this.key, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// _TypeCard  — individual request-type selection tile
// ─────────────────────────────────────────────────────────────────────────────

class _TypeCard extends StatelessWidget {
  final _RequestType type;
  final bool         isSelected;
  final VoidCallback onTap;
  const _TypeCard({
    required this.type, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:  EdgeInsets.all(kIsWeb ? 14 : 12.sp),
        decoration: BoxDecoration(
          color: isSelected ? type.bg : Colors.white,
          borderRadius: BorderRadius.circular(kIsWeb ? 14 : 12.sp),
          border: Border.all(
            color: isSelected ? type.color : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? type.color.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment:  MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width:  kIsWeb ? 40 : 36.sp,
              height: kIsWeb ? 40 : 36.sp,
              decoration: BoxDecoration(
                color: isSelected
                    ? type.color.withOpacity(0.18)
                    : type.bg,
                borderRadius: BorderRadius.circular(kIsWeb ? 10 : 8.sp),
              ),
              child: Icon(type.icon,
                  color: type.color, size: kIsWeb ? 20 : 18.sp),
            ),
            SizedBox(height: kIsWeb ? 8 : 6.h),
            Text(
              type.label,
              style: GoogleFonts.poppins(
                fontSize:   kIsWeb ? 13 : 12.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? type.color : const Color(0xFF111827),
              ),
            ),
            if (isSelected) ...[
              SizedBox(height: kIsWeb ? 3 : 2.h),
              Row(children: [
                Icon(Icons.check_circle_rounded,
                    size: kIsWeb ? 12 : 11.sp, color: type.color),
                SizedBox(width: kIsWeb ? 3 : 3.w),
                Text('Selected',
                    style: GoogleFonts.poppins(
                      fontSize:   kIsWeb ? 10 : 9.sp,
                      color:      type.color,
                      fontWeight: FontWeight.w500,
                    )),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusBadgeCard  — "Status / Waiter notified" box from the mockup
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadgeCard extends StatelessWidget {
  final String status;
  const _StatusBadgeCard({required this.status});

  static const Map<String, Map<String, dynamic>> _cfg = {
    'pending':      {'label': 'Waiter notified',   'color': Color(0xFFD97706), 'bg': Color(0xFFFEF9C3)},
    'acknowledged': {'label': 'Waiter assigned',   'color': Color(0xFF0EA5E9), 'bg': Color(0xFFE0F2FE)},
    'on_the_way':   {'label': 'Waiter on the way', 'color': Color(0xFF7C3AED), 'bg': Color(0xFFF3EEFF)},
    'completed':    {'label': 'Request completed', 'color': Color(0xFF059669), 'bg': Color(0xFFD1FAE5)},
  };

  @override
  Widget build(BuildContext context) {
    final c     = _cfg[status] ?? _cfg['pending']!;
    final Color color = c['color'] as Color;
    final Color bg    = c['bg']    as Color;
    final String lbl  = c['label'] as String;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: kIsWeb ? 16 : 14.sp,
        vertical:   kIsWeb ? 13 : 11.sp,
      ),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width:  kIsWeb ? 8 : 8.sp,
          height: kIsWeb ? 8 : 8.sp,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: kIsWeb ? 10 : 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status',
                style: GoogleFonts.poppins(
                  fontSize:   kIsWeb ? 11 : 10.sp,
                  fontWeight: FontWeight.w500,
                  color:      color,
                )),
            Text(lbl,
                style: GoogleFonts.poppins(
                  fontSize:   kIsWeb ? 14 : 13.sp,
                  fontWeight: FontWeight.w700,
                  color:      color,
                )),
          ],
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusTimeline  — animated vertical step tracker
// ─────────────────────────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final List<_StatusStep> steps;
  final Map<String, int>  statusIndex;
  final String            currentStatus;

  const _StatusTimeline({
    required this.steps,
    required this.statusIndex,
    required this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final int cur = statusIndex[currentStatus] ?? 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(kIsWeb ? 16 : 14.sp),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(kIsWeb ? 14 : 12.sp),
        border:       Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(steps.length, (i) {
          final bool done    = i < cur;
          final bool active  = i == cur;
          final bool pending = i > cur;
          final bool isLast  = i == steps.length - 1;

          final Color dotColor = done
              ? const Color(0xFF059669)
              : active
              ? const Color(0xFFD97706)
              : const Color(0xFFD1D5DB);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dot + connector column
              SizedBox(
                width: kIsWeb ? 28 : 26.sp,
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width:  kIsWeb ? 20 : 18.sp,
                    height: kIsWeb ? 20 : 18.sp,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      boxShadow: active
                          ? [BoxShadow(
                        color:       dotColor.withOpacity(0.35),
                        blurRadius:  6,
                        spreadRadius: 2,
                      )]
                          : [],
                    ),
                    child: done
                        ? Icon(Icons.check_rounded,
                        size:  kIsWeb ? 11 : 10.sp,
                        color: Colors.white)
                        : active
                        ? Container(
                      margin: EdgeInsets.all(kIsWeb ? 5 : 4.sp),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    )
                        : null,
                  ),
                  if (!isLast)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width:  2,
                      height: kIsWeb ? 32 : 28.h,
                      color:  done
                          ? const Color(0xFF059669)
                          : const Color(0xFFE5E7EB),
                    ),
                ]),
              ),
              SizedBox(width: kIsWeb ? 12 : 10.w),
              // Step label
              Padding(
                padding: EdgeInsets.only(
                  top:    kIsWeb ? 1 : 1.h,
                  bottom: isLast ? 0 : (kIsWeb ? 24 : 20.h),
                ),
                child: Text(
                  steps[i].label,
                  style: GoogleFonts.poppins(
                    fontSize:   kIsWeb ? 13 : 12.sp,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: pending
                        ? const Color(0xFF9CA3AF)
                        : done
                        ? const Color(0xFF059669)
                        : const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}