import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import 'ff_journal_service.dart';

class FFUniversalLedgerSummary {
  final double openingBalance;
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;
  final String normalBalance;

  const FFUniversalLedgerSummary({
    required this.openingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
    required this.normalBalance,
  });
}

class FFUniversalLedgerService {
  FFUniversalLedgerService._();

  static final FFUniversalLedgerService instance = FFUniversalLedgerService._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final FFJournalService _journalService = FFJournalService.instance;

  // ============================================================
  // UNIVERSAL LEDGER
  //
  // FF Journal follows normal double-entry accounting:
  //
  // Debit-normal account:
  //   Balance = Opening + Debit - Credit
  //
  // Credit-normal account:
  //   Balance = Opening + Credit - Debit
  //
  // The account nature is intentionally NOT hard-coded for
  // the complete FF hierarchy yet because CA review is pending.
  //
  // Legacy CASH/BANK/MOBILE_BANKING/CARD accounts are treated
  // as debit-normal for FF journal purposes.
  // ============================================================

  Future<List<Map<String, dynamic>>> getLedger({
    required int accountId,
    String? fromDate,
    String? toDate,
    String? entityType,
    int? entityId,
    String? normalBalance,
  }) async {
    final rows = await _journalService.getLedgerLines(
      accountId: accountId,
      fromDate: null,
      toDate: toDate,
    );

    final direction = await _resolveNormalBalance(
      accountId: accountId,
      requested: normalBalance,
    );

    final accountOpening = await _getOpeningBalanceForContext(
      accountId: accountId,
      entityType: entityType,
      entityId: entityId,
    );

    final beforePeriod = <Map<String, dynamic>>[];
    final periodRows = <Map<String, dynamic>>[];

    for (final row in rows) {
      if (!_matchesEntity(row, entityType, entityId)) {
        continue;
      }

      final date = row['transaction_date']?.toString() ?? '';

      if (fromDate != null && date.compareTo(fromDate) < 0) {
        beforePeriod.add(row);
      } else {
        periodRows.add(row);
      }
    }

    double balance = accountOpening + _signedMovement(beforePeriod, direction);

    final result = <Map<String, dynamic>>[];

    final Database db = await _databaseHelper.database;

    for (final row in periodRows) {
      final debit = _toDouble(row['debit']);
      final credit = _toDouble(row['credit']);

      balance += _signedAmount(
        debit: debit,
        credit: credit,
        normalBalance: direction,
      );

      final journalId = _toInt(row['journal_id']);

      String counterparty = '';

      if (journalId != null) {
        counterparty = await _getCounterpartyNames(
          db: db,
          journalId: journalId,
          accountId: accountId,
          currentLineDebit: debit,
          currentLineCredit: credit,
        );
      }

      result.add({
        ...row,
        'running_balance': balance,
        'counterparty': counterparty,
      });
    }

    return result;
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Future<FFUniversalLedgerSummary> getSummary({
    required int accountId,
    String? fromDate,
    String? toDate,
    String? entityType,
    int? entityId,
    String? normalBalance,
  }) async {
    final rows = await _journalService.getLedgerLines(
      accountId: accountId,
      fromDate: null,
      toDate: toDate,
    );

    final direction = await _resolveNormalBalance(
      accountId: accountId,
      requested: normalBalance,
    );

    final accountOpening = await _getOpeningBalanceForContext(
      accountId: accountId,
      entityType: entityType,
      entityId: entityId,
    );

    double periodDebit = 0;
    double periodCredit = 0;
    double openingMovement = 0;

    for (final row in rows) {
      if (!_matchesEntity(row, entityType, entityId)) {
        continue;
      }

      final date = row['transaction_date']?.toString() ?? '';

      final debit = _toDouble(row['debit']);
      final credit = _toDouble(row['credit']);

      if (fromDate != null && date.compareTo(fromDate) < 0) {
        openingMovement += _signedAmount(
          debit: debit,
          credit: credit,
          normalBalance: direction,
        );
        continue;
      }

      periodDebit += debit;
      periodCredit += credit;
    }

    final openingBalance = accountOpening + openingMovement;

    final closingBalance =
        openingBalance +
        _signedAmount(
          debit: periodDebit,
          credit: periodCredit,
          normalBalance: direction,
        );

    return FFUniversalLedgerSummary(
      openingBalance: openingBalance,
      totalDebit: periodDebit,
      totalCredit: periodCredit,
      closingBalance: closingBalance,
      normalBalance: direction,
    );
  }

  // ============================================================
  // CLOSING BALANCE
  // ============================================================

  Future<double> getClosingBalance({
    required int accountId,
    String? toDate,
    String? entityType,
    int? entityId,
    String? normalBalance,
  }) async {
    final summary = await getSummary(
      accountId: accountId,
      toDate: toDate,
      entityType: entityType,
      entityId: entityId,
      normalBalance: normalBalance,
    );

    return summary.closingBalance;
  }

  // ============================================================
  // OPENING BALANCE FOR DATE RANGE
  // ============================================================

  Future<double> getOpeningBalance({
    required int accountId,
    required String fromDate,
    String? entityType,
    int? entityId,
    String? normalBalance,
  }) async {
    final summary = await getSummary(
      accountId: accountId,
      fromDate: fromDate,
      toDate: fromDate,
      entityType: entityType,
      entityId: entityId,
      normalBalance: normalBalance,
    );

    return summary.openingBalance;
  }

  // ============================================================
  // ACCOUNT OPENING BALANCE
  // ============================================================

  Future<double> _getOpeningBalanceForContext({
    required int accountId,
    String? entityType,
    int? entityId,
  }) async {
    final Database db = await _databaseHelper.database;

    final accountRows = await db.query(
      'accounts',
      columns: ['type'],
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );

    if (accountRows.isEmpty) {
      throw StateError('Account not found: $accountId');
    }

    final accountType =
        accountRows.first['type']?.toString().trim().toUpperCase() ?? '';

    // ========================================================
    // CUSTOMER RECEIVABLE
    // ========================================================

    if (accountType == 'CUSTOMER_RECEIVABLE') {
      if (entityType != null && entityType.trim().toUpperCase() != 'CUSTOMER') {
        return 0;
      }

      if (entityId != null) {
        final rows = await db.query(
          'customers',
          columns: ['opening_balance'],
          where: 'id = ?',
          whereArgs: [entityId],
          limit: 1,
        );

        if (rows.isEmpty) {
          return 0;
        }

        return _toDouble(rows.first['opening_balance']);
      }

      final rows = await db.rawQuery('''
        SELECT COALESCE(SUM(opening_balance), 0) AS total
        FROM customers
        ''');

      return _toDouble(rows.first['total']);
    }

    // ========================================================
    // SUPPLIER PAYABLE
    // ========================================================

    if (accountType == 'SUPPLIER_PAYABLE') {
      if (entityType != null && entityType.trim().toUpperCase() != 'SUPPLIER') {
        return 0;
      }

      if (entityId != null) {
        final rows = await db.query(
          'suppliers',
          columns: ['opening_balance'],
          where: 'id = ?',
          whereArgs: [entityId],
          limit: 1,
        );

        if (rows.isEmpty) {
          return 0;
        }

        return _toDouble(rows.first['opening_balance']);
      }

      final rows = await db.rawQuery('''
        SELECT COALESCE(SUM(opening_balance), 0) AS total
        FROM suppliers
        ''');

      return _toDouble(rows.first['total']);
    }

    // ========================================================
    // NORMAL ACCOUNT
    // ========================================================

    return _getAccountOpeningBalance(accountId);
  }

  Future<double> _getAccountOpeningBalance(int accountId) async {
    final Database db = await _databaseHelper.database;

    final rows = await db.query(
      'accounts',
      columns: ['opening_balance'],
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Account not found: $accountId');
    }

    return _toDouble(rows.first['opening_balance']);
  }

  // ============================================================
  // NORMAL BALANCE RESOLUTION
  // ============================================================

  Future<String> _resolveNormalBalance({
    required int accountId,
    String? requested,
  }) async {
    if (requested != null) {
      final value = requested.trim().toUpperCase();

      if (value == 'DEBIT' || value == 'CREDIT') {
        return value;
      }

      throw ArgumentError('normalBalance must be DEBIT or CREDIT.');
    }

    final Database db = await _databaseHelper.database;

    // First preference:
    // FF hierarchy primary group's account_nature.
    final hierarchyRows = await db.rawQuery(
      '''
      SELECT g.account_nature
      FROM ff_account_links l
      INNER JOIN ff_account_groups g
        ON g.id = l.group_id
      WHERE l.account_id = ?
        AND l.is_primary = 1
        AND g.account_nature IS NOT NULL
        AND TRIM(g.account_nature) != ''
      LIMIT 1
      ''',
      [accountId],
    );

    if (hierarchyRows.isNotEmpty) {
      final nature = hierarchyRows.first['account_nature']
          ?.toString()
          .trim()
          .toUpperCase();

      if (nature == 'DEBIT' || nature == 'CREDIT') {
        return nature!;
      }
    }

    // Legacy account types currently represent money accounts.
    // In FF double-entry they are debit-normal assets.
    final accountRows = await db.query(
      'accounts',
      columns: ['type'],
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );

    if (accountRows.isEmpty) {
      throw StateError('Account not found: $accountId');
    }

    final type =
        accountRows.first['type']?.toString().trim().toUpperCase() ?? '';

    const legacyDebitNormalTypes = {'CASH', 'BANK', 'MOBILE_BANKING', 'CARD'};

    if (legacyDebitNormalTypes.contains(type)) {
      return 'DEBIT';
    }

    // Do not silently guess the nature of a future FF account.
    throw StateError(
      'Account nature is not defined for account $accountId. '
      'Assign an FF account group with account_nature '
      'or explicitly provide normalBalance.',
    );
  }

  // ============================================================
  // MOVEMENT CALCULATION
  // ============================================================

  double _signedMovement(
    List<Map<String, dynamic>> rows,
    String normalBalance,
  ) {
    double total = 0;

    for (final row in rows) {
      total += _signedAmount(
        debit: _toDouble(row['debit']),
        credit: _toDouble(row['credit']),
        normalBalance: normalBalance,
      );
    }

    return total;
  }

  double _signedAmount({
    required double debit,
    required double credit,
    required String normalBalance,
  }) {
    if (normalBalance == 'DEBIT') {
      return debit - credit;
    }

    return credit - debit;
  }

  // ============================================================
  // COUNTERPARTY
  //
  // For a debit line, counterparties are normally credit lines
  // from the same journal.
  //
  // For a credit line, counterparties are normally debit lines.
  //
  // This keeps Cash / Bank / MFS ledgers understandable without
  // relying on manually typed narration.
  // ============================================================

  Future<String> _getCounterpartyNames({
    required DatabaseExecutor db,
    required int journalId,
    required int accountId,
    required double currentLineDebit,
    required double currentLineCredit,
  }) async {
    // Only the opposite side of the current ledger line can be a
    // counterparty. Previously every other line in the journal was
    // returned, which exposed Sales Income / COGS / Inventory etc.
    final oppositeCondition = currentLineDebit > 0
        ? 'jl.credit > 0'
        : currentLineCredit > 0
        ? 'jl.debit > 0'
        : '(jl.debit > 0 OR jl.credit > 0)';

    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT
        a.id AS account_id,
        a.name AS account_name,
        jl.entity_type AS entity_type,
        jl.entity_id AS entity_id,
        jl.id AS line_id
      FROM journal_lines jl
      INNER JOIN accounts a
        ON a.id = jl.account_id
      WHERE jl.journal_id = ?
        AND jl.account_id != ?
        AND $oppositeCondition
      ORDER BY
        CASE
          WHEN jl.entity_type IS NOT NULL
           AND TRIM(jl.entity_type) != ''
           AND jl.entity_id IS NOT NULL
          THEN 0
          ELSE 1
        END,
        jl.id
      ''',
      [journalId, accountId],
    );

    // A party-linked journal line is the meaningful counterparty for
    // Sale/Purchase receipts and payments. Prefer it over internal
    // accounting lines such as Sales Income, COGS and Inventory.
    for (final row in rows) {
      final entityType = row['entity_type']?.toString().trim() ?? '';
      final entityId = row['entity_id'];

      if (entityType.isNotEmpty && entityId != null) {
        final name = row['account_name']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          return name;
        }
      }
    }

    // Generic journals may legitimately have multiple counterpart
    // accounts, so preserve that behaviour when no party line exists.
    final names = <String>[];

    for (final row in rows) {
      final name = row['account_name']?.toString().trim() ?? '';

      if (name.isNotEmpty && !names.contains(name)) {
        names.add(name);
      }
    }

    return names.join(', ');
  }

  // ============================================================
  // ENTITY FILTER
  // ============================================================

  bool _matchesEntity(
    Map<String, dynamic> row,
    String? entityType,
    int? entityId,
  ) {
    if (entityType != null && row['entity_type']?.toString() != entityType) {
      return false;
    }

    if (entityId != null && _toInt(row['entity_id']) != entityId) {
      return false;
    }

    return true;
  }

  // ============================================================
  // VALUE HELPERS
  // ============================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}
