import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final int position;
  final String restaurantId;
  final DateTime? createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.position,
    required this.restaurantId,
    this.createdAt,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      position: (data['position'] as num?)?.toInt() ?? 0,
      restaurantId: (data['restaurantId'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
    'name': name,
    'image': '',
    'position': position,
    'restaurantId': restaurantId,
    'createdAt': FieldValue.serverTimestamp(),
  };

  @override
  String toString() => 'CategoryModel(id: $id, name: $name)';
}