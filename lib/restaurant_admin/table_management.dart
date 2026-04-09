import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/localization_service.dart';

class _C {
  static const bg          = Color(0xFFFFF3EE);
  static const card        = Color(0xFFFFFFFF);
  static const orange      = Color(0xFFE8622A);
  static const orangeLight = Color(0xFFFFF0E8);
  static const orangeMid   = Color(0xFFFFD5C0);
  static const textDark    = Color(0xFF1A1A1A);
  static const textMid     = Color(0xFF666666);
  static const textLight   = Color(0xFF999999);
  static const cardBorder  = Color(0xFFEEEEEE);
  static const divider     = Color(0xFFF0F0F0);
  static const green       = Color(0xFF27AE60);
  static const greenBg     = Color(0xFFE8F8EF);
  static const greenLight  = Color(0xFFB7E4CA);
  static const red         = Color(0xFFE74C3C);
  static const redBg       = Color(0xFFFEEEEE);
}

TextStyle _p(double size, FontWeight weight, Color color) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

// ─── Model ────────────────────────────────────────────────────────────────────
class TableModel {
  final String tableId;
  final String name;
  final int capacity;
  final String status;
  final String? currentOrderId;
  final bool isActive;

  const TableModel({
    required this.tableId,
    required this.name,
    required this.capacity,
    required this.status,
    this.currentOrderId,
    required this.isActive,
  });

  factory TableModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TableModel(
      tableId: doc.id,
      name: d['name'] as String? ?? '',
      capacity: (d['capacity'] as num?)?.toInt() ?? 0,
      status: d['status'] as String? ?? 'available',
      currentOrderId: d['current_order_id'] as String?,
      isActive: d['is_active'] as bool? ?? true,
    );
  }

  bool get isAvailable => status == 'available';
}

// ─── Service ──────────────────────────────────────────────────────────────────
class TableService {
  CollectionReference _ref(String restaurantId) => FirebaseFirestore.instance
      .collection('restaurants')
      .doc(restaurantId)
      .collection('tables');

  Stream<List<TableModel>> watchTables(String restaurantId) =>
      _ref(restaurantId)
          .where('is_active', isEqualTo: true)
          .orderBy('table_id')
          .snapshots()
          .map((s) => s.docs.map(TableModel.fromDoc).toList());

  Future<void> addTable({
    required String restaurantId,
    required String tableId,
    required String name,
    required int capacity,
  }) async {
    final ref = _ref(restaurantId).doc(tableId);
    if ((await ref.get()).exists) {
      throw Exception('Table "$tableId" already exists. Choose a different ID.');
    }
    await ref.set({
      'table_id': tableId,
      'name': name,
      'capacity': capacity,
      'status': 'available',
      'current_order_id': null,
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTable({
    required String restaurantId,
    required String tableId,
    required String name,
    required int capacity,
  }) async {
    await _ref(restaurantId).doc(tableId).update({
      'name': name,
      'capacity': capacity,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> disableTable(String restaurantId, String tableId) async {
    await _ref(restaurantId).doc(tableId).update({
      'is_active': false,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTableStatus({
    required String restaurantId,
    required String tableId,
    required String status,
    String? currentOrderId,
  }) async {
    await _ref(restaurantId).doc(tableId).update({
      'status': status,
      'current_order_id': currentOrderId ?? '',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> freeTable({
    required String restaurantId,
    required String tableId,
  }) async {
    await _ref(restaurantId).doc(tableId).update({
      'status': 'available',
      'current_order_id': '',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}

// ─── Main Page ────────────────────────────────────────────────────────────────
class TableManagementPage extends StatefulWidget {
  final String restaurantId;
  const TableManagementPage({super.key, required this.restaurantId});

  @override
  State<TableManagementPage> createState() => _TableManagementPageState();
}

class _TableManagementPageState extends State<TableManagementPage> {
  final _service = TableService();
  String _filter = 'All';

  // ── Snack ─────────────────────────────────────────────────────────────────
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

  // ── Add / Edit dialog ─────────────────────────────────────────────────────
  void _showTableDialog({TableModel? existing}) {
    final isEdit  = existing != null;
    final idCtrl  = TextEditingController(text: isEdit ? existing.tableId : '');
    final nmCtrl  = TextEditingController(text: isEdit ? existing.name : '');
    final capCtrl = TextEditingController(
        text: isEdit ? existing.capacity.toString() : '');
    final formKey = GlobalKey<FormState>();
    bool saving   = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 50,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Header
                Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: const Color(0xFF070B2D),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(
                      isEdit ? Icons.edit_rounded : Icons.table_restaurant_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEdit ? AppLocalizations.of(ctx).editTable : AppLocalizations.of(ctx).addNewTable,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(ctx).colorScheme.onSurface,
                              )),
                          Text(
                              isEdit
                                  ? AppLocalizations.of(ctx).editTableDetails
                                  : AppLocalizations.of(ctx).fillTableInfo,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6),
                              )),
                        ]),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6),
                      size: 22,
                    ),
                  ),
                ]),
                Divider(color: _C.divider, height: 30),

                // Fields
                _FormField(
                  controller: idCtrl,
                  label: AppLocalizations.of(ctx).tableId,
                  hint: AppLocalizations.of(ctx).tableIdHint,
                  icon: Icons.tag_rounded,
                  readOnly: isEdit,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return AppLocalizations.of(ctx).tableIdRequired;
                    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(v.trim()))
                      return AppLocalizations.of(ctx).alphanumericOnly;
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _FormField(
                  controller: nmCtrl,
                  label: AppLocalizations.of(ctx).tableName,
                  hint: AppLocalizations.of(ctx).tableNameHint,
                  icon: Icons.drive_file_rename_outline_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? AppLocalizations.of(ctx).tableNameRequired
                      : null,
                ),
                const SizedBox(height: 14),
                _FormField(
                  controller: capCtrl,
                  label: AppLocalizations.of(ctx).capacity,
                  hint: AppLocalizations.of(ctx).capacityHint,
                  icon: Icons.people_outline_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return AppLocalizations.of(ctx).capacityRequired;
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 1) return AppLocalizations.of(ctx).validCapacity;
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: Theme.of(ctx).colorScheme.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(ctx).commonCancel,
                        style: TextStyle(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                        if (!formKey.currentState!.validate()) return;
                        setS(() => saving = true);
                        try {
                          if (isEdit) {
                            await _service.updateTable(
                              restaurantId: widget.restaurantId,
                              tableId: existing.tableId,
                              name: nmCtrl.text.trim(),
                              capacity: int.parse(capCtrl.text.trim()),
                            );
                          } else {
                            await _service.addTable(
                              restaurantId: widget.restaurantId,
                              tableId:
                              idCtrl.text.trim().toUpperCase(),
                              name: nmCtrl.text.trim(),
                              capacity: int.parse(capCtrl.text.trim()),
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _snack(
                            isEdit
                                ? AppLocalizations.of(ctx).tableUpdatedSuccess
                                : AppLocalizations.of(ctx).tableAddedSuccess,
                            _C.green,
                            Icons.check_circle_rounded,
                          );
                        } catch (e) {
                          setS(() => saving = false);
                          _snack(
                              e.toString().replaceFirst('Exception: ', ''),
                              _C.red,
                              Icons.error_rounded);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: saving
                            ? const Color(0xFF070B2D).withOpacity(0.6)
                            : const Color(0xFF070B2D),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : Text(
                        isEdit ? AppLocalizations.of(ctx).commonSave : AppLocalizations.of(ctx).addTable,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(TableModel table) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: _C.redBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: _C.red,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(ctx).disableTableQuestion,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(ctx).disableTableDescription.replaceAll('{tableName}', table.name),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(
                          color: Theme.of(ctx).colorScheme.outline,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(ctx).commonCancel,
                        style: TextStyle(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await _service.disableTable(
                            widget.restaurantId,
                            table.tableId,
                          );
                          _snack(
                            AppLocalizations.of(ctx).tableDisabled.replaceAll('{tableName}', table.name),
                            _C.textMid,
                            Icons.info_outline_rounded,
                          );
                        } catch (e) {
                          _snack(
                            e.toString(),
                            _C.red,
                            Icons.error_rounded,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(ctx).disableTable,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
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

  // ── Filter chip ───────────────────────────────────────────────────────────
  Widget _filterChip(String label) {
    final active = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _C.orange : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border:
          Border.all(color: active ? _C.orange : _C.cardBorder, width: 1.2),
          boxShadow: active
              ? [
            BoxShadow(
                color: _C.orange.withOpacity(0.22),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]
              : [],
        ),
        child: Text(
          label,
          style: _p(12, active ? FontWeight.w600 : FontWeight.w500,
              active ? Colors.white : _C.textMid),
        ),
      ),
    );
  }

  // ── Stat card ─────────────────────────────────────────────────────────────
  Widget _statCard(
      String label, int count, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count', style: _p(16, FontWeight.w700, color)),
              Text(label,
                  style: _p(10, FontWeight.w500, color.withOpacity(0.75))),
            ]),
      ]),
    );
  }

  // ── Table card ────────────────────────────────────────────────────────────
  // GridView gives every card the same bounding box (childAspectRatio).
  // Inside we use a Column with Spacer so content distributes naturally —
  // no overflow, no unbounded-height error.
  Widget _tableCard(TableModel t, bool isMobile) {
    final isAvailable = t.isAvailable;
    final statusColor = isAvailable ? _C.green : _C.red;
    final statusBg    = isAvailable ? _C.greenBg : _C.redBg;
    final statusLabel = isAvailable ? AppLocalizations.of(context).tablesAvailable : AppLocalizations.of(context).tablesOccupied;

    // Capacity drives accent bar thickness and icon size
    final tier     = t.capacity <= 2 ? 0 : t.capacity <= 4 ? 1 : t.capacity <= 7 ? 2 : 3;
    final iconSize = 18.0 + tier * 3.0;   // 18 / 21 / 24 / 27
    final accentH  =  3.0 + tier * 0.5;  //  3 / 3.5 / 4 / 4.5

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Data-driven accent bar (capacity → thickness + colour)
            Container(
              height: accentH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isAvailable
                      ? [_C.green, _C.greenLight]
                      : [_C.red, _C.red.withOpacity(0.55)],
                ),
              ),
            ),

            // ── Card body — intrinsic height, no Expanded/Spacer needed
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: status pill + 3-dot menu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(statusLabel,
                              style: _p(11, FontWeight.w600, statusColor)),
                        ]),
                      ),

                      // 3-dot menu
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _showTableDialog(existing: t);
                          if (v == 'delete') _confirmDelete(t);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              const Icon(Icons.edit_outlined,
                                  size: 15, color: _C.textMid),
                              const SizedBox(width: 8),
                              Text(AppLocalizations.of(context).edit,
                                  style: _p(13, FontWeight.w400, _C.textDark)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              const Icon(Icons.delete_outline_rounded,
                                  size: 15, color: _C.red),
                              const SizedBox(width: 8),
                              Text(AppLocalizations.of(context).disableTable,
                                  style: _p(13, FontWeight.w400, _C.red)),
                            ]),
                          ),
                        ],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        padding: EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(7)),
                          child: const Icon(Icons.more_horiz_rounded,
                              size: 15, color: _C.textMid),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Table icon (size = capacity tier)
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: _C.orangeLight,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.table_restaurant_rounded,
                        color: _C.orange, size: iconSize),
                  ),
                  const SizedBox(height: 10),

                  // Table ID
                  Text(t.tableId,
                      style: _p(11, FontWeight.w500, _C.textLight)),
                  const SizedBox(height: 2),

                  // Table name
                  Text(t.name,
                      style: _p(15, FontWeight.w700, _C.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),

                  // Capacity
                  Row(children: [
                    const Icon(Icons.people_outline_rounded,
                        size: 13, color: _C.textLight),
                    const SizedBox(width: 4),
                    Text('${t.capacity} ${AppLocalizations.of(context).seats}',
                        style: _p(13, FontWeight.w400, _C.textMid)),
                  ]),

                  // Order ID badge (occupied only)
                  if (t.currentOrderId != null &&
                      t.currentOrderId!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: _C.orangeLight,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        '# ${t.currentOrderId}',
                        style: _p(11, FontWeight.w600, _C.orange),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;

    return StreamBuilder<List<TableModel>>(
      stream: _service.watchTables(widget.restaurantId),
      builder: (context, snapshot) {
        final all       = snapshot.data ?? [];
        final available = all.where((t) => t.isAvailable).length;
        final occupied  = all.where((t) => !t.isAvailable).length;

        List<TableModel> filtered = all;
        if (_filter == AppLocalizations.of(context).tablesAvailable) filtered = all.where((t) => t.isAvailable).toList();
        if (_filter == AppLocalizations.of(context).tablesOccupied)  filtered = all.where((t) => !t.isAvailable).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.only(left: isMobile ? 16 : 8, right: isMobile ? 16 : 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(AppLocalizations.of(context).tablesTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w200,
                          color: const Color(0xFF0E1A2F),
                        )),
                    const SizedBox(height: 3),
                    Text(AppLocalizations.of(context).tablesSubtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF808896),
                        )),
                  ]),
                  ElevatedButton(
                    onPressed: () => _showTableDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF070B2D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context).addTable,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Stat cards ────────────────────────────────────────────────
              if (snapshot.hasData)
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _statCard(AppLocalizations.of(context).totalTables, all.length, _C.textMid,
                      const Color(0xFFF5F5F5), Icons.table_restaurant_rounded),
                  _statCard(AppLocalizations.of(context).tablesAvailable, available, _C.green, _C.greenBg,
                      Icons.check_circle_outline_rounded),
                  _statCard(AppLocalizations.of(context).tablesOccupied, occupied, _C.red, _C.redBg,
                      Icons.people_rounded),
                ]),

              const SizedBox(height: 12),

              // ── Filter chips ──────────────────────────────────────────────
              Wrap(
                spacing: 8,
                children: [AppLocalizations.of(context).tablesAll, AppLocalizations.of(context).tablesAvailable, AppLocalizations.of(context).tablesOccupied]
                    .map(_filterChip)
                    .toList(),
              ),

              const SizedBox(height: 12),

              // ── Content ───────────────────────────────────────────────────
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: CircularProgressIndicator(color: _C.orange),
                  ),
                )
              else if (snapshot.hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Text('Error: ${snapshot.error}',
                        style: _p(13, FontWeight.w400, _C.red)),
                  ),
                )
              else if (filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: const BoxDecoration(
                              color: _C.orangeLight, shape: BoxShape.circle),
                          child: const Icon(Icons.table_restaurant_rounded,
                              color: _C.orange, size: 38),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _filter == AppLocalizations.of(context).tablesAll
                              ? AppLocalizations.of(context).noTablesYet
                              : _filter == AppLocalizations.of(context).tablesAvailable ? AppLocalizations.of(context).noAvailableTables : AppLocalizations.of(context).noOccupiedTables,
                          style: _p(16, FontWeight.w600, _C.textDark),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _filter == AppLocalizations.of(context).tablesAll
                              ? AppLocalizations.of(context).tapAddTable
                              : _filter == AppLocalizations.of(context).tablesAvailable ? AppLocalizations.of(context).allOccupied : AppLocalizations.of(context).allAvailable,
                          style: _p(12, FontWeight.w400, _C.textLight),
                        ),
                      ]),
                    ),
                  )
                else
                // ── Wrap grid — cards size to their own content ──
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols    = isMobile ? 2 : 4;
                      final spacing = 12.0;
                      final cardW   = (constraints.maxWidth - spacing * (cols - 1)) / cols;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: filtered
                            .map((t) => SizedBox(
                          width: cardW,
                          child: _tableCard(t, isMobile),
                        ))
                            .toList(),
                      );
                    },
                  ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

// ─── Reusable form field ──────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool readOnly;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          )),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500,
            color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.4)),
          prefixIcon: Icon(icon,
              size: 20,
              color: readOnly
                  ? colorScheme.onSurface.withOpacity(0.4)
                  : colorScheme.onSurface.withOpacity(0.5)),
          filled: true,
          fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            BorderSide(color: colorScheme.outline.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            BorderSide(color: colorScheme.outline.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.error, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}