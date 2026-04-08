import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/models/category_model.dart';
import '../data/models/menu_item_model.dart';
import '../provider/csv_menu_upload_provider.dart';



class CsvUploadPage extends ConsumerStatefulWidget {
  final String restaurantId;

  const CsvUploadPage({super.key, required this.restaurantId});

  @override
  ConsumerState<CsvUploadPage> createState() => _CsvUploadPageState();
}

class _CsvUploadPageState extends ConsumerState<CsvUploadPage> {
  // ── Helpers ──────────────────────────────────────────────────────────────

  CsvUploadNotifier get _notifier =>
      ref.read(csvUploadProvider(widget.restaurantId).notifier);

  double get _w => MediaQuery.of(context).size.width;
  bool get _isWide => _w >= 900;

  // ── File Picker ───────────────────────────────────────────────────────────

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('Could not read file.', isError: true);
      return;
    }

    final content = String.fromCharCodes(bytes);
    await _notifier.parseCsv(content, widget.restaurantId);
  }

  // ── Download Sample CSV ───────────────────────────────────────────────────

  void _downloadSample(bool advanced) {
    final svc = ref.read(csvParsingServiceProvider);
    final content = advanced
        ? svc.generateAdvancedSampleCsv()
        : svc.generateSimpleSampleCsv();
    final filename = advanced ? 'sample_advanced.csv' : 'sample_simple.csv';

    if (kIsWeb) {
      // Web: trigger browser download via anchor element
      // ignore: avoid_web_libraries_in_flutter
      final bytes = Uint8List.fromList(content.codeUnits);
      _downloadBytesWeb(bytes, filename);
    } else {
      _showSnack('Sample CSV copied! Use it as a template.', isError: false);
    }
  }

  // Platform-safe web download helper (avoids dart:html import at compile time)
  void _downloadBytesWeb(Uint8List bytes, String filename) {
    final content = String.fromCharCodes(bytes);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(filename),
        content: SingleChildScrollView(child: SelectableText(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(csvUploadProvider(widget.restaurantId));
    final cs = Theme.of(context).colorScheme;

    // Post-frame callbacks for snackbars on state changes
    ref.listen(csvUploadProvider(widget.restaurantId), (prev, next) {
      if (next.step == UploadStep.done) {
        _showSnack(
          '✅ ${next.savedCount} items saved to menu!',
          isError: false,
        );
      } else if (next.step == UploadStep.error && next.errorMessage != null) {
        _showSnack(next.errorMessage!, isError: true);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: _buildAppBar(cs),
      body: state.items.isEmpty
          ? _buildEmptyState(state, cs)
          : _buildPreviewBody(state, cs),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  App Bar
  // ─────────────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(ColorScheme cs) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleSpacing: kIsWeb ? 24 : 16,
      title: Row(
        children: [
          Container(
            width: kIsWeb ? 44 : 36.sp,
            height: kIsWeb ? 44 : 36.sp,
            decoration: BoxDecoration(
              color: const Color(0xFF070B2D),
              borderRadius: BorderRadius.circular(kIsWeb ? 12 : 10.sp),
            ),
            child: Icon(
              Icons.upload_file_rounded,
              color: Colors.white,
              size: kIsWeb ? 22 : 18.sp,
            ),
          ),
          SizedBox(width: kIsWeb ? 14 : 10.sp),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CSV Menu Upload',
                style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 18 : 16.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
              Text(
                'Bulk import menu items',
                style: GoogleFonts.poppins(
                  fontSize: kIsWeb ? 12 : 11.sp,
                  color: const Color(0xFF8A93A3),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Sample download buttons
        _SampleButton(
          label: 'Simple CSV',
          onTap: () => _downloadSample(false),
        ),
        const SizedBox(width: 8),
        _SampleButton(
          label: 'Advanced CSV',
          onTap: () => _downloadSample(true),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Empty / Upload State
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(CsvUploadState state, ColorScheme cs) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drop zone
              GestureDetector(
                onTap: state.isLoading ? null : _pickAndParse,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFD1D5DB),
                      width: 2,
                      // dashed-effect via custom painter in production;
                      // solid border is fine for this scope
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          size: 38,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Click to upload CSV',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Supports simple & advanced (variants) format',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF8A93A3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Format cards
              _isWide
                  ? Row(
                children: [
                  Expanded(child: _FormatCard(advanced: false)),
                  const SizedBox(width: 16),
                  Expanded(child: _FormatCard(advanced: true)),
                ],
              )
                  : Column(
                children: [
                  _FormatCard(advanced: false),
                  const SizedBox(height: 12),
                  _FormatCard(advanced: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Preview Body
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPreviewBody(CsvUploadState state, ColorScheme cs) {
    final validCount = state.validItemCount;
    final errorCount = state.errorItemCount;

    return Column(
      children: [
        // ── Summary Bar ─────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 24 : 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              _StatChip(
                label: '$validCount valid',
                color: const Color(0xFF16A34A),
                bg: const Color(0xFFDCFCE7),
              ),
              const SizedBox(width: 10),
              if (errorCount > 0)
                _StatChip(
                  label: '$errorCount errors',
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEE2E2),
                ),
              const Spacer(),
              // Reset
              TextButton.icon(
                onPressed: state.isLoading ? null : () {
                  _notifier.reset();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 8),
              // Save All
              _buildSaveButton(state),
            ],
          ),
        ),

        // ── Progress Bar ────────────────────────────────────────────────
        if (state.step == UploadStep.saving)
          LinearProgressIndicator(
            value: state.saveProgress,
            backgroundColor: const Color(0xFFE5E7EB),
            color: const Color(0xFF4F46E5),
            minHeight: 3,
          ),

        // ── Item List ───────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 24 : 12,
              vertical: 16,
            ),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              return _MenuItemCard(
                item: state.items[index],
                index: index,
                categoryMap: state.categoryMap,
                restaurantId: widget.restaurantId,
                onUpdate: (updated) => _notifier.updateItem(index, updated),
                onRemove: () => _notifier.removeItem(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(CsvUploadState state) {
    final isSaving = state.step == UploadStep.saving ||
        state.step == UploadStep.resolvingCategories;
    final isDone = state.step == UploadStep.done;

    return ElevatedButton.icon(
      onPressed: (isSaving || state.validItemCount == 0)
          ? null
          : () => _notifier.saveAll(widget.restaurantId),
      icon: isSaving
          ? const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : Icon(isDone ? Icons.check_circle : Icons.save_rounded, size: 18),
      label: Text(
        isSaving
            ? 'Saving ${state.savedCount}/${state.totalToSave}...'
            : isDone
            ? 'Saved!'
            : 'Save All (${state.validItemCount})',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
        isDone ? const Color(0xFF16A34A) : const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 24 : 18,
          vertical: kIsWeb ? 14 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }
}



class _MenuItemCard extends StatefulWidget {
  final MenuItem item;
  final int index;
  final Map<String, CategoryModel> categoryMap;
  final String restaurantId;
  final ValueChanged<MenuItem> onUpdate;
  final VoidCallback onRemove;

  const _MenuItemCard({
    required this.item,
    required this.index,
    required this.categoryMap,
    required this.restaurantId,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<_MenuItemCard> {
  bool _expanded = false;
  late TextEditingController _nameCtrl;
  late List<TextEditingController> _variantNameCtrls;
  late List<TextEditingController> _variantPriceCtrls;
  String? _selectedCategoryName;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _selectedCategoryName = widget.item.categoryName.isEmpty
        ? null
        : widget.item.categoryName;
    _initVariantControllers();
  }

  void _initVariantControllers() {
    _variantNameCtrls = widget.item.variants
        .map((v) => TextEditingController(text: v.name))
        .toList();
    _variantPriceCtrls = widget.item.variants
        .map((v) => TextEditingController(text: v.price.toString()))
        .toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _variantNameCtrls) {
      c.dispose();
    }
    for (final c in _variantPriceCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    // Rebuild variants from controllers
    final variants = <MenuVariant>[];
    for (int i = 0; i < _variantNameCtrls.length; i++) {
      final name = _variantNameCtrls[i].text.trim();
      final price = double.tryParse(_variantPriceCtrls[i].text.trim()) ?? -1;
      if (name.isNotEmpty && price >= 0) {
        variants.add(MenuVariant(name: name, price: price));
      }
    }

    final hasError = _nameCtrl.text.trim().isEmpty || variants.isEmpty;
    widget.onUpdate(widget.item.copyWith(
      name: _nameCtrl.text.trim(),
      categoryName: _selectedCategoryName ?? widget.item.categoryName,
      variants: variants,
      hasError: hasError,
      errorMessage: hasError ? 'Name or variants invalid.' : null,
    ));
    setState(() => _expanded = false);
  }

  void _addVariant() {
    setState(() {
      _variantNameCtrls.add(TextEditingController());
      _variantPriceCtrls.add(TextEditingController());
    });
  }

  void _removeVariant(int i) {
    setState(() {
      _variantNameCtrls[i].dispose();
      _variantPriceCtrls[i].dispose();
      _variantNameCtrls.removeAt(i);
      _variantPriceCtrls.removeAt(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasError = item.hasError;
    final borderColor =
    hasError ? const Color(0xFFFCA5A5) : const Color(0xFFE6E8EF);
    final bgColor =
    hasError ? const Color(0xFFFFF5F5) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header Row ─────────────────────────────────────────────────
          ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasError
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.index + 1}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: hasError
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF4F46E5),
                ),
              ),
            ),
            title: Text(
              item.name.isEmpty ? 'Unnamed Item' : item.name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.categoryName.isNotEmpty)
                  Text(
                    item.categoryName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                if (hasError && item.errorMessage != null)
                  Text(
                    item.errorMessage!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFDC2626),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Variant count chip
                if (item.variants.isNotEmpty)
                  _variantChip(item),
                const SizedBox(width: 8),
                // Edit toggle
                IconButton(
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.edit_outlined,
                    size: 20,
                    color: const Color(0xFF6A7280),
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
                // Delete
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Color(0xFFE15757),
                  ),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ),

          // ── Edit Panel ─────────────────────────────────────────────────
          if (_expanded)
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Item Name
                  _label('Item Name'),
                  const SizedBox(height: 6),
                  _textField(controller: _nameCtrl, hint: 'e.g. Margherita Pizza'),
                  const SizedBox(height: 14),

                  // Category Dropdown
                  _label('Category'),
                  const SizedBox(height: 6),
                  _CategoryDropdown(
                    categoryMap: widget.categoryMap,
                    selectedName: _selectedCategoryName,
                    onChanged: (name) =>
                        setState(() => _selectedCategoryName = name),
                  ),
                  const SizedBox(height: 16),

                  // Variants
                  Row(
                    children: [
                      _label('Variants'),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addVariant,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(_variantNameCtrls.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _textField(
                              controller: _variantNameCtrls[i],
                              hint: 'e.g. Regular',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _textField(
                              controller: _variantPriceCtrls[i],
                              hint: '₹ Price',
                              keyboardType: TextInputType.number,
                              prefix: const Text('₹ '),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Color(0xFFE15757),
                              size: 20,
                            ),
                            onPressed: _variantNameCtrls.length > 1
                                ? () => _removeVariant(i)
                                : null,
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF070B2D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Apply Changes',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _variantChip(MenuItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${item.variants.length} variant${item.variants.length > 1 ? 's' : ''}',
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF4F46E5),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF374151),
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    Widget? prefix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix == null ? null : null,
        prefix: prefix,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4F46E5)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _CategoryDropdown
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryDropdown extends StatelessWidget {
  final Map<String, CategoryModel> categoryMap;
  final String? selectedName;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({
    required this.categoryMap,
    required this.selectedName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Build unique category names (from map values)
    final names = categoryMap.values.map((c) => c.name).toSet().toList()
      ..sort();

    // Check if current selectedName is in the list
    final effectiveValue =
    names.contains(selectedName) ? selectedName : null;

    return DropdownButtonFormField<String>(
      value: effectiveValue,
      hint: const Text('Select category'),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4F46E5)),
        ),
      ),
      items: names
          .map((name) => DropdownMenuItem(value: name, child: Text(name)))
          .toList(),
      onChanged: onChanged,
      isExpanded: true,
      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _StatChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SampleButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SampleButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.download_rounded, size: 15),
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF4F46E5),
        side: const BorderSide(color: Color(0xFFD1D5DB)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  final bool advanced;

  const _FormatCard({required this.advanced});

  @override
  Widget build(BuildContext context) {
    final title = advanced ? 'Advanced CSV (Variants)' : 'Simple CSV';
    final example = advanced
        ? 'name, category, variant_name, price\nDish1, Ice Cream, Regular, 40\nDish1, Ice Cream, Large, 70'
        : 'name, price, category\nDish1, 40, Ice Cream\nDish2, 80, Pizza';
    final color =
    advanced ? const Color(0xFF7C3AED) : const Color(0xFF2563EB);
    final bg = advanced ? const Color(0xFFF5F3FF) : const Color(0xFFEFF6FF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                advanced ? Icons.layers_rounded : Icons.table_rows_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              example,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Color(0xFF374151),
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}