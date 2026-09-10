class ProductLedger {
  final String date;
  final String reference;
  final String particular;

  final int stockIn;
  final int stockOut;
  final int balance;

  final double purchasePrice;
  final double sellingPrice;

  ProductLedger({
    required this.date,
    required this.reference,
    required this.particular,
    required this.stockIn,
    required this.stockOut,
    required this.balance,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
  });
}