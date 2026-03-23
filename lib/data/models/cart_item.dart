class CartItem {
  String itemId;
  String name;
  String variant;
  int price;
  int qty;
  String? image;

  CartItem({
    required this.itemId,
    required this.name,
    required this.variant,
    required this.price,
    this.qty = 1,
    this.image,
  });
}