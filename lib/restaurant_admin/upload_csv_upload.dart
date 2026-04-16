import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
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
const _kBg          = Color(0xFFF8F9FA);
const _kCard        = Color(0xFFFFFFFF);
const _kOrange      = Color(0xFFE8622A);
const _kOrangeLight = Color(0xFFFFF0E8);
const _kOrangeBg    = Color(0xFFFEE9DE);
const _kTextDark    = Color(0xFF1A1A1A);
const _kTextMid     = Color(0xFF555555);
const _kTextLight   = Color(0xFF999999);
const _kBorder      = Color(0xFFE5E7EB);
const _kGreen       = Color(0xFF16A34A);
const _kRed         = Color(0xFFDC2626);
const _kGreenBg     = Color(0xFFDCFCE7);
const _kRedBg       = Color(0xFFFEE2E2);
const _kStepActive  = Color(0xFF1E293B);

const _kImgBBKey = "a923bc17d28cd6fe1be417700456eb69";

TextStyle _p(double size, FontWeight weight, Color color) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

// ─────────────────────────────────────────────────────────────────────────────
//  ImgBB upload
// ─────────────────────────────────────────────────────────────────────────────
Future<String?> _uploadToImgBB(Uint8List bytes, String filename) async {
  try {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.imgbb.com/1/upload?key=$_kImgBBKey'),
    );
    req.files.add(http.MultipartFile.fromBytes('image', bytes, filename: filename));
    final res  = await req.send();
    final body = await res.stream.bytesToString();
    final data = json.decode(body);
    return data['data']['url'] as String?;
  } catch (e) {
    debugPrint('IMGBB ERROR: $e');
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Claude Vision — read menu image → CSV rows
// ─────────────────────────────────────────────────────────────────────────────
Future<String> _readMenuImage(String imgbbUrl) async {
  const system = '''
You are a restaurant menu reader.
Look at the menu image and extract every dish you can see.

Return ONLY plain CSV rows — no header line, no markdown, no explanations.

Format for each dish:
dish_name,price,category

Rules:
- dish_name: exact name as shown on the menu (no quotes unless the name contains a comma)
- price: number only (no ₹ or Rs or commas), e.g. 80
- category: the section/category heading the dish belongs to (e.g. Roti, Rice, Paneer, Starters)
- If price is not visible, use 0
- If category heading is not visible, use Other
- One dish per line
- Do not add any blank lines or extra text
- If a dish name contains a comma, wrap the name in double quotes
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
        'max_tokens': 2048,
        'system': system,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'image', 'source': {'type': 'url', 'url': imgbbUrl}},
              {'type': 'text', 'text': 'Extract all menu items from this image as CSV rows.'},
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

      // Strip markdown fences if Claude accidentally adds them
      final cleaned = rawText
          .replaceAll(RegExp(r'^```[a-z]*\n?', multiLine: true), '')
          .replaceAll(RegExp(r'```$', multiLine: true), '')
          .trim();

      // Validate: keep only lines with at least 3 comma-separated parts
      // where the second part is numeric (the price field).
      final validRows = cleaned
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .where((l) {
        // Handle quoted fields: split on commas outside quotes
        final parts = _splitCsvRow(l);
        if (parts.length < 3) return false;
        final price = parts[1].trim().replaceAll(RegExp(r'[^\d.]'), '');
        return double.tryParse(price) != null;
      })
          .join('\n');

      return validRows;
    } else {
      debugPrint('CLAUDE API ${res.statusCode}: ${res.body}');
      return '';
    }
  } catch (e) {
    debugPrint('CLAUDE ERROR: $e');
    return '';
  }
}

/// Splits a CSV row respecting double-quoted fields.
List<String> _splitCsvRow(String row) {
  final parts = <String>[];
  var current = StringBuffer();
  var inQuotes = false;
  for (int i = 0; i < row.length; i++) {
    final ch = row[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
    } else if (ch == ',' && !inQuotes) {
      parts.add(current.toString());
      current = StringBuffer();
    } else {
      current.write(ch);
    }
  }
  parts.add(current.toString());
  return parts;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Per-image lifecycle model
// ─────────────────────────────────────────────────────────────────────────────
class _PickedImage {
  final String    name;
  final Uint8List bytes;
  String? imgbbUrl;
  String? csvRows;
  int     rowCount = 0;
  bool uploading = false;
  bool reading   = false;
  bool done      = false;
  bool failed    = false;
  String? failReason;
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
  bool _csvParsing   = false;

  // ── Auth helper ───────────────────────────────────────────────────────────
  /// Returns true if user is authenticated and token was refreshed.
  /// Shows a snackbar and returns false if not.
  Future<bool> _ensureAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Not signed in. Please log in as admin before uploading.', error: true);
      return false;
    }
    try {
      // Force-refresh token so Firestore receives it on the next write.
      await user.getIdToken(true);
      return true;
    } catch (e) {
      _snack('Auth token refresh failed: $e', error: true);
      return false;
    }
  }

  // ── Step 1: Pick images ───────────────────────────────────────────────────
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

  // ── Step 2: Process images → CSV → parseCsv ───────────────────────────────
  Future<void> _processImages() async {
    if (_isProcessing || _images.isEmpty) return;
    if (!await _ensureAuth()) return;

    setState(() => _isProcessing = true);

    // 2a. Upload to ImgBB
    for (final img in _images) {
      if (img.imgbbUrl != null || img.failed) continue;
      setState(() => img.uploading = true);
      final url = await _uploadToImgBB(img.bytes, img.name);
      setState(() {
        img.uploading = false;
        if (url != null) {
          img.imgbbUrl = url;
        } else {
          img.failed     = true;
          img.failReason = 'Image upload to ImgBB failed';
        }
      });
    }

    // 2b. Send to Claude Vision
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
        img.done = true;
        if (rows.isEmpty) {
          img.failed     = true;
          img.failReason = 'No menu items could be extracted — try a clearer photo';
        }
      });
    }

    // 2c. Stitch CSV
    final buf = StringBuffer();
    buf.writeln('name,price,category');
    for (final img in _images) {
      if (img.csvRows == null || img.csvRows!.isEmpty) continue;
      buf.writeln(img.csvRows!.trim());
    }
    final csvString = buf.toString().trim();
    final lines = csvString.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.length < 2) {
      _snack('No valid menu items could be extracted from the images.', error: true);
      setState(() => _isProcessing = false);
      return;
    }

    // 2d. Parse → provider
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
    if (!await _ensureAuth()) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null || bytes.isEmpty) {
      _snack('Could not read the selected file.', error: true);
      return;
    }
    setState(() => _csvParsing = true);
    await _notifier.parseCsv(String.fromCharCodes(bytes), widget.restaurantId);
    if (mounted) setState(() => _csvParsing = false);
  }

  void _downloadSample(bool advanced) {
    final svc     = ref.read(csvParsingServiceProvider);
    final content = advanced ? svc.generateAdvancedSampleCsv() : svc.generateSimpleSampleCsv();
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: Colors.white, size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: _p(13, FontWeight.w500, Colors.white))),
      ]),
      backgroundColor: error ? _kRed : _kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: error ? 5 : 3),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(csvUploadProvider(widget.restaurantId));

    ref.listen(csvUploadProvider(widget.restaurantId), (_, next) {
      if (next.step == UploadStep.done) {
        _snack('✅ ${next.savedCount} items saved to menu!');
      } else if (next.step == UploadStep.error && next.errorMessage != null) {
        _snack(next.errorMessage!, error: true);
      }
    });

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(state),
      body: state.items.isEmpty
          ? (_images.isEmpty ? _buildEmptyState() : _buildImageStage())
          : _buildPreviewBody(state),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(CsvUploadState state) {
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
          width: kIsWeb ? 40 : 36.sp,
          height: kIsWeb ? 40 : 36.sp,
          decoration: BoxDecoration(
              color: _kOrange, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
        ),
        SizedBox(width: kIsWeb ? 12 : 10.sp),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Menu Upload', style: _p(kIsWeb ? 16 : 14, FontWeight.w700, _kTextDark)),
            Text('Photo or CSV → Menu items',
                style: _p(kIsWeb ? 11 : 10, FontWeight.w400, _kTextLight)),
          ],
        ),
      ]),
      actions: [
        _csvParsing
            ? _loadingChip('Parsing…')
            : _OutlineBtn(label: 'Upload CSV', icon: Icons.table_chart_outlined, onTap: _pickCsvFile),
        const SizedBox(width: 8),
        _OutlineBtn(label: 'Sample CSV', icon: Icons.download_rounded, onTap: () => _downloadSample(false)),
        const SizedBox(width: kIsWeb ? 20 : 12),
      ],
    );
  }

  Widget _loadingChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
        color: _kOrangeBg, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: _kOrange)),
      const SizedBox(width: 8),
      Text(label, style: _p(12, FontWeight.w500, _kOrange)),
    ]),
  );

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Step indicator
            _StepRow(steps: const ['Pick photos', 'AI reads menu', 'Review items', 'Save to menu']),
            const SizedBox(height: 28),

            // Drop zone
            GestureDetector(
              onTap: _pickImages,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kOrange.withOpacity(0.4), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, 4))
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(color: _kOrangeBg, borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.add_photo_alternate_outlined, size: 36, color: _kOrange),
                    ),
                    const SizedBox(height: 18),
                    Text('Tap to select menu photos', style: _p(17, FontWeight.w600, _kTextDark)),
                    const SizedBox(height: 6),
                    Text('AI extracts every dish, price and category automatically',
                        style: _p(13, FontWeight.w400, _kTextMid), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          color: _kOrangeBg, borderRadius: BorderRadius.circular(10)),
                      child: Text('JPG · PNG · WEBP accepted',
                          style: _p(11.5, FontWeight.w500, _kOrange)),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _CsvFormatCard(),
          ]),
        ),
      ),
    );
  }

  // ── Image stage ───────────────────────────────────────────────────────────
  Widget _buildImageStage() {
    final total     = _images.length;
    final done      = _images.where((i) => i.done && !i.failed).length;
    final failed    = _images.where((i) => i.failed).length;
    final totalRows = _images.fold<int>(0, (s, i) => s + i.rowCount);
    final progress  = total == 0 ? 0.0 : done / total;

    return Column(children: [
      // Top summary bar
      Container(
        color: _kCard,
        padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 24 : 16, vertical: 12),
        child: Row(children: [
          _StatusChip(label: '$total photo${total == 1 ? '' : 's'}', color: _kOrange, bg: _kOrangeBg),
          if (done > 0) ...[
            const SizedBox(width: 8),
            _StatusChip(label: '$totalRows items found', color: _kGreen, bg: _kGreenBg),
          ],
          if (failed > 0) ...[
            const SizedBox(width: 8),
            _StatusChip(label: '$failed failed', color: _kRed, bg: _kRedBg),
          ],
          const Spacer(),
          if (!_isProcessing) ...[
            TextButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 17),
              label: Text('Add more', style: _p(12, FontWeight.w500, _kOrange)),
              style: TextButton.styleFrom(foregroundColor: _kOrange),
            ),
            TextButton.icon(
              onPressed: _clearImages,
              icon: const Icon(Icons.clear_all_rounded, size: 17),
              label: Text('Clear all', style: _p(12, FontWeight.w500, _kTextLight)),
              style: TextButton.styleFrom(foregroundColor: _kTextLight),
            ),
            const SizedBox(width: 4),
          ],
          _buildConvertButton(),
        ]),
      ),

      // Progress bar
      if (_isProcessing)
        _AnimatedProgressBar(
          label: _progressLabel(),
          value: progress,
          color: _kOrange,
        ),

      // Photo grid
      Expanded(
        child: GridView.builder(
          padding: EdgeInsets.all(kIsWeb ? 24 : 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _isWide ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: _images.length,
          itemBuilder: (ctx, i) => _ImageTile(
            img: _images[i],
            onRemove: _isProcessing ? null : () => _removeImage(i),
          ),
        ),
      ),
    ]);
  }

  String _progressLabel() {
    if (_images.any((i) => i.uploading)) return 'Uploading photos…';
    if (_images.any((i) => i.reading))   return 'AI is reading menu items…';
    return 'Building CSV…';
  }

  Widget _buildConvertButton() {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : _processImages,
      icon: _isProcessing
          ? const SizedBox(width: 15, height: 15,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.auto_awesome_rounded, size: 17),
      label: Text(
        _isProcessing ? 'Processing…' : 'Extract & Review',
        style: _p(13, FontWeight.w600, Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _kOrange.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  // ── Preview body ──────────────────────────────────────────────────────────
  Widget _buildPreviewBody(CsvUploadState state) {
    return Column(children: [
      // Header bar
      Container(
        color: _kCard,
        padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 24 : 16, vertical: 12),
        child: Row(children: [
          _StatusChip(label: '${state.validItemCount} valid', color: _kGreen, bg: _kGreenBg),
          if (state.errorItemCount > 0) ...[
            const SizedBox(width: 8),
            _StatusChip(label: '${state.errorItemCount} errors', color: _kRed, bg: _kRedBg),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: state.isLoading ? null : () {
              _notifier.reset();
              setState(() => _images.clear());
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: Text('Start over', style: _p(12, FontWeight.w500, _kTextLight)),
            style: TextButton.styleFrom(foregroundColor: _kTextLight),
          ),
          const SizedBox(width: 8),
          _buildSaveButton(state),
        ]),
      ),

      // Progress bars
      if (state.step == UploadStep.fetchingImages)
        _AnimatedProgressBar(
          label: 'Fetching images ${state.imagesDone}/${state.imagesTotal}…',
          value: state.imageProgress, color: _kOrange,
        ),
      if (state.step == UploadStep.saving)
        _AnimatedProgressBar(
          label: 'Saving ${state.savedCount}/${state.totalToSave} items…',
          value: state.saveProgress, color: _kGreen,
        ),
      if (state.step == UploadStep.resolvingCategories)
        const LinearProgressIndicator(color: _kOrange, minHeight: 3,
            backgroundColor: Color(0xFFE5E7EB)),

      // Done banner
      if (state.step == UploadStep.done)
        _DoneBanner(savedCount: state.savedCount),

      // Error banner
      if (state.step == UploadStep.error && state.errorMessage != null)
        _ErrorBanner(message: state.errorMessage!),

      // Item list
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
    ]);
  }

  Widget _buildSaveButton(CsvUploadState state) {
    final busy = state.step == UploadStep.saving ||
        state.step == UploadStep.resolvingCategories;
    final done = state.step == UploadStep.done;

    String label;
    if (busy) {
      final pct = state.step == UploadStep.saving && state.totalToSave > 0
          ? ' ${(state.saveProgress * 100).toInt()}%'
          : '';
      label = 'Saving…$pct';
    } else if (done) {
      label = '✓ Saved!';
    } else {
      label = 'Save ${state.validItemCount} Items';
    }

    return ElevatedButton.icon(
      onPressed: (busy || state.validItemCount == 0 || done)
          ? null
          : () async {
        if (!await _ensureAuth()) return;
        _notifier.saveAll(widget.restaurantId);
      },
      icon: busy
          ? const SizedBox(width: 15, height: 15,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(done ? Icons.check_circle : Icons.save_rounded, size: 17),
      label: Text(label, style: _p(13, FontWeight.w600, Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: done ? _kGreen : _kOrange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: done ? _kGreen : _kOrange.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step Row
// ─────────────────────────────────────────────────────────────────────────────
class _StepRow extends StatelessWidget {
  final List<String> steps;
  const _StepRow({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward_rounded, size: 12, color: _kTextLight.withOpacity(0.5)),
          );
        }
        final idx = i ~/ 2;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 20, height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: _kOrange, shape: BoxShape.circle),
            child: Text('${idx + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 5),
          Text(steps[idx], style: _p(11, FontWeight.w500, _kTextMid)),
        ]);
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Animated progress bar
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _AnimatedProgressBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    color: _kCard,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: _p(12, FontWeight.w500, _kTextMid)),
        Text('${(value * 100).toInt()}%', style: _p(11, FontWeight.w600, color)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 300),
          builder: (_, v, __) => LinearProgressIndicator(
            value: v, backgroundColor: _kBorder, color: color, minHeight: 5,
          ),
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Done banner
// ─────────────────────────────────────────────────────────────────────────────
class _DoneBanner extends StatelessWidget {
  final int savedCount;
  const _DoneBanner({required this.savedCount});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
        color: _kGreenBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withOpacity(0.3))),
    child: Row(children: [
      const Icon(Icons.check_circle_rounded, color: _kGreen, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(
        '$savedCount menu items saved successfully! They are now live on your menu.',
        style: _p(13, FontWeight.w500, _kGreen),
      )),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Error banner
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
        color: _kRedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withOpacity(0.3))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(Icons.error_outline_rounded, color: _kRed, size: 20),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: _p(13, FontWeight.w500, _kRed))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CSV format preview card
// ─────────────────────────────────────────────────────────────────────────────
class _CsvFormatCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const example =
        'name,price,category\n'
        'Butter Chapati,10,Roti\n'
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
          const Icon(Icons.info_outline_rounded, size: 15, color: _kOrange),
          const SizedBox(width: 7),
          Text('AI-generated CSV format', style: _p(13, FontWeight.w600, _kTextDark)),
        ]),
        const SizedBox(height: 10),
        Text('Each photo produces rows in this format:', style: _p(12, FontWeight.w400, _kTextMid)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _kOrangeLight, borderRadius: BorderRadius.circular(10)),
          child: SelectableText(example,
              style: _p(11.5, FontWeight.w500, _kTextDark).copyWith(
                  fontFamily: 'monospace', height: 1.8)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.check_circle_outline_rounded, size: 14, color: _kGreen),
          const SizedBox(width: 6),
          Expanded(child: Text('Feeds directly into the review screen before saving',
              style: _p(11.5, FontWeight.w400, _kTextMid))),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Status chip
// ─────────────────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _StatusChip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: _p(12, FontWeight.w600, color)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Image tile
// ─────────────────────────────────────────────────────────────────────────────
class _ImageTile extends StatelessWidget {
  final _PickedImage img;
  final VoidCallback? onRemove;
  const _ImageTile({required this.img, this.onRemove});

  @override
  Widget build(BuildContext context) {
    Color borderColor = _kBorder;
    if (img.done && !img.failed) borderColor = _kGreen;
    if (img.failed)               borderColor = _kRed;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: Image.memory(img.bytes, fit: BoxFit.cover),
            ),
            // Processing overlay
            if (img.uploading || img.reading)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  const SizedBox(height: 10),
                  Text(img.uploading ? 'Uploading…' : 'AI reading…',
                      style: _p(11, FontWeight.w600, Colors.white), textAlign: TextAlign.center),
                ]),
              ),
            // Success badge
            if (img.done && !img.failed)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(20)),
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
                  decoration: const BoxDecoration(color: _kRed, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
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
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                  ),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(img.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: _p(11, FontWeight.w600, _kTextDark)),
            const SizedBox(height: 2),
            Text(
              img.failed
                  ? (img.failReason ?? 'Could not read menu')
                  : img.done
                  ? '${img.rowCount} items extracted'
                  : img.reading ? 'AI reading menu…'
                  : img.uploading ? 'Uploading…'
                  : 'Ready',
              maxLines: 2,
              style: _p(10, FontWeight.w500,
                  img.failed ? _kRed : img.done ? _kGreen : _kTextLight),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Menu item preview + edit card
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
    _selectedCategory = widget.item.categoryName.isEmpty ? null : widget.item.categoryName;
    _initVariants();
  }

  void _initVariants() {
    _vNameCtrls  = widget.item.variants.map((v) => TextEditingController(text: v.name)).toList();
    _vPriceCtrls = widget.item.variants.map((v) => TextEditingController(text: v.price.toInt().toString())).toList();
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
        content: Text('Image upload failed', style: _p(13, FontWeight.w500, Colors.white)),
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
      errorMessage: err ? 'Item name and at least one valid variant are required.' : null,
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

  @override
  Widget build(BuildContext context) {
    final item   = widget.item;
    final hasErr = item.hasError;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: hasErr ? const Color(0xFFFFF5F5) : _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasErr ? _kRed.withOpacity(0.35) : _kBorder),
        boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        // Collapsed row
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Thumbnail
            GestureDetector(
              onTap: _uploading ? null : _pickAndUpload,
              child: Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 68, height: 68,
                    child: _uploading
                        ? Stack(fit: StackFit.expand, children: [
                      if (_localBytes != null)
                        Image.memory(_localBytes!, fit: BoxFit.cover)
                      else
                        _imgPlaceholder(),
                      Container(color: Colors.black38),
                      const Center(child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                    ])
                        : _localBytes != null
                        ? Image.memory(_localBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                        : item.image.isNotEmpty
                        ? Image.network(item.image, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                        errorBuilder: (_, __, ___) => _imgPlaceholder())
                        : _imgPlaceholder(),
                  ),
                ),
                Positioned(bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 20,
                    decoration: const BoxDecoration(color: Colors.black54,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10))),
                    alignment: Alignment.center,
                    child: Text('Change', style: const TextStyle(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name.isEmpty ? 'Unnamed Item' : item.name,
                    style: _p(14, FontWeight.w600, _kTextDark)),
                if (item.categoryName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(item.categoryName, style: _p(12, FontWeight.w400, _kTextLight)),
                  ),
                if (hasErr && item.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, size: 12, color: _kRed),
                      const SizedBox(width: 4),
                      Expanded(child: Text(item.errorMessage!,
                          style: _p(11, FontWeight.w400, _kRed))),
                    ]),
                  ),
                if (item.variants.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Wrap(spacing: 5, runSpacing: 3,
                        children: item.variants.map((v) => _VariantChip(v)).toList()),
                  ),
              ]),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: Icon(_expanded ? Icons.expand_less : Icons.edit_outlined,
                    size: 19, color: _kOrange),
                onPressed: () => setState(() => _expanded = !_expanded),
                tooltip: _expanded ? 'Collapse' : 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 19, color: _kTextLight),
                onPressed: widget.onRemove,
                tooltip: 'Remove',
              ),
            ]),
          ]),
        ),

        // Expanded edit section
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Divider(height: 1, color: _kBorder),
              const SizedBox(height: 16),

              // Image
              _label('Item Image'),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 110, height: 110,
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
                      else _imgPlaceholder(large: true),
                      Container(color: Colors.black26),
                      const Center(child: CircularProgressIndicator(
                          color: _kOrange, strokeWidth: 2)),
                    ])
                        : _localBytes != null
                        ? Image.memory(_localBytes!, fit: BoxFit.cover)
                        : item.image.isNotEmpty
                        ? Image.network(item.image, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imgPlaceholder(large: true))
                        : _imgPlaceholder(large: true),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Upload from gallery or paste a URL',
                        style: _p(12, FontWeight.w400, _kTextMid)),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickAndUpload,
                      icon: _uploading
                          ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _kOrange))
                          : const Icon(Icons.image_outlined, color: _kOrange, size: 16),
                      label: Text(_uploading ? 'Uploading…' : 'Upload Image',
                          style: _p(12, FontWeight.w500, _kOrange)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        side: BorderSide(color: _kOrange.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                        controller: _imageUrlCtrl,
                        style: _p(12, FontWeight.w400, _kTextDark),
                        decoration: _inputDecor('Paste image URL…')),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),

              _label('Item Name'),
              const SizedBox(height: 6),
              TextField(controller: _nameCtrl,
                  style: _p(13, FontWeight.w400, _kTextDark),
                  decoration: _inputDecor('e.g. Paneer Butter Masala')),
              const SizedBox(height: 12),

              _label('Category'),
              const SizedBox(height: 6),
              _CategoryDropdown(
                categoryMap: widget.categoryMap,
                selectedName: _selectedCategory,
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(height: 14),

              Row(children: [
                _label('Variants'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addVariant,
                  icon: const Icon(Icons.add, size: 15),
                  label: Text('Add variant', style: _p(12, FontWeight.w500, _kOrange)),
                  style: TextButton.styleFrom(
                      foregroundColor: _kOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                ),
              ]),
              const SizedBox(height: 6),
              ...List.generate(_vNameCtrls.length, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(flex: 3,
                      child: TextField(controller: _vNameCtrls[i],
                          style: _p(13, FontWeight.w400, _kTextDark),
                          decoration: _inputDecor('e.g. Regular'))),
                  const SizedBox(width: 10),
                  Expanded(flex: 2,
                      child: TextField(controller: _vPriceCtrls[i],
                          keyboardType: TextInputType.number,
                          style: _p(13, FontWeight.w400, _kTextDark),
                          decoration: _inputDecor('₹ Price'))),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: _kRed, size: 19),
                    onPressed: _vNameCtrls.length > 1 ? () => _removeVariant(i) : null,
                  ),
                ]),
              )),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => setState(() => _expanded = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kTextMid,
                    side: const BorderSide(color: _kBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  child: Text('Cancel', style: _p(12, FontWeight.w500, _kTextMid)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _applyChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  child: Text('Apply Changes', style: _p(12, FontWeight.w600, Colors.white)),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _imgPlaceholder({bool large = false}) => Container(
    color: _kOrangeLight,
    child: Icon(Icons.fastfood_rounded, color: _kOrange, size: large ? 36 : 28),
  );

  Widget _label(String t) => Text(t, style: _p(12, FontWeight.w600, _kTextDark));
}

// ─────────────────────────────────────────────────────────────────────────────
//  Category dropdown
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryDropdown extends StatelessWidget {
  final Map<String, CategoryModel> categoryMap;
  final String? selectedName;
  final ValueChanged<String?> onChanged;
  const _CategoryDropdown({required this.categoryMap, required this.selectedName, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final names = categoryMap.values.map((c) => c.name).toSet().toList()..sort();
    final eff = names.contains(selectedName) ? selectedName : null;
    return DropdownButtonFormField<String>(
      value: eff,
      hint: Text('Select category', style: _p(13, FontWeight.w400, _kTextLight)),
      decoration: _inputDecor(''),
      items: names.map((n) => DropdownMenuItem(
          value: n, child: Text(n, style: _p(13, FontWeight.w400, _kTextDark)))).toList(),
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor: _kCard,
      iconEnabledColor: _kOrange,
      style: _p(13, FontWeight.w400, _kTextDark),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Variant chip
// ─────────────────────────────────────────────────────────────────────────────
class _VariantChip extends StatelessWidget {
  final MenuVariant variant;
  const _VariantChip(this.variant);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: _kOrangeLight, borderRadius: BorderRadius.circular(20)),
    child: Text('${variant.name} · ₹${variant.price.toInt()}',
        style: _p(11, FontWeight.w600, _kOrange)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Outline button
// ─────────────────────────────────────────────────────────────────────────────
class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14),
    label: Text(label, style: _p(12, FontWeight.w500, _kOrange)),
    style: OutlinedButton.styleFrom(
      foregroundColor: _kOrange,
      side: const BorderSide(color: _kOrange),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Input decoration
// ─────────────────────────────────────────────────────────────────────────────
InputDecoration _inputDecor(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: _kTextLight, fontSize: 13,
      fontFamily: GoogleFonts.poppins().fontFamily),
  filled: true,
  fillColor: _kOrangeLight,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _kBorder)),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _kBorder)),
  focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _kOrange, width: 1.5)),
);