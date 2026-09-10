class LoanPayment {
  final int? id;

  final int loanId;

  /// Total payment amount
  /// = principal + interest
  final double amount;

  /// Principal portion of this payment
  final double principalAmount;

  /// Interest portion of this payment
  final double interestAmount;

  /// Cash / Bank / Mobile Banking
  final int? accountId;
  final String? paymentMethod;

  final String paymentDate;

  final String? voucherNo;

  final String? note;

  final String createdAt;

  const LoanPayment({
    this.id,
    required this.loanId,
    required this.amount,
    required this.principalAmount,
    required this.interestAmount,
    this.accountId,
    this.paymentMethod,
    required this.paymentDate,
    this.voucherNo,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loan_id': loanId,
      'amount': amount,
      'principal_amount': principalAmount,
      'interest_amount': interestAmount,
      'account_id': accountId,
      'payment_method': paymentMethod,
      'payment_date': paymentDate,
      'voucher_no': voucherNo,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory LoanPayment.fromMap(
    Map<String, dynamic> map,
  ) {
    return LoanPayment(
      id: map['id'] as int?,
      loanId: (map['loan_id'] as num).toInt(),
      amount:
          (map['amount'] as num?)?.toDouble() ?? 0.0,
      principalAmount:
          (map['principal_amount'] as num?)
                  ?.toDouble() ??
              0.0,
      interestAmount:
          (map['interest_amount'] as num?)
                  ?.toDouble() ??
              0.0,
      accountId:
          (map['account_id'] as num?)?.toInt(),
      paymentMethod:
          map['payment_method'] as String?,
      paymentDate:
          map['payment_date'] as String,
      voucherNo:
          map['voucher_no'] as String?,
      note:
          map['note'] as String?,
      createdAt:
          map['created_at'] as String,
    );
  }
}