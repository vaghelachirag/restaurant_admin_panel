import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RestaurantListPage extends StatefulWidget {
  const RestaurantListPage({super.key});

  @override
  State<RestaurantListPage> createState() => _RestaurantListPageState();
}

class _RestaurantListPageState extends State<RestaurantListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all'; // 'all' | 'active'

  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFFF4F4F5);
  static const Color _surface = Colors.white;
  static const Color _border = Color(0xFFE4E4E7);
  static const Color _textPrimary = Color(0xFF09090B);
  static const Color _textSecondary = Color(0xFF71717A);
  static const Color _textTertiary = Color(0xFFA1A1AA);
  static const Color _accent = Color(0xFF09090B);
  static const Color _successBg = Color(0xFFF0FDF4);
  static const Color _successText = Color(0xFF16A34A);
  static const Color _dangerBg = Color(0xFFFEF2F2);
  static const Color _dangerText = Color(0xFFDC2626);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        icon: Icons.logout_rounded,
        iconColor: _textSecondary,
        iconBg: const Color(0xFFF4F4F5),
        title: 'Sign out?',
        message: 'You will be returned to the login screen.',
        confirmLabel: 'Sign out',
        confirmColor: _accent,
        confirmTextColor: Colors.white,
      ),
    );
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  // ── Add Restaurant ────────────────────────────────────────────────────────
  void _openAddRestaurant() {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddRestaurantSheet(
        nameCtrl: nameCtrl,
        addrCtrl: addrCtrl,
        phoneCtrl: phoneCtrl,
        emailCtrl: emailCtrl,
        passCtrl: passCtrl,
        onSave: () async {
          if (nameCtrl.text.trim().isEmpty ||
              addrCtrl.text.trim().isEmpty ||
              phoneCtrl.text.trim().isEmpty ||
              emailCtrl.text.trim().isEmpty ||
              passCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please fill in all fields.')),
            );
            return;
          }

          try {
            final ref = await FirebaseFirestore.instance
                .collection('restaurants')
                .add({
              'name': nameCtrl.text.trim(),
              'address': addrCtrl.text.trim(),
              'phone': phoneCtrl.text.trim(),
              'logo': '',
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
              'theme': {
                'backgroundColor': '#FAF5EF',
                'textColor': '#000000',
                'cardColor': '#FFFFFF',
                'categoryBackgroundColor': '#6D4C41',
                'categoryTextColor': '#FFFFFF',
                'cardInfoColor': '#757575',
              },
            });

            final cred = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
              email: emailCtrl.text.trim(),
              password: passCtrl.text.trim(),
            );

            await FirebaseFirestore.instance
                .collection('users')
                .doc(cred.user!.uid)
                .set({
              'email': emailCtrl.text.trim(),
              'role': 'admin',
              'restaurantId': ref.id,
              'createdAt': FieldValue.serverTimestamp(),
            });

            if (mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Restaurant & admin created successfully.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
      ),
    );
  }

  // ── Delete Restaurant ─────────────────────────────────────────────────────
  Future<void> _deleteRestaurant(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: _dangerText,
        iconBg: _dangerBg,
        title: 'Delete restaurant?',
        message: 'Remove "$name"? This action cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: _dangerText,
        confirmTextColor: Colors.white,
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(id)
          .delete();
    }
  }

  // ── Edit Restaurant ───────────────────────────────────────────────────────
  void _openEditRestaurant({
    required String docId,
    required String currentName,
    required String currentAddress,
    required String currentPhone,
    required bool currentIsActive,
  }) {
    final nameCtrl = TextEditingController(text: currentName);
    final addrCtrl = TextEditingController(text: currentAddress);
    final phoneCtrl = TextEditingController(text: currentPhone);
    bool isActive = currentIsActive;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF4F4F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Edit restaurant',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF09090B))),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border:
                            Border.all(color: _border, width: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Color(0xFF71717A)),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                    height: 0.5,
                    color: _border,
                    margin: const EdgeInsets.only(top: 12)),
                Flexible(
                  child: SingleChildScrollView(
                    padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section label
                        const Text('RESTAURANT INFO',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.7,
                                color: Color(0xFFA1A1AA))),
                        const SizedBox(height: 10),
                        _editField('Name', nameCtrl,
                            hint: 'Restaurant name'),
                        _editField('Address', addrCtrl,
                            hint: 'Street, City'),
                        _editField('Phone', phoneCtrl,
                            hint: '+91 98765 43210',
                            keyboardType: TextInputType.phone),
                        const SizedBox(height: 8),
                        // Active toggle
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: _border, width: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text('Active status',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF09090B))),
                                    SizedBox(height: 2),
                                    Text(
                                        'Toggle restaurant visibility',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF71717A))),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isActive,
                                activeColor: const Color(0xFF09090B),
                                onChanged: (val) =>
                                    setSheetState(() => isActive = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  side: const BorderSide(
                                      color: Color(0xFFE4E4E7),
                                      width: 0.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(8)),
                                ),
                                child: const Text('Cancel',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF71717A))),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final name =
                                  nameCtrl.text.trim();
                                  final addr =
                                  addrCtrl.text.trim();
                                  final phone =
                                  phoneCtrl.text.trim();
                                  if (name.isEmpty ||
                                      addr.isEmpty ||
                                      phone.isEmpty) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Please fill in all fields.')),
                                    );
                                    return;
                                  }
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('restaurants')
                                        .doc(docId)
                                        .update({
                                      'name': name,
                                      'address': addr,
                                      'phone': phone,
                                      'isActive': isActive,
                                    });
                                    if (mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Restaurant updated successfully.')),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                            Text('Error: $e')),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  const Color(0xFF09090B),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(8)),
                                ),
                                child: const Text('Save changes',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Reusable field for edit sheet
  Widget _editField(
      String label,
      TextEditingController ctrl, {
        String hint = '',
        TextInputType keyboardType = TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF71717A))),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF09090B)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  fontSize: 13, color: Color(0xFFA1A1AA)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFFE4E4E7), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF71717A), width: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream:
        FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // Filter & search
          final filtered = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final name =
            (data['name'] as String? ?? '').toLowerCase();
            final address =
            (data['address'] as String? ?? '').toLowerCase();
            final isActive = data['isActive'] as bool? ?? true;
            final matchesFilter =
                _filter == 'all' || (_filter == 'active' && isActive);
            final matchesSearch = _searchQuery.isEmpty ||
                name.contains(_searchQuery) ||
                address.contains(_searchQuery);
            return matchesFilter && matchesSearch;
          }).toList();

          final totalCount = docs.length;
          final activeCount =
              docs.where((d) => (d.data() as Map)['isActive'] == true).length;
          final inactiveCount = totalCount - activeCount;

          return ListView(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Stats row
              _StatsRow(
                total: totalCount,
                active: activeCount,
                inactive: inactiveCount,
              ),
              const SizedBox(height: 14),

              // Search + filter
              Row(
                children: [
                  Expanded(
                    child: _SearchBar(
                      controller: _searchController,
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'All',
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'Active',
                    selected: _filter == 'active',
                    onTap: () => setState(() => _filter = 'active'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Restaurant cards
              if (filtered.isEmpty)
                _EmptyState()
              else
                ...filtered.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RestaurantCard(
                      name: data['name'] ?? '',
                      address: data['address'] ?? '',
                      phone: data['phone'] ?? '',
                      isActive: data['isActive'] ?? true,
                      onEdit: () => _openEditRestaurant(
                        docId: doc.id,
                        currentName: data['name'] ?? '',
                        currentAddress: data['address'] ?? '',
                        currentPhone: data['phone'] ?? '',
                        currentIsActive: data['isActive'] ?? true,
                      ),
                      onDelete: () => _deleteRestaurant(doc.id, data['name'] ?? ''),
                    ),
                  );
                }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddRestaurant,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add, size: 18),
        label: const Text(
          'Add restaurant',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: const Text(
        'Restaurants',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: _textPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: _border),
      ),
      actions: [
        // Logout button
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _logout,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: _border, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.logout_rounded,
                      size: 14, color: _textSecondary),
                  SizedBox(width: 5),
                  Text(
                    'Sign out',
                    style: TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int total, active, inactive;
  const _StatsRow(
      {required this.total, required this.active, required this.inactive});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Total', value: '$total')),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                label: 'Active',
                value: '$active',
                dotColor: const Color(0xFF16A34A))),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                label: 'Inactive',
                value: '$inactive',
                dotColor: const Color(0xFFA1A1AA))),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color? dotColor;
  const _StatCard({required this.label, required this.value, this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E4E7), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Color(0xFF09090B),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF71717A))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: Color(0xFF09090B)),
      decoration: InputDecoration(
        hintText: 'Search by name or address…',
        hintStyle:
        const TextStyle(fontSize: 13, color: Color(0xFFA1A1AA)),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 16, color: Color(0xFFA1A1AA)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE4E4E7), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF71717A), width: 0.5),
        ),
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: selected
                ? const Color(0xFF09090B)
                : const Color(0xFFE4E4E7),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
            selected ? FontWeight.w500 : FontWeight.w400,
            color: selected
                ? const Color(0xFF09090B)
                : const Color(0xFF71717A),
          ),
        ),
      ),
    );
  }
}

// ── Restaurant Card ───────────────────────────────────────────────────────────
class _RestaurantCard extends StatelessWidget {
  final String name, address, phone;
  final bool isActive;
  final VoidCallback onEdit, onDelete;

  const _RestaurantCard({
    required this.name,
    required this.address,
    required this.phone,
    required this.isActive,
    required this.onEdit,
    required this.onDelete,
  });

  String _initials(String n) => n
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E4E7), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              border:
              Border.all(color: const Color(0xFFE4E4E7), width: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF71717A),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF09090B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(address,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF71717A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(phone,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF71717A))),
                const SizedBox(height: 8),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFA1A1AA),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF71717A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action buttons
          Column(
            children: [
              _IconBtn(
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              const SizedBox(height: 6),
              _IconBtn(
                icon: Icons.delete_outline_rounded,
                onTap: onDelete,
                danger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  const _IconBtn(
      {required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E4E7), width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 15,
          color: danger
              ? const Color(0xFFDC2626)
              : const Color(0xFF71717A),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.storefront_outlined,
                size: 32, color: Color(0xFFA1A1AA)),
            SizedBox(height: 10),
            Text('No restaurants found',
                style: TextStyle(
                    fontSize: 14, color: Color(0xFF71717A))),
          ],
        ),
      ),
    );
  }
}

// ── Add Restaurant Bottom Sheet ───────────────────────────────────────────────
class _AddRestaurantSheet extends StatefulWidget {
  final TextEditingController nameCtrl, addrCtrl, phoneCtrl, emailCtrl,
      passCtrl;
  final VoidCallback onSave;

  const _AddRestaurantSheet({
    required this.nameCtrl,
    required this.addrCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.onSave,
  });

  @override
  State<_AddRestaurantSheet> createState() => _AddRestaurantSheetState();
}

class _AddRestaurantSheetState extends State<_AddRestaurantSheet> {
  bool _obscurePass = true;

  static const _border = Color(0xFFE4E4E7);
  static const _textPrimary = Color(0xFF09090B);
  static const _textSecondary = Color(0xFF71717A);
  static const _textTertiary = Color(0xFFA1A1AA);
  static const _surface = Colors.white;
  static const _bg = Color(0xFFF4F4F5);

  final _themeColors = const [
    {'label': 'Background', 'value': '#FAF5EF', 'color': Color(0xFFFAF5EF)},
    {'label': 'Text', 'value': '#000000', 'color': Color(0xFF000000)},
    {'label': 'Card', 'value': '#FFFFFF', 'color': Color(0xFFFFFFFF)},
    {'label': 'Category bg', 'value': '#6D4C41', 'color': Color(0xFF6D4C41)},
    {'label': 'Category text', 'value': '#FFFFFF', 'color': Color(0xFFFFFFFF)},
    {'label': 'Card info', 'value': '#757575', 'color': Color(0xFF757575)},
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add restaurant',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _surface,
                      border: Border.all(color: _border, width: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: _textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: _border, margin: const EdgeInsets.only(top: 12)),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant Info
                  _sectionTitle('Restaurant info'),
                  const SizedBox(height: 10),
                  _field('Name', widget.nameCtrl,
                      hint: 'e.g. The Grand Table'),
                  _field('Address', widget.addrCtrl,
                      hint: 'Street, City'),
                  _field('Phone', widget.phoneCtrl,
                      hint: '+91 98765 43210',
                      keyboardType: TextInputType.phone),

                  const SizedBox(height: 16),
                  Container(height: 0.5, color: _border),
                  const SizedBox(height: 16),

                  // Theme Colors
                  _sectionTitle('Theme colors'),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 3.2,
                    children: _themeColors.map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _surface,
                          border: Border.all(color: _border, width: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: c['color'] as Color,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                Border.all(color: _border, width: 0.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(c['label'] as String,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: _textTertiary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(c['value'] as String,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: _textPrimary,
                                          fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  Container(height: 0.5, color: _border),
                  const SizedBox(height: 16),

                  // Admin Credentials
                  _sectionTitle('Admin credentials'),
                  const SizedBox(height: 10),
                  _field('Email', widget.emailCtrl,
                      hint: 'admin@restaurant.com',
                      keyboardType: TextInputType.emailAddress),
                  _passwordField(),

                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(
                                color: _border, width: 0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(
                                  fontSize: 13, color: _textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: widget.onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _textPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Save restaurant',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.7,
      color: _textTertiary,
    ),
  );

  Widget _field(
      String label,
      TextEditingController ctrl, {
        String hint = '',
        TextInputType keyboardType = TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: _textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: const TextStyle(
                fontSize: 13, color: _textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  fontSize: 13, color: _textTertiary),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                const BorderSide(color: _border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF71717A), width: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Password',
              style: TextStyle(fontSize: 12, color: _textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: widget.passCtrl,
            obscureText: _obscurePass,
            style:
            const TextStyle(fontSize: 13, color: _textPrimary),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: const TextStyle(
                  fontSize: 13, color: _textTertiary),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscurePass = !_obscurePass),
                child: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16,
                  color: _textTertiary,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                const BorderSide(color: _border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF71717A), width: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confirm Dialog ────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, message, confirmLabel;
  final Color confirmColor, confirmTextColor;

  const _ConfirmDialog({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.confirmTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFE4E4E7), width: 0.5),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF09090B))),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF71717A))),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFE4E4E7), width: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF71717A))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: confirmTextColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(confirmLabel,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}