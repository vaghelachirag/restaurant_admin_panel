import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:restaurant_admin_panel/restaurant_admin/upload_csv_upload.dart';
import '../../uttils/responsive.dart';
import '../services/localization_service.dart';
import '../uttils/snackbar_helper.dart';
import 'package:restaurant_admin_panel/widgets/loading_card.dart';


class MenuPage extends StatefulWidget {
  final String restaurantId;

  const MenuPage({super.key, required this.restaurantId});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {

  XFile? pickedImage;
  Uint8List? imageBytes;

  final String apiKey = "a923bc17d28cd6fe1be417700456eb69";

  /// null  = "All" selected (show everything)
  /// non-null = filter by this categoryId
  String? _selectedCategoryId;

  String _searchQuery = "";

  bool _isAddingMenuItem = false;
  bool _isEditingMenuItem = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Category chip bar
  // ─────────────────────────────────────────────────────────────────────────

  final ScrollController _chipScrollController = ScrollController();

  /// Keys for "All" chip (index 0) + each category chip (index 1…n).
  final List<GlobalKey> _chipKeys = [];

  /// Scrolls the chip list so the chip at [chipIndex] is centred in view.
  void _scrollToChip(int chipIndex) {
    if (!_chipScrollController.hasClients) return;
    if (chipIndex < 0 || chipIndex >= _chipKeys.length) return;

    final key = _chipKeys[chipIndex];
    final ctx = key.currentContext;
    if (ctx == null) return;

    final chipBox    = ctx.findRenderObject() as RenderBox?;
    final scrollBox  = _chipScrollController.position.context.storageContext
        .findRenderObject() as RenderBox?;
    if (chipBox == null || scrollBox == null) return;

    final chipOffset  = chipBox.localToGlobal(Offset.zero, ancestor: scrollBox).dx;
    final chipWidth   = chipBox.size.width;
    final viewWidth   = scrollBox.size.width;
    final current     = _chipScrollController.offset;

    // Target: centre the chip horizontally in the viewport
    final target = (current + chipOffset + chipWidth / 2 - viewWidth / 2)
        .clamp(0.0, _chipScrollController.position.maxScrollExtent);

    _chipScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Builds the horizontal scrollable chip row from [categories].
  Widget _buildCategoryChips(List<QueryDocumentSnapshot> categories) {
    // Rebuild key list whenever categories change
    _chipKeys
      ..clear()
      ..addAll(List.generate(categories.length + 1, (_) => GlobalKey()));

    return SizedBox(
      height: 40,
      child: ListView(
        controller: _chipScrollController,
        scrollDirection: Axis.horizontal,
        // Extra end-padding so the last chip is never clipped
        padding: const EdgeInsets.only(right: 16),
        children: [
          // ── "All" chip (index 0) ────────────────────────────────────────
          _CategoryChip(
            key: _chipKeys[0],
            label: 'All',
            isSelected: _selectedCategoryId == null,
            onTap: () {
              setState(() => _selectedCategoryId = null);
              _scrollToChip(0);
            },
          ),
          const SizedBox(width: 8),

          // ── Per-category chips (index 1…n) ──────────────────────────────
          ...categories.asMap().entries.map((entry) {
            final chipIndex = entry.key + 1; // offset by 1 for "All"
            final cat    = entry.value;
            final catId  = cat.id;
            final catName =
            ((cat.data() as Map<String, dynamic>)['name'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                key: _chipKeys[chipIndex],
                label: catName,
                isSelected: _selectedCategoryId == catId,
                onTap: () {
                  setState(() => _selectedCategoryId = catId);
                  _scrollToChip(chipIndex);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chipScrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Image helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      pickedImage = image;
      imageBytes = await image.readAsBytes();
      setState(() {});
    }
  }

  Future<String?> uploadImageToImgBB() async {
    if (imageBytes == null) return null;
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("https://api.imgbb.com/1/upload?key=$apiKey"),
      );
      request.files.add(
        http.MultipartFile.fromBytes('image', imageBytes!, filename: "menu.jpg"),
      );
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);
      return jsonData['data']['url'];
    } catch (e) {
      if (kDebugMode) print("UPLOAD ERROR $e");
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Add menu item dialog  (unchanged from original)
  // ─────────────────────────────────────────────────────────────────────────

  void addMenuItem() {
    TextEditingController nameController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    String? selectedCategoryId = _selectedCategoryId;
    bool isVeg = true;
    List<Map<String, TextEditingController>> variants = [
      {"name": TextEditingController(text: "Regular"), "price": TextEditingController()}
    ];

    Widget sectionLabel(String text, IconData icon) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 14, color: const Color(0xFFC4622D)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280), letterSpacing: 0.8, fontFamily: 'Poppins',
        )),
      ]),
    );

    InputDecoration inputDec(String hint, IconData icon) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0B7C3), fontFamily: 'Poppins', fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFFB0B7C3)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFC4622D), width: 1.5)),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDesktop = Responsive.isDesktop(context);
        final isMobile  = Responsive.isMobile(context);
        bool isDialogLoading = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {

            Widget imageUploadZone(double height) => GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  setStateDialog(() { imageBytes = bytes; });
                }
              },
              child: Container(
                width: double.infinity, height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: imageBytes != null ? const Color(0xFFC4622D) : const Color(0xFFD1D5DB),
                    width: imageBytes != null ? 2 : 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: imageBytes != null
                      ? Stack(fit: StackFit.expand, children: [
                    Image.memory(imageBytes!, fit: BoxFit.cover),
                    Positioned(bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(20)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text("Change", style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Poppins')),
                        ]),
                      ),
                    ),
                  ])
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(color: Color(0xFFFFF0E8), shape: BoxShape.circle),
                      child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFC4622D), size: 26),
                    ),
                    const SizedBox(height: 10),
                    const Text("Tap to upload photo", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151), fontFamily: 'Poppins')),
                    const SizedBox(height: 3),
                    const Text("JPG, PNG • Max 5MB", style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontFamily: 'Poppins')),
                  ]),
                ),
              ),
            );

            Widget foodTypeSelector() => Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setStateDialog(() { isVeg = true; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: isVeg ? const Color(0xFFE8F5E9) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isVeg ? const Color(0xFF388E3C) : const Color(0xFFE5E7EB), width: isVeg ? 2 : 1),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 13, height: 13,
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF388E3C), width: 2), borderRadius: BorderRadius.circular(3)),
                        child: isVeg ? Center(child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF388E3C), shape: BoxShape.circle))) : null),
                    const SizedBox(width: 7),
                    Text(AppLocalizations.of(context).veg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF388E3C), fontFamily: 'Poppins')),
                  ]),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => setStateDialog(() { isVeg = false; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: !isVeg ? const Color(0xFFFFEBEE) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: !isVeg ? const Color(0xFFC62828) : const Color(0xFFE5E7EB), width: !isVeg ? 2 : 1),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 13, height: 13,
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC62828), width: 2), borderRadius: BorderRadius.circular(3)),
                        child: !isVeg ? Center(child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFC62828), shape: BoxShape.circle))) : null),
                    const SizedBox(width: 7),
                    Text(AppLocalizations.of(context).nonVeg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC62828), fontFamily: 'Poppins')),
                  ]),
                ),
              )),
            ]);

            Widget categoryDropdownWidget() => StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('restaurants').doc(widget.restaurantId)
                  .collection('categories').orderBy('position').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(height: 46,
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC4622D)))),
                  );
                }
                final categories = snapshot.data!.docs;
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selectedCategoryId != null ? const Color(0xFFC4622D) : const Color(0xFFE5E7EB)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCategoryId,
                      hint: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(AppLocalizations.of(context).selectCategory,
                            style: const TextStyle(color: Color(0xFFB0B7C3), fontFamily: 'Poppins', fontSize: 13)),
                      ),
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      icon: const Icon(Icons.expand_more_rounded, color: Color(0xFF9CA3AF), size: 20),
                      items: categories.map((cat) => DropdownMenuItem<String>(
                        value: cat.id,
                        child: Text(cat['name'], style: const TextStyle(fontSize: 13, fontFamily: 'Poppins')),
                      )).toList(),
                      onChanged: (value) => setStateDialog(() { selectedCategoryId = value; }),
                    ),
                  ),
                );
              },
            );

            Widget variantRows() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: const [
                  Icon(Icons.tune_rounded, size: 14, color: Color(0xFFC4622D)),
                  SizedBox(width: 6),
                  Text("VARIANTS & PRICING", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.8, fontFamily: 'Poppins')),
                ]),
                TextButton.icon(
                  onPressed: () { variants.add({"name": TextEditingController(), "price": TextEditingController()}); setStateDialog(() {}); },
                  icon: const Icon(Icons.add_rounded, size: 15, color: Color(0xFFC4622D)),
                  label: const Text("Add", style: TextStyle(fontSize: 12, color: Color(0xFFC4622D), fontFamily: 'Poppins')),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      backgroundColor: const Color(0xFFFFF0E8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ]),
              const SizedBox(height: 10),
              ...variants.asMap().entries.map((entry) {
                final index = entry.key;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(children: [
                    Container(width: 24, height: 24,
                        decoration: const BoxDecoration(color: Color(0xFFFFF0E8), shape: BoxShape.circle),
                        child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC4622D), fontFamily: 'Poppins')))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: variants[index]["name"],
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Variant name",
                        hintStyle: const TextStyle(color: Color(0xFFB0B7C3), fontFamily: 'Poppins', fontSize: 12),
                        filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFC4622D))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        isDense: true,
                      ),
                    )),
                    const SizedBox(width: 8),
                    SizedBox(width: 100, child: TextField(
                      controller: variants[index]["price"],
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "0",
                        hintStyle: const TextStyle(color: Color(0xFFB0B7C3), fontFamily: 'Poppins'),
                        prefixText: "₹ ",
                        prefixStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                        filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFC4622D))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        isDense: true,
                      ),
                    )),
                    if (variants.length > 1) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () { variants.removeAt(index); setStateDialog(() {}); },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFE53935)),
                        ),
                      ),
                    ],
                  ]),
                );
              }).toList(),
            ]);

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 36,
                vertical:   isMobile ? 20 : 36,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:  isDesktop ? 860 : (isMobile ? double.infinity : 600),
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                child: Stack(children: [
                  Column(mainAxisSize: MainAxisSize.min, children: [

                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 18, 20, 18),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D1140),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                          Text("Add Menu Item", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')),
                          SizedBox(height: 2),
                          Text("Fill in the details below to add a new dish",
                              style: TextStyle(fontSize: 12, color: Colors.white60, fontFamily: 'Poppins')),
                        ])),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          ),
                        ),
                      ]),
                    ),

                    Flexible(
                      child: isDesktop
                          ? IntrinsicHeight(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Container(
                            width: 240,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF9FAFB),
                              border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                sectionLabel("DISH PHOTO", Icons.image_outlined),
                                imageUploadZone(160),
                                const SizedBox(height: 22),
                                sectionLabel("FOOD TYPE", Icons.eco_outlined),
                                foodTypeSelector(),
                                const SizedBox(height: 22),
                                sectionLabel("CATEGORY", Icons.folder_open_outlined),
                                categoryDropdownWidget(),
                              ]),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                sectionLabel("ITEM NAME", Icons.label_outline_rounded),
                                TextField(
                                  controller: nameController,
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                                  decoration: inputDec(AppLocalizations.of(context).enterItemName, Icons.restaurant_outlined),
                                ),
                                const SizedBox(height: 20),
                                sectionLabel("DESCRIPTION", Icons.description_outlined),
                                TextField(
                                  controller: descriptionController,
                                  maxLines: 3,
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                                  decoration: inputDec(AppLocalizations.of(context).enterItemDescription, Icons.notes_rounded),
                                ),
                                const SizedBox(height: 22),
                                variantRows(),
                              ]),
                            ),
                          ),
                        ]),
                      )
                          : SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          sectionLabel("DISH PHOTO", Icons.image_outlined),
                          imageUploadZone(130),
                          const SizedBox(height: 18),
                          sectionLabel("FOOD TYPE", Icons.eco_outlined),
                          foodTypeSelector(),
                          const SizedBox(height: 18),
                          sectionLabel("CATEGORY", Icons.folder_open_outlined),
                          categoryDropdownWidget(),
                          const SizedBox(height: 18),
                          sectionLabel("ITEM NAME", Icons.label_outline_rounded),
                          TextField(
                            controller: nameController,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                            decoration: inputDec(AppLocalizations.of(context).enterItemName, Icons.restaurant_outlined),
                          ),
                          const SizedBox(height: 18),
                          sectionLabel("DESCRIPTION", Icons.description_outlined),
                          TextField(
                            controller: descriptionController,
                            maxLines: 3,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                            decoration: inputDec(AppLocalizations.of(context).enterItemDescription, Icons.notes_rounded),
                          ),
                          const SizedBox(height: 20),
                          variantRows(),
                        ]),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                      ),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isVeg ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 9, height: 9,
                                decoration: BoxDecoration(
                                    border: Border.all(color: isVeg ? const Color(0xFF388E3C) : const Color(0xFFC62828), width: 1.5),
                                    borderRadius: BorderRadius.circular(2)),
                                child: Center(child: Container(width: 3.5, height: 3.5,
                                    decoration: BoxDecoration(color: isVeg ? const Color(0xFF388E3C) : const Color(0xFFC62828), shape: BoxShape.circle)))),
                            const SizedBox(width: 5),
                            Text(isVeg ? "Veg" : "Non-Veg",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                    color: isVeg ? const Color(0xFF388E3C) : const Color(0xFFC62828), fontFamily: 'Poppins')),
                          ]),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Cancel", style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500, fontFamily: 'Poppins', fontSize: 13)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isDialogLoading ? null : () async {
                            if (selectedCategoryId == null || nameController.text.trim().isEmpty) {
                              SnackBarHelper.showError(context, AppLocalizations.of(context).pleaseFillAllRequiredFields);
                              return;
                            }
                            setStateDialog(() { isDialogLoading = true; });
                            setState(() { _isAddingMenuItem = true; });
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) throw Exception('Not authenticated. Please log in as admin.');
                              await user.getIdToken(true);
                              String? imageUrl = await uploadImageToImgBB();
                              List<Map<String, dynamic>> variantList = variants.map((v) =>
                              {"name": v["name"]!.text, "price": int.tryParse(v["price"]!.text) ?? 0}).toList();
                              await FirebaseFirestore.instance
                                  .collection('restaurants').doc(widget.restaurantId)
                                  .collection('menu_items').add({
                                "name": nameController.text.trim(),
                                "image": imageUrl ?? '',
                                "categoryId": selectedCategoryId,
                                "restaurantId": widget.restaurantId,
                                "variants": variantList,
                                "description": descriptionController.text.trim(),
                                "isVeg": isVeg,
                                "isAvailable": true,
                                "createdAt": FieldValue.serverTimestamp(),
                              });
                              Navigator.pop(context);
                              setState(() { _selectedCategoryId = selectedCategoryId; });
                              SnackBarHelper.showSuccess(context, AppLocalizations.of(context).menuItemAddedSuccess);
                            } catch (e) {
                              setStateDialog(() { isDialogLoading = false; });
                              SnackBarHelper.showError(context, "${AppLocalizations.of(context).errorAddingMenuItem}: $e");
                            } finally {
                              setState(() { _isAddingMenuItem = false; });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D1140),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isDialogLoading
                              ? const Row(mainAxisSize: MainAxisSize.min, children: [
                            SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 8),
                            Text("Adding...", style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins', fontSize: 13)),
                          ])
                              : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_rounded, size: 17),
                            SizedBox(width: 6),
                            Text("Add Item", style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins', fontSize: 13)),
                          ]),
                        ),
                      ]),
                    ),
                  ]),

                  if (isDialogLoading)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          color: Colors.black.withOpacity(0.28),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24)],
                              ),
                              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                                CircularProgressIndicator(color: Color(0xFFC4622D), strokeWidth: 3),
                                SizedBox(height: 16),
                                Text("Saving menu item...",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: Color(0xFF374151))),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete / Edit (unchanged from original)
  // ─────────────────────────────────────────────────────────────────────────

  void deleteMenuItem(String id, String itemName) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 8.sp : 10.sp),
              decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp)),
              child: Icon(Icons.delete_outline, color: colorScheme.error, size: kIsWeb ? 20 : 20.sp),
            ),
            SizedBox(width: isMobile ? 10.sp : 12.sp),
            Expanded(
              child: Text(AppLocalizations.of(context).deleteMenuItem, style: TextStyle(fontSize: isMobile ? 16.sp : 18.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).areYouSureDeleteMenuItem, style: TextStyle(fontSize: kIsWeb ? 14 : 14.sp, color: colorScheme.onSurface)),
            if (itemName.isNotEmpty) ...[
              SizedBox(height: isMobile ? 8.sp : 12.sp),
              Container(
                padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.restaurant, color: colorScheme.onSurface.withOpacity(0.6), size: kIsWeb ? 16 : 16.sp),
                    SizedBox(width: isMobile ? 8.sp : 10.sp),
                    Expanded(child: Text(itemName, style: TextStyle(fontSize: isMobile ? 14.sp : 15.sp, fontWeight: FontWeight.w500, color: colorScheme.onSurface), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ],
            SizedBox(height: isMobile ? 12.sp : 16.sp),
            Text(AppLocalizations.of(context).thisActionCannotBeUndone, style: TextStyle(fontSize: kIsWeb ? 12 : 12.sp, color: colorScheme.error, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16.sp : 20.sp, vertical: isMobile ? 10.sp : 12.sp),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp)),
            ),
            child: Text(AppLocalizations.of(context).cancel, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w500, fontSize: isMobile ? 14.sp : null)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('Not authenticated. Please log in as admin.');
                await user.getIdToken(true);
                await FirebaseFirestore.instance
                    .collection('restaurants')
                    .doc(widget.restaurantId)
                    .collection('menu_items')
                    .doc(id)
                    .delete();
                if (mounted) SnackBarHelper.showSuccess(context, AppLocalizations.of(context).menuItemDeletedSuccess);
              } catch (e) {
                if (mounted) SnackBarHelper.showError(context, "${AppLocalizations.of(context).errorDeletingMenuItem}: $e");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16.sp : 20.sp, vertical: isMobile ? 10.sp : 12.sp),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp)),
            ),
            child: Text(AppLocalizations.of(context).delete, style: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 14.sp : null)),
          ),
        ],
      ),
    );
  }

  void editMenuItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    TextEditingController nameController = TextEditingController(text: data['name'] ?? '');
    TextEditingController descriptionController = TextEditingController(text: data['description'] ?? '');
    String? selectedCategoryId = data['categoryId'];
    String? imageUrl = (data['image'] ?? '') as String?;
    bool isVeg = data['isVeg'] ?? true;
    Uint8List? newImageBytes;

    List<Map<String, TextEditingController>> variantsControllers = [];
    final List variants = data['variants'] ?? [];

    if (variants.isEmpty) {
      variantsControllers = [{"name": TextEditingController(), "price": TextEditingController()}];
    } else {
      for (var v in variants) {
        variantsControllers.add({
          "name": TextEditingController(text: v['name']?.toString() ?? ''),
          "price": TextEditingController(text: v['price']?.toString() ?? ''),
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool isEditing = _isEditingMenuItem;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp)),
              backgroundColor: colorScheme.surface,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 24 : 20.sp, vertical: kIsWeb ? 20 : 16.sp),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        border: Border(bottom: BorderSide(color: colorScheme.outline.withOpacity(0.15))),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Container(
                          width: kIsWeb ? 44 : 38.sp, height: kIsWeb ? 44 : 38.sp,
                          decoration: BoxDecoration(color: const Color(0xFFC4622D), borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp)),
                          child: Icon(Icons.edit_outlined, color: Colors.white, size: kIsWeb ? 22 : 19.sp),
                        ),
                        SizedBox(width: kIsWeb ? 14 : 12.sp),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(AppLocalizations.of(context).editMenuItem, style: TextStyle(fontSize: kIsWeb ? 18 : 16.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface, letterSpacing: 0.1)),
                          SizedBox(height: kIsWeb ? 3 : 2.sp),
                          Text(AppLocalizations.of(context).updateDetailsOfMenuItem, style: TextStyle(fontSize: kIsWeb ? 13 : 12.sp, color: colorScheme.onSurface.withOpacity(0.55), height: 1.3)),
                        ])),
                        SizedBox(width: kIsWeb ? 8 : 6.sp),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                          child: Container(
                            width: kIsWeb ? 32 : 28.sp, height: kIsWeb ? 32 : 28.sp,
                            decoration: BoxDecoration(color: colorScheme.onSurface.withOpacity(0.07), borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp)),
                            child: Icon(Icons.close_rounded, color: colorScheme.onSurface.withOpacity(0.6), size: kIsWeb ? 18 : 16.sp),
                          ),
                        ),
                      ]),
                    ),
                    // Body + footer (unchanged – omitting for brevity; copy from original)
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // image
                            Text(AppLocalizations.of(context).itemImage, style: TextStyle(fontSize: kIsWeb ? 14 : 14.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                            SizedBox(height: kIsWeb ? 10 : 10.sp),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                width: kIsWeb ? 120 : 120.sp, height: kIsWeb ? 120 : 120.sp,
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp), color: colorScheme.surfaceVariant.withOpacity(0.5), border: Border.all(color: colorScheme.outline.withOpacity(0.3))),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                                  child: newImageBytes != null
                                      ? Image.memory(newImageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                      : (imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                      : Icon(Icons.restaurant, color: colorScheme.onSurface.withOpacity(0.4), size: kIsWeb ? 30 : 30.sp)),
                                ),
                              ),
                              SizedBox(width: kIsWeb ? 12 : 16.sp),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(AppLocalizations.of(context).uploadOrChangeDishImage, style: TextStyle(fontSize: kIsWeb ? 12 : 12.sp, color: colorScheme.onSurface.withOpacity(0.6))),
                                SizedBox(height: kIsWeb ? 10 : 10.sp),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      setStateDialog(() { newImageBytes = bytes; });
                                    }
                                  },
                                  icon: Icon(Icons.image_outlined, color: colorScheme.primary, size: kIsWeb ? 18 : 18.sp),
                                  label: Text(imageUrl != null && imageUrl.isNotEmpty ? AppLocalizations.of(context).changeImage : AppLocalizations.of(context).uploadImage,
                                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500, fontSize: kIsWeb ? 12 : 12.sp)),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 16 : 20.sp, vertical: kIsWeb ? 10 : 12.sp),
                                    side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp)),
                                  ),
                                ),
                              ])),
                            ]),
                            SizedBox(height: kIsWeb ? 20 : 20.sp),
                            // category dropdown, name, desc, veg, variants — same as original
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('restaurants').doc(widget.restaurantId).collection('categories').orderBy('position').snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return Container(height: kIsWeb ? 50 : 50.sp, decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp)), child: Center(child: CircularProgressIndicator(strokeWidth: kIsWeb ? 2 : 2.sp)));
                                final categories = snapshot.data!.docs;
                                return Container(
                                  decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp), border: Border.all(color: colorScheme.outline.withOpacity(0.2))),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedCategoryId,
                                      hint: Padding(padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 12 : 12.sp, vertical: kIsWeb ? 8 : 8.sp), child: Text(AppLocalizations.of(context).selectCategory, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)))),
                                      isExpanded: true,
                                      padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 12 : 12.sp, vertical: kIsWeb ? 8 : 8.sp),
                                      items: categories.map((cat) => DropdownMenuItem<String>(value: cat.id, child: Text(cat['name'], style: TextStyle(fontSize: kIsWeb ? 12 : 15.sp)))).toList(),
                                      onChanged: (value) { setStateDialog(() { selectedCategoryId = value; }); },
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: kIsWeb ? 20 : 20.sp),
                            TextField(controller: nameController, decoration: InputDecoration(hintText: AppLocalizations.of(context).enterItemName, filled: true, fillColor: colorScheme.surfaceVariant.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp), borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12), borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp), borderSide: BorderSide(color: colorScheme.primary)), prefixIcon: Icon(Icons.restaurant, color: colorScheme.onSurface.withOpacity(0.5)))),
                            SizedBox(height: kIsWeb ? 20 : 20.sp),
                            TextField(controller: descriptionController, maxLines: 3, decoration: InputDecoration(hintText: AppLocalizations.of(context).enterItemDescription, filled: true, fillColor: colorScheme.surfaceVariant.withOpacity(0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp), borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12), borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp), borderSide: BorderSide(color: colorScheme.primary)))),
                            SizedBox(height: kIsWeb ? 20 : 20.sp),
                            // veg/non-veg row (same as original add dialog)
                            Row(children: [
                              Expanded(child: GestureDetector(onTap: () => setStateDialog(() { isVeg = true; }), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: EdgeInsets.symmetric(vertical: kIsWeb ? 12 : 12.sp), decoration: BoxDecoration(color: isVeg ? const Color(0xFFE8F5E9) : colorScheme.surfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp), border: Border.all(color: isVeg ? const Color(0xFF388E3C) : colorScheme.outline.withOpacity(0.3), width: isVeg ? 2 : 1)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 16, height: 16, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF388E3C), width: 2), borderRadius: BorderRadius.circular(3)), child: Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF388E3C), shape: BoxShape.circle)))), SizedBox(width: kIsWeb ? 8 : 8.sp), Text(AppLocalizations.of(context).veg, style: TextStyle(fontSize: kIsWeb ? 13 : 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF388E3C)))])))),
                              SizedBox(width: kIsWeb ? 12 : 12.sp),
                              Expanded(child: GestureDetector(onTap: () => setStateDialog(() { isVeg = false; }), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: EdgeInsets.symmetric(vertical: kIsWeb ? 12 : 12.sp), decoration: BoxDecoration(color: !isVeg ? const Color(0xFFFFEBEE) : colorScheme.surfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.sp), border: Border.all(color: !isVeg ? const Color(0xFFC62828) : colorScheme.outline.withOpacity(0.3), width: !isVeg ? 2 : 1)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 16, height: 16, decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC62828), width: 2), borderRadius: BorderRadius.circular(3)), child: Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFC62828), shape: BoxShape.circle)))), SizedBox(width: kIsWeb ? 8 : 8.sp), Text(AppLocalizations.of(context).nonVeg, style: TextStyle(fontSize: kIsWeb ? 13 : 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFFC62828)))])))),
                            ]),
                            SizedBox(height: kIsWeb ? 24 : 24.sp),
                            ...variantsControllers.asMap().entries.map((entry) {
                              final index = entry.key;
                              return Container(
                                margin: EdgeInsets.only(bottom: kIsWeb ? 12 : 12.sp),
                                padding: EdgeInsets.all(kIsWeb ? 16 : 16.sp),
                                decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp), border: Border.all(color: colorScheme.outline.withOpacity(0.2))),
                                child: Row(children: [
                                  Expanded(child: TextField(controller: variantsControllers[index]["name"], decoration: InputDecoration(labelText: AppLocalizations.of(context).variantName, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp), borderSide: BorderSide.none), contentPadding: EdgeInsets.symmetric(horizontal: kIsWeb ? 12 : 12.sp, vertical: kIsWeb ? 8 : 8.sp)))),
                                  SizedBox(width: kIsWeb ? 12 : 12.sp),
                                  SizedBox(width: kIsWeb ? 100 : 100.sp, child: TextField(controller: variantsControllers[index]["price"], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: AppLocalizations.of(context).price, prefixText: "₹", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp), borderSide: BorderSide.none), contentPadding: EdgeInsets.symmetric(horizontal: kIsWeb ? 10 : 10.sp, vertical: 8)))),
                                  SizedBox(width: kIsWeb ? 10 : 10.sp),
                                  if (variantsControllers.length > 1) IconButton(icon: Icon(Icons.remove_circle_outline, color: colorScheme.error), onPressed: () { variantsControllers.removeAt(index); setStateDialog(() {}); }),
                                ]),
                              );
                            }),
                            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { variantsControllers.add({"name": TextEditingController(), "price": TextEditingController()}); setStateDialog(() {}); }, icon: Icon(Icons.add_circle_outline, color: colorScheme.primary), label: Text(AppLocalizations.of(context).addAnotherVariant, style: TextStyle(color: colorScheme.primary)), style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: kIsWeb ? 12 : 12.sp), side: BorderSide(color: colorScheme.primary.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp))))),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(kIsWeb ? 20 : 20.sp),
                      decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.vertical(bottom: Radius.circular(kIsWeb ? 20 : 20.sp))),
                      child: Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: kIsWeb ? 14 : 12.sp), side: BorderSide(color: colorScheme.outline), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12))), child: Text(AppLocalizations.of(context).cancel, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w500)))),
                        SizedBox(width: kIsWeb ? 12 : 12.sp),
                        Expanded(flex: 2, child: ElevatedButton(
                          onPressed: isEditing ? null : () async {
                            if (selectedCategoryId == null || nameController.text.trim().isEmpty) { SnackBarHelper.showError(context, AppLocalizations.of(context).pleaseFillAllRequiredFields); return; }
                            setState(() { _isEditingMenuItem = true; }); setStateDialog(() { isEditing = true; });
                            try {
                              final editUser = FirebaseAuth.instance.currentUser;
                              if (editUser == null) throw Exception('Not authenticated.');
                              await editUser.getIdToken(true);
                              final List<Map<String, dynamic>> updatedVariants = [];
                              for (var v in variantsControllers) { final vName = v["name"]!.text.trim(); final priceText = v["price"]!.text.trim(); if (vName.isEmpty || priceText.isEmpty) continue; updatedVariants.add({"name": vName, "price": int.tryParse(priceText) ?? 0}); }
                              String? finalImageUrl = imageUrl;
                              if (newImageBytes != null) {
                                try { var request = http.MultipartRequest('POST', Uri.parse("https://api.imgbb.com/1/upload?key=$apiKey")); request.files.add(http.MultipartFile.fromBytes('image', newImageBytes!, filename: "menu.jpg")); var response = await request.send(); var responseData = await response.stream.bytesToString(); var jsonData = json.decode(responseData); final uploadedUrl = jsonData['data']['url']; if (uploadedUrl != null && uploadedUrl.isNotEmpty) finalImageUrl = uploadedUrl; } catch (e) { if (kDebugMode) print("UPLOAD ERROR $e"); }
                              }
                              await FirebaseFirestore.instance.collection('restaurants').doc(widget.restaurantId).collection('menu_items').doc(doc.id).update({"name": nameController.text.trim(), "categoryId": selectedCategoryId, "variants": updatedVariants, "description": descriptionController.text.trim(), "isVeg": isVeg, "image": finalImageUrl ?? imageUrl ?? ''});
                              if (context.mounted) { Navigator.pop(context); SnackBarHelper.showSuccess(context, AppLocalizations.of(context).menuItemUpdatedSuccess); }
                            } finally { setState(() { _isEditingMenuItem = false; }); setStateDialog(() { isEditing = false; }); }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF070B2D), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12))),
                          child: isEditing ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 8), Text(AppLocalizations.of(context).updatingMenuItem, style: const TextStyle(fontWeight: FontWeight.w600))]) : Text(AppLocalizations.of(context).updateMenuItem, style: const TextStyle(fontWeight: FontWeight.w600)),
                        )),
                      ]),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> toggleAvailability(String id, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await user.getIdToken(true);
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .collection('menu_items')
        .doc(id)
        .update({"isAvailable": value});
  }

  @override
  void initState() {
    super.initState();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile  = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Top bar: title, CSV, Add button, search, chips ─────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 28 : 16,
                isDesktop ? 20 : 14,
                isDesktop ? 28 : 16,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context).menuItems,
                        style: TextStyle(
                          fontSize: isDesktop ? 24 : 30,
                          fontWeight: FontWeight.w200,
                          color: const Color(0xFF1C1C1C),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProviderScope(
                                child: CsvUploadPage(restaurantId: widget.restaurantId),
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF070B2D),
                          side: const BorderSide(color: Color(0xFF070B2D), width: 1.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.upload_file_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(isMobile ? 'CSV' : 'Import CSV', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: addMenuItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF070B2D),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.add, size: 16),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context).addMenuItem, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  SizedBox(
                    height: 44,
                    width: isDesktop ? 400 : double.infinity,
                    child: TextField(
                      onChanged: (value) => setState(() { _searchQuery = value.trim().toLowerCase(); }),
                      decoration: InputDecoration(
                        hintText: 'Search menu items...',
                        hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFAAAAAA), size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E5E5))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8622A))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Category chip bar (stream-driven) ──────────────────
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('restaurants')
                        .doc(widget.restaurantId)
                        .collection('categories')
                        .orderBy('position')
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox(height: 40);
                      return _buildCategoryChips(snap.data!.docs);
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // ── Grid ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('restaurants')
                  .doc(widget.restaurantId)
                  .collection('categories')
                  .orderBy('position')
                  .snapshots(),
              builder: (context, catSnapshot) {
                if (!catSnapshot.hasData) {
                  return _skeletonGrid(isDesktop);
                }

                final categories = catSnapshot.data!.docs;
                final Map<String, String> categoryMap = {
                  for (final c in categories)
                    c.id: ((c.data() as Map<String, dynamic>)["name"] ?? "").toString(),
                };

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('restaurants')
                      .doc(widget.restaurantId)
                      .collection('menu_items')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(AppLocalizations.of(context).failedToLoadMenu, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)));
                    }
                    if (!snapshot.hasData) return _skeletonGrid(isDesktop);

                    final allItems = snapshot.data!.docs;

                    // Apply category filter + search
                    final items = allItems.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name        = (data['name'] ?? '').toString().toLowerCase();
                      final desc        = (data['description'] ?? '').toString().toLowerCase();
                      final categoryId  = (data['categoryId'] ?? '').toString();
                      final categoryName = (categoryMap[categoryId] ?? '').toLowerCase();

                      // Category chip filter
                      if (_selectedCategoryId != null && categoryId != _selectedCategoryId) return false;

                      // Search filter
                      if (_searchQuery.isEmpty) return true;
                      return name.contains(_searchQuery) || desc.contains(_searchQuery) || categoryName.contains(_searchQuery);
                    }).toList();

                    if (items.isEmpty) {
                      return _NoMenuItemsEmptyState(
                        isSearching: _searchQuery.isNotEmpty,
                        isCategoryFiltered: _selectedCategoryId != null,
                        searchQuery: _searchQuery,
                        onAddItem: addMenuItem,
                        onClearFilter: () => setState(() {
                          _selectedCategoryId = null;
                          _searchQuery = '';
                        }),
                      );
                    }

                    final isTablet = Responsive.isTablet(context);
                    final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);

                    return Padding(
                      padding: EdgeInsets.fromLTRB(isDesktop ? 28 : 16, 0, isDesktop ? 28 : 16, 30),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: isDesktop ? 0.68 : 0.72,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final doc = items[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final List variantList = (data['variants'] ?? []) as List;
                          final String name        = (data['name'] ?? '').toString();
                          final String imageUrl    = (data['image'] ?? '').toString();
                          final String description = (data['description'] ?? '').toString();
                          final String categoryId  = (data['categoryId'] ?? '').toString();
                          final String categoryName = (categoryMap[categoryId] ?? '').toString();
                          final num firstPrice     = variantList.isNotEmpty ? (variantList.first['price'] ?? 0) as num : 0;
                          final bool isVeg         = data['isVeg'] ?? true;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                flex: 58,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF3F4F6), child: const Center(child: Icon(Icons.fastfood_rounded, color: Color(0xFFCCCCCC), size: 36))))
                                      : Container(color: const Color(0xFFF3F4F6), child: const Center(child: Icon(Icons.fastfood_rounded, color: Color(0xFFCCCCCC), size: 36))),
                                ),
                              ),
                              Expanded(
                                flex: 42,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)))),
                                      InkWell(onTap: () => editMenuItem(doc), borderRadius: BorderRadius.circular(6), child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.edit_outlined, size: 30, color: Colors.grey[500]))),
                                      const SizedBox(width: 6),
                                      InkWell(onTap: () => deleteMenuItem(doc.id, name), borderRadius: BorderRadius.circular(6), child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.delete_outline, size: 30, color: Color(0xFFEF4444)))),
                                    ]),
                                    const SizedBox(height: 5),
                                    Row(children: [
                                      if (categoryName.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 5, right: 5),
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                          decoration: BoxDecoration(color: const Color(0xFFFFF0E6), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8622A).withOpacity(0.35))),
                                          child: Text(categoryName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE8622A))),
                                        ),
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 5),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(color: isVeg ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(20), border: Border.all(color: isVeg ? const Color(0xFF388E3C).withOpacity(0.5) : const Color(0xFFC62828).withOpacity(0.5))),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Container(width: 9, height: 9, decoration: BoxDecoration(border: Border.all(color: isVeg ? const Color(0xFF388E3C) : const Color(0xFFC62828), width: 1.5), borderRadius: BorderRadius.circular(2)), child: Center(child: Container(width: 4, height: 4, decoration: BoxDecoration(color: isVeg ? const Color(0xFF388E3C) : const Color(0xFFC62828), shape: BoxShape.circle)))),
                                          const SizedBox(width: 4),
                                          Text(isVeg ? AppLocalizations.of(context).veg : AppLocalizations.of(context).nonVeg, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isVeg ? const Color(0xFF388E3C) : const Color(0xFFC62828))),
                                        ]),
                                      ),
                                    ]),
                                    if (description.isNotEmpty)
                                      Flexible(child: Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4))),
                                    const Spacer(),
                                    Text('₹${firstPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.red)),
                                  ]),
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonGrid(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isDesktop ? 28 : 16, 10, isDesktop ? 28 : 16, 30),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 4 : 2,
          childAspectRatio: isDesktop ? 0.68 : 0.72,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const MenuCardSkeleton(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No Menu Items Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _NoMenuItemsEmptyState extends StatefulWidget {
  final bool isSearching;
  final bool isCategoryFiltered;
  final String searchQuery;
  final VoidCallback onAddItem;
  final VoidCallback onClearFilter;

  const _NoMenuItemsEmptyState({
    required this.isSearching,
    required this.isCategoryFiltered,
    required this.searchQuery,
    required this.onAddItem,
    required this.onClearFilter,
  });

  @override
  State<_NoMenuItemsEmptyState> createState() => _NoMenuItemsEmptyStateState();
}

class _NoMenuItemsEmptyStateState extends State<_NoMenuItemsEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine which state we're in: search, category filter, or fully empty
    final bool isFiltered = widget.isSearching || widget.isCategoryFiltered;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            kIsWeb ? 28 : 16,
            kIsWeb ? 60 : 48,
            kIsWeb ? 28 : 16,
            kIsWeb ? 40 : 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon with badge ─────────────────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: kIsWeb ? 96 : 80.sp,
                    height: kIsWeb ? 96 : 80.sp,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E6),
                      borderRadius:
                      BorderRadius.circular(kIsWeb ? 20 : 16.sp),
                    ),
                    child: Icon(
                      isFiltered
                          ? Icons.search_off_rounded
                          : Icons.fastfood_rounded,
                      color: const Color(0xFFE8622A),
                      size: kIsWeb ? 44 : 36.sp,
                    ),
                  ),
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      width: kIsWeb ? 20 : 16.sp,
                      height: kIsWeb ? 20 : 16.sp,
                      decoration: BoxDecoration(
                        color: isFiltered
                            ? const Color(0xFF6B7280)
                            : const Color(0xFFE8622A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: Icon(
                        isFiltered ? Icons.close : Icons.add,
                        color: Colors.white,
                        size: kIsWeb ? 11 : 9.sp,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: kIsWeb ? 28 : 22.sp),

              // ── Title ───────────────────────────────────────────────────
              Text(
                widget.isSearching
                    ? 'No results for "${widget.searchQuery}"'
                    : widget.isCategoryFiltered
                    ? 'No items in this category'
                    : AppLocalizations.of(context).noMenuItems,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  fontFamily: 'Poppins',
                ),
              ),

              SizedBox(height: kIsWeb ? 10 : 8.sp),

              // ── Subtitle ────────────────────────────────────────────────
              Text(
                isFiltered
                    ? 'Try adjusting your search or filter to find what you\'re looking for.'
                    : 'Add your first dish — include a photo, price\nand category to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: kIsWeb ? 14 : 12.sp,
                  color: const Color(0xFF6B7280),
                  height: 1.6,
                  fontFamily: 'Poppins',
                ),
              ),

              SizedBox(height: kIsWeb ? 32 : 26.sp),

              // ── CTA Buttons ─────────────────────────────────────────────
              if (isFiltered) ...[
                // For filtered state: primary = clear filter, secondary = add item
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onClearFilter,
                      icon: const Icon(Icons.filter_alt_off_outlined,
                          size: 16, color: Color(0xFF070B2D)),
                      label: const Text(
                        'Clear filter',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF070B2D),
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 20 : 16.sp,
                          vertical: kIsWeb ? 12 : 10.sp,
                        ),
                        side: const BorderSide(color: Color(0xFF070B2D)),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(kIsWeb ? 10 : 8.sp),
                        ),
                      ),
                    ),
                    SizedBox(width: kIsWeb ? 12 : 10.sp),
                    ElevatedButton.icon(
                      onPressed: widget.onAddItem,
                      icon: const Icon(Icons.add,
                          color: Colors.white, size: 16),
                      label: const Text(
                        'Add item',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF070B2D),
                        padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 20 : 16.sp,
                          vertical: kIsWeb ? 12 : 10.sp,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(kIsWeb ? 10 : 8.sp),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // For fully empty state: single prominent CTA
                ElevatedButton.icon(
                  onPressed: widget.onAddItem,
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: Text(
                    'Add your first item',
                    style: TextStyle(
                      fontSize: kIsWeb ? 14 : 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF070B2D),
                    padding: EdgeInsets.symmetric(
                      horizontal: kIsWeb ? 28 : 22.sp,
                      vertical: kIsWeb ? 14 : 12.sp,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(kIsWeb ? 12 : 10.sp),
                    ),
                    elevation: 0,
                  ),
                ),

                SizedBox(height: kIsWeb ? 44 : 36.sp),

                // ── Ghost preview cards ─────────────────────────────────
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: const [
                    _GhostMenuCard(
                        name: 'Paneer Tikka',
                        category: 'Starters',
                        price: '₹220',
                        isVeg: true,
                        opacity: 0.55),
                    _GhostMenuCard(
                        name: 'Butter Chicken',
                        category: 'Mains',
                        price: '₹340',
                        isVeg: false,
                        opacity: 0.35),
                    _GhostMenuCard(
                        name: 'Gulab Jamun',
                        category: 'Desserts',
                        price: '₹120',
                        isVeg: true,
                        opacity: 0.18),
                  ],
                ),

                SizedBox(height: kIsWeb ? 12 : 10.sp),

                Text(
                  'Ghost preview — items will appear here once added',
                  style: TextStyle(
                    fontSize: kIsWeb ? 11 : 10.sp,
                    color: const Color(0xFFC4C9D4),
                    letterSpacing: 0.2,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ghost menu card (preview placeholder)
// ─────────────────────────────────────────────────────────────────────────────

class _GhostMenuCard extends StatelessWidget {
  final String name;
  final String category;
  final String price;
  final bool isVeg;
  final double opacity;

  const _GhostMenuCard({
    required this.name,
    required this.category,
    required this.price,
    required this.isVeg,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: kIsWeb ? 160 : 130.sp,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kIsWeb ? 14 : 12.sp),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: kIsWeb ? 90 : 72.sp,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(kIsWeb ? 14 : 12.sp),
                  topRight: Radius.circular(kIsWeb ? 14 : 12.sp),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.fastfood_rounded,
                  color: const Color(0xFFCCCCCC),
                  size: kIsWeb ? 30 : 24.sp,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(kIsWeb ? 10 : 8.sp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: kIsWeb ? 13 : 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: kIsWeb ? 4 : 3.sp),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: kIsWeb ? 7 : 5.sp,
                          vertical: kIsWeb ? 2 : 1.5.sp,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFE8622A).withOpacity(0.35)),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: kIsWeb ? 9 : 8.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE8622A),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      SizedBox(width: kIsWeb ? 4 : 3.sp),
                      Container(
                        width: kIsWeb ? 10 : 8.sp,
                        height: kIsWeb ? 10 : 8.sp,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isVeg
                                ? const Color(0xFF388E3C)
                                : const Color(0xFFC62828),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Center(
                          child: Container(
                            width: kIsWeb ? 5 : 4.sp,
                            height: kIsWeb ? 5 : 4.sp,
                            decoration: BoxDecoration(
                              color: isVeg
                                  ? const Color(0xFF388E3C)
                                  : const Color(0xFFC62828),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: kIsWeb ? 6 : 4.sp),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: kIsWeb ? 14 : 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                      fontFamily: 'Poppins',
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

// ─────────────────────────────────────────────────────────────────────────────
// Category chip widget
// ─────────────────────────────────────────────────────────────────────────────

/// Theme palette (matches the admin panel's terracotta + navy palette)
const _kOrange  = Color(0xFFE8622A); // terracotta accent
const _kNavy    = Color(0xFF070B2D); // deep navy (Add-button colour)
const _kCream   = Color(0xFFFFF0E6); // warm cream tint
const _kBorder  = Color(0xFFE5E7EB); // default border

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        height: 36,
        decoration: BoxDecoration(
          // Selected  → terracotta fill; Unselected → cream tint or white
          color: isSelected ? _kOrange : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _kOrange : _kBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: _kOrange.withOpacity(0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : [],
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF4B5563),
              letterSpacing: 0.2,
              fontFamily: 'Poppins',
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildImage(Uint8List? imageBytes, ColorScheme colorScheme, bool isMobile) {
  if (imageBytes == null) {
    return Container(
      width: double.infinity, height: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
  return Image.memory(imageBytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
    errorBuilder: (context, error, stackTrace) => Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Icon(Icons.broken_image, color: colorScheme.onSurface.withOpacity(0.4), size: isMobile ? 30 : 36),
    ),
  );
}