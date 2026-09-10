class CustomerLedger {
  final String date;

  /// Sale / Payment / Return
  final String particular;

  /// Invoice No / Payment No
  final String reference;

  /// Money Added To Due
  final double debit;

  /// Money Received
  final double credit;

  CustomerLedger({
    required this.date,
    required this.particular,
    required this.reference,
    required this.debit,
    required this.credit,
  });

  factory CustomerLedger.fromMap(
    Map<String, dynamic> map,
  ) {
    return CustomerLedger(
      date: (map['date'] ?? '').toString(),
      particular:
          (map['particular'] ?? '').toString(),
      reference:
          (map['reference'] ?? '').toString(),
      debit: map['debit'] == null
          ? 0
          : (map['debit'] as num).toDouble(),
      credit: map['credit'] == null
          ? 0
          : (map['credit'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'particular': particular,
      'reference': reference,
      'debit': debit,
      'credit': credit,
    };
  }
}