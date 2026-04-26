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

// ─────────────────────────────────────────────────────────────────────────────


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

// ── Google Translate API key ──────────────────────────────────────────────────
const _kTranslateKey = String.fromEnvironment(
  'GOOGLE_TRANSLATE_KEY',
  defaultValue: '',
);

// ─────────────────────────────────────────────────────────────────────────────
//  Google Translate  —  English → Gujarati
// ─────────────────────────────────────────────────────────────────────────────
Future<List<String>> _translateToGujarati(List<String> texts) async {
  if (_kTranslateKey.isEmpty || texts.isEmpty) return texts;
  try {
    final res = await http.post(
      Uri.parse('https://translation.googleapis.com/language/translate/v2?key=$_kTranslateKey'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'q': texts, 'source': 'en', 'target': 'gu', 'format': 'text'}),
    );
    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      final translations = (body['data']['translations'] as List)
          .map((t) => (t as Map)['translatedText'] as String)
          .toList();
      debugPrint('TRANSLATE: ${texts.length} items translated to Gujarati');
      return translations;
    } else {
      debugPrint('TRANSLATE ERROR ${res.statusCode}: ${res.body}');
      return texts;
    }
  } catch (e) {
    debugPrint('TRANSLATE EXCEPTION: $e');
    return texts;
  }
}

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




// ═════════════════════════════════════════════════════════════════════════════
//  GEMINI AI  —  Menu extraction engine
//
//  Flow:
//    1. User picks a menu image (JPEG / PNG / WEBP).
//    2. Image bytes are base64-encoded and sent directly to Gemini Vision API.
//    3. Gemini returns clean JSON with all items, categories and variants.
//    4. JSON is converted to TSV the existing provider understands.
//
//  Free tier: 15 req/min · 1500 req/day — no credit card needed.
//  Get key:   https://aistudio.google.com/app/apikey
//  Run with:  flutter run --dart-define=GEMINI_KEY=AIzaSy...
// ═════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
//  Gemini API key
//  Set via:  flutter run --dart-define=GEMINI_KEY=AIzaSy...
//  Or paste directly in defaultValue for local development.
// ─────────────────────────────────────────────────────────────────────────────
const _kGeminiKey = String.fromEnvironment(
  'GEMINI_KEY',
  defaultValue: 'AIzaSyD-rA0qSkqm9u9zPP2ebsebOgi5wOH5DqU', // ← paste key here for local dev
);

// ─────────────────────────────────────────────────────────────────────────────
//  System prompt sent to Gemini Vision for every menu image
// ─────────────────────────────────────────────────────────────────────────────
const _kMenuSystemPrompt = r'''
You are an expert system that reads restaurant menu images and converts them into structured JSON.

You will be given a menu image directly. Read every item visible in the image carefully.

OUTPUT FORMAT — return ONLY a valid JSON array, no other text:
[
  {
    "category": "Category Name",
    "name": "Item Name",
    "variants": [
      { "name": "Oil",    "price": 100 },
      { "name": "Butter", "price": 120 },
      { "name": "Cheese", "price": 150 }
    ]
  }
]

RULES:
1. ALL-CAPS words at the start of a section are CATEGORY names.
   Examples: PULAV, UTTAPAM, BHAJIPAV, ROTI, RICE, PANEER, CHINESE, GUJARATI.
2. Assign every item to the category that appears ABOVE it in the image.
3. Column headers (OIL, BUTTER, CHEESE, HALF, FULL, SMALL, MEDIUM, LARGE, etc.)
   define variant names. Map each price to its header left-to-right.
4. If no column header row is present, use "Regular" as the single variant name.
5. If a price shows "-", is missing, or cannot be read → OMIT that variant entirely.
   Do NOT include zero-price or null-price variants.
6. IGNORE all non-English text (Gujarati, Hindi subtitles below item names).
7. Fix obvious spelling errors in item names only (not categories).
8. Ignore decorative separators, page numbers, restaurant logos, watermarks.
9. All price values must be plain positive integers — no ₹, no commas, no decimals.
10. Do NOT invent any item, category, or price not visible in the image.
11. Do NOT add any fields beyond: category, name, variants.
12. If an item has sub-variant lines (e.g. "Small 80" / "Large 120") treat them
    as one entry with variants array. Do NOT append the size to the item name.
13. Items with NO valid variants must be OMITTED.

Return ONLY the JSON array. No markdown. No explanation. No comments.
''';

// ─────────────────────────────────────────────────────────────────────────────
//  Detect image MIME type from magic bytes
// ─────────────────────────────────────────────────────────────────────────────
String _imageMimeType(Uint8List bytes) {
  if (bytes.length > 4) {
    if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (bytes[0] == 0x47 && bytes[1] == 0x49) return 'image/gif';
    if (bytes[0] == 0x52 && bytes[1] == 0x49) return 'image/webp';
  }
  return 'image/jpeg';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Gemini Vision API — image bytes → List of structured item maps
//  Model: gemini-1.5-flash (free tier, no credit card needed)
// ─────────────────────────────────────────────────────────────────────────────
Future<List<Map<String, dynamic>>> _extractWithGeminiVision(Uint8List imageBytes) async {
  if (_kGeminiKey.isEmpty) return [];

  try {
    final mimeType  = _imageMimeType(imageBytes);
    final base64Img = base64Encode(imageBytes);
    debugPrint('GEMINI: sending image (${imageBytes.length} bytes, $mimeType)…');

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/'
          'gemini-2.5-flash:generateContent?key=$_kGeminiKey',
    );

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'contents': [
          {
            'parts': [
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data'     : base64Img,
                },
              },
              {
                'text': '$_kMenuSystemPrompt\n\nExtract all menu items from this menu image.',
              },
            ],
          }
        ],
        'generationConfig': {
          'temperature'    : 0.1,
          'maxOutputTokens': 8192,
        },
      }),
    );

    if (res.statusCode != 200) {
      debugPrint('GEMINI API ERROR ${res.statusCode}: ${res.body}');
      return [];
    }

    // Gemini response:
    // { "candidates": [{ "content": { "parts": [{"text": "...json..."}] } }] }
    final body       = json.decode(res.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List? ?? [];
    if (candidates.isEmpty) {
      debugPrint('GEMINI: No candidates in response');
      return [];
    }
    final parts = ((candidates.first as Map)['content']
    as Map?)?['parts'] as List? ?? [];
    if (parts.isEmpty) {
      debugPrint('GEMINI: No parts in candidate');
      return [];
    }

    String rawJson = (parts.first as Map)['text']?.toString() ?? '';
    debugPrint('GEMINI RESPONSE:\n$rawJson');

    // Strip accidental markdown fences
    rawJson = rawJson
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    // Find the JSON array boundaries robustly
    final start = rawJson.indexOf('[');
    final end   = rawJson.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) {
      debugPrint('GEMINI: Could not find JSON array in response');
      return [];
    }
    rawJson = rawJson.substring(start, end + 1);

    dynamic decoded;
    try {
      decoded = json.decode(rawJson);
    } catch (e) {
      debugPrint('GEMINI: JSON decode failed: $e');
      return [];
    }
    if (decoded is! List) return [];

    // Validate items
    final result = <Map<String, dynamic>>[];
    for (final raw in decoded) {
      if (raw is! Map) continue;
      final m    = Map<String, dynamic>.from(raw);
      final name = (m['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      result.add(m);
    }

    debugPrint('GEMINI: Extracted ${result.length} valid items');
    return result;
  } catch (e, st) {
    debugPrint('GEMINI EXCEPTION: $e\n$st');
    return [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Convert Gemini JSON output → TSV rows for the existing provider
//
//  TSV format per row:
//    name \t firstPrice \t category \t variantsJson
//  variantsJson example:
//    [{"n":"Oil","p":100},{"n":"Butter","p":120},{"n":"Cheese","p":150}]
// ─────────────────────────────────────────────────────────────────────────────
/// Converts Gemini JSON response → TSV rows.
///
/// Gemini returns items with a dynamic [variants] array:
///   {"category":"Pulav","name":"Veg Pulav","variants":[{"name":"Oil","price":100},...]}
///
/// TSV row format (consumed by _processImages step C):
///   name \t firstPrice \t category \t [{"n":"Oil","p":100},...]
String _claudeItemsToTsv(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return '';
  final rows = <String>[];

  for (final item in items) {
    final name = (item['name'] ?? '').toString().replaceAll('\t', ' ').trim();
    final cat  = (item['category'] ?? 'Other').toString().replaceAll('\t', ' ').trim();
    if (name.isEmpty) continue;

    // ── Read dynamic variants array ──────────────────────────────────────
    final validVariants = <Map<String, dynamic>>[];

    final rawVariants = item['variants'];
    if (rawVariants is List && rawVariants.isNotEmpty) {
      // New format: {"variants": [{"name": "Oil", "price": 100}, ...]}
      for (final v in rawVariants) {
        if (v is! Map) continue;
        final vName  = (v['name'] ?? '').toString().trim();
        final vPrice = v['price'];
        if (vName.isEmpty) continue;
        final pNum = vPrice is num ? vPrice : num.tryParse(vPrice.toString() ?? '');
        if (pNum == null || pNum <= 0) continue;
        validVariants.add({'n': vName, 'p': pNum.toInt()});
      }
    }

    // ── Legacy fallback: flat oil/butter/cheese fields ───────────────────
    // (handles responses from older prompt versions gracefully)
    if (validVariants.isEmpty) {
      num? toNum(dynamic v) {
        if (v == null) return null;
        if (v is num) return v;
        return num.tryParse(v.toString());
      }
      void addFlat(String varName, dynamic rawVal) {
        final p = toNum(rawVal);
        if (p != null && p > 0) validVariants.add({'n': varName, 'p': p.toInt()});
      }
      addFlat('Oil',     item['oil']);
      addFlat('Butter',  item['butter']);
      addFlat('Cheese',  item['cheese']);
      if (validVariants.isEmpty) {
        addFlat('Regular', item['price']);
      }
    }

    if (validVariants.isEmpty) continue;

    final firstPrice = validVariants.first['p'].toString();
    final varJson = '[${validVariants.map((v) => '{"n":"${v['n']}","p":${v['p']}}').join(',')}]';
    rows.add('$name\t$firstPrice\t$cat\t$varJson');
  }

  return rows.join('\n');
}

// ─────────────────────────────────────────────────────────────────────────────
//  Local regex fallback parser  (no API key required)
//  Used automatically when GEMINI_KEY is empty or Gemini returns nothing.
// ─────────────────────────────────────────────────────────────────────────────
bool _isMostlyNonLatin(String s) {
  if (s.isEmpty) return false;
  return s.runes.where((r) => r > 127).length / s.length > 0.30;
}
String _fixOcrDigits(String s) => s
    .replaceAll('l', '1').replaceAll('I', '1')
    .replaceAll('O', '0').replaceAll('o', '0')
    .replaceAll('S', '5').replaceAll('Z', '2');
String _toTitleCase(String s) => s
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');
const _kColKeywords = {
  'OIL','BUTTER','CHEESE','HALF','FULL','SMALL','MEDIUM',
  'LARGE','MINI','JUMBO','REGULAR','SPECIAL','PLAIN','PRICE','RATE',
};
bool _isColHeaderLine(String line) {
  final up = line.toUpperCase();
  return _kColKeywords.where((k) => up.contains(k)).length >= 2;
}
List<String> _extractColNames(String line) {
  const skip = {'AND','OR','THE','FOR','IN','OF','AT','BY'};
  final tokens = line.toUpperCase().split(RegExp(r'\s+'))
      .map((t) => t.replaceAll(RegExp(r'[^A-Z]'), ''))
      .where((t) => t.length >= 2 && !skip.contains(t)).toList();
  final recognised = tokens.where(_kColKeywords.contains).toList();
  final result = recognised.isNotEmpty ? recognised : tokens.where((t) => t.length >= 3).toList();
  return result.map((n) => n[0] + n.substring(1).toLowerCase()).toList();
}
bool _isCatHeading(String line) {
  if (_isMostlyNonLatin(line)) return false;
  if (RegExp(r'\d').hasMatch(line)) return false;
  if (line != line.toUpperCase()) return false;
  if (!RegExp(r'[A-Z]{3,}').hasMatch(line)) return false;
  if (line.length > 50) return false;
  return line.replaceAll(RegExp(r'[^A-Z\s]'), '').trim().length >= 3;
}
String _catFromHeading(String line) =>
    _toTitleCase(line.replaceAll(RegExp(r'[^A-Z\s]'), '').trim());

final _reTrailingPrice = RegExp(r'\s+([\d]{1,4}(?:\.\d{1,2})?)\s*$');
final _reTrailingDash  = RegExp(r'\s*([-–—])\s*$');
final _reOnlyPrices    = RegExp(r'^[\d\s.\-–—]+$');
final _reSerialPrice   = RegExp(r'^\d+[\.\)]\s*[\d\-–—\s]+$');
final _reAllDigits     = RegExp(r'^\d+$');

({String name, List<String> prices}) _peelPrices(String line, {int maxTokens = 5}) {
  var working = line;
  final peeled = <String>[];
  for (var i = 0; i < maxTokens; i++) {
    final pm = _reTrailingPrice.firstMatch(working);
    if (pm != null) {
      final raw = _fixOcrDigits(pm.group(1)!);
      if ((double.tryParse(raw) ?? 0) >= 5) {
        peeled.insert(0, raw);
        working = working.substring(0, pm.start).trimRight();
        continue;
      }
    }
    final dm = _reTrailingDash.firstMatch(working);
    if (dm != null) {
      peeled.insert(0, '');
      working = working.substring(0, dm.start).trimRight();
      continue;
    }
    break;
  }
  final cleanName = working
      .replaceAll(RegExp(r'^\d+[\.\)]\s*'), '')
      .replaceAll(RegExp(r'[.…]{3,}'), '')
      .trim();
  return (name: cleanName, prices: peeled);
}

List<Map<String, dynamic>> _buildColVariants(List<String> prices, List<String> cols) {
  final aligned = prices.length > cols.length
      ? prices.sublist(prices.length - cols.length)
      : [...prices, ...List.filled(cols.length - prices.length, '')];
  final result = <Map<String, dynamic>>[];
  for (int i = 0; i < cols.length; i++) {
    final p = i < aligned.length ? aligned[i] : '';
    if (p.isEmpty) continue;
    final pVal = double.tryParse(p) ?? 0;
    if (pVal > 0) result.add({'n': cols[i], 'p': pVal.toInt()});
  }
  return result;
}

String _fallbackRegexParse(String rawText) {
  final rawLines = rawText
      .replaceAll('\r\n', '\n').replaceAll('\r', '\n')
      .split('\n').map((l) => l.trimRight())
      .where((l) => l.trim().isNotEmpty).toList();
  if (rawLines.isEmpty) return '';

  String       currentCat  = 'Other';
  List<String> currentCols = [];
  final        rows        = <String>[];

  final lines = rawLines.map((l) => l.trim()).where((l) {
    if (l.length < 2) return false;
    if (_isMostlyNonLatin(l)) return false;
    if (RegExp(r'^[-=_|*\s]{3,}$').hasMatch(l)) return false;
    if (_reSerialPrice.hasMatch(l)) return false;
    return true;
  }).toList();

  for (final line in lines) {
    if (_isCatHeading(line)) {
      currentCat  = _catFromHeading(line);
      currentCols = [];
      continue;
    }
    if (_isColHeaderLine(line)) {
      final e = _extractColNames(line);
      if (e.length >= 2) currentCols = e;
      continue;
    }
    if (_reOnlyPrices.hasMatch(line)) continue;

    final maxPeel = currentCols.isNotEmpty ? currentCols.length + 1 : 2;
    final (:name, :prices) = _peelPrices(line, maxTokens: maxPeel);
    if (prices.isEmpty || prices.every((p) => p.isEmpty)) continue;
    if (name.isEmpty || _reAllDigits.hasMatch(name)) continue;
    if (!RegExp(r'[A-Za-z]').hasMatch(name)) continue;

    final List<Map<String, dynamic>> variants;
    if (currentCols.isNotEmpty) {
      variants = _buildColVariants(prices, currentCols);
    } else {
      final p    = prices.firstWhere((x) => x.isNotEmpty, orElse: () => '');
      final pVal = double.tryParse(p) ?? 0;
      variants   = pVal > 0 ? [{'n': 'Regular', 'p': pVal.toInt()}] : [];
    }
    if (variants.isEmpty) continue;

    final firstPrice = variants.first['p'].toString();
    final varJson    = '[${variants.map((v) => '{"n":"${v['n']}","p":${v['p']}}').join(',')}]';
    rows.add('${name.replaceAll('\t',' ')}\t$firstPrice\t${currentCat.replaceAll('\t',' ')}\t$varJson');
  }
  return rows.join('\n');
}

// ─────────────────────────────────────────────────────────────────────────────
//  Master entry point — Gemini Vision reads image directly (no OCR step).
//  Free API key from https://aistudio.google.com/app/apikey
// ─────────────────────────────────────────────────────────────────────────────
Future<String> _extractMenuToTsv(Uint8List imageBytes) async {
  if (_kGeminiKey.isNotEmpty) {
    final items = await _extractWithGeminiVision(imageBytes);
    if (items.isNotEmpty) {
      final tsv = _claudeItemsToTsv(items);
      if (tsv.isNotEmpty) {
        debugPrint('GEMINI: TSV built with ${items.length} items');
        return tsv;
      }
    }
    debugPrint('GEMINI: Empty result');
  }
  return '';
}


//  Per-image lifecycle model
// ─────────────────────────────────────────────────────────────────────────────
class _PickedImage {
  final String    name;
  final Uint8List bytes;
  String? csvRows;
  int     rowCount  = 0;
  bool    reading   = false;
  bool    done      = false;
  bool    failed    = false;
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
  bool _translateToGu = _kTranslateKey.isNotEmpty;

  // ── Auth helper ───────────────────────────────────────────────────────────
  Future<bool> _ensureAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Not signed in. Please log in as admin before uploading.', error: true);
      return false;
    }
    try {
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

  // ── Step 2: Process images → OCR → preview ───────────────────────────────
  //
  //  ROOT-CAUSE FIX — variants not saving correctly:
  //  OLD: simple CSV (name,price,category) → parseCsv → patch loop after delay
  //       parseCsv sets Regular variant, patch may be lost by updateItemImage.
  //  NEW: advanced CSV (name,category,variant_name,price) — one row per variant.
  //       _parseAdvanced groups by item name and builds MenuVariants in one shot.
  //       No patch step. No race condition. No overwriting.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _processImages() async {
    if (_isProcessing || _images.isEmpty) return;
    if (!await _ensureAuth()) return;

    setState(() => _isProcessing = true);

    // A. Send each image directly to Gemini Vision — no OCR step needed
    for (final img in _images) {
      if (img.csvRows != null || img.failed) continue;

      if (_kGeminiKey.isEmpty) {
        setState(() {
          img.done       = true;
          img.failed     = true;
          img.failReason = 'GEMINI_KEY is not set. '
              'Run: flutter run --dart-define=GEMINI_KEY=AIzaSy...';
        });
        continue;
      }

      setState(() => img.reading = true);

      final tsvRows = await _extractMenuToTsv(img.bytes);
      debugPrint('GEMINI ROWS [${img.name}]:\n$tsvRows');

      setState(() {
        img.reading  = false;
        img.csvRows  = tsvRows;
        img.rowCount = tsvRows.isEmpty
            ? 0
            : tsvRows.split('\n').where((l) => l.trim().isNotEmpty).length;
        img.done = true;
        if (tsvRows.isEmpty) {
          img.failed     = true;
          img.failReason = 'No menu items found — try a clearer, well-lit photo';
        }
      });
    }

    // ── B. Collect all TSV rows ───────────────────────────────────────────
    final allRows = <String>[];
    for (final img in _images) {
      if (img.csvRows == null || img.csvRows!.isEmpty) continue;
      allRows.addAll(
          img.csvRows!.split('\n').where((l) => l.trim().isNotEmpty));
    }

    if (allRows.isEmpty) {
      _snack('No menu items extracted. Check the browser console (F12) for OCR output.',
          error: true);
      setState(() => _isProcessing = false);
      return;
    }

    // ── C. Convert TSV → ADVANCED CSV (name,category,variant_name,price) ──
    //
    //  TSV row:  name \t firstPrice \t category \t [{"n":"Oil","p":100},...]
    //  We expand each variant into its own CSV row so _parseAdvanced builds
    //  the correct MenuVariant list in one pass — no patching needed.
    // ─────────────────────────────────────────────────────────────────────
    final advCsvBuf = StringBuffer();
    advCsvBuf.writeln('name,category,variant_name,price');

    for (final row in allRows) {
      final parts   = row.split('\t');
      final name    = (parts.isNotEmpty ? parts[0] : '').trim();
      final cat     = (parts.length > 2 ? parts[2] : 'Other').trim();
      final varJson = (parts.length > 3 ? parts[3] : '[]').trim();
      if (name.isEmpty) continue;

      List<dynamic> variants = [];
      try { variants = json.decode(varJson) as List; } catch (_) {}

      if (variants.isEmpty) {
        final price = (parts.length > 1 ? parts[1] : '0').trim();
        advCsvBuf.writeln(
            '${_csvEscape(name)},${_csvEscape(cat)},Regular,$price');
      } else {
        for (final v in variants) {
          final m        = v as Map;
          final varName  = m['n']?.toString() ?? 'Regular';
          final varPrice = (m['p'] as num?)?.toString() ?? '0';
          advCsvBuf.writeln(
              '${_csvEscape(name)},${_csvEscape(cat)},${_csvEscape(varName)},$varPrice');
        }
      }
    }

    final advCsv = advCsvBuf.toString().trim();
    debugPrint('ADVANCED CSV sent to provider:\n$advCsv');

    // ── D. One call to parseCsv — variants fully built, no patch needed ───
    await _notifier.parseCsv(advCsv, widget.restaurantId);

    // ── E. Auto-fetch food images (safe: variants already in provider) ────
    await _autoFetchImages();

    // ── F. Translate to Gujarati if enabled ───────────────────────────────
    if (_translateToGu && _kTranslateKey.isNotEmpty) {
      await _applyGujaratiTranslations();
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _autoFetchImages() async {
    final items = _notifier.state.items;
    for (int i = 0; i < items.length; i++) {
      if (i >= _notifier.state.items.length) break;
      final item = _notifier.state.items[i];
      if (item.image.isNotEmpty) continue;
      final query    = Uri.encodeComponent(item.name.split(' ').take(2).join(' '));
      final imageUrl = 'https://source.unsplash.com/200x200/?$query,food,indian';
      _notifier.updateItemImage(i, imageUrl);
    }
  }

  Future<void> _applyGujaratiTranslations() async {
    final items = _notifier.state.items;
    if (items.isEmpty) return;
    setState(() {});
    final names      = items.map((i) => i.name).toList();
    final translated = await _translateToGujarati(names);
    for (int i = 0; i < items.length; i++) {
      if (i >= _notifier.state.items.length) break;
      final gujaratiName = i < translated.length ? translated[i] : '';
      if (gujaratiName.isEmpty || gujaratiName == names[i]) continue;
      _notifier.updateItem(
        i,
        _notifier.state.items[i].copyWith(description: gujaratiName),
      );
    }
  }

  String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
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
            child: Text('Close', style: _p(13, FontWeight.w600, _kOrange)),
          ),
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
            : _OutlineBtn(
          label: 'Upload CSV',
          icon: Icons.table_chart_outlined,
          onTap: _pickCsvFile,
        ),
        const SizedBox(width: 8),
        _OutlineBtn(
          label: 'Sample CSV',
          icon: Icons.download_rounded,
          onTap: () => _downloadSample(false),
        ),
        const SizedBox(width: kIsWeb ? 20 : 12),
      ],
    );
  }

  Widget _loadingChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: _kOrangeBg, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(
          width: 14,
          height: 14,
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
            _StepRow(steps: const [
              'Pick photos',
              'AI reads menu',
              'Review items',
              'Save to menu'
            ]),
            const SizedBox(height: 28),
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
                    BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 20,
                        offset: Offset(0, 4))
                  ],
                ),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child:
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                          color: _kOrangeBg,
                          borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.add_photo_alternate_outlined,
                          size: 36, color: _kOrange),
                    ),
                    const SizedBox(height: 18),
                    Text('Tap to select menu photos',
                        style: _p(17, FontWeight.w600, _kTextDark)),
                    const SizedBox(height: 6),
                    Text(
                        'AI extracts every dish, price and category automatically',
                        style: _p(13, FontWeight.w400, _kTextMid),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          color: _kOrangeBg,
                          borderRadius: BorderRadius.circular(10)),
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
      Container(
        color: _kCard,
        padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 24 : 16, vertical: 12),
        child: Row(children: [
          _StatusChip(
              label: '$total photo${total == 1 ? '' : 's'}',
              color: _kOrange,
              bg: _kOrangeBg),
          if (done > 0) ...[
            const SizedBox(width: 8),
            _StatusChip(
                label: '$totalRows items found',
                color: _kGreen,
                bg: _kGreenBg),
          ],
          if (failed > 0) ...[
            const SizedBox(width: 8),
            _StatusChip(
                label: '$failed failed', color: _kRed, bg: _kRedBg),
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
              label: Text('Clear all',
                  style: _p(12, FontWeight.w500, _kTextLight)),
              style: TextButton.styleFrom(foregroundColor: _kTextLight),
            ),
            const SizedBox(width: 8),
            _TranslateToggle(
              enabled: _translateToGu,
              hasKey: _kTranslateKey.isNotEmpty,
              onChanged: (v) => setState(() => _translateToGu = v),
            ),
            const SizedBox(width: 4),
          ],
          _buildConvertButton(),
        ]),
      ),
      if (_isProcessing)
        _AnimatedProgressBar(
          label: _progressLabel(),
          value: progress,
          color: _kOrange,
        ),
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
    if (_images.any((i) => i.reading)) return 'AI reading menu images…';
    if (_translateToGu && _kTranslateKey.isNotEmpty) return 'Translating to Gujarati…';
    return 'Building preview…';
  }

  Widget _buildConvertButton() {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : _processImages,
      icon: _isProcessing
          ? const SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white))
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
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  // ── Preview body ──────────────────────────────────────────────────────────
  Widget _buildPreviewBody(CsvUploadState state) {
    return Column(children: [
      Container(
        color: _kCard,
        padding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 24 : 16, vertical: 12),
        child: Row(children: [
          _StatusChip(
              label: '${state.validItemCount} valid',
              color: _kGreen,
              bg: _kGreenBg),
          if (state.errorItemCount > 0) ...[
            const SizedBox(width: 8),
            _StatusChip(
                label: '${state.errorItemCount} errors',
                color: _kRed,
                bg: _kRedBg),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: state.isLoading
                ? null
                : () {
              _notifier.reset();
              setState(() => _images.clear());
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label:
            Text('Start over', style: _p(12, FontWeight.w500, _kTextLight)),
            style: TextButton.styleFrom(foregroundColor: _kTextLight),
          ),
          const SizedBox(width: 8),
          _buildSaveButton(state),
        ]),
      ),
      if (state.step == UploadStep.fetchingImages)
        _AnimatedProgressBar(
          label:
          'Fetching images ${state.imagesDone}/${state.imagesTotal}…',
          value: state.imageProgress,
          color: _kOrange,
        ),
      if (state.step == UploadStep.saving)
        _AnimatedProgressBar(
          label: 'Saving ${state.savedCount}/${state.totalToSave} items…',
          value: state.saveProgress,
          color: _kGreen,
        ),
      if (state.step == UploadStep.resolvingCategories)
        const LinearProgressIndicator(
            color: _kOrange,
            minHeight: 3,
            backgroundColor: Color(0xFFE5E7EB)),
      if (state.step == UploadStep.done)
        _DoneBanner(savedCount: state.savedCount),
      if (state.step == UploadStep.error && state.errorMessage != null)
        _ErrorBanner(message: state.errorMessage!),
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
          ? const SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white))
          : Icon(done ? Icons.check_circle : Icons.save_rounded, size: 17),
      label: Text(label, style: _p(13, FontWeight.w600, Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: done ? _kGreen : _kOrange,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
        done ? _kGreen : _kOrange.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            child: Icon(Icons.arrow_forward_rounded,
                size: 12, color: _kTextLight.withOpacity(0.5)),
          );
        }
        final idx = i ~/ 2;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration:
            const BoxDecoration(color: _kOrange, shape: BoxShape.circle),
            child: Text('${idx + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
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
  final Color  color;
  const _AnimatedProgressBar(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    color: _kCard,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: _p(12, FontWeight.w500, _kTextMid)),
        Text('${(value * 100).toInt()}%',
            style: _p(11, FontWeight.w600, color)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 300),
          builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              backgroundColor: _kBorder,
              color: color,
              minHeight: 5),
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
      Expanded(
          child: Text(
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
        child:
        Icon(Icons.error_outline_rounded, color: _kRed, size: 20),
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
    const example = 'name,price,category\n'
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
          Text('AI-generated CSV format',
              style: _p(13, FontWeight.w600, _kTextDark)),
        ]),
        const SizedBox(height: 10),
        Text('Each photo produces rows in this format:',
            style: _p(12, FontWeight.w400, _kTextMid)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _kOrangeLight,
              borderRadius: BorderRadius.circular(10)),
          child: SelectableText(example,
              style: _p(11.5, FontWeight.w500, _kTextDark)
                  .copyWith(fontFamily: 'monospace', height: 1.8)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 14, color: _kGreen),
          const SizedBox(width: 6),
          Expanded(
              child: Text(
                  'Feeds directly into the review screen before saving',
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
  final Color  color, bg;
  const _StatusChip(
      {required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration:
    BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: _p(12, FontWeight.w600, color)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Image tile
// ─────────────────────────────────────────────────────────────────────────────
class _ImageTile extends StatelessWidget {
  final _PickedImage   img;
  final VoidCallback?  onRemove;
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
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
                  child: Image.memory(img.bytes, fit: BoxFit.cover),
                ),
                if (img.reading)
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(13)),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                          const SizedBox(height: 10),
                          Text('AI reading…',
                              style: _p(11, FontWeight.w600, Colors.white),
                              textAlign: TextAlign.center),
                        ]),
                  ),
                if (img.done && !img.failed)
                  Positioned(
                    top: 8,
                    right: 8,
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
                if (img.failed)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: _kRed, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ),
                if (onRemove != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(img.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _p(11, FontWeight.w600, _kTextDark)),
                    const SizedBox(height: 2),
                    Text(
                      img.failed
                          ? (img.failReason ?? 'Could not read menu')
                          : img.done
                          ? '${img.rowCount} items extracted'
                          : img.reading
                          ? 'AI reading…'
                          : 'Ready',
                      maxLines: 2,
                      style: _p(
                          10,
                          FontWeight.w500,
                          img.failed
                              ? _kRed
                              : img.done
                              ? _kGreen
                              : _kTextLight),
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
  final MenuItem                   item;
  final int                        index;
  final Map<String, CategoryModel> categoryMap;
  final ValueChanged<MenuItem>     onUpdate;
  final ValueChanged<String>       onImageChange;
  final VoidCallback               onRemove;

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
  String?   _selectedCategory;
  Uint8List? _localBytes;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl         = TextEditingController(text: widget.item.name);
    _imageUrlCtrl     = TextEditingController(text: widget.item.image);
    _selectedCategory =
    widget.item.categoryName.isEmpty ? null : widget.item.categoryName;
    _initVariants();
  }

  @override
  void didUpdateWidget(_MenuItemCard old) {
    super.didUpdateWidget(old);
    if (widget.item.variants.length != old.item.variants.length) {
      for (final c in [..._vNameCtrls, ..._vPriceCtrls]) c.dispose();
      _initVariants();
    }
    if (widget.item.categoryName != old.item.categoryName &&
        widget.item.categoryName.isNotEmpty) {
      _selectedCategory = widget.item.categoryName;
    }
    if (widget.item.image != old.item.image && _localBytes == null) {
      _imageUrlCtrl.text = widget.item.image;
    }
  }

  void _initVariants() {
    _vNameCtrls = widget.item.variants
        .map((v) => TextEditingController(text: v.name))
        .toList();
    _vPriceCtrls = widget.item.variants
        .map((v) => TextEditingController(text: v.price.toInt().toString()))
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
    setState(() {
      _localBytes = bytes;
      _uploading  = true;
    });
    final url = await _uploadToImgBB(bytes, picked.name);
    if (!mounted) return;
    if (url != null) {
      widget.onImageChange(url);
      _imageUrlCtrl.text = url;
      setState(() => _uploading = false);
    } else {
      setState(() {
        _localBytes = null;
        _uploading  = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Image upload failed',
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
    final err =
        _nameCtrl.text.trim().isEmpty || variants.isEmpty;
    widget.onUpdate(widget.item.copyWith(
      name:         _nameCtrl.text.trim(),
      categoryName: _selectedCategory ?? widget.item.categoryName,
      image:        _imageUrlCtrl.text.trim(),
      variants:     variants,
      hasError:     err,
      errorMessage: err
          ? 'Item name and at least one valid variant are required.'
          : null,
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
        border: Border.all(
            color: hasErr ? _kRed.withOpacity(0.35) : _kBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x04000000),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // Collapsed row
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Thumbnail
                GestureDetector(
                  onTap: _uploading ? null : _pickAndUpload,
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: _uploading
                            ? Stack(fit: StackFit.expand, children: [
                          if (_localBytes != null)
                            Image.memory(_localBytes!, fit: BoxFit.cover)
                          else
                            _imgPlaceholder(),
                          Container(color: Colors.black38),
                          const Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
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
                                _imgPlaceholder())
                            : _imgPlaceholder(),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 20,
                        decoration: const BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(10))),
                        alignment: Alignment.center,
                        child: const Text('Change',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
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
                            style: _p(14, FontWeight.w600, _kTextDark)),
                        if (item.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Row(children: [
                              Container(
                                margin: const EdgeInsets.only(right: 5),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0E8),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: _kOrange.withOpacity(0.3)),
                                ),
                                child: Text('gu',
                                    style: _p(8, FontWeight.w700, _kOrange)),
                              ),
                              Expanded(
                                child: Text(item.description,
                                    style: _p(12, FontWeight.w400, _kTextLight),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ),
                        if (item.categoryName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(item.categoryName,
                                style: _p(12, FontWeight.w400, _kTextLight)),
                          ),
                        if (hasErr && item.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 12, color: _kRed),
                              const SizedBox(width: 4),
                              Expanded(
                                  child: Text(item.errorMessage!,
                                      style:
                                      _p(11, FontWeight.w400, _kRed))),
                            ]),
                          ),
                        if (item.variants.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Wrap(
                                spacing: 5,
                                runSpacing: 3,
                                children: item.variants
                                    .map((v) => _VariantChip(v))
                                    .toList()),
                          ),
                      ]),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.edit_outlined,
                        size: 19,
                        color: _kOrange),
                    onPressed: () =>
                        setState(() => _expanded = !_expanded),
                    tooltip: _expanded ? 'Collapse' : 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 19, color: _kTextLight),
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
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Divider(height: 1, color: _kBorder),
              const SizedBox(height: 16),

              // Image
              _label('Item Image'),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 110,
                  height: 110,
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
                        _imgPlaceholder(large: true),
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
                            _imgPlaceholder(large: true))
                        : _imgPlaceholder(large: true),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upload from gallery or paste a URL',
                            style: _p(12, FontWeight.w400, _kTextMid)),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickAndUpload,
                          icon: _uploading
                              ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _kOrange))
                              : const Icon(Icons.image_outlined,
                              color: _kOrange, size: 16),
                          label: Text(
                              _uploading ? 'Uploading…' : 'Upload Image',
                              style: _p(12, FontWeight.w500, _kOrange)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            side: BorderSide(
                                color: _kOrange.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9)),
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
              TextField(
                  controller: _nameCtrl,
                  style: _p(13, FontWeight.w400, _kTextDark),
                  decoration:
                  _inputDecor('e.g. Paneer Butter Masala')),
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
                  label: Text('Add variant',
                      style: _p(12, FontWeight.w500, _kOrange)),
                  style: TextButton.styleFrom(
                      foregroundColor: _kOrange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5)),
                ),
              ]),
              const SizedBox(height: 6),
              ...List.generate(
                _vNameCtrls.length,
                    (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                        flex: 3,
                        child: TextField(
                            controller: _vNameCtrls[i],
                            style: _p(13, FontWeight.w400, _kTextDark),
                            decoration: _inputDecor('e.g. Regular'))),
                    const SizedBox(width: 10),
                    Expanded(
                        flex: 2,
                        child: TextField(
                            controller: _vPriceCtrls[i],
                            keyboardType: TextInputType.number,
                            style: _p(13, FontWeight.w400, _kTextDark),
                            decoration: _inputDecor('₹ Price'))),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: _kRed, size: 19),
                      onPressed: _vNameCtrls.length > 1
                          ? () => _removeVariant(i)
                          : null,
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => setState(() => _expanded = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kTextMid,
                    side: const BorderSide(color: _kBorder),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: Text('Cancel',
                      style: _p(12, FontWeight.w500, _kTextMid)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _applyChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: Text('Apply Changes',
                      style: _p(12, FontWeight.w600, Colors.white)),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _imgPlaceholder({bool large = false}) => Container(
    color: _kOrangeLight,
    child: Icon(Icons.fastfood_rounded,
        color: _kOrange, size: large ? 36 : 28),
  );

  Widget _label(String t) =>
      Text(t, style: _p(12, FontWeight.w600, _kTextDark));
}

// ─────────────────────────────────────────────────────────────────────────────
//  Category dropdown
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryDropdown extends StatelessWidget {
  final Map<String, CategoryModel> categoryMap;
  final String?                    selectedName;
  final ValueChanged<String?>      onChanged;
  const _CategoryDropdown(
      {required this.categoryMap,
        required this.selectedName,
        required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final existing = categoryMap.values.map((c) => c.name).toSet();
    final names    = existing.toList()..sort();

    final isNew = selectedName != null &&
        selectedName!.isNotEmpty &&
        !existing.contains(selectedName);
    if (isNew) names.insert(0, selectedName!);

    final eff = names.contains(selectedName) ? selectedName : null;

    return DropdownButtonFormField<String>(
      value: eff,
      hint: Text('Select category',
          style: _p(13, FontWeight.w400, _kTextLight)),
      decoration: _inputDecor(''),
      items: names.map((n) {
        final isNewCat = !existing.contains(n);
        return DropdownMenuItem(
          value: n,
          child: Row(children: [
            Expanded(child: Text(n, style: _p(13, FontWeight.w400, _kTextDark))),
            if (isNewCat)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: _kOrangeBg,
                    borderRadius: BorderRadius.circular(4)),
                child: Text('new', style: _p(9, FontWeight.w700, _kOrange)),
              ),
          ]),
        );
      }).toList(),
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
    decoration: BoxDecoration(
        color: _kOrangeLight,
        borderRadius: BorderRadius.circular(20)),
    child: Text('${variant.name} · ₹${variant.price.toInt()}',
        style: _p(11, FontWeight.w600, _kOrange)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Outline button
// ─────────────────────────────────────────────────────────────────────────────
class _OutlineBtn extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final VoidCallback onTap;
  const _OutlineBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14),
    label: Text(label, style: _p(12, FontWeight.w500, _kOrange)),
    style: OutlinedButton.styleFrom(
      foregroundColor: _kOrange,
      side: const BorderSide(color: _kOrange),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Input decoration
// ─────────────────────────────────────────────────────────────────────────────
InputDecoration _inputDecor(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(
      color: _kTextLight,
      fontSize: 13,
      fontFamily: GoogleFonts.poppins().fontFamily),
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
      borderSide: const BorderSide(color: _kOrange, width: 1.5)),
);

// ─────────────────────────────────────────────────────────────────────────────
//  Gujarati Translation Toggle
// ─────────────────────────────────────────────────────────────────────────────
class _TranslateToggle extends StatelessWidget {
  final bool enabled;
  final bool hasKey;
  final ValueChanged<bool> onChanged;
  const _TranslateToggle(
      {required this.enabled,
        required this.hasKey,
        required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hasKey
          ? 'Auto-translate item names to Gujarati'
          : 'Add GOOGLE_TRANSLATE_KEY to enable auto-translation',
      child: GestureDetector(
        onTap: () => hasKey ? onChanged(!enabled) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: enabled && hasKey
                ? const Color(0xFFFFF0E8)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: enabled && hasKey
                  ? _kOrange.withOpacity(0.5)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('ગુ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: enabled && hasKey ? _kOrange : _kTextLight,
                )),
            const SizedBox(width: 6),
            Text('Gujarati',
                style: _p(11, FontWeight.w600,
                    enabled && hasKey ? _kOrange : _kTextLight)),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 16,
              decoration: BoxDecoration(
                color: enabled && hasKey
                    ? _kOrange
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: enabled && hasKey
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
            if (!hasKey) ...[
              const SizedBox(width: 4),
              const Icon(Icons.lock_outline_rounded,
                  size: 11, color: _kTextLight),
            ],
          ]),
        ),
      ),
    );
  }
}