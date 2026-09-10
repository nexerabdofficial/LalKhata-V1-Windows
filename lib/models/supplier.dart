class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final double openingBalance;
  final double balance;
  final DateTime? openingDate;

  Supplier({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.openingBalance = 0,
    this.balance = 0,
    this.openingDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'opening_balance': openingBalance,
      'opening_date': openingDate?.toIso8601String(),
      'balance': balance,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
  return Supplier(
    id: map['id'],
    name: map['name'],
    phone: map['phone'],
    address: map['address'],
    openingBalance:
        (map['opening_balance'] as num?)?.toDouble() ?? 0,
    balance:
        (map['balance'] as num?)?.toDouble() ?? 0,
    openingDate:
        map['opening_date'] != null &&
                map['opening_date'].toString().isNotEmpty
            ? DateTime.tryParse(
                map['opening_date'].toString(),
              )
            : null,
  );
}
}