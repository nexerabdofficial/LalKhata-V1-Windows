class Purchase {
  final int? id;
  final int supplierId;
  final String? invoiceNo;
  final String purchaseDate;
  final double grandTotal;
  final double paid;
  final double due;
  final String? note;
  final String createdAt;
  final int? accountId;
  final String paymentMethod;

  Purchase({
    this.id,
    required this.supplierId,
    this.invoiceNo,
    required this.purchaseDate,
    required this.grandTotal,
    required this.paid,
    required this.due,
    this.note,
    required this.createdAt,

    this.accountId,
    required this.paymentMethod,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'invoice_no': invoiceNo,
      'purchase_date': purchaseDate,
      'grand_total': grandTotal,
      'paid': paid,
      'due': due,
      'note': note,
      'created_at': createdAt,
      'account_id': accountId,
      'payment_method': paymentMethod,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'],
      supplierId: map['supplier_id'],
      invoiceNo: map['invoice_no'],
      purchaseDate: map['purchase_date'],
      grandTotal: (map['grand_total'] as num).toDouble(),
      paid: (map['paid'] as num).toDouble(),
      due: (map['due'] as num).toDouble(),
      note: map['note'],
      createdAt: map['created_at'],
      accountId: map['account_id'],

    paymentMethod:
        map['payment_method'] ?? 'Cash',
        );
  }
}