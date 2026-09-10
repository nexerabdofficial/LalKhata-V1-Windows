class AccountTransaction {
  final int? id;

  final int accountId;

  final String transactionType;

  final String? referenceType;

  final int? referenceId;

  final String? voucherNo;

  final double debit;

  final double credit;

  final String transactionDate;

  final String? note;

  final String createdAt;

  const AccountTransaction({
    this.id,
    required this.accountId,
    required this.transactionType,
    this.referenceType,
    this.referenceId,
    this.voucherNo,
    required this.debit,
    required this.credit,
    required this.transactionDate,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'transaction_type': transactionType,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'voucher_no': voucherNo,
      'debit': debit,
      'credit': credit,
      'transaction_date': transactionDate,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory AccountTransaction.fromMap(
    Map<String, dynamic> map,
  ) {
    return AccountTransaction(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      transactionType:
          map['transaction_type'] as String,
      referenceType:
          map['reference_type'] as String?,
      referenceId:
          map['reference_id'] as int?,
      voucherNo:
          map['voucher_no'] as String?,
      debit:
          (map['debit'] as num?)?.toDouble() ?? 0,
      credit:
          (map['credit'] as num?)?.toDouble() ?? 0,
      transactionDate:
          map['transaction_date'] as String,
      note:
          map['note'] as String?,
      createdAt:
          map['created_at'] as String,
    );
  }
}