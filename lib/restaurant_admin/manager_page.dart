import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class _C {
  static const bg          = Color(0xFFFFF3EE);
  static const card        = Color(0xFFFFFFFF);
  static const orange      = Color(0xFFE8622A);
  static const orangeLight = Color(0xFFFFF0E8);
  static const textDark    = Color(0xFF1A1A1A);
  static const textMid     = Color(0xFF666666);
  static const textLight   = Color(0xFF999999);
  static const cardBorder  = Color(0xFFEEEEEE);
  static const green       = Color(0xFF2ECC71);
  static const red         = Color(0xFFE74C3C);
}

TextStyle _p(double size, FontWeight weight, Color color) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

// ════════════════════════════════════════════════════════════════════════════
class ManagerPage extends StatefulWidget {
  final String restaurantId;
  const ManagerPage({super.key, required this.restaurantId});

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  void _snack(String msg, Color color, {IconData icon = Icons.info_rounded}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _showManagerDialog({
    String? docId,
    String initialName = '',
    String initialEmail = '',
    bool initialActive = true,
  }) async {
    final nameCtrl  = TextEditingController(text: initialName);
    final emailCtrl = TextEditingController(text: initialEmail);
    final passCtrl  = TextEditingController();
    bool  isActive  = initialActive;
    bool  isLoading = false;
    final formKey   = GlobalKey<FormState>();
    final isEdit    = docId != null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 16))
              ],
            ),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _C.orangeLight,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(
                      isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                      color: _C.orange, size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(isEdit ? "Edit Manager" : "Add Manager",
                        style: _p(17, FontWeight.w700, _C.textDark)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded,
                        color: _C.textLight, size: 22),
                  ),
                ]),
                const SizedBox(height: 24),

                // Name field
                _label("Manager Name"),
                const SizedBox(height: 6),
                _field(
                  controller: nameCtrl,
                  hint: "Enter full name",
                  icon: Icons.person_outline_rounded,
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? "Name is required" : null,
                ),
                const SizedBox(height: 16),

                // Email field
                _label("Email Address"),
                const SizedBox(height: 6),
                _field(
                  controller: emailCtrl,
                  hint: "Enter email address",
                  icon: Icons.email_outlined,
                  enabled: !isEdit, // can't change email after creation
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Email is required";
                    final emailReg = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailReg.hasMatch(v.trim())) return "Enter a valid email";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field (only shown on add; for edit it's optional)
                _label(isEdit ? "New Password (leave blank to keep)" : "Password"),
                const SizedBox(height: 6),
                _field(
                  controller: passCtrl,
                  hint: isEdit ? "Enter new password (optional)" : "Enter password",
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                  validator: (v) {
                    if (!isEdit && (v == null || v.trim().isEmpty)) {
                      return "Password is required";
                    }
                    if (v != null && v.isNotEmpty && v.length < 6) {
                      return "Password must be at least 6 characters";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Active toggle
                Row(children: [
                  Text("Status", style: _p(13, FontWeight.w500, _C.textMid)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setDlg(() => isActive = !isActive),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isActive ? _C.green : _C.textLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: isActive
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isActive ? "Active" : "Inactive",
                    style: _p(13, FontWeight.w600,
                        isActive ? _C.green : _C.textLight),
                  ),
                ]),
                const SizedBox(height: 26),

                // Action buttons
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(10)),
                        child: Center(
                          child: Text("Cancel",
                              style: _p(13, FontWeight.w600, _C.textMid)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: isLoading
                          ? null
                          : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDlg(() => isLoading = true);

                        try {
                          if (isEdit) {
                            await _updateManager(
                              docId: docId!,
                              name: nameCtrl.text.trim(),
                              isActive: isActive,
                              newPassword: passCtrl.text.trim().isEmpty
                                  ? null
                                  : passCtrl.text.trim(),
                            );
                          } else {
                            await _addManager(
                              name: nameCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              password: passCtrl.text.trim(),
                              isActive: isActive,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setDlg(() => isLoading = false);
                          if (mounted) {
                            _snack(e.toString(), _C.red,
                                icon: Icons.error_rounded);
                          }
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                            color: _C.orange,
                            borderRadius: BorderRadius.circular(10)),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                              : Text(
                            isEdit ? "Save Changes" : "Add Manager",
                            style:
                            _p(13, FontWeight.w600, Colors.white),
                          ),
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


  Future<void> _addManager({
    required String name,
    required String email,
    required String password,
    required bool isActive,
  }) async {
    // 1. Create Firebase Auth user
    final currentUser = FirebaseAuth.instance.currentUser;

    UserCredential? cred;
    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _authError(e);
    }

    // 2. Write Firestore document
    await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
      'name': name,
      'email': email,
      'role': 'manager',
      'restaurantId': widget.restaurantId,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });


    if (currentUser != null) {
    }

    if (mounted) {
      _snack("Manager added successfully!", _C.green,
          icon: Icons.check_circle_rounded);
    }
  }


  Future<void> _updateManager({
    required String docId,
    required String name,
    required bool isActive,
    String? newPassword,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).update({
      'name': name,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Updating password requires Auth — only works if the user is the
    // currently signed-in user. For admin-side password reset, trigger a
    // password-reset email instead.
    if (newPassword != null && newPassword.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid == docId) {
        await user.updatePassword(newPassword);
      } else {
        // Send password reset email as fallback
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .get();
        final email = doc.data()?['email'] as String?;
        if (email != null) {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          if (mounted) {
            _snack("Password reset email sent to manager.", _C.orange,
                icon: Icons.email_rounded);
          }
        }
      }
    }

    if (mounted) {
      _snack("Manager updated!", _C.green, icon: Icons.check_circle_rounded);
    }
  }

  // ── Firebase: Toggle Active ──────────────────────────────────────────────
  Future<void> _toggleActive(String docId, bool current) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(docId)
        .update({'isActive': !current});
    if (mounted) {
      _snack(
        !current ? "Manager activated." : "Manager deactivated.",
        !current ? _C.green : _C.textMid,
        icon: !current
            ? Icons.check_circle_rounded
            : Icons.block_rounded,
      );
    }
  }

  // ── Firebase: Delete Manager ─────────────────────────────────────────────
  Future<void> _deleteManager(String docId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08), blurRadius: 30)
              ]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration:
              const BoxDecoration(color: Color(0xFFFEEEEE), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded,
                  color: _C.red, size: 26),
            ),
            const SizedBox(height: 14),
            Text("Delete Manager?",
                style: _p(17, FontWeight.w700, _C.textDark)),
            const SizedBox(height: 8),
            Text(
              "Are you sure you want to delete \"$name\"? This action cannot be undone.",
              textAlign: TextAlign.center,
              style: _p(12, FontWeight.w400, _C.textMid),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(
                        child: Text("Cancel",
                            style: _p(13, FontWeight.w600, _C.textMid))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                        color: _C.red,
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(
                        child: Text("Delete",
                            style: _p(13, FontWeight.w600, Colors.white))),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );

    if (ok != true) return;
    await FirebaseFirestore.instance.collection('users').doc(docId).delete();
    if (mounted) {
      _snack("Manager deleted.", _C.red, icon: Icons.delete_rounded);
    }
  }

  // ── Auth error messages ──────────────────────────────────────────────────
  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      default:
        return e.message ?? 'An error occurred.';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;

    return Container(
      color: const Color(0xFFFAFAFA),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Top bar ───────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28, vertical: 18),
          decoration: const BoxDecoration(
            border:
            Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Managers",
                  style: _p(isMobile ? 20 : 22, FontWeight.w700, _C.textDark)),
              Text("Manage your restaurant managers",
                  style: _p(12, FontWeight.w400, _C.textLight)),
            ]),
            const Spacer(),
            GestureDetector(
              onTap: () => _showManagerDialog(),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 18, vertical: 11),
                decoration: BoxDecoration(
                    color: _C.orange,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.person_add_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  if (!isMobile)
                    Text("Add Manager",
                        style: _p(13, FontWeight.w600, Colors.white)),
                ]),
              ),
            ),
          ]),
        ),

        // ── Manager list ─────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('restaurantId', isEqualTo: widget.restaurantId)
                .where('role', isEqualTo: 'manager')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _C.orange));
              }

              if (snap.hasError) {
                return Center(
                    child: Text("Error loading managers",
                        style: _p(14, FontWeight.w500, _C.red)));
              }

              final docs = snap.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: _C.orangeLight,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.people_outline_rounded,
                            color: _C.orange, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text("No Managers Yet",
                          style: _p(16, FontWeight.w700, _C.textDark)),
                      const SizedBox(height: 6),
                      Text("Tap Add Manager to get started.",
                          style: _p(13, FontWeight.w400, _C.textLight)),
                    ],
                  ),
                );
              }

              return isMobile
                  ? _MobileList(
                docs: docs,
                onEdit: (doc) => _showManagerDialog(
                  docId: doc.id,
                  initialName: doc['name'] ?? '',
                  initialEmail: doc['email'] ?? '',
                  initialActive: doc['isActive'] ?? true,
                ),
                onToggle: (doc) =>
                    _toggleActive(doc.id, doc['isActive'] ?? true),
                onDelete: (doc) =>
                    _deleteManager(doc.id, doc['name'] ?? 'Manager'),
              )
                  : _DesktopTable(
                docs: docs,
                onEdit: (doc) => _showManagerDialog(
                  docId: doc.id,
                  initialName: doc['name'] ?? '',
                  initialEmail: doc['email'] ?? '',
                  initialActive: doc['isActive'] ?? true,
                ),
                onToggle: (doc) =>
                    _toggleActive(doc.id, doc['isActive'] ?? true),
                onDelete: (doc) =>
                    _deleteManager(doc.id, doc['name'] ?? 'Manager'),
              );
            },
          ),
        ),
      ]),
    );
  }
}

Widget _label(String text) =>
    Text(text, style: _p(12, FontWeight.w500, _C.textMid));

Widget _field({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  bool obscure = false,
  bool enabled = true,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    obscureText: obscure,
    enabled: enabled,
    keyboardType: keyboardType,
    validator: validator,
    style: _p(13, FontWeight.w400, _C.textDark),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: _p(13, FontWeight.w400, _C.textLight),
      prefixIcon: Icon(icon, color: _C.textLight, size: 18),
      filled: true,
      fillColor: enabled ? const Color(0xFFF9F9F9) : const Color(0xFFF2F2F2),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.cardBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.cardBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.orange, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.red)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.red, width: 1.5)),
    ),
  );
}

// ── Desktop Table View ───────────────────────────────────────────────────────
class _DesktopTable extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final void Function(QueryDocumentSnapshot) onEdit;
  final void Function(QueryDocumentSnapshot) onToggle;
  final void Function(QueryDocumentSnapshot) onDelete;

  const _DesktopTable(
      {required this.docs,
        required this.onEdit,
        required this.onToggle,
        required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.cardBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(children: [
          // Table header
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(color: _C.cardBorder, width: 1)),
            ),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Text("Manager",
                      style: _p(12, FontWeight.w600, _C.textMid))),
              Expanded(
                  flex: 3,
                  child: Text("Email",
                      style: _p(12, FontWeight.w600, _C.textMid))),
              Expanded(
                  flex: 2,
                  child: Text("Password",
                      style: _p(12, FontWeight.w600, _C.textMid))),
              Expanded(
                  flex: 2,
                  child: Text("Status",
                      style: _p(12, FontWeight.w600, _C.textMid))),
              SizedBox(
                  width: 100,
                  child: Text("Actions",
                      style: _p(12, FontWeight.w600, _C.textMid))),
            ]),
          ),

          // Rows
          Expanded(
            child: ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) =>
              const Divider(color: _C.cardBorder, height: 1),
              itemBuilder: (_, i) {
                final doc  = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                final name    = data['name'] ?? '—';
                final email   = data['email'] ?? '—';
                final active  = data['isActive'] ?? true;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(children: [
                    // Avatar + name
                    Expanded(
                      flex: 3,
                      child: Row(children: [
                        _Avatar(name: name),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(name,
                              style: _p(13, FontWeight.w600, _C.textDark),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ),
                    // Email
                    Expanded(
                      flex: 3,
                      child: Text(email,
                          style: _p(13, FontWeight.w400, _C.textMid),
                          overflow: TextOverflow.ellipsis),
                    ),
                    // Password (masked)
                    Expanded(
                      flex: 2,
                      child: Text("••••••••",
                          style:
                          _p(14, FontWeight.w700, _C.textLight)),
                    ),
                    // Status badge
                    Expanded(
                      flex: 2,
                      child: _StatusBadge(active: active),
                    ),
                    // Actions
                    SizedBox(
                      width: 100,
                      child: Row(children: [
                        // Toggle
                        _IconBtn(
                          icon: active
                              ? Icons.toggle_on_rounded
                              : Icons.toggle_off_rounded,
                          color: active ? _C.green : _C.textLight,
                          tooltip:
                          active ? "Deactivate" : "Activate",
                          onTap: () => onToggle(doc),
                        ),
                        const SizedBox(width: 4),
                        // Edit
                        _IconBtn(
                          icon: Icons.edit_outlined,
                          color: _C.orange,
                          tooltip: "Edit",
                          onTap: () => onEdit(doc),
                        ),
                        const SizedBox(width: 4),
                        // Delete
                        _IconBtn(
                          icon: Icons.delete_outline_rounded,
                          color: _C.red,
                          tooltip: "Delete",
                          onTap: () => onDelete(doc),
                        ),
                      ]),
                    ),
                  ]),
                );
              },
            ),
          ),

          // Footer count
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(
                  top: BorderSide(color: _C.cardBorder, width: 1)),
            ),
            child: Row(children: [
              Text("${docs.length} manager${docs.length == 1 ? '' : 's'} total",
                  style: _p(12, FontWeight.w400, _C.textLight)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Mobile Card List ─────────────────────────────────────────────────────────
class _MobileList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final void Function(QueryDocumentSnapshot) onEdit;
  final void Function(QueryDocumentSnapshot) onToggle;
  final void Function(QueryDocumentSnapshot) onDelete;

  const _MobileList(
      {required this.docs,
        required this.onEdit,
        required this.onToggle,
        required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc    = docs[i];
        final data   = doc.data() as Map<String, dynamic>;
        final name   = data['name'] ?? '—';
        final email  = data['email'] ?? '—';
        final active = data['isActive'] ?? true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.cardBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(children: [
            Row(children: [
              _Avatar(name: name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style:
                          _p(14, FontWeight.w600, _C.textDark),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(email,
                          style:
                          _p(12, FontWeight.w400, _C.textMid),
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              _StatusBadge(active: active),
            ]),
            const SizedBox(height: 14),
            const Divider(color: _C.cardBorder, height: 1),
            const SizedBox(height: 10),
            Row(children: [
              Text("Password: ••••••••",
                  style: _p(12, FontWeight.w400, _C.textLight)),
              const Spacer(),
              _IconBtn(
                icon: active
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                color: active ? _C.green : _C.textLight,
                tooltip: active ? "Deactivate" : "Activate",
                onTap: () => onToggle(doc),
              ),
              const SizedBox(width: 4),
              _IconBtn(
                icon: Icons.edit_outlined,
                color: _C.orange,
                tooltip: "Edit",
                onTap: () => onEdit(doc),
              ),
              const SizedBox(width: 4),
              _IconBtn(
                icon: Icons.delete_outline_rounded,
                color: _C.red,
                tooltip: "Delete",
                onTap: () => onDelete(doc),
              ),
            ]),
          ]),
        );
      },
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
          color: _C.orangeLight, borderRadius: BorderRadius.circular(10)),
      child:
      Center(child: Text(initial, style: _p(16, FontWeight.w700, _C.orange))),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? _C.green.withOpacity(0.12)
            : _C.textLight.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? "Active" : "Inactive",
        style: _p(11, FontWeight.w600, active ? _C.green : _C.textLight),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon,
        required this.color,
        required this.tooltip,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
