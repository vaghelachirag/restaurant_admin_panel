import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../data/models/category_model.dart';
import '../data/models/menu_item_model.dart';
import '../provider/csv_menu_upload_provider.dart';
import '../services/csv_parsing_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design tokens
// ─────────────────────────────────────────────────────────────────────────────
const _kBg          = Color(0xFFFFF3EE);
const _kCard        = Color(0xFFFFFFFF);
const _kOrange      = Color(0xFFE8622A);
const _kOrangeLight = Color(0xFFFFF0E8);
const _kOrangeBg    = Color(0xFFFEE9DE);
const _kTextDark    = Color(0xFF1A1A1A);
const _kTextMid     = Color(0xFF666666);
const _kTextLight   = Color(0xFF999999);
const _kBorder      = Color(0xFFEEEEEE);
const _kGreen       = Color(0xFF2ECC71);
const _kRed         = Color(0xFFE74C3C);
const _kGreenBg     = Color(0xFFEBF9F5);
const _kRedBg       = Color(0xFFFEE2E2);

const _kImgBBKey = "a923bc17d28cd6fe1be417700456eb69";

TextStyle _p(double size, FontWeight weight, Color color) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

// ─────────────────────────────────────────────────────────────────────────────
//  ImgBB upload  (same as menu_page.dart)
// ─────────────────────────────────────────────────────────────────────────────
Future<String?> _uploadToImgBB(Uint8List bytes, String filename) async {
  try {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.imgbb.com/1/upload?key=$_kImgBBKey'),
    );
    req.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: filename));
    final res  = await req.send();
    final body = await res.stream.bytesToString();
    final data = json.decode(body);
    return data['data']['url'] as String?;
  } catch (e) {
    if (kDebugMode) print('IMGBB ERROR: $e');
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Claude Vision — read a menu image and return CSV rows.
//
//  The parser (CsvParsingService) uses Simple CSV format:
//    header  →  name,price,category
//    rows    →  Butter Chapati,10,Roti
//               Paneer Butter Masala,160,Paneer
//
//  We ask Claude to output ONLY rows in that exact format, no header.
//  We build the header ourselves and stitch rows together.
// ─────────────────────────────────────────────────────────────────────────────
Future<String> _readMenuImage(String imgbbUrl) async {
  const system = '''
You are a restaurant menu reader.
Look at the menu image and extract every dish you can see.

Return ONLY plain CSV rows — no header line, no markdown, no explanations.

Format for each dish:
dish_name,price,category

Rules:
- dish_name: exact name as shown on the menu
- price: number only (no ₹ or Rs or commas), e.g. 80
- category: the section/category heading the dish belongs to (e.g. Roti, Rice, Paneer, Starters)
- If price is not visible, use 0
- If category heading is not visible, use Other
- One dish per line
- Do not add any blank lines or extra text
''';

  try {
    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
      },
      body: json.encode({
        'model': 'claude-opus-4-5',
        'max_tokens': 1024,
        'system': system,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {'type': 'url', 'url': imgbbUrl},
              },
              {
                'type': 'text',
                'text': 'Read all the menu items from this image and return the CSV rows.',
              },
            ],
          }
        ],
      }),
    );

    if (res.statusCode == 200) {
      final body    = json.decode(res.body);
      final rawText = (body['content'] as List)
          .whereType<Map>()
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'] as String)
          .join()
          .trim();

      // Strip any accidental markdown fences
      final cleaned = rawText
          .replaceAll(RegExp(r'^```[a-z]*\n?', multiLine: true), '')
          .replaceAll(RegExp(r'```$',           multiLine: true), '')
          .trim();

      // Validate: keep only lines that look like "text,number,text"
      final validRows = cleaned
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .where((l) {
        final parts = l.split(',');
        // Must have exactly 3 parts; 2nd must be numeric
        if (parts.length < 3) return false;
        final price = parts[1].trim();
        return double.tryParse(price) != null;
      })
          .join('\n');

      return validRows;
    } else {
      if (kDebugMode) print('CLAUDE ${res.statusCode}: ${res.body}');
      return '';
    }
  } catch (e) {
    if (kDebugMode) print('CLAUDE ERROR: $e');
    return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Per-image lifecycle model
// ─────────────────────────────────────────────────────────────────────────────
class _PickedImage {
  final String    name;
  final Uint8List bytes;

  String? imgbbUrl;
  String? csvRows;     // validated rows extracted by Claude (no header)
  int     rowCount = 0;

  bool uploading = false;
  bool reading   = false;
  bool done      = false;
  bool failed    = false;

  _PickedImage({required this.name, required this.bytes});
}

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

  final List<_PickedImage> _images = [];
  bool _isProcessing = false;
  bool _csvParsing   = false;   // true while _pickCsvFile is running

  // ── Step 1  Pick images ───────────────────────────────────────────────────
  Future<void> _pickImages() async {
    if (_isProcessing) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files
        .where((f) => f.bytes != null && f.bytes!.isNotEmpty)
        .map((f) => _PickedImage(name: f.name, bytes: f.bytes!))
        .toList();
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked));
  }

  // ── Step 2  Process: upload → read → stitch CSV → parseCsv ───────────────
  Future<void> _processImages() async {
    if (_isProcessing || _images.isEmpty) return;
    setState(() => _isProcessing = true);

    // 2a. Upload each image to ImgBB
    for (final img in _images) {
      if (img.imgbbUrl != null || img.failed) continue;
      setState(() => img.uploading = true);
      final url = await _uploadToImgBB(img.bytes, img.name);
      setState(() {
        img.uploading = false;
        if (url != null) img.imgbbUrl = url;
        else             img.failed   = true;
      });
    }

    // 2b. Send each uploaded image to Claude to read menu items
    for (final img in _images) {
      if (img.imgbbUrl == null || img.csvRows != null || img.failed) continue;
      setState(() => img.reading = true);
      final rows = await _readMenuImage(img.imgbbUrl!);
      setState(() {
        img.reading  = false;
        img.csvRows  = rows;
        img.rowCount = rows.isEmpty
            ? 0
            : rows.split('\n').where((l) => l.trim().isNotEmpty).length;
        img.done     = true;
        if (rows.isEmpty) img.failed = true;
      });
    }

    // 2c. Stitch into Simple CSV that CsvParsingService expects exactly:
    //       name,price,category
    //       Butter Chapati,10,Roti
    //       Paneer Butter Masala,160,Paneer
    final buf = StringBuffer();
    buf.writeln('name,price,category');          // exact header the parser uses

    for (final img in _images) {
      if (img.csvRows == null || img.csvRows!.isEmpty) continue;
      buf.writeln(img.csvRows!.trim());
    }

    final csvString = buf.toString().trim();

    // Guard: at least one data row beyond the header
    final lines = csvString.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) {
      _snack('No menu items could be read from the images.', error: true);
      setState(() => _isProcessing = false);
      return;
    }

    // 2d. Hand off to the existing provider — completely unchanged
    await _notifier.parseCsv(csvString, widget.restaurantId);

    setState(() => _isProcessing = false);
  }

  void _removeImage(int i) {
    if (_isProcessing) return;
    setState(() => _images.removeAt(i));
  }

  void _clearImages() {
    if (_isProcessing) return;
    setState(() => _images.clear());
  }

  // ── Legacy CSV picker ─────────────────────────────────────────────────────
  Future<void> _pickCsvFile() async {
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
    setState(() => _csvParsing = true);
    await _notifier.parseCsv(
        String.fromCharCodes(bytes), widget.restaurantId);
    if (mounted) setState(() => _csvParsing = false);
  }

  void _downloadSample(bool advanced) {
    final svc     = ref.read(csvParsingServiceProvider);
    final content = advanced
        ? svc.generateAdvancedSampleCsv()
        : svc.generateSimpleSampleCsv();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(advanced ? 'Advanced CSV sample' : 'Simple CSV sample',
            style: _p(16, FontWeight.w600, _kTextDark)),
        content: SingleChildScrollView(
          child: SelectableText(content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: _kOrange),
              child: Text('Close', style: _p(13, FontWeight.w600, _kOrange))),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
            error
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg, style: _p(13, FontWeight.w500, Colors.white))),
      ]),
      backgroundColor: error ? _kRed : _kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(csvUploadProvider(widget.restaurantId));

    ref.listen(csvUploadProvider(widget.restaurantId), (_, next) {
      if (next.step == UploadStep.done) {
        _snack('✅ ${next.savedCount} items saved!');
      } else if (next.step == UploadStep.error && next.errorMessage != null) {
        _snack(next.errorMessage!, error: true);
      }
    });

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _appBar(state),
      body: state.items.isEmpty
          ? (_images.isEmpty ? _emptyState() : _imageStage())
          : _previewBody(state),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  AppBar _appBar(CsvUploadState state) {
    return AppBar(
      elevation: 0,
      backgroundColor: _kCard,
      surfaceTintColor: Colors.transparent,
      titleSpacing: kIsWeb ? 24 : 16,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _kBorder),
      ),
      title: Row(children: [
        Container(
          width: kIsWeb ? 44 : 36.sp,
          height: kIsWeb ? 44 : 36.sp,
          decoration: BoxDecoration(
              color: _kOrange,
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.upload_file_rounded,
              color: Colors.white, size: 22),
        ),
        SizedBox(width: kIsWeb ? 14 : 10.sp),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Menu Image Upload',
                style: _p(kIsWeb ? 17 : 15, FontWeight.w700, _kTextDark)),
            Text('Photo → CSV → Menu items',
                style: _p(kIsWeb ? 11 : 10, FontWeight.w400, _kTextLight)),
          ],
        ),
      ]),
      actions: [
        _csvParsing
            ? OutlinedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: _kOrange),
          ),
          label: Text('Parsing…',
              style: _p(12, FontWeight.w500, _kOrange)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kOrange,
            side: const BorderSide(color: _kOrange),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        )
            : _OutlineBtn(
            label: 'Upload CSV',
            icon: Icons.table_chart_outlined,
            onTap: _pickCsvFile),
        const SizedBox(width: 8),
        _OutlineBtn(
            label: 'Sample CSV',
            icon: Icons.download_rounded,
            onTap: () => _downloadSample(false)),
        const SizedBox(width: 16),
      ],
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _emptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drop zone
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _kOrange.withOpacity(0.35), width: 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 16,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                            color: _kOrangeBg,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 42, color: _kOrange),
                      ),
                      const SizedBox(height: 18),
                      Text('Tap to select menu images',
                          style: _p(16, FontWeight.w600, _kTextDark)),
                      const SizedBox(height: 6),
                      Text(
                          'Pick photos of your menu — AI converts them to CSV',
                          style: _p(12.5, FontWeight.w400, _kTextLight)),
                      const SizedBox(height: 18),
                      // Step pills
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6, runSpacing: 8,
                        children: [
                          _StepPill(n: '1', label: 'Pick photos'),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 13, color: _kTextLight),
                          _StepPill(n: '2', label: 'Upload to cloud'),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 13, color: _kTextLight),
                          _StepPill(n: '3', label: 'AI reads menu'),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 13, color: _kTextLight),
                          _StepPill(n: '4', label: 'Review & save'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // CSV format preview card
              _CsvFormatCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Image stage ───────────────────────────────────────────────────────────
  Widget _imageStage() {
    final total  = _images.length;
    final done   = _images.where((i) => i.done && !i.failed).length;
    final failed = _images.where((i) => i.failed).length;
    final totalRows =
    _images.fold<int>(0, (sum, i) => sum + i.rowCount);

    return Column(
      children: [
        // Top bar
        Container(
          color: _kCard,
          padding: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 24 : 16, vertical: 14),
          child: Row(children: [
            _Chip(
                label: '$total image${total == 1 ? '' : 's'}',
                color: _kOrange, bg: _kOrangeLight),
            if (done > 0) ...[
              const SizedBox(width: 8),
              _Chip(
                  label: '$totalRows item${totalRows == 1 ? '' : 's'} found',
                  color: _kGreen, bg: _kGreenBg),
            ],
            if (failed > 0) ...[
              const SizedBox(width: 8),
              _Chip(label: '$failed failed', color: _kRed, bg: _kRedBg),
            ],
            const Spacer(),
            if (!_isProcessing) ...[
              TextButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text('Add more',
                    style: _p(13, FontWeight.w500, _kOrange)),
                style: TextButton.styleFrom(foregroundColor: _kOrange),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _clearImages,
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: Text('Clear',
                    style: _p(13, FontWeight.w500, _kTextMid)),
                style: TextButton.styleFrom(foregroundColor: _kTextMid),
              ),
              const SizedBox(width: 8),
            ],
            _processButton(),
          ]),
        ),

        // Progress bar
        if (_isProcessing)
          _ProgressBar(
            label: _progressLabel(),
            value: total == 0 ? 0 : done / total,
            color: _kOrange,
          ),

        // Grid
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(kIsWeb ? 24 : 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _isWide ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.80,
            ),
            itemCount: _images.length,
            itemBuilder: (ctx, i) => _ImageTile(
              img: _images[i],
              onRemove: _isProcessing ? null : () => _removeImage(i),
            ),
          ),
        ),
      ],
    );
  }

  String _progressLabel() {
    if (_images.any((i) => i.uploading)) return 'Uploading to cloud…';
    if (_images.any((i) => i.reading))   return 'Reading menu items…';
    return 'Building CSV…';
  }

  Widget _processButton() {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : _processImages,
      icon: _isProcessing
          ? const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.auto_awesome_rounded, size: 18),
      label: Text(
        _isProcessing ? 'Processing…' : 'Convert to CSV',
        style: _p(13, FontWeight.w600, Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  // ── Preview body  ─────────────────────────────────────────────────────────
  //  100% identical to original CsvUploadPage — zero changes to this section
  Widget _previewBody(CsvUploadState state) {
    return Column(
      children: [
        Container(
          color: _kCard,
          padding: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 24 : 16, vertical: 14),
          child: Row(children: [
            _Chip(
                label: '${state.validItemCount} valid',
                color: _kGreen, bg: _kGreenBg),
            const SizedBox(width: 10),
            if (state.errorItemCount > 0)
              _Chip(
                  label: '${state.errorItemCount} errors',
                  color: _kRed, bg: _kRedBg),
            const Spacer(),
            TextButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () {
                _notifier.reset();
                setState(() => _images.clear());
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Reset',
                  style: _p(13, FontWeight.w500, _kTextLight)),
              style: TextButton.styleFrom(foregroundColor: _kTextLight),
            ),
            const SizedBox(width: 8),
            _saveButton(state),
          ]),
        ),
        if (state.step == UploadStep.fetchingImages)
          _ProgressBar(
              label:
              'Fetching images ${state.imagesDone}/${state.imagesTotal}',
              value: state.imageProgress, color: _kOrange),
        if (state.step == UploadStep.saving)
          _ProgressBar(
              label: 'Saving ${state.savedCount}/${state.totalToSave}',
              value: state.saveProgress, color: _kGreen),
        if (state.step == UploadStep.resolvingCategories)
          const LinearProgressIndicator(color: _kOrange, minHeight: 3),
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
              onImageChange: (url) =>
                  _notifier.updateItemImage(index, url),
              onRemove: () => _notifier.removeItem(index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _saveButton(CsvUploadState state) {
    final busy =
        state.step == UploadStep.saving ||
            state.step == UploadStep.resolvingCategories;
    final done = state.step == UploadStep.done;

    // Build label: show "Saving… 55%" during active save
    String buttonLabel;
    if (busy) {
      if (state.step == UploadStep.saving && state.totalToSave > 0) {
        final pct = (state.saveProgress * 100).toInt();
        buttonLabel = 'Saving… $pct%';
      } else {
        buttonLabel = state.stepLabel;
      }
    } else if (done) {
      buttonLabel = 'Saved!';
    } else {
      buttonLabel = 'Save All (${state.validItemCount})';
    }

    return ElevatedButton.icon(
      onPressed: (busy || state.validItemCount == 0)
          ? null
          : () => _notifier.saveAll(widget.restaurantId),
      icon: busy
          ? const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white))
          : Icon(done ? Icons.check_circle : Icons.save_rounded, size: 18),
      label: Text(
        buttonLabel,
        style: _p(13, FontWeight.w600, Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: done ? _kGreen : _kOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ImageTile
// ─────────────────────────────────────────────────────────────────────────────
class _ImageTile extends StatelessWidget {
  final _PickedImage img;
  final VoidCallback? onRemove;
  const _ImageTile({required this.img, this.onRemove});

  @override
  Widget build(BuildContext context) {
    Color border = _kBorder;
    if (img.done && !img.failed) border = _kGreen;
    if (img.failed)               border = _kRed;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image preview
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13)),
                child: Image.memory(img.bytes, fit: BoxFit.cover),
              ),
              // Uploading / reading overlay
              if (img.uploading || img.reading)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13)),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                        const SizedBox(height: 8),
                        Text(
                          img.uploading ? 'Uploading…' : 'Reading menu…',
                          style: _p(11, FontWeight.w600, Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                ),
              // Done badge
              if (img.done && !img.failed)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: _kGreen,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${img.rowCount} items',
                        style: _p(10, FontWeight.w700, Colors.white)),
                  ),
                ),
              // Failed badge
              if (img.failed)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: _kRed, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              // Remove button
              if (onRemove != null)
                Positioned(
                  top: 6, left: 6,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ),
                ),
            ]),
          ),
          // File info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  img.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _p(11, FontWeight.w600, _kTextDark),
                ),
                const SizedBox(height: 2),
                Text(
                  img.failed
                      ? 'Could not read menu'
                      : img.done
                      ? '${img.rowCount} items extracted'
                      : img.reading
                      ? 'Reading menu…'
                      : img.uploading
                      ? 'Uploading…'
                      : 'Waiting',
                  style: _p(
                      10, FontWeight.w500,
                      img.failed
                          ? _kRed
                          : img.done
                          ? _kGreen
                          : _kTextLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _MenuItemCard — preview + edit (unchanged logic, orange theme)
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
  Uint8List? _localBytes;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl     = TextEditingController(text: widget.item.name);
    _imageUrlCtrl = TextEditingController(text: widget.item.image);
    _selectedCategory = widget.item.categoryName.isEmpty
        ? null
        : widget.item.categoryName;
    _initVariants();
  }

  void _initVariants() {
    _vNameCtrls = widget.item.variants
        .map((v) => TextEditingController(text: v.name))
        .toList();
    _vPriceCtrls = widget.item.variants
        .map((v) =>
        TextEditingController(text: v.price.toInt().toString()))
        .toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _imageUrlCtrl.dispose();
    for (final c in [..._vNameCtrls, ..._vPriceCtrls]) c.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() { _localBytes = bytes; _uploading = true; });
    final url = await _uploadToImgBB(bytes, picked.name);
    if (!mounted) return;
    if (url != null) {
      widget.onImageChange(url);
      _imageUrlCtrl.text = url;
      setState(() => _uploading = false);
    } else {
      setState(() { _localBytes = null; _uploading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Upload failed',
            style: _p(13, FontWeight.w500, Colors.white)),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  void _applyChanges() {
    final variants = <MenuVariant>[];
    for (int i = 0; i < _vNameCtrls.length; i++) {
      final n = _vNameCtrls[i].text.trim();
      final p = double.tryParse(_vPriceCtrls[i].text.trim()) ?? -1;
      if (n.isNotEmpty && p >= 0) variants.add(MenuVariant(name: n, price: p));
    }
    final err = _nameCtrl.text.trim().isEmpty || variants.isEmpty;
    widget.onUpdate(widget.item.copyWith(
      name:         _nameCtrl.text.trim(),
      categoryName: _selectedCategory ?? widget.item.categoryName,
      image:        _imageUrlCtrl.text.trim(),
      variants:     variants,
      hasError:     err,
      errorMessage: err ? 'Name or variants invalid.' : null,
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

  void _pasteUrlDialog() {
    final ctrl = TextEditingController(text: widget.item.image);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Paste Image URL',
            style: _p(16, FontWeight.w600, _kTextDark)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.item.image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                widget.item.image,
                height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    height: 140, color: _kOrangeLight,
                    child: const Icon(Icons.broken_image,
                        color: _kOrange, size: 40)),
              ),
            ),
          const SizedBox(height: 14),
          TextField(
              controller: ctrl,
              decoration: _inputDecor('https://...'),
              autofocus: true),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: _p(13, FontWeight.w500, _kTextMid))),
          ElevatedButton(
            onPressed: () {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                widget.onImageChange(url);
                _imageUrlCtrl.text = url;
                setState(() => _localBytes = null);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Apply',
                style: _p(13, FontWeight.w600, Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item   = widget.item;
    final hasErr = item.hasError;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: hasErr ? const Color(0xFFFFF5F5) : _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hasErr ? const Color(0xFFFCA5A5) : _kBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000),
              blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail — tap to replace image
              GestureDetector(
                onTap: _uploading ? null : _pickAndUpload,
                child: Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72, height: 72,
                      child: _uploading
                          ? Stack(fit: StackFit.expand, children: [
                        if (_localBytes != null)
                          Image.memory(_localBytes!, fit: BoxFit.cover)
                        else
                          _placeholder(),
                        Container(color: Colors.black38),
                        const Center(
                            child: SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))),
                      ])
                          : _localBytes != null
                          ? Image.memory(_localBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity)
                          : item.image.isNotEmpty
                          ? Image.network(item.image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              _placeholder())
                          : _placeholder(),
                    ),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 22,
                      decoration: const BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(10))),
                      alignment: Alignment.center,
                      child: Text(
                          _uploading ? 'Uploading…' : 'Change',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.isEmpty ? 'Unnamed Item' : item.name,
                      style: _p(14, FontWeight.w600, _kTextDark),
                    ),
                    if (item.categoryName.isNotEmpty)
                      Text(item.categoryName,
                          style: _p(12, FontWeight.w400, _kTextLight)),
                    if (hasErr && item.errorMessage != null)
                      Text(item.errorMessage!,
                          style: _p(11, FontWeight.w400, _kRed)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6, runSpacing: 4,
                      children: item.variants
                          .map((v) => _VariantChip(v))
                          .toList(),
                    ),
                  ],
                ),
              ),
              Column(children: [
                IconButton(
                  icon: Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.edit_outlined,
                      size: 20,
                      color: _expanded ? _kOrange : _kTextLight),
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: _kRed),
                  onPressed: widget.onRemove,
                ),
              ]),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: _kBorder),
                const SizedBox(height: 14),

                // Image section
                _label('Item Image'),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                        color: _kOrangeLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _uploading
                          ? Stack(fit: StackFit.expand, children: [
                        if (_localBytes != null)
                          Image.memory(_localBytes!, fit: BoxFit.cover)
                        else
                          _placeholder(large: true),
                        Container(color: Colors.black26),
                        const Center(
                            child: CircularProgressIndicator(
                                color: _kOrange, strokeWidth: 2)),
                      ])
                          : _localBytes != null
                          ? Image.memory(_localBytes!, fit: BoxFit.cover)
                          : item.image.isNotEmpty
                          ? Image.network(item.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _placeholder(large: true))
                          : _placeholder(large: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upload from gallery or paste a URL.',
                            style: _p(12, FontWeight.w400, _kTextMid)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickAndUpload,
                          icon: _uploading
                              ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _kOrange))
                              : const Icon(Icons.image_outlined,
                              color: _kOrange, size: 18),
                          label: Text(
                            _uploading ? 'Uploading…' : 'Upload Image',
                            style: _p(12, FontWeight.w500, _kOrange),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            side: BorderSide(
                                color: _kOrange.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _pasteUrlDialog,
                          icon: const Icon(Icons.link_rounded,
                              color: _kTextMid, size: 16),
                          label: Text('Paste URL',
                              style: _p(12, FontWeight.w500, _kTextMid)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            side: const BorderSide(color: _kBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                _label('Item Name'),
                const SizedBox(height: 6),
                TextField(
                    controller: _nameCtrl,
                    decoration: _inputDecor('e.g. Paneer Butter Masala')),
                const SizedBox(height: 12),

                _label('Category'),
                const SizedBox(height: 6),
                _CategoryDropdown(
                  categoryMap: widget.categoryMap,
                  selectedName: _selectedCategory,
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
                const SizedBox(height: 12),

                _label('Image URL'),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _imageUrlCtrl,
                          decoration: _inputDecor('https://...'))),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pasteUrlDialog,
                    icon: const Icon(Icons.image_search, size: 16),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kOrange,
                      side: const BorderSide(color: _kOrange),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                Row(children: [
                  _label('Variants'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addVariant,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add variant'),
                    style: TextButton.styleFrom(
                        foregroundColor: _kOrange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6)),
                  ),
                ]),
                const SizedBox(height: 6),
                ...List.generate(_vNameCtrls.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                        flex: 3,
                        child: TextField(
                            controller: _vNameCtrls[i],
                            decoration: _inputDecor('e.g. Regular'))),
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
                          color: _kRed, size: 20),
                      onPressed: _vNameCtrls.length > 1
                          ? () => _removeVariant(i)
                          : null,
                    ),
                  ]),
                )),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _applyChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text('Apply Changes',
                        style: _p(13, FontWeight.w600, Colors.white)),
                  ),
                ),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _placeholder({bool large = false}) => Container(
      color: _kOrangeLight,
      child: Icon(Icons.fastfood_rounded,
          color: _kOrange, size: large ? 40 : 30));

  Widget _label(String t) =>
      Text(t, style: _p(13, FontWeight.w500, _kTextDark));
}

// ─────────────────────────────────────────────────────────────────────────────
//  CSV format preview card (shown on empty state)
// ─────────────────────────────────────────────────────────────────────────────
class _CsvFormatCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const example =
        'name,price,category\n'
        'Butter Chapati (Tawa),10,Roti\n'
        'Paneer Butter Masala,160,Paneer\n'
        'Veg. Biryani,80,Rice\n'
        'Masala Dhosa,80,Dhosa';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: _kOrange),
          const SizedBox(width: 8),
          Text('Generated CSV format',
              style: _p(13, FontWeight.w600, _kTextDark)),
        ]),
        const SizedBox(height: 10),
        Text(
          'AI reads each photo and produces:',
          style: _p(12, FontWeight.w400, _kTextMid),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _kOrangeLight,
              borderRadius: BorderRadius.circular(10)),
          child: SelectableText(
            example,
            style: _p(11.5, FontWeight.w500, _kTextDark).copyWith(
                fontFamily: 'monospace', height: 1.8),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 14, color: _kGreen),
          const SizedBox(width: 6),
          Expanded(
              child: Text('Feeds directly into the existing menu upload flow',
                  style: _p(11.5, FontWeight.w400, _kTextMid))),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StepPill extends StatelessWidget {
  final String n, label;
  const _StepPill({required this.n, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 20, height: 20,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: _kOrange, shape: BoxShape.circle),
        child: Text(n,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 5),
      Text(label, style: _p(11, FontWeight.w500, _kTextMid)),
    ],
  );
}

class _CategoryDropdown extends StatelessWidget {
  final Map<String, CategoryModel> categoryMap;
  final String? selectedName;
  final ValueChanged<String?> onChanged;
  const _CategoryDropdown(
      {required this.categoryMap,
        required this.selectedName,
        required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final names =
    categoryMap.values.map((c) => c.name).toSet().toList()..sort();
    final eff = names.contains(selectedName) ? selectedName : null;
    return DropdownButtonFormField<String>(
      value: eff,
      hint: Text('Select category',
          style: _p(13, FontWeight.w400, _kTextLight)),
      decoration: _inputDecor(''),
      items: names
          .map((n) => DropdownMenuItem(
          value: n,
          child: Text(n, style: _p(13, FontWeight.w400, _kTextDark))))
          .toList(),
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor: _kCard,
      iconEnabledColor: _kOrange,
      style: _p(14, FontWeight.w400, _kTextDark),
    );
  }
}

class _VariantChip extends StatelessWidget {
  final MenuVariant variant;
  const _VariantChip(this.variant);

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: _kOrangeLight,
        borderRadius: BorderRadius.circular(20)),
    child: Text(
        '${variant.name} · ₹${variant.price.toInt()}',
        style: _p(11, FontWeight.w600, _kOrange)),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _Chip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: _p(12, FontWeight.w600, color)),
  );
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ProgressBar(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    color: _kCard,
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
    child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _p(12, FontWeight.w400, _kTextLight)),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value,
          backgroundColor: _kBorder,
          color: color,
          minHeight: 5,
        ),
      ),
    ]),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 15),
    label: Text(label, style: _p(12, FontWeight.w500, _kOrange)),
    style: OutlinedButton.styleFrom(
      foregroundColor: _kOrange,
      side: const BorderSide(color: _kOrange),
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
    ),
  );
}

InputDecoration _inputDecor(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: _kTextLight, fontSize: 13),
  filled: true,
  fillColor: _kOrangeLight,
  contentPadding:
  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _kBorder)),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _kBorder)),
  focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:
      const BorderSide(color: _kOrange, width: 1.5)),
);