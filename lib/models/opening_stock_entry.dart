class OpeningStockEntry {
  final int? id;
  final int productId;
  final int quantity;
  final double unitCost;
  final double totalValue;
  final String openingDate;
  final String createdAt;

  const OpeningStockEntry({
    this.id,
    required this.productId,
    required this.quantity,
    required this.unitCost,
    required this.totalValue,
    required this.openingDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'total_value': totalValue,
      'opening_date': openingDate,
      'created_at': createdAt,
    };
  }

  factory OpeningStockEntry.fromMap(Map<String, dynamic> map) {
    return OpeningStockEntry(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      quantity: map['quantity'] as int,
      unitCost: (map['unit_cost'] as num).toDouble(),
      totalValue: (map['total_value'] as num).toDouble(),
      openingDate: map['opening_date'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
