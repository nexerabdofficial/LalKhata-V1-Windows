class PurchaseItemDraft {
  final int productId;
  final String productName;

  final int qty;
  final double purchasePrice;
  final double subtotal;

  const PurchaseItemDraft({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.purchasePrice,
    required this.subtotal,
  });
}