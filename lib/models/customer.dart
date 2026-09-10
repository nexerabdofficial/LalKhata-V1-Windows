class Customer {
  final int? id;

  // Local ↔ Supabase identity
  final String? supabaseId;
  final String? customerCode;

  final String name;

  final String? phone;

  final String? address;

  final double openingBalance;

  final double balance;

  final DateTime? openingDate;

  double get balanceForward => balance;

  Customer({
    this.id,
    this.supabaseId,
    this.customerCode,
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
      'supabase_id': supabaseId,
      'customer_code': customerCode,
      'name': name,
      'phone': phone,
      'address': address,
      'opening_balance': openingBalance,
      'balance': balance,
      'opening_date': openingDate?.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      supabaseId: map['supabase_id'],
      customerCode: map['customer_code'],
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      openingBalance:
          ((map['opening_balance'] ?? 0) as num).toDouble(),
      balance:
          ((map['balance'] ?? 0) as num).toDouble(),
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