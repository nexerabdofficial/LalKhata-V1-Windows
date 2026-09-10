class Account {
  final int? id;
  final String name;
  final String type;

  final double balance;

  final double openingBalance;
  final String openingDate;

  final String createdAt;

  const Account({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.openingBalance,
    required this.openingDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'opening_balance': openingBalance,
      'opening_date': openingDate,
      'created_at': createdAt,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      balance: (map['balance'] as num).toDouble(),
      openingBalance:
          (map['opening_balance'] as num).toDouble(),
      openingDate: map['opening_date'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}