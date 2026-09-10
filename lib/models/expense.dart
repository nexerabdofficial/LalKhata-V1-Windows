class Expense {
  final int? id;
  final String category;
  final double amount;
  final int? accountId;
  final String expenseDate;
  final String? note;
  final String createdAt;
  final String? voucherNo;
  Expense({
    this.id,
    required this.category,
    required this.amount,
    this.accountId,
    required this.expenseDate,
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
      'expense_date': expenseDate,
      'note': note,
      'created_at': createdAt,
      'voucher_no': voucherNo,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      accountId: map['account_id'] as int?,
      expenseDate: map['expense_date'] as String,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
      voucherNo: map['voucher_no'] as String?,
    );
  }
}