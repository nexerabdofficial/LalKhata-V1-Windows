class SaleItemDraft {
  final int productId;
  final String productName;
  final int qty;
  final double sellingPrice;
  final double subtotal;

  SaleItemDraft({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.sellingPrice,
    required this.subtotal,
  });
}