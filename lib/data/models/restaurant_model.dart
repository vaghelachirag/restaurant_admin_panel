class RestaurantModel {

  final String id;
  final String name;
  final String address;
  final String phone;
  final String? logoUrl;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.logoUrl,
  });

  factory RestaurantModel.fromMap(Map<String, dynamic> map, String id) {
    return RestaurantModel(
      id: id,
      name: map['name'],
      address: map['address'],
      phone: map['phone'],
      logoUrl: map['logoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "address": address,
      "phone": phone,
      "logoUrl": logoUrl,
    };
  }
}