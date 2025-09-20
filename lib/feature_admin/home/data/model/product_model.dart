class Product {
  int? id;
  String name;
  num price;
  String barcode;
  DateTime? expire;
  int quantity; // كمية المنتج

  Product({
    this.id,
    required this.name,
    required this.price,
    required this.barcode,
    this.expire,
    this.quantity = 0, // قيمة افتراضية
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'barcode': barcode,
      'expire': expire?.toIso8601String(),
      'quantity': quantity,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    final priceValue = map['price'];
    num price;

    if (priceValue is int) {
      price = priceValue;
    } else if (priceValue is double) {
      price = priceValue;
    } else if (priceValue is String) {
      price = priceValue.contains('.')
          ? double.parse(priceValue)
          : int.parse(priceValue);
    } else {
      price = 0;
    }
    return Product(
      id: map['id'],
      name: map['name'],
      price: price,
      barcode: map['barcode'],
      expire: map['expire'] != null ? DateTime.parse(map['expire']) : null,
      quantity: map['quantity'] ?? 0,
    );
  }
}
