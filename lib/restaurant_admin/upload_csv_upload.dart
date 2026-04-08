import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/models/category_model.dart';
import '../data/models/menu_item_model.dart';
import '../provider/csv_menu_upload_provider.dart';
import '../services/csv_parsing_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design tokens (match your existing app palette)
// ─────────────────────────────────────────────────────────────────────────────
const _kNavy    = Color(0xFF070B2D);
const _kIndigo  = Color(0xFF4F46E5);
const _kGreen   = Color(0xFF16A34A);
const _kRed     = Color(0xFFDC2626);
const _kGrey50  = Color(0xFFF9FAFB);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey700 = Color(0xFF374151);
const _kGrey900 = Color(0xFF111827);

// ─────────────────────────────────────────────────────────────────────────────
//  CsvUploadPage
// ─────────────────────────────────────────────────────────────────────────────

class CsvUploadPage extends ConsumerStatefulWidget {
  final String restaurantId;

  const CsvUploadPage({super.key, required this.restaurantId});

  @override
  ConsumerState<CsvUploadPage> createState() => _CsvUploadPageState();
}

class _CsvUploadPageState extends ConsumerState<CsvUploadPage> {
  CsvUploadNotifier get _notifier =>
      ref.read(csvUploadProvider(widget.restaurantId).notifier);

  bool get _isWide => MediaQuery.of(context).size.width >= 900;

  // ── File picker ───────────────────────────────────────────────────────────

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null || bytes.isEmpty) {
      _snack('Could not read file.', error: true);
      return;
    }
    await _notifier.parseCsv(
        String.fromCharCodes(bytes), widget.restaurantId);
  }

  // ── Sample CSV download ───────────────────────────────────────────────────

  void _downloadSample(bool advanced) {
    final svc = ref.read(csvParsingServiceProvider);
    final content = advanced
        ? svc.generateAdvancedSampleCsv()
        : svc.generateSimpleSampleCsv();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(advanced ? 'Advanced CSV sample' : 'Simple CSV sample'),
        content: SingleChildScrollView(
          child: SelectableText(
            content,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _kRed : _kGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(csvUploadProvider(widget.restaurantId));

    ref.listen(csvUploadProvider(widget.restaurantId), (_, next) {
      if (next.step == UploadStep.done) {
        _snack('✅ ${next.savedCount} items saved!');
      } else if (next.step == UploadStep.error &&
          next.errorMessage != null) {
        _snack(next.errorMessage!, error: true);
      }
    });

    return Scaffold(
      backgroundColor: _kGrey100,
      appBar: _appBar(state),
      body: state.items.isEmpty
          ? _emptyState(state)
          : _previewBody(state),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  App Bar
  // ─────────────────────────────────────────────────────────────────────────

  AppBar _appBar(CsvUploadState state) {
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
              color: _kNavy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.upload_file_rounded,
                color: Colors.white, size: 22),
          ),
          SizedBox(width: kIsWeb ? 14 : 10.sp),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('CSV Menu Upload',
                  style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 18 : 16.sp,
                      fontWeight: FontWeight.w600,
                      color: _kGrey900)),
              Text('Auto image · bulk import',
                  style: GoogleFonts.poppins(
                      fontSize: kIsWeb ? 11 : 10.sp,
                      color: _kGrey400)),
            ],
          ),
        ],
      ),
      actions: [
        _OutlineBtn(label: 'Simple CSV', onTap: () => _downloadSample(false)),
        const SizedBox(width: 8),
        _OutlineBtn(label: 'Advanced CSV', onTap: () => _downloadSample(true)),
        const SizedBox(width: 16),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Empty / upload state
  // ─────────────────────────────────────────────────────────────────────────

  Widget _emptyState(CsvUploadState state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drop zone
              GestureDetector(
                onTap: state.isLoading ? null : _pickAndParse,
                child: Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kGrey200, width: 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 16,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: state.isLoading
                      ? _loadingState(state)
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
                        child: const Icon(Icons.cloud_upload_outlined,
                            size: 38, color: _kIndigo),
                      ),
                      const SizedBox(height: 16),
                      Text('Click to upload CSV',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _kGrey900)),
                      const SizedBox(height: 6),
                      Text(
                          'Images auto-assigned via keyword match + Unsplash',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, color: _kGrey400)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Format cards
              _isWide
                  ? Row(children: [
                Expanded(child: _FormatCard(advanced: false)),
                const SizedBox(width: 16),
                Expanded(child: _FormatCard(advanced: true)),
              ])
                  : Column(children: [
                _FormatCard(advanced: false),
                const SizedBox(height: 12),
                _FormatCard(advanced: true),
              ]),

              const SizedBox(height: 20),

              // Image pipeline explanation
              _ImagePipelineCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingState(CsvUploadState state) {
    final isFetchingImages = state.step == UploadStep.fetchingImages;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: _kIndigo),
          const SizedBox(height: 16),
          Text(state.stepLabel,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kGrey700)),
          if (isFetchingImages) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.imageProgress,
                backgroundColor: _kGrey200,
                color: _kIndigo,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${state.imagesDone} / ${state.imagesTotal} images fetched',
              style: const TextStyle(fontSize: 12, color: _kGrey400),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Preview body
  // ─────────────────────────────────────────────────────────────────────────

  Widget _previewBody(CsvUploadState state) {
    return Column(
      children: [
        // ── Summary bar ─────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 24 : 16, vertical: 14),
          child: Row(
            children: [
              _Chip(
                  label: '${state.validItemCount} valid',
                  color: _kGreen,
                  bg: const Color(0xFFDCFCE7)),
              const SizedBox(width: 10),
              if (state.errorItemCount > 0)
                _Chip(
                    label: '${state.errorItemCount} errors',
                    color: _kRed,
                    bg: const Color(0xFFFEE2E2)),
              const Spacer(),
              TextButton.icon(
                onPressed: state.isLoading ? null : _notifier.reset,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset'),
                style: TextButton.styleFrom(foregroundColor: _kGrey400),
              ),
              const SizedBox(width: 8),
              _saveButton(state),
            ],
          ),
        ),

        // ── Progress bars ────────────────────────────────────────────────
        if (state.step == UploadStep.fetchingImages)
          _ProgressBar(
            label:
            'Fetching images ${state.imagesDone}/${state.imagesTotal}',
            value: state.imageProgress,
            color: _kIndigo,
          ),
        if (state.step == UploadStep.saving)
          _ProgressBar(
            label: 'Saving ${state.savedCount}/${state.totalToSave}',
            value: state.saveProgress,
            color: _kGreen,
          ),
        if (state.step == UploadStep.resolvingCategories)
          const LinearProgressIndicator(color: _kIndigo, minHeight: 3),

        // ── Item list ────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 24 : 12, vertical: 16),
            itemCount: state.items.length,
            itemBuilder: (context, index) => _MenuItemCard(
              item: state.items[index],
              index: index,
              categoryMap: state.categoryMap,
              onUpdate: (u) => _notifier.updateItem(index, u),
              onImageChange: (url) => _notifier.updateItemImage(index, url),
              onRemove: () => _notifier.removeItem(index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _saveButton(CsvUploadState state) {
    final busy = state.step == UploadStep.saving ||
        state.step == UploadStep.resolvingCategories;
    final done = state.step == UploadStep.done;

    return ElevatedButton.icon(
      onPressed: (busy || state.validItemCount == 0)
          ? null
          : () => _notifier.saveAll(widget.restaurantId),
      icon: busy
          ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white))
          : Icon(done ? Icons.check_circle : Icons.save_rounded, size: 18),
      label: Text(
        busy
            ? state.stepLabel
            : done
            ? 'Saved!'
            : 'Save All (${state.validItemCount})',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: done ? _kGreen : _kIndigo,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _MenuItemCard  — preview card with image thumbnail + Change Image button
// ─────────────────────────────────────────────────────────────────────────────

class _MenuItemCard extends StatefulWidget {
  final MenuItem item;
  final int index;
  final Map<String, CategoryModel> categoryMap;
  final ValueChanged<MenuItem> onUpdate;
  final ValueChanged<String> onImageChange;
  final VoidCallback onRemove;

  const _MenuItemCard({
    required this.item,
    required this.index,
    required this.categoryMap,
    required this.onUpdate,
    required this.onImageChange,
    required this.onRemove,
  });

  @override
  State<_MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<_MenuItemCard> {
  bool _expanded = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _imageUrlCtrl;
  late List<TextEditingController> _vNameCtrls;
  late List<TextEditingController> _vPriceCtrls;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _imageUrlCtrl = TextEditingController(text: widget.item.image);
    _selectedCategory = widget.item.categoryName.isEmpty
        ? null
        : widget.item.categoryName;
    _initVariants();
  }

  void _initVariants() {
    _vNameCtrls =
        widget.item.variants.map((v) => TextEditingController(text: v.name)).toList();
    _vPriceCtrls = widget.item.variants
        .map((v) => TextEditingController(text: v.price.toInt().toString()))
        .toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _imageUrlCtrl.dispose();
    for (final c in [..._vNameCtrls, ..._vPriceCtrls]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyChanges() {
    final variants = <MenuVariant>[];
    for (int i = 0; i < _vNameCtrls.length; i++) {
      final name = _vNameCtrls[i].text.trim();
      final price = double.tryParse(_vPriceCtrls[i].text.trim()) ?? -1;
      if (name.isNotEmpty && price >= 0) {
        variants.add(MenuVariant(name: name, price: price));
      }
    }
    final hasError =
        _nameCtrl.text.trim().isEmpty || variants.isEmpty;
    widget.onUpdate(widget.item.copyWith(
      name: _nameCtrl.text.trim(),
      categoryName: _selectedCategory ?? widget.item.categoryName,
      image: _imageUrlCtrl.text.trim(),
      variants: variants,
      hasError: hasError,
      errorMessage: hasError ? 'Name or variants invalid.' : null,
    ));
    setState(() => _expanded = false);
  }

  void _addVariant() => setState(() {
    _vNameCtrls.add(TextEditingController());
    _vPriceCtrls.add(TextEditingController());
  });

  void _removeVariant(int i) => setState(() {
    _vNameCtrls[i].dispose();
    _vPriceCtrls[i].dispose();
    _vNameCtrls.removeAt(i);
    _vPriceCtrls.removeAt(i);
  });

  // ── Change Image dialog ───────────────────────────────────────────────────

  void _showChangeImageDialog() {
    final ctrl = TextEditingController(text: widget.item.image);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Image',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview current
            if (widget.item.image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  widget.item.image,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: _kGrey100,
                    child: const Icon(Icons.broken_image,
                        color: _kGrey400, size: 40),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Text('Paste image URL:',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              decoration: _inputDecor('https://...'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                widget.onImageChange(url);
                _imageUrlCtrl.text = url;
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasError = item.hasError;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: hasError ? const Color(0xFFFFF5F5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hasError ? const Color(0xFFFCA5A5) : _kGrey200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // ── Row: image thumbnail + info + actions ──────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image thumbnail ─────────────────────────────────────
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item.image.isNotEmpty
                          ? Image.network(
                        item.image,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _imagePlaceholder(),
                      )
                          : _imagePlaceholder(),
                    ),
                    // Change image overlay button
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showChangeImageDialog,
                        child: Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(10)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Change',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                // ── Item info ───────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name.isEmpty ? 'Unnamed Item' : item.name,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kGrey900),
                      ),
                      if (item.categoryName.isNotEmpty)
                        Text(item.categoryName,
                            style: const TextStyle(
                                fontSize: 12, color: _kGrey400)),
                      if (hasError && item.errorMessage != null)
                        Text(item.errorMessage!,
                            style: const TextStyle(
                                fontSize: 11, color: _kRed)),
                      const SizedBox(height: 6),
                      // Variant chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: item.variants
                            .map((v) => _VariantChip(v))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                // ── Actions ─────────────────────────────────────────────
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                          _expanded
                              ? Icons.expand_less
                              : Icons.edit_outlined,
                          size: 20,
                          color: _kGrey400),
                      onPressed: () =>
                          setState(() => _expanded = !_expanded),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: Color(0xFFE15757)),
                      onPressed: widget.onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Expandable edit panel ──────────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Name
                  _label('Item Name'),
                  const SizedBox(height: 6),
                  TextField(
                      controller: _nameCtrl,
                      decoration: _inputDecor('e.g. Margherita Pizza')),
                  const SizedBox(height: 12),

                  // Category
                  _label('Category'),
                  const SizedBox(height: 6),
                  _CategoryDropdown(
                    categoryMap: widget.categoryMap,
                    selectedName: _selectedCategory,
                    onChanged: (v) =>
                        setState(() => _selectedCategory = v),
                  ),
                  const SizedBox(height: 12),

                  // Image URL
                  _label('Image URL'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                            controller: _imageUrlCtrl,
                            decoration:
                            _inputDecor('https://...')),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _showChangeImageDialog,
                        icon: const Icon(Icons.image_search, size: 16),
                        label: const Text('Preview'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kIndigo,
                          side: const BorderSide(color: _kIndigo),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Variants
                  Row(
                    children: [
                      _label('Variants'),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addVariant,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add variant'),
                        style: TextButton.styleFrom(
                            foregroundColor: _kIndigo,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(_vNameCtrls.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 3,
                              child: TextField(
                                  controller: _vNameCtrls[i],
                                  decoration:
                                  _inputDecor('e.g. Regular'))),
                          const SizedBox(width: 10),
                          Expanded(
                              flex: 2,
                              child: TextField(
                                  controller: _vPriceCtrls[i],
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecor('₹ Price'))),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Color(0xFFE15757), size: 20),
                            onPressed: _vNameCtrls.length > 1
                                ? () => _removeVariant(i)
                                : null,
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _applyChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text('Apply Changes',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
    width: 72,
    height: 72,
    color: _kGrey100,
    child: const Icon(Icons.fastfood_rounded,
        color: _kGrey400, size: 30),
  );

  Widget _label(String text) => Text(text,
      style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _kGrey700));
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small reusable widgets
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
    final names =
    categoryMap.values.map((c) => c.name).toSet().toList()..sort();
    final effective = names.contains(selectedName) ? selectedName : null;

    return DropdownButtonFormField<String>(
      value: effective,
      hint: const Text('Select category'),
      decoration: _inputDecor(''),
      items: names
          .map((n) => DropdownMenuItem(value: n, child: Text(n)))
          .toList(),
      onChanged: onChanged,
      isExpanded: true,
      style: const TextStyle(fontSize: 14, color: _kGrey900),
    );
  }
}

class _VariantChip extends StatelessWidget {
  final MenuVariant variant;
  const _VariantChip(this.variant);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${variant.name} · ₹${variant.price.toInt()}',
        style: const TextStyle(
            fontSize: 11, color: _kIndigo, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _Chip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ProgressBar(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: _kGrey400)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: _kGrey200,
              color: color,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.download_rounded, size: 15),
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kIndigo,
        side: const BorderSide(color: _kGrey200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    final color = advanced ? const Color(0xFF7C3AED) : _kIndigo;
    final bg =
    advanced ? const Color(0xFFF5F3FF) : const Color(0xFFEFF6FF);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
                advanced
                    ? Icons.layers_rounded
                    : Icons.table_rows_rounded,
                size: 15,
                color: color),
            const SizedBox(width: 6),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(example,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: _kGrey700,
                    height: 1.7)),
          ),
        ],
      ),
    );
  }
}

class _ImagePipelineCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGrey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome, size: 16, color: _kIndigo),
            const SizedBox(width: 8),
            Text('Auto Image Assignment',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kGrey900)),
          ]),
          const SizedBox(height: 10),
          _PipelineStep(
              n: '1',
              label: 'Keyword match',
              detail: 'paneer → curry image, biryani → biryani image…',
              color: _kGreen),
          _PipelineStep(
              n: '2',
              label: 'Unsplash API (via Cloud Function)',
              detail: 'Dynamic photo for any dish name',
              color: _kIndigo),
          _PipelineStep(
              n: '3',
              label: 'Category fallback',
              detail: 'Generic image for Ice Cream, Pizza, etc.',
              color: _kGrey400),
        ],
      ),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  final String n, label, detail;
  final Color color;
  const _PipelineStep(
      {required this.n,
        required this.label,
        required this.detail,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration:
            BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(n,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _kGrey700)),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 11.5, color: _kGrey400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared InputDecoration helper
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDecor(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: _kGrey50,
  contentPadding:
  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _kGrey200)),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _kGrey200)),
  focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _kIndigo)),
);