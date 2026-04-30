import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/localization_service.dart';

class _C {
  static const bg          = Color(0xFFFFF3EE);
  static const card        = Color(0xFFFFFFFF);
  static const orange      = Color(0xFFE8622A);
  static const orangeLight = Color(0xFFFFF0E8);
  static const textDark    = Color(0xFF1A1A1A);
  static const textMid     = Color(0xFF666666);
  static const textLight   = Color(0xFF999999);
  static const cardBorder  = Color(0xFFEEEEEE);
  static const divider     = Color(0xFFF0F0F0);
  static const red         = Color(0xFFE74C3C);
  static const redBg       = Color(0xFFFEEEEE);
}

TextStyle _p(double size, FontWeight weight, Color color) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

// ─── Model ────────────────────────────────────────────────────────────────────
class TableModel {
  final String tableId;
  final String restaurantId;
  final String name;
  final int capacity;
  final bool isActive;

  const TableModel({
    required this.tableId,
    required this.restaurantId,
    required this.name,
    required this.capacity,
    required this.isActive,
  });

  factory TableModel.fromDoc(DocumentSnapshot doc, {String restaurantId = ''}) {
    final d = doc.data() as Map<String, dynamic>;
    return TableModel(
      tableId: doc.id,
      restaurantId: d['restaurantId'] as String? ?? restaurantId,
      name: d['name'] as String? ?? '',
      capacity: (d['capacity'] as num?)?.toInt() ?? 0,
      isActive: d['is_active'] as bool? ?? true,
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────
class TableService {
  CollectionReference _ref(String restaurantId) => FirebaseFirestore.instance
      .collection('restaurants')
      .doc(restaurantId)
      .collection('tables');

  Stream<List<TableModel>> watchTables(String restaurantId) {
    return FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .collection('tables')
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map((s) {
      final tables = s.docs
          .map((doc) => TableModel.fromDoc(doc, restaurantId: restaurantId))
          .toList();
      tables.sort((a, b) => a.name.compareTo(b.name));
      return tables;
    });
  }

  Future<void> addTable({
    required String restaurantId,
    required String name,
    required int capacity,
  }) async {
    // Force-refresh token so Firestore receives request.auth on the write.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await user.getIdToken(true);

    // Same pattern as categories:
    // .collection('restaurants').doc(restaurantId).collection('tables').add(...)
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .collection('tables')
        .add({
      'name': name,
      'restaurantId': restaurantId,
      'capacity': capacity,
      'is_active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTable({
    required String restaurantId,
    required String tableId,
    required String name,
    required int capacity,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await user.getIdToken(true);

    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .collection('tables')
        .doc(tableId)
        .update({
      'name': name,
      'capacity': capacity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> disableTable(String restaurantId, String tableId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await user.getIdToken(true);

    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .collection('tables')
        .doc(tableId)
        .update({
      'is_active': false,
      'updatedAt': FieldValue.serverTimestamp(),
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
                          const SizedBox(height: 20),
                          Text(
                              isEdit
                                  ? AppLocalizations.of(ctx).editTable
                                  : AppLocalizations.of(ctx).addNewTable,
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
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
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
                // Table ID field shown only when editing (doc.id is auto-generated on add)
                if (isEdit) ...[
                  _FormField(
                    controller: idCtrl,
                    label: AppLocalizations.of(ctx).tableId,
                    hint: AppLocalizations.of(ctx).tableIdHint,
                    icon: Icons.tag_rounded,
                    readOnly: true,
                    validator: null,
                  ),
                  const SizedBox(height: 14),
                ],
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
                    if (v == null || v.trim().isEmpty) {
                      return AppLocalizations.of(ctx).capacityRequired;
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 1) {
                      return AppLocalizations.of(ctx).validCapacity;
                    }
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
                              name: nmCtrl.text.trim(),
                              capacity: int.parse(capCtrl.text.trim()),
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _snack(
                            isEdit
                                ? AppLocalizations.of(ctx).tableUpdatedSuccess
                                : AppLocalizations.of(ctx).tableAddedSuccess,
                            _C.orange,
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
                        isEdit
                            ? AppLocalizations.of(ctx).commonSave
                            : AppLocalizations.of(ctx).addTable,
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
                AppLocalizations.of(ctx)
                    .disableTableDescription
                    .replaceAll('{tableName}', table.name),
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
                            AppLocalizations.of(ctx)
                                .tableDisabled
                                .replaceAll('{tableName}', table.name),
                            _C.textMid,
                            Icons.info_outline_rounded,
                          );
                        } catch (e) {
                          _snack(e.toString(), _C.red, Icons.error_rounded);
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
                        style: const TextStyle(
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

  Widget _tableCard(TableModel t, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top section: icon + actions ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _C.orangeLight,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.table_restaurant_rounded,
                    color: _C.orange,
                    size: 26,
                  ),
                ),
                const Spacer(),
                // Edit button
                _CardActionBtn(
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF888888),
                  bgColor: const Color(0xFFF5F5F5),
                  onTap: () => _showTableDialog(existing: t),
                ),
                const SizedBox(width: 6),
                // Delete button
                _CardActionBtn(
                  icon: Icons.delete_outline_rounded,
                  color: _C.red,
                  bgColor: _C.redBg,
                  onTap: () => _confirmDelete(t),
                ),
              ],
            ),
          ),

          // ── Bottom section: name + capacity ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  style: _p(15, FontWeight.w700, _C.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.people_outline_rounded,
                        size: 12, color: Color(0xFF3B5BDB)),
                    const SizedBox(width: 4),
                    Text(
                      '${t.capacity} ${AppLocalizations.of(context).seats}',
                      style: _p(11, FontWeight.w600, const Color(0xFF3B5BDB)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    final sidePad  = isMobile ? 14.0 : 24.0;

    return StreamBuilder<List<TableModel>>(
      stream: _service.watchTables(widget.restaurantId),
      builder: (context, snapshot) {
        final tables = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Compact header bar ─────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(sidePad, 10, sidePad, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).tablesTitle,
                          style: _p(18, FontWeight.w700, const Color(0xFF0E1A2F)),
                        ),
                        const SizedBox(height: 2),
                        Row(children: [
                          Container(
                            width: 7, height: 7,
                            decoration: const BoxDecoration(
                                color: _C.orange, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${tables.length} ${AppLocalizations.of(context).totalTables}',
                            style: _p(12, FontWeight.w400, _C.textMid),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  // ── Add Table button ───────────────────────────────────
                  GestureDetector(
                    onTap: () => _showTableDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070B2D),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF070B2D).withOpacity(0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 7),
                        Text(
                          AppLocalizations.of(context).addTable,
                          style: _p(13, FontWeight.w600, Colors.white),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ───────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(sidePad, 16, sidePad, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Loading skeleton
                    if (snapshot.connectionState == ConnectionState.waiting)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cols    = isMobile ? 2 : 3;
                          const spacing = 12.0;
                          final cardW   = (constraints.maxWidth - spacing * (cols - 1)) / cols;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: List.generate(
                              6,
                                  (_) => SizedBox(
                                  width: cardW,
                                  child: const _TableCardSkeleton()),
                            ),
                          );
                        },
                      )

                    // Error
                    else if (snapshot.hasError)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Text('Error: ${snapshot.error}',
                              style: _p(13, FontWeight.w400, _C.red)),
                        ),
                      )

                    // Empty state
                    else if (tables.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: const BoxDecoration(
                                    color: _C.orangeLight,
                                    shape: BoxShape.circle),
                                child: const Icon(
                                    Icons.table_restaurant_rounded,
                                    color: _C.orange,
                                    size: 38),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                AppLocalizations.of(context).noTablesYet,
                                style: _p(16, FontWeight.w600, _C.textDark),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                AppLocalizations.of(context).tapAddTable,
                                style: _p(12, FontWeight.w400, _C.textLight),
                              ),
                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: () => _showTableDialog(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _C.orange,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.add_rounded,
                                            size: 16, color: Colors.white),
                                        const SizedBox(width: 7),
                                        Text(
                                          AppLocalizations.of(context).addTable,
                                          style: _p(13, FontWeight.w600, Colors.white),
                                        ),
                                      ]),
                                ),
                              ),
                            ]),
                          ),
                        )

                      // Table grid
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cols    = isMobile ? 2 : 3;
                            const spacing = 12.0;
                            final cardW   = (constraints.maxWidth -
                                spacing * (cols - 1)) /
                                cols;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: tables
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
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Card action button ───────────────────────────────────────────────────────
class _CardActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _CardActionBtn({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─── Skeleton widgets ─────────────────────────────────────────────────────────

class _SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const _SkeletonBox({
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

class _TableCardSkeleton extends StatelessWidget {
  const _TableCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: icon box + edit/delete buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SkeletonBox(width: 72, height: 72, radius: 14),
              const Spacer(),
              const _SkeletonBox(width: 20, height: 20, radius: 4),
              const SizedBox(width: 12),
              const _SkeletonBox(width: 20, height: 20, radius: 4),
            ],
          ),
          const SizedBox(height: 14),
          // Table name
          const _SkeletonBox(width: 100, height: 15, radius: 4),
          const SizedBox(height: 8),
          // Capacity row
          const _SkeletonBox(width: 70, height: 12, radius: 4),
        ],
      ),
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
        style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.4)),
          prefixIcon: Icon(icon,
              size: 20,
              color: readOnly
                  ? colorScheme.onSurface.withOpacity(0.4)
                  : colorScheme.onSurface.withOpacity(0.5)),
          filled: true,
          fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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