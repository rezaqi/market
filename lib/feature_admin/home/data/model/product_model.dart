class Product {
  int? id;
  String name;
  num price;
  String barcode;
  DateTime? expire;
  final num originalPrice;
  int quantity; // كمية المنتج
  final num totalOriginalPrice; // ✅ جديد
  final num allProductsOriginalTotal; // ✅ جديد

  Product({
    this.id,
    required this.name,
    required this.price,
    required this.barcode,
    required this.originalPrice,
    this.expire,
    this.quantity = 0, // قيمة افتراضية
    required this.totalOriginalPrice,
    required this.allProductsOriginalTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'barcode': barcode,
      'originalPrice': originalPrice,
      'expire': expire?.toIso8601String(),
      'quantity': quantity,
      'totalOriginalPrice': totalOriginalPrice,
      'allProductsOriginalTotal': allProductsOriginalTotal,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    num parseNum(dynamic val) {
      if (val == null) return 0;
      if (val is int || val is double) return val;
      if (val is String) {
        return num.tryParse(val) ?? 0;
      }
      return 0;
    }

    return Product(
      id: map['id'] as int?,
      name: map['name']?.toString() ?? "",
      price: parseNum(map['price']),
      barcode: map['barcode']?.toString() ?? "",
      originalPrice: parseNum(map['originalPrice']),
      expire: map['expire'] != null
          ? DateTime.tryParse(map['expire'].toString())
          : null,
      quantity: parseNum(map['quantity']).toInt(),
      totalOriginalPrice: map['totalOriginalPrice'] ?? 0.0,
      allProductsOriginalTotal: map['allProductsOriginalTotal'] ?? 0.0,
    );
  }

  Product copyWith({
    int? id,
    String? name,
    double? price,
    double? originalPrice,
    int? quantity,
    String? barcode,
    DateTime? expire,
    double? totalOriginalPrice,
    double? allProductsOriginalTotal,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      quantity: quantity ?? this.quantity,
      barcode: barcode ?? this.barcode,
      expire: expire ?? this.expire,
      totalOriginalPrice: totalOriginalPrice ?? this.totalOriginalPrice,
      allProductsOriginalTotal:
          allProductsOriginalTotal ?? this.allProductsOriginalTotal,
    );
  }
}
