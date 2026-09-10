class Sale {
  final int? id;
  final int customerId;
  final String? invoiceNo;
  final String saleDate;
  final double grandTotal;
  final double additionalCharge;
  final double invoiceDiscount;
  final double paid;
  final double due;
  final String note;
  final String paymentMethod;
  final String createdAt;

  Sale({
    this.id,
    required this.customerId,
    this.invoiceNo,
    required this.saleDate,
    required this.grandTotal,
    required this.additionalCharge,
    required this.invoiceDiscount,
    required this.paid,
    required this.due,
    required this.note,
    required this.paymentMethod,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'invoice_no': invoiceNo,
      'sale_date': saleDate,
      'grand_total': grandTotal,
      'additional_charge': additionalCharge,
      'invoice_discount': invoiceDiscount,
      'paid': paid,
      'due': due,
      'note': note,
      'payment_method': paymentMethod,
      'created_at': createdAt,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      customerId: map['customer_id'],
      invoiceNo: map['invoice_no'],
      saleDate: map['sale_date'],
      grandTotal:
          (map['grand_total'] as num).toDouble(),
      additionalCharge:
          ((map['additional_charge'] ?? 0) as num)
              .toDouble(),
      invoiceDiscount:
          ((map['invoice_discount'] ?? 0) as num)
              .toDouble(),
      paid:
          (map['paid'] as num).toDouble(),
      due:
          (map['due'] as num).toDouble(),
      note:
          map['note'] ?? '',
      paymentMethod:
          map['payment_method'] ?? 'Cash',
      createdAt:
          map['created_at'],
    );
  }
}