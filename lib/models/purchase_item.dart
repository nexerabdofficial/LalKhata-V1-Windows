class PurchaseItem {
  final int? id;
  final int purchaseId;
  final int productId;
  final int qty;
  final double purchasePrice;
  final double subtotal;

  PurchaseItem({
    this.id,
    this.purchaseId = 0,
    required this.productId,
    required this.qty,
    required this.purchasePrice,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'product_id': productId,
      'qty': qty,
      'purchase_price': purchasePrice,
      'subtotal': subtotal,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'],
      purchaseId: map['purchase_id'],
      productId: map['product_id'],
      qty: map['qty'],
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }
}