class Product {
  final int? id;

  final String name;

  final double purchasePrice;

  final double sellingPrice;

  final String unit;

  final int stock;

  // Current total value of the stock.
  //
  // Example:
  // 10 pcs × ৳10 = ৳100
  // 5 pcs × ৳12  = ৳60
  // Total stock value = ৳160
  final double stockValue;

  const Product({
    this.id,
    required this.name,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    this.stockValue = 0,
    this.unit = 'PCS',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'stock': stock,
      'stock_value': stockValue,
      'unit': unit,
    };
  }

  factory Product.fromMap(
    Map<String, dynamic> map,
  ) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      purchasePrice:
          ((map['purchase_price'] ?? 0) as num).toDouble(),
      sellingPrice:
          ((map['selling_price'] ?? 0) as num).toDouble(),
      stock:
          ((map['stock'] ?? 0) as num).toInt(),
      stockValue:
          ((map['stock_value'] ?? 0) as num).toDouble(),
      unit: map['unit'] ?? 'PCS',
    );
  }

  Product copyWith({
    int? id,
    String? name,
    double? purchasePrice,
    double? sellingPrice,
    int? stock,
    double? stockValue,
    String? unit,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      purchasePrice:
          purchasePrice ?? this.purchasePrice,
      sellingPrice:
          sellingPrice ?? this.sellingPrice,
      stock: stock ?? this.stock,
      stockValue:
          stockValue ?? this.stockValue,
      unit: unit ?? this.unit,
    );
  }
}