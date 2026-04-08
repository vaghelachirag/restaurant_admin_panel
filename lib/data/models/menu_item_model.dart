import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────
//  Variant Model
// ─────────────────────────────────────────────
class MenuVariant {
  final String name;
  final double price;

  const MenuVariant({required this.name, required this.price});

  factory MenuVariant.fromMap(Map<String, dynamic> map) => MenuVariant(
    name: (map['name'] ?? 'Regular').toString(),
    price: (map['price'] is num)
        ? (map['price'] as num).toDouble()
        : double.tryParse(map['price'].toString()) ?? 0.0,
  );

  // price stored as int to match existing app schema
  Map<String, dynamic> toMap() => {'name': name, 'price': price.toInt()};

  MenuVariant copyWith({String? name, double? price}) =>
      MenuVariant(name: name ?? this.name, price: price ?? this.price);

  @override
  String toString() => 'MenuVariant(name: $name, price: $price)';
}

// ─────────────────────────────────────────────
//  MenuItem Model
// ─────────────────────────────────────────────
class MenuItem {
  final String? id; // null until saved to Firestore
  final String name;
  final String categoryId;
  final String categoryName;
  final String restaurantId;
  final String image;
  final bool isAvailable;
  final bool isVeg;
  final String description;
  final List<MenuVariant> variants;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // CSV-specific: validation state
  final bool hasError;
  final String? errorMessage;

  const MenuItem({
    this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.restaurantId,
    this.image = '',
    this.isAvailable = true,
    this.isVeg = true,
    this.description = '',
    required this.variants,
    this.createdAt,
    this.updatedAt,
    this.hasError = false,
    this.errorMessage,
  });

  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawVariants = data['variants'] as List<dynamic>? ?? [];
    return MenuItem(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      categoryId: (data['categoryId'] ?? '').toString(),
      categoryName: (data['categoryName'] ?? '').toString(),
      restaurantId: (data['restaurantId'] ?? '').toString(),
      image: (data['image'] ?? '').toString(),
      isAvailable: data['isAvailable'] as bool? ?? true,
      isVeg: data['isVeg'] as bool? ?? true,
      description: (data['description'] ?? '').toString(),
      variants: rawVariants
          .map((v) => MenuVariant.fromMap(Map<String, dynamic>.from(v as Map)))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
    'name': name,
    'categoryId': categoryId,
    'restaurantId': restaurantId,
    'image': image,                          // '' from CSV (no image upload)
    'isAvailable': isAvailable,
    'isVeg': isVeg,
    'description': description,
    'variants': variants.map((v) => v.toMap()).toList(), // price is int
    'createdAt': FieldValue.serverTimestamp(),
  };

  MenuItem copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? categoryName,
    String? restaurantId,
    String? image,
    bool? isAvailable,
    bool? isVeg,
    String? description,
    List<MenuVariant>? variants,
    bool? hasError,
    String? errorMessage,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      restaurantId: restaurantId ?? this.restaurantId,
      image: image ?? this.image,
      isAvailable: isAvailable ?? this.isAvailable,
      isVeg: isVeg ?? this.isVeg,
      description: description ?? this.description,
      variants: variants ?? this.variants,
      createdAt: createdAt,
      updatedAt: updatedAt,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  double get lowestPrice =>
      variants.isEmpty ? 0 : variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);

  @override
  String toString() => 'MenuItem(name: $name, category: $categoryName, variants: ${variants.length})';
}