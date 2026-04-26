import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;


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
  //  Grouped by cuisine/business type for easy maintenance.
  //  Matching is substring-based (lowercase) so a key like 'masala dosa'
  //  matches "Mysore Masala Dosa" because it contains that substring.
  //  Keys are ordered longest-first within each section so more-specific
  //  phrases match before shorter generic ones.
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, String> _keywordImages = {

    // ═══════════════════════════════════════════════════════════════════════
    //  GUJARATI — Thali & Full Meals
    // ═══════════════════════════════════════════════════════════════════════

    'unlimited gujarati thali':  'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'deluxe gujarati thali':     'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'special gujarati thali':    'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'mini gujarati thali':       'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'gujarati thali':            'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiyawadi special thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiawadi special thali':  'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiyawadi thali':         'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiawadi thali':          'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiyawadi meal':          'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiawadi meal':           'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiyawadi':               'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiawadi':                'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'punjabi special thali':     'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'punjabi deluxe thali':      'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'punjabi thali':             'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'punjabi meal':              'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'punjabi lunch':             'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'punjabi dinner':            'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'unlimited thali':           'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'deluxe thali':              'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'special thali':             'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'mini thali':                'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'regular thali':             'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'full thali':                'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'complete meal':             'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'full meal':                 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'thali':                     'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'meal':                      'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'gujarati':                  'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  GUJARATI — Main Sabzi / Shaak
    // ═══════════════════════════════════════════════════════════════════════

    'sev tameta':             'https://i.ibb.co/jPppW02F/sev-tamata.jpg',
    'sev tamatar':            'https://i.ibb.co/jPppW02F/sev-tamata.jpg',
    'sev tomato':             'https://i.ibb.co/jPppW02F/sev-tamata.jpg',
    'sev bhaji':              'https://i.ibb.co/jPppW02F/sev-tamata.jpg',
    'lasaniya bataka':        'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'lasania batata':         'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'garlic potato':          'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'bataka nu shaak':        'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'bataka bhaji':           'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'aloo sabji':             'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'suki bhaji':             'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'ringan no olo':          'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'ringan na ola':          'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'baingan bharta':         'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'ringna bharta':          'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'bharela marcha nu shaak':'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'bharela marcha':         'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'stuffed chilli':         'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'stuffed pepper':         'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'ringan bataka':          'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'ringna batata':          'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'brinjal potato':         'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'dudhi chana':            'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'lauki chana':            'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'bottle gourd':           'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'tuvar lilva':            'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'toor lilva':             'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'fresh pigeon pea':       'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'undhiyu':                'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'undiya':                 'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'mix veg':                'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'gujarati sabji':         'https://i.ibb.co/d04sDbST/mix-veg.jpg',
    'gujarati shaak':         'https://i.ibb.co/d04sDbST/mix-veg.jpg',

    // ═══════════════════════════════════════════════════════════════════════
    //  GUJARATI — Dal / Kadhi / Rice
    // ═══════════════════════════════════════════════════════════════════════

    'dal dhokli':             'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'daal dhokli':            'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'gujarati dal':           'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'dal tadka':              'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'daal tadka':             'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'dal fry':                'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'daal fry':               'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'daal':                   'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'dal':                    'https://i.ibb.co/cSKkggND/dal-tadka.jpg',
    'kadhi khichdi':          'https://i.ibb.co/Vppg6n75/dahi.jpg',
    'kadhi':                  'https://i.ibb.co/Vppg6n75/dahi.jpg',
    'vaghareli khichdi':      'https://i.ibb.co/DHCdDmwZ/Rice.jpg',
    'vagharelo rotlo':        'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'khichdi':                'https://i.ibb.co/DHCdDmwZ/Rice.jpg',
    'jeera rice':             'https://i.ibb.co/DHCdDmwZ/Rice.jpg',
    'steam rice':             'https://i.ibb.co/DHCdDmwZ/Rice.jpg',
    'plain rice':             'https://i.ibb.co/DHCdDmwZ/Rice.jpg',
    'veg pulao':              'https://i.ibb.co/PG9pMZfP/pulav.jpg',
    'pulao':                  'https://i.ibb.co/PG9pMZfP/pulav.jpg',
    'pulav':                  'https://i.ibb.co/PG9pMZfP/pulav.jpg',

    // ═══════════════════════════════════════════════════════════════════════
    //  GUJARATI — Rotli / Breads
    // ═══════════════════════════════════════════════════════════════════════

    'bajra rotla':            'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'bajri rotla':            'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'rotlo':                  'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'bhakhri':                'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'methi thepla':           'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'thepla':                 'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'paratha':                'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'parotha':                'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'rotli':                  'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'phulka':                 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'chapati':                'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'roti':                   'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'puri':                   'https://i.ibb.co/YFrtBSS0/puri-shak.jpg',
    'poori':                  'https://i.ibb.co/YFrtBSS0/puri-shak.jpg',

    // ═══════════════════════════════════════════════════════════════════════
    //  GUJARATI — Snacks & Farsan
    // ═══════════════════════════════════════════════════════════════════════

    'khaman dhokla':          'https://i.ibb.co/fzjQWzx4/salad.jpg',
    'khaman':                 'https://i.ibb.co/fzjQWzx4/salad.jpg',
    'dhokla':                 'https://i.ibb.co/fzjQWzx4/salad.jpg',
    'fafda jalebi':           'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'fafda':                  'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'patra':                  'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'handvo':                 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'ganthiya':               'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'farsan':                 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'sev usal':               'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'usal':                   'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'locho':                  'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'sev':                    'https://i.ibb.co/jPppW02F/sev-tamata.jpg',

    // ═══════════════════════════════════════════════════════════════════════
    //  GUJARATI — Street Food
    // ═══════════════════════════════════════════════════════════════════════

    'vada pav':               'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
    'dabeli':                 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
    'pav bhaji':              'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'samosa':                 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'pakora':                 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'pakoda':                 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'bhajiya':                'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'chaat':                  'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'pav':                    'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  GUJARATI — Sweets & Desserts
    // ═══════════════════════════════════════════════════════════════════════

    'shree khand':            'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'shrikhand':              'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'basundi':                'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'lapsi':                  'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'mohanthal':              'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'sukhdi':                 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'jalebi':                 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'gulab jamun':            'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'gulab':                  'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'halwa':                  'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'kheer':                  'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'sweet':                  'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'mithai':                 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  GUJARATI — Dairy & Sides
    // ═══════════════════════════════════════════════════════════════════════

    'dahi':                   'https://i.ibb.co/Vppg6n75/dahi.jpg',
    'curd':                   'https://i.ibb.co/Vppg6n75/dahi.jpg',
    'chaas':                  'https://i.ibb.co/4RTPQqCS/butter-milk.jpg',
    'buttermilk':             'https://i.ibb.co/4RTPQqCS/butter-milk.jpg',
    'salad':                  'https://i.ibb.co/fzjQWzx4/salad.jpg',
    'papad':                  'https://i.ibb.co/7NLnSw1b/paapad.jpg',
    'pickle':                 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'milk':                   'https://i.ibb.co/4RTPQqCS/butter-milk.jpg',

    // ═══════════════════════════════════════════════════════════════════════
    //  PUNJABI / NORTH INDIAN — Paneer
    // ═══════════════════════════════════════════════════════════════════════

    'paneer butter masala':   'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'paneer tikka masala':    'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'paneer makhani':         'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'kadai paneer':           'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'karahi paneer':          'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'shahi paneer':           'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'palak paneer':           'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'saag paneer':            'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'paneer tikka':           'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'paneer do pyaza':        'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'paneer lababdar':        'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'matar paneer':           'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',
    'paneer':                 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  PUNJABI / NORTH INDIAN — Dal & Legumes
    // ═══════════════════════════════════════════════════════════════════════

    'dal makhani':            'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'daal makhani':           'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'dal bukhara':            'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'chole bhature':          'https://i.ibb.co/4RBqprCD/chanapuri.jpg',
    'chole puri':             'https://i.ibb.co/4RBqprCD/chanapuri.jpg',
    'chana puri':             'https://i.ibb.co/4RBqprCD/chanapuri.jpg',
    'chana bhatura':          'https://i.ibb.co/4RBqprCD/chanapuri.jpg',
    'chana masala':           'https://i.ibb.co/4RBqprCD/chanapuri.jpg',
    'chole masala':           'https://i.ibb.co/4RBqprCD/chanapuri.jpg',
    'chole':                  'https://i.ibb.co/4RBqprCD/chanapuri.jpg',
    'chana':                  'https://i.ibb.co/4RBqprCD/chanapuri.jpg',
    'rajma chawal':           'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'rajma rice':             'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'rajma':                  'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  PUNJABI / NORTH INDIAN — Curries & Mains
    // ═══════════════════════════════════════════════════════════════════════

    'malai kofta':            'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'veg kolhapuri':          'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'veg kadai':              'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'aloo matar':             'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'aloo gobi':              'https://i.ibb.co/qVR3Ykk/sukhi-bhaji.jpg',
    'kaju masala':            'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'kaju curry':             'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'kaju':                   'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'curry':                  'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'masala':                 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  PUNJABI / NORTH INDIAN — Breads
    // ═══════════════════════════════════════════════════════════════════════

    'garlic naan':            'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'butter naan':            'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'naan':                   'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'lachha paratha':         'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'lacha paratha':          'https://i.ibb.co/LX79cbxn/parotha.jpg',
    'tandoori roti':          'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'tandoor':                'https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80',
    'kulcha':                 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'missi roti':             'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'bhatura':                'https://i.ibb.co/4RBqprCD/chanapuri.jpg',

    // ═══════════════════════════════════════════════════════════════════════
    //  PUNJABI / NORTH INDIAN — Rice & Biryani
    // ═══════════════════════════════════════════════════════════════════════

    'veg biryani':            'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80',
    'dum biryani':            'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80',
    'biryani':                'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80',
    'rice':                   'https://i.ibb.co/DHCdDmwZ/Rice.jpg',

    // ═══════════════════════════════════════════════════════════════════════
    //  PUNJABI / NORTH INDIAN — Beverages & General
    // ═══════════════════════════════════════════════════════════════════════

    'mango lassi':            'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'sweet lassi':            'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'salted lassi':           'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'lassi':                  'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'punjabi':                'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  DOSA CENTER / SOUTH INDIAN — Dosa Varieties
    // ═══════════════════════════════════════════════════════════════════════

    'mysore masala dosa':     'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'mysore dosa':            'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'masala dosa':            'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'cheese dosa':            'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'paneer dosa':            'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'paper dosa':             'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'rava dosa':              'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'onion dosa':             'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'set dosa':               'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'plain dosa':             'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'ghee dosa':              'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'dosa':                   'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'dhosa':                  'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  DOSA CENTER / SOUTH INDIAN — Uttapam, Idli, Vada
    // ═══════════════════════════════════════════════════════════════════════

    'onion uttapam':          'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'mixed uttapam':          'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'uttapam':                'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'uttapa':                 'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'mini idli':              'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'rava idli':              'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'idli':                   'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'medu vada':              'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'medhu vadai':            'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'vada':                   'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  DOSA CENTER / SOUTH INDIAN — Accompaniments & Beverages
    // ═══════════════════════════════════════════════════════════════════════

    'sambar':                 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=400&q=80',
    'sambhar':                'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=400&q=80',
    'coconut chutney':        'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=400&q=80',
    'tomato chutney':         'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=400&q=80',
    'chutney':                'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=400&q=80',
    'south indian coffee':    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400&q=80',
    'filter coffee':          'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400&q=80',
    'south indian':           'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  ICE CREAM PARLOR — Classic Flavours
    // ═══════════════════════════════════════════════════════════════════════

    'kesar pista':            'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'black currant':          'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'blackcurrant':           'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'butterscotch':           'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'strawberry':             'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'chocolate':              'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'vanilla':                'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'rajbhog':                'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'mango':                  'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'pista':                  'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'kesar':                  'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  ICE CREAM PARLOR — Kulfi, Cone, Cup, Cassata
    // ═══════════════════════════════════════════════════════════════════════

    'matka kulfi':            'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'kulfi':                  'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'cup ice cream':          'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'cone ice cream':         'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'ice cream cone':         'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'cassata':                'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'ice cream':              'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'icecream':               'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'cone':                   'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  ICE CREAM PARLOR — Sundae, Falooda & Shakes
    // ═══════════════════════════════════════════════════════════════════════

    'brownie sundae':         'https://images.unsplash.com/photo-1564355808539-22fda35bed7e?w=400&q=80',
    'hot brownie':            'https://images.unsplash.com/photo-1564355808539-22fda35bed7e?w=400&q=80',
    'sundae':                 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'brownie':                'https://images.unsplash.com/photo-1564355808539-22fda35bed7e?w=400&q=80',
    'rose falooda':           'https://images.unsplash.com/photo-1619158401201-8fa94e9c5b45?w=400&q=80',
    'falooda':                'https://images.unsplash.com/photo-1619158401201-8fa94e9c5b45?w=400&q=80',
    'thick shake':            'https://images.unsplash.com/photo-1619158401201-8fa94e9c5b45?w=400&q=80',
    'milkshake':              'https://images.unsplash.com/photo-1619158401201-8fa94e9c5b45?w=400&q=80',
    'milk shake':             'https://images.unsplash.com/photo-1619158401201-8fa94e9c5b45?w=400&q=80',
    'shake':                  'https://images.unsplash.com/photo-1619158401201-8fa94e9c5b45?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  GOLA CENTER / ICE CRUSH
    // ═══════════════════════════════════════════════════════════════════════

    'kaccha aam gola':        'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'kala khatta gola':       'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'rabdi gola':             'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'chocolate gola':         'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'mango gola':             'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'orange gola':            'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'rose gola':              'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'baraf gola':             'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'ice gola':               'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'crushed ice':            'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'chuski':                 'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'gola':                   'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  BEVERAGES
    // ═══════════════════════════════════════════════════════════════════════

    'masala chai':            'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&q=80',
    'ginger tea':             'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&q=80',
    'chai':                   'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&q=80',
    'tea':                    'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&q=80',
    'cold coffee':            'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400&q=80',
    'coffee':                 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400&q=80',
    'fresh juice':            'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'juice':                  'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'mocktail':               'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=400&q=80',
    'water':                  'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=400&q=80',
    'soft drink':             'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'cold drink':             'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  INTERNATIONAL / FUSION
    // ═══════════════════════════════════════════════════════════════════════

    'pizza':                  'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&q=80',
    'burger':                 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
    'pasta':                  'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=400&q=80',
    'sandwich':               'https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=400&q=80',
    'wrap':                   'https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=400&q=80',
    'roll':                   'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&q=80',
    'manchurian':             'https://i.ibb.co/f6YBw0t/manchuriyan.jpg',
    'noodles':                'https://i.ibb.co/BKGvxZDK/noodles.jpg',
    'noodle':                 'https://i.ibb.co/BKGvxZDK/noodles.jpg',
    'maggi':                  'https://i.ibb.co/FL4RhV0D/maggie.jpg',
    'cake':                   'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&q=80',
    'tikka':                  'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'kebab':                  'https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80',
    'kabab':                  'https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  NON-VEGETARIAN
    // ═══════════════════════════════════════════════════════════════════════

    'chicken':                'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400&q=80',
    'mutton':                 'https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80',
    'fish':                   'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&q=80',
    'prawn':                  'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&q=80',
    'egg':                    'https://images.unsplash.com/photo-1607690022687-5c37be86c7e1?w=400&q=80',

    // ═══════════════════════════════════════════════════════════════════════
    //  GENERIC FALLBACK TRIGGERS (single-word, lowest priority)
    // ═══════════════════════════════════════════════════════════════════════

    'veg':                    'https://i.ibb.co/d04sDbST/mix-veg.jpg',
  };

  // ─────────────────────────────────────────────────────────────────────────
  //  Category fallback images
  //  Used when no keyword matches the item name.
  //  Keys are matched with exact → substring → word-level logic.
  // ─────────────────────────────────────────────────────────────────────────

  static const String _defaultFallback =
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&q=80';

  static const Map<String, String> _categoryFallbacks = {

    // ── Gujarati ────────────────────────────────────────────────────────────
    'gujarati thali':    'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiyawadi thali': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiawadi thali':  'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiyawadi':       'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'kathiawadi':        'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'gujarati':          'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',
    'farsan':            'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'farshan':           'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'thali':             'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&q=80',

    // ── Punjabi / North Indian ──────────────────────────────────────────────
    'punjabi':           'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'north indian':      'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',
    'mughlai':           'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80',

    // ── South Indian / Dosa ─────────────────────────────────────────────────
    'south indian':      'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=400&q=80',
    'dosa':              'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&q=80',
    'idli':              'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',
    'vada':              'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&q=80',

    // ── Ice Cream & Desserts ────────────────────────────────────────────────
    'ice cream':         'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'icecream':          'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'kulfi':             'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'dessert':           'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&q=80',
    'desserts':          'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&q=80',
    'sweets':            'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'sweet':             'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'mithai':            'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'falooda':           'https://images.unsplash.com/photo-1619158401201-8fa94e9c5b45?w=400&q=80',
    'sundae':            'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&q=80',
    'shakes':            'https://images.unsplash.com/photo-1619158401201-8fa94e9c5b45?w=400&q=80',
    'shake':             'https://images.unsplash.com/photo-1619158401201-8fa94e9c5b45?w=400&q=80',

    // ── Gola / Ice Crush ────────────────────────────────────────────────────
    'gola':              'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'baraf gola':        'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'chuski':            'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'ice crush':         'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',
    'crushed ice':       'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400&q=80',

    // ── Beverages ───────────────────────────────────────────────────────────
    'beverages':         'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'drinks':            'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'lassi':             'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'juice':             'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&q=80',
    'chaas':             'https://i.ibb.co/4RTPQqCS/butter-milk.jpg',
    'buttermilk':        'https://i.ibb.co/4RTPQqCS/butter-milk.jpg',

    // ── Generic categories ──────────────────────────────────────────────────
    'starters':          'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'snacks':            'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'breads':            'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'bread':             'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
    'rice':              'https://i.ibb.co/DHCdDmwZ/Rice.jpg',
    'dal':               'https://images.unsplash.com/photo-1626500154744-e4b394ffea16?w=400&q=80',
    'salad':             'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&q=80',
    'soup':              'https://i.ibb.co/5hsHrYvD/soup.jpg',
    'biryani':           'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80',
    'pizza':             'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&q=80',
    'burger':            'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
    'chinese':           'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&q=80',
    'italian':           'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=400&q=80',
    'chicken':           'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400&q=80',
    'seafood':           'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&q=80',


    // ── Gujarati / Street Food ─────────────────────────────

    'bhaji pav':              'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'bhajiya pav':            'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
    'bhaji pav masala':       'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
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

    // 1. Memory cache — fastest path, no network
    if (_memCache.containsKey(cacheKey)) return _memCache[cacheKey]!;

    // 2. Firestore cache — avoids duplicate API calls across sessions
    final firestoreUrl = await _checkFirestoreCache(cacheKey);
    if (firestoreUrl != null) {
      _memCache[cacheKey] = firestoreUrl;
      debugPrint('[ImageService] Cache hit: $itemName');
      return firestoreUrl;
    }

    // 3. Keyword match — curated food images, most reliable
    final keywordUrl = _matchKeyword(itemName);
    if (keywordUrl != null) {
      debugPrint('[ImageService] Keyword match: $itemName');
      await _saveToCache(cacheKey, keywordUrl);
      return keywordUrl;
    }

    // 4. Cloud Function (Unsplash) — only if URL is provided
    if (cloudFunctionUrl != null && cloudFunctionUrl.isNotEmpty) {
      final fetchedUrl =
      await _fetchFromCloudFunction(itemName, cloudFunctionUrl);
      if (fetchedUrl != null) {
        debugPrint('[ImageService] Cloud function hit: $itemName');
        await _saveToCache(cacheKey, fetchedUrl);
        return fetchedUrl;
      }
    }

    // 5. Category fallback — guarantees a non-empty food image URL
    final fallback = _categoryFallback(categoryName);
    debugPrint(
      '[ImageService] No keyword match for "$itemName" '
          '(category: "$categoryName") → using fallback image',
    );
    _memCache[cacheKey] = fallback;
    return fallback;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Resolve images for a full list (with concurrency limiting)
  // ─────────────────────────────────────────────────────────────────────────

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

  /// Normalise to a stable Firestore doc key.
  /// "Paneer Butter Masala!" → "paneer_butter_masala"
  String _normalizeKey(String name) =>
      name.toLowerCase().trim()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_');

  /// Substring keyword match — case-insensitive.
  /// Longer / more-specific keys are defined first in the map, so they win
  /// over shorter generic ones (e.g. 'mysore masala dosa' before 'dosa').
  String? _matchKeyword(String itemName) {
    final lower = itemName.toLowerCase().trim();
    for (final entry in _keywordImages.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Three-level category fallback:
  /// 1. Exact match on the full category string
  /// 2. Substring match ("South Indian Starters" contains "south indian")
  /// 3. Word-level match — splits "Roti & Bread" → checks "roti", "bread"
  String _categoryFallback(String categoryName) {
    if (categoryName.trim().isEmpty) return _defaultFallback;
    final lower = categoryName.toLowerCase().trim();

    if (_categoryFallbacks.containsKey(lower)) {
      return _categoryFallbacks[lower]!;
    }

    for (final entry in _categoryFallbacks.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }

    final words = lower.split(RegExp(r'[\s&,/]+'));
    for (final word in words) {
      if (word.isEmpty) continue;
      if (_categoryFallbacks.containsKey(word)) {
        return _categoryFallbacks[word]!;
      }
      for (final entry in _categoryFallbacks.entries) {
        if (entry.key.contains(word)) return entry.value;
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
    } catch (e) {
      debugPrint('[ImageService] Cache read skipped (non-fatal): $e');
    }
    return null;
  }

  Future<void> _saveToCache(String key, String url) async {
    _memCache[key] = url;
    try {
      await _cacheRef.doc(key).set({
        'url': url,
        'cachedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ImageService] Cache write skipped (non-fatal): $e');
    }
  }

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

  String _buildSearchQuery(String itemName) {
    final cleaned = itemName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .trim();
    return '$cleaned food';
  }
}