class PurchaseFormState {
  int? supplierId;
  int? productId;

  DateTime purchaseDate;

  PurchaseFormState({
    this.supplierId,
    this.productId,
    DateTime? purchaseDate,
  }) : purchaseDate = purchaseDate ?? DateTime.now();
}