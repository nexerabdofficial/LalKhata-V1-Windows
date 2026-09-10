class SaleItem {
  final int? id;
  final int saleId;
  final int productId;

  // NEW
  final String productName;

  final int qty;
  final double sellingPrice;
  final double subtotal;
  final double purchasePrice;

  SaleItem({
  this.id,
  required this.saleId,
  required this.productId,
  required this.productName,
  required this.qty,
  required this.purchasePrice,
  required this.sellingPrice,
  required this.subtotal,
});
  Map<String, dynamic> toMap() {
  return {
    'id': id,
    'sale_id': saleId,
    'product_id': productId,
    'product_name': productName,
    'qty': qty,
    'purchase_price': purchasePrice,
    'selling_price': sellingPrice,
    'subtotal': subtotal,
  };
}

  factory SaleItem.fromMap(
    Map<String, dynamic> map,
  ) {
    return SaleItem(
      id: map['id'],
      saleId: map['sale_id'],
      productId: map['product_id'],

      productName:
          map['product_name'] ?? "",
      purchasePrice:
          ((map['purchase_price'] ?? 0) as num).toDouble(),

      qty: map['qty'],

      sellingPrice:
          (map['selling_price'] as num)
              .toDouble(),

      subtotal:
          (map['subtotal'] as num)
              .toDouble(),
    );
  }
}