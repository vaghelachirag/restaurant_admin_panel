import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _C.orangeLight,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.table_restaurant_rounded,
                        color: _C.orange, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEdit ? 'Edit Table' : 'Add New Table',
                              style: _p(16, FontWeight.w700, _C.textDark)),
                          Text(
                              isEdit
                                  ? 'Update table details'
                                  : 'Fill in table information',
                              style: _p(11, FontWeight.w400, _C.textLight)),
                        ]),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close_rounded,
                          color: _C.textLight, size: 18),
                    ),
                  ),
                ]),
                Divider(color: _C.divider, height: 30),

                // Fields
                _FormField(
                  controller: idCtrl,
                  label: 'Table ID',
                  hint: 'e.g. T01, T02',
                  icon: Icons.tag_rounded,
                  readOnly: isEdit,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Table ID is required';
                    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(v.trim()))
                      return 'Only letters and numbers allowed';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _FormField(
                  controller: nmCtrl,
                  label: 'Table Name',
                  hint: 'e.g. Window Table, Garden Patio',
                  icon: Icons.drive_file_rename_outline_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 14),
                _FormField(
                  controller: capCtrl,
                  label: 'Capacity (seats)',
                  hint: 'e.g. 4',
                  icon: Icons.people_outline_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Capacity is required';
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 1) return 'Enter a valid number (min 1)';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F4),
                            borderRadius: BorderRadius.circular(12)),
                        child: Center(
                            child: Text('Cancel',
                                style: _p(13, FontWeight.w600, _C.textMid))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: saving
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
                                ? 'Table updated successfully'
                                : 'Table added successfully',
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                            color: saving
                                ? _C.orange.withOpacity(0.6)
                                : _C.orange,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: saving
                                ? []
                                : [
                              BoxShadow(
                                  color: _C.orange.withOpacity(0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ]),
                        child: Center(
                          child: saving
                              ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                              : Text(isEdit ? 'Save Changes' : 'Add Table',
                              style: _p(13, FontWeight.w600, Colors.white)),
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

  // ── Disable confirm dialog ────────────────────────────────────────────────
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
                  color: Colors.black.withOpacity(0.10), blurRadius: 40)
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration:
              const BoxDecoration(color: _C.redBg, shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded,
                  color: _C.red, size: 26),
            ),
            const SizedBox(height: 16),
            Text('Disable Table?',
                style: _p(17, FontWeight.w700, _C.textDark)),
            const SizedBox(height: 8),
            Text(
              '"${table.name}" will be hidden from the table list. This can be undone from Firestore.',
              textAlign: TextAlign.center,
              style: _p(12, FontWeight.w400, _C.textMid),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F4),
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(
                        child: Text('Cancel',
                            style: _p(13, FontWeight.w600, _C.textMid))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await _service.disableTable(
                          widget.restaurantId, table.tableId);
                      _snack('${table.name} disabled', _C.textMid,
                          Icons.info_outline_rounded);
                    } catch (e) {
                      _snack(e.toString(), _C.red, Icons.error_rounded);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                        color: _C.red,
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(
                        child: Text('Disable',
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
    final statusLabel = isAvailable ? 'Available' : 'Occupied';

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

            // ── Card body — Expanded so it fills the GridView cell
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: status pill + 3-dot menu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Status pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
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
                                style: _p(9, FontWeight.w600, statusColor)),
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
                                Text('Edit',
                                    style: _p(13, FontWeight.w400, _C.textDark)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                const Icon(Icons.delete_outline_rounded,
                                    size: 15, color: _C.red),
                                const SizedBox(width: 8),
                                Text('Disable',
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

                    // Spacer: pushes icon + text to the bottom half
                    const Spacer(),

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
                        style: _p(9, FontWeight.w500, _C.textLight)),
                    const SizedBox(height: 1),

                    // Table name
                    Text(t.name,
                        style: _p(13, FontWeight.w700, _C.textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),

                    // Capacity
                    Row(children: [
                      const Icon(Icons.people_outline_rounded,
                          size: 12, color: _C.textLight),
                      const SizedBox(width: 4),
                      Text('${t.capacity} seats',
                          style: _p(11, FontWeight.w400, _C.textMid)),
                    ]),

                    // Order ID badge (occupied only)
                    if (t.currentOrderId != null &&
                        t.currentOrderId!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: _C.orangeLight,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          '# ${t.currentOrderId}',
                          style: _p(9, FontWeight.w600, _C.orange),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
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
        if (_filter == 'Available') filtered = all.where((t) => t.isAvailable).toList();
        if (_filter == 'Occupied')  filtered = all.where((t) => !t.isAvailable).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Table Management',
                        style: _p(isMobile ? 20 : 22, FontWeight.w700, _C.textDark)),
                    const SizedBox(height: 3),
                    Text('Monitor and manage your restaurant tables',
                        style: _p(12, FontWeight.w400, _C.textLight)),
                  ]),
                  GestureDetector(
                    onTap: () => _showTableDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(
                          color: _C.orange,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: _C.orange.withOpacity(0.28),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add_rounded, color: Colors.white, size: 17),
                        const SizedBox(width: 6),
                        Text('Add Table',
                            style: _p(13, FontWeight.w600, Colors.white)),
                      ]),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Stat cards ────────────────────────────────────────────────
              if (snapshot.hasData)
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _statCard('Total Tables', all.length, _C.textMid,
                      const Color(0xFFF5F5F5), Icons.table_restaurant_rounded),
                  _statCard('Available', available, _C.green, _C.greenBg,
                      Icons.check_circle_outline_rounded),
                  _statCard('Occupied', occupied, _C.red, _C.redBg,
                      Icons.people_rounded),
                ]),

              const SizedBox(height: 20),

              // ── Filter chips ──────────────────────────────────────────────
              Wrap(
                spacing: 8,
                children: ['All', 'Available', 'Occupied']
                    .map(_filterChip)
                    .toList(),
              ),

              const SizedBox(height: 20),

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
                          _filter == 'All'
                              ? 'No tables yet'
                              : 'No $_filter tables',
                          style: _p(16, FontWeight.w600, _C.textDark),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _filter == 'All'
                              ? 'Tap "Add Table" to create your first table'
                              : 'All tables are ${_filter == 'Available' ? 'occupied' : 'available'}',
                          style: _p(12, FontWeight.w400, _C.textLight),
                        ),
                      ]),
                    ),
                  )
                else
                // ── Uniform grid — Spacer works fine inside a bounded cell ──
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 2 : 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isMobile ? 0.80 : 0.75,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _tableCard(filtered[i], isMobile),
                  ),

              const SizedBox(height: 28),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _p(11, FontWeight.w600, _C.textDark)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        validator: validator,
        style: _p(13, FontWeight.w500, _C.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _p(13, FontWeight.w400, _C.textLight),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(icon,
                size: 17, color: readOnly ? _C.textLight : _C.orange),
          ),
          prefixIconConstraints:
          const BoxConstraints(minWidth: 0, minHeight: 0),
          filled: true,
          fillColor: readOnly ? const Color(0xFFF8F8F8) : Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.orange, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.red, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}