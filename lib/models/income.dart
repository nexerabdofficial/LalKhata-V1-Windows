class Income {
  final int? id;
  final String category;
  final double amount;

  final int? accountId;

  final String incomeDate;
  final String? note;
  final String createdAt;
  final String? voucherNo;

  Income({
    this.id,
    required this.category,
    required this.amount,

    this.accountId,

    required this.incomeDate,
    this.note,
    required this.createdAt,
    this.voucherNo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,

      'account_id': accountId,

      'income_date': incomeDate,
      'note': note,
      'created_at': createdAt,
      'voucher_no': voucherNo,
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'],
      category: map['category'],
      amount: (map['amount'] as num).toDouble(),

      accountId: map['account_id'],

      incomeDate: map['income_date'],
      note: map['note'],
      createdAt: map['created_at'],
      voucherNo: map['voucher_no'] as String?,
    );
  }
}
