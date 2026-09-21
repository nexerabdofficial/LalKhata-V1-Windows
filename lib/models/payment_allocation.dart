class PaymentAllocation {
  final int? id;
  final String referenceType;
  final int referenceId;
  final int accountId;
  final double amount;
  final String paymentMethod;
  final String createdAt;

  const PaymentAllocation({
    this.id,
    required this.referenceType,
    required this.referenceId,
    required this.accountId,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'account_id': accountId,
      'amount': amount,
      'payment_method': paymentMethod,
      'created_at': createdAt,
    };
  }

  factory PaymentAllocation.fromMap(Map<String, dynamic> map) {
    return PaymentAllocation(
      id: (map['id'] as num?)?.toInt(),
      referenceType: map['reference_type']?.toString() ?? '',
      referenceId: (map['reference_id'] as num).toInt(),
      accountId: (map['account_id'] as num).toInt(),
      amount: ((map['amount'] ?? 0) as num).toDouble(),
      paymentMethod: map['payment_method']?.toString() ?? '',
      createdAt: map['created_at']?.toString() ?? '',
    );
  }
}
