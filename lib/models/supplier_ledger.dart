class SupplierLedger {
  final String date;
  final String particular;
  final String reference;
  final double debit;
  final double credit;

  SupplierLedger({
    required this.date,
    required this.particular,
    required this.reference,
    required this.debit,
    required this.credit,
  });

  factory SupplierLedger.fromMap(
    Map<String, dynamic> map,
  ) {
    return SupplierLedger(
      date: map['date'] ?? '',
      particular: map['particular'] ?? '',
      reference: map['reference'] ?? '',
      debit: (map['debit'] as num).toDouble(),
      credit: (map['credit'] as num).toDouble(),
    );
  }
}