class FFJournalLine {
  final int accountId;
  final String? entityType;
  final int? entityId;
  final double debit;
  final double credit;
  final String? note;

  const FFJournalLine({
    required this.accountId,
    this.entityType,
    this.entityId,
    this.debit = 0,
    this.credit = 0,
    this.note,
  });

  Map<String, dynamic> toMap(int journalId) {
    return {
      'journal_id': journalId,
      'account_id': accountId,
      'entity_type': entityType,
      'entity_id': entityId,
      'debit': debit,
      'credit': credit,
      'note': note,
    };
  }
}

class FFJournalEntry {
  final String transactionType;
  final String voucherNo;
  final String transactionDate;
  final String? referenceType;
  final int? referenceId;
  final String? description;
  final String createdAt;
  final List<FFJournalLine> lines;

  const FFJournalEntry({
    required this.transactionType,
    required this.voucherNo,
    required this.transactionDate,
    this.referenceType,
    this.referenceId,
    this.description,
    required this.createdAt,
    required this.lines,
  });

  double get totalDebit => lines.fold(0.0, (sum, line) => sum + line.debit);

  double get totalCredit => lines.fold(0.0, (sum, line) => sum + line.credit);

  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.000001;
}
