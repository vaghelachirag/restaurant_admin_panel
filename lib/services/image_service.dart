import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
//  ImageService
//
//  Resolution order for every menu item name:
//   1. In-session memory cache (instant, no network)
//   2. Firestore image cache collection (avoids duplicate API calls)
//   3. Keyword map (curated, always correct food images)
//   4. Firebase Cloud Function → Unsplash API (dynamic, accurate)
//   5. Category-based fallback image (guaranteed non-null)
// ─────────────────────────────────────────────────────────────────────────────

class ImageService {
  final FirebaseFirestore _db;

  ImageService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── In-memory cache (per app session) ────────────────────────────────────
  final Map<String, String> _memCache = {};

  // ── Firestore cache collection ────────────────────────────────────────────
  CollectionReference get _cacheRef =>
      _db.collection('menu_image_cache');

  // ─────────────────────────────────────────────────────────────────────────
  //  Keyword → Image URL map
  //  Use high-quality, stable, publicly accessible food images.
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, String> _keywordImages = {

    // ───────────────── Gujarati Main Sabzi ─────────────────
    'sev tameta': 'https://i.ibb.co/jPppW02F/sev-tamata.jpg',
    'sev tomato': 'https://i.ibb.co/jPppW02F/sev-tamata.jpg',
    'suki bhaji': 'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'bataka nu shaak': 'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'bataka bhaji': 'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'aloo sabji': 'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'ringna bataka': 'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'undhiyu': 'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'mix veg': 'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'gujarati sabji': 'https://i.ibb.co/d04sDbST/mix-veg.jpg',

// ───────────────── Dal / Kadhi / Rice ─────────────────
    'gujarati dal': 'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'daal': 'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'dal fry': 'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'kadhi': 'https://i.ibb.co/Vppg6n75/dahi.jpg',
    'kadhi khichdi': 'https://i.ibb.co/Vppg6n75/dahi.jpg',
    'khichdi': 'https://i.ibb.co/DHCdDmwZ/Rice.jpg',
    'vaghareli khichdi': 'https://i.ibb.co/DHCdDmwZ/Rice.jpg',
    'jeera rice': 'https://i.ibb.co/DHCdDmwZ/Rice.jpg',
    'steam rice': 'https://i.ibb.co/DHCdDmwZ/Rice.jpg',

// ───────────────── Rotli / Breads ─────────────────
    'rotli': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'phulka': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'chapati': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'bhakhri': 'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'thepla': 'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'methi thepla': 'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'paratha': 'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'puri': 'https://i.ibb.co/YFrtBSS0/puri-shak.jpg',

// ───────────────── Snacks / Farsan ─────────────────
    'dhokla': 'https://i.ibb.co/fzjQWzx4/salad.jpg',
    'khaman': 'https://i.ibb.co/fzjQWzx4/salad.jpg',
    'khaman dhokla': 'https://i.ibb.co/fzjQWzx4/salad.jpg',
    'fafda': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'fafda jalebi': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'patra': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'handvo': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'ganthiya': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'sev': 'https://i.ibb.co/jPppW02F/sev-tamata.jpg',

// ───────────────── Street Food Gujarati ─────────────────
    'locho': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'sev usal': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'usal': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'vada pav': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
    'dabeli': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
    'pav bhaji': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',

// ───────────────── Dairy / Sides ─────────────────
    'dahi': 'https://i.ibb.co/Vppg6n75/dahi.jpg',
    'curd': 'https://i.ibb.co/Vppg6n75/dahi.jpg',
    'chaas': 'https://i.ibb.co/4RTPQqCS/butter-milk.jpg',
    'buttermilk': 'https://i.ibb.co/4RTPQqCS/butter-milk.jpg',
    'salad': 'https://i.ibb.co/fzjQWzx4/salad.jpg',
    'papad': 'https://i.ibb.co/7NLnSw1b/paapad.jpg',
    'pickle': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',

// ───────────────── Sweets (Gujarati) ─────────────────
    'shree khand': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'shrikhand': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'basundi': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'lapsi': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'mohanthal': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'gulab jamun': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'jalebi': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',

    // ───────────────── Thali Keywords ─────────────────
    'full thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'gujarati thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'mini gujarati thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'deluxe gujarati thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'special gujarati thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'unlimited gujarati thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'regular thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'special thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'deluxe thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'mini thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'unlimited thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'full meal': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'complete meal': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',

    'kathiyawadi thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiawadi thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiyawadi special thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiawadi special thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiyawadi meal': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiawadi meal': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',

    'punjabi thali': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'punjabi special thali': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'punjabi deluxe thali': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'punjabi meal': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'punjabi lunch': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'punjabi dinner': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',

    'thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'meal': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'gujarati': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiyawadi': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiawadi': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'punjabi': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',


    // Indian mains
    'paneer':   'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'biryani':  'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80',
    'dosa':     'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w5MTg3NDh8MHwxfHNlYXJjaHwxfHxEb3NhfGVufDB8fHx8MTc3NTYzMjI1Mnww&ixlib=rb-4.1.0&q=80&w=400',
    'dhosa':    'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w5MTg3NDh8MHwxfHNlYXJjaHwxfHxEb3NhfGVufDB8fHx8MTc3NTYzMjI1Mnww&ixlib=rb-4.1.0&q=80&w=400',
    'idli':     'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'vada':     'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'roti':     'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'naan':     'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'rice':     'https://images.unsplash.com/photo-1536304993881-ff86e6c89c0d?w=400&q=80',
    'dal':      'https://images.unsplash.com/photo-1626500154744-e4b394ffea16?w=400&q=80',
    'curry':    'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'kaju':     'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'masala':   'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'tikka':    'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'kebab':    'https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80',
    'tandoor':  'https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80',
    'samosa':   'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'chana':   'https://i.ibb.co/4RBqprCD/chanapuri.jpg',
    'maggi':   'https://i.ibb.co/FL4RhV0D/maggie.jpg',
    'parotha':   'https://i.ibb.co/LX79cbxn/parotha.jpg',
    // International
    'pizza':    'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&q=80',
    'burger':   'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
    'pasta':    'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=400&q=80',
    'noodle':   'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&q=80',
    'sandwich': 'https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=400&q=80',
    'wrap':     'https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=400&q=80',
    'roll':     'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&q=80',
    // Beverages
    'chai':     'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&q=80',
    'tea':      'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&q=80',
    'coffee':   'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400&q=80',
    'juice':    'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'lassi':    'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'shake':    'https://images.unsplash.com/photo-1619158401201-8fa94e9c5b45?w=400&q=80',
    'mocktail': 'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=400&q=80',
    'water':    'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=400&q=80',
    // Desserts
    'ice cream':'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'icecream': 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'kulfi':    'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'gulab':    'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'halwa':    'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'cake':     'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&q=80',
    'brownie':  'https://images.unsplash.com/photo-1564355808539-22fda35bed7e?w=400&q=80',
    'sweet':    'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'mithai':   'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    // Breads / Snacks
    'bhatura':  'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'pakora':   'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'chaat':    'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'pav':      'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    // Chicken / Meat
    'chicken':  'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400&q=80',
    'mutton':   'https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80',
    'fish':     'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&q=80',
    'prawn':    'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&q=80',
    'egg':      'https://images.unsplash.com/photo-1607690022687-5c37be86c7e1?w=400&q=80',
    'milk':      'https://i.ibb.co/4RTPQqCS/butter-milk.jpg',
    'manchurian': 'https://i.ibb.co/f6YBw0t/manchuriyan.jpg',
    'pulav': 'https://i.ibb.co/PG9pMZfP/pulav.jpg',
    'noodles': 'https://i.ibb.co/BKGvxZDK/noodles.jpg',
    'veg': 'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'Rice': 'https://i.ibb.co/DHCdDmwZ/Rice.jpg',
    'Noodles': 'https://i.ibb.co/BKGvxZDK/noodles.jpg',

  };



  // ─────────────────────────────────────────────────────────────────────────
  //  Category fallback images
  // ─────────────────────────────────────────────────────────────────────────

  static const String _defaultFallback =
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&q=80';

  static const Map<String, String> _categoryFallbacks = {
    'ice cream':  'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'icecream':   'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'pizza':      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&q=80',
    'burger':     'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
    'biryani':    'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80',
    'soup':       'https://i.ibb.co/5hsHrYvD/soup.jpg',
    'salad':      'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&q=80',
    'beverages':  'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'drinks':     'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'desserts':   'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&q=80',
    'sweets':     'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'starters':   'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'snacks':     'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'breads':     'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'chicken':    'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400&q=80',
    'seafood':    'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&q=80',
    'chinese':    'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&q=80',
    'italian':    'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=400&q=80',
    'south indian': 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=400&q=80',
    'north indian': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
  };

  // ─────────────────────────────────────────────────────────────────────────
  //  Main resolve method — call this for each menu item
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> resolveImage({
    required String itemName,
    required String categoryName,
    String? cloudFunctionUrl,
  }) async {
    final cacheKey = _normalizeKey(itemName);

    // 1. Memory cache
    if (_memCache.containsKey(cacheKey)) return _memCache[cacheKey]!;

    // 2. Firestore cache
    final firestoreUrl = await _checkFirestoreCache(cacheKey);
    if (firestoreUrl != null) {
      _memCache[cacheKey] = firestoreUrl;
      return firestoreUrl;
    }

    // 3. Keyword match
    final keywordUrl = _matchKeyword(itemName);
    if (keywordUrl != null) {
      await _saveToCache(cacheKey, keywordUrl);
      return keywordUrl;
    }

    // 4. Cloud Function → Unsplash
    if (cloudFunctionUrl != null && cloudFunctionUrl.isNotEmpty) {
      final apiUrl = await _fetchFromCloudFunction(itemName, cloudFunctionUrl);
      if (apiUrl != null) {
        await _saveToCache(cacheKey, apiUrl);
        return apiUrl;
      }
    }

    // 5. Category fallback
    final fallback = _categoryFallback(categoryName);
    _memCache[cacheKey] = fallback; // cache fallback in memory only
    return fallback;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Resolve images for a full list (with concurrency limiting)
  // ─────────────────────────────────────────────────────────────────────────

  /// Resolves images for all [names] concurrently (max 5 at a time).
  /// Returns Map<itemName, imageUrl>.
  Future<Map<String, String>> resolveAll({
    required List<({String name, String category})> items,
    String? cloudFunctionUrl,
    void Function(int done, int total)? onProgress,
  }) async {
    final result = <String, String>{};
    int done = 0;
    const concurrency = 5;

    for (int i = 0; i < items.length; i += concurrency) {
      final chunk = items.sublist(
          i, i + concurrency > items.length ? items.length : i + concurrency);

      final futures = chunk.map((item) async {
        final url = await resolveImage(
          itemName: item.name,
          categoryName: item.category,
          cloudFunctionUrl: cloudFunctionUrl,
        );
        return MapEntry(item.name, url);
      });

      final resolved = await Future.wait(futures);
      for (final e in resolved) {
        result[e.key] = e.value;
      }
      done += chunk.length;
      onProgress?.call(done, items.length);
    }

    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _normalizeKey(String name) =>
      name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');

  String? _matchKeyword(String itemName) {
    final lower = itemName.toLowerCase();
    for (final entry in _keywordImages.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String _categoryFallback(String categoryName) {
    final lower = categoryName.toLowerCase().trim();
    for (final entry in _categoryFallbacks.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }
    return _defaultFallback;
  }

  Future<String?> _checkFirestoreCache(String key) async {
    try {
      final doc = await _cacheRef.doc(key).get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>?)?['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveToCache(String key, String url) async {
    _memCache[key] = url;
    try {
      await _cacheRef.doc(key).set({
        'url': url,
        'cachedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {} // non-critical — silently ignore
  }

  /// Calls your Firebase Cloud Function which wraps the Unsplash API.
  /// The function receives { query: "paneer butter masala" }
  /// and returns { url: "https://..." }
  Future<String?> _fetchFromCloudFunction(
      String itemName, String functionUrl) async {
    try {
      final query = _buildSearchQuery(itemName);
      final response = await http
          .post(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
    } catch (_) {}
    return null;
  }

  /// Cleans item name into a good Unsplash search query.
  /// "Paneer Butter Masala" → "paneer curry indian food"
  String _buildSearchQuery(String itemName) {
    final cleaned = itemName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .trim();
    // Append "food" so Unsplash returns food images, not random results
    return '$cleaned food';
  }
}