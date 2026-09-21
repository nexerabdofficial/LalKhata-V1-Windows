import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import '../profit_repository.dart';

class FFBalanceSheetRow {
  final int accountId;
  final String accountName;
  final String accountType;
  final String groupCode;
  final String groupKind;
  final String accountNature;
  final double balance;

  const FFBalanceSheetRow({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.groupCode,
    required this.groupKind,
    required this.accountNature,
    required this.balance,
  });
}

class FFBalanceSheetReport {
  final List<FFBalanceSheetRow> assets;
  final List<FFBalanceSheetRow> liabilities;
  final List<FFBalanceSheetRow> equity;

  final double inventoryValue;
  final double currentProfit;
  final double openingDifference;

  const FFBalanceSheetReport({
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.inventoryValue,
    required this.currentProfit,
    required this.openingDifference,
  });

  double get totalAssets {
    double total = 0;

    for (final row in assets) {
      if (row.accountType == 'INVENTORY') {
        continue;
      }

      total += row.balance;
    }

    return total + inventoryValue;
  }

  double get totalLiabilities {
    double total = 0;

    for (final row in liabilities) {
      total += row.balance;
    }

    return total;
  }

  double get ledgerEquity {
    double total = 0;

    for (final row in equity) {
      if (row.accountNature == 'DEBIT') {
        total -= row.balance;
      } else {
        total += row.balance;
      }
    }

    return total;
  }

  double get totalEquity => ledgerEquity + currentProfit;

  double get liabilitiesAndEquity => totalLiabilities + totalEquity;

  double get accountingDifference => totalAssets - liabilitiesAndEquity;
}

class FFBalanceSheetService {
  FFBalanceSheetService._();

  static final FFBalanceSheetService instance = FFBalanceSheetService._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  final ProfitRepository _profitRepository = ProfitRepository();

  Future<FFBalanceSheetReport> getReport({DateTime? asOf}) async {
    final db = await _databaseHelper.database;

    final effectiveAsOf = asOf ?? DateTime(9999, 12, 31, 23, 59, 59, 999);

    final rows = await _loadBalanceSheetAccounts(
      db,
      effectiveAsOf.toIso8601String(),
    );

    final inventoryValue = await _loadCurrentInventoryValue(db);

    final profit = await _profitRepository.getProfitStatement(
      from: DateTime(2000, 1, 1),
      to: effectiveAsOf,
    );

    final openingDifference = await _loadOpeningDifference(db);

    return FFBalanceSheetReport(
      assets: rows.where((row) => row.groupKind == 'ASSET').toList(),
      liabilities: rows.where((row) => row.groupKind == 'LIABILITY').toList(),
      equity: rows.where((row) => row.groupKind == 'EQUITY').toList(),
      inventoryValue: inventoryValue,
      currentProfit: profit.netProfit,
      openingDifference: openingDifference,
    );
  }

  Future<List<FFBalanceSheetRow>> _loadBalanceSheetAccounts(
    DatabaseExecutor db,
    String asOfIso,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        a.id,
        a.name,
        a.type,
        COALESCE(g.group_code, '') AS group_code,
        COALESCE(g.group_kind, '') AS group_kind,
        COALESCE(g.account_nature, '') AS account_nature,

        CASE
          WHEN a.type = 'CUSTOMER_RECEIVABLE'
            THEN COALESCE(
              (
                SELECT SUM(opening_balance)
                FROM customers
              ),
              0
            )

          WHEN a.type = 'SUPPLIER_PAYABLE'
            THEN COALESCE(
              (
                SELECT SUM(opening_balance)
                FROM suppliers
              ),
              0
            )

          ELSE COALESCE(a.opening_balance, 0)
        END AS opening_balance,

        COALESCE(
          (
            SELECT SUM(jl.debit)
            FROM journal_lines jl
            INNER JOIN journal_entries je
              ON je.id = jl.journal_id
            WHERE jl.account_id = a.id
              AND je.transaction_date <= ?
          ),
          0
        ) AS total_debit,

        COALESCE(
          (
            SELECT SUM(jl.credit)
            FROM journal_lines jl
            INNER JOIN journal_entries je
              ON je.id = jl.journal_id
            WHERE jl.account_id = a.id
              AND je.transaction_date <= ?
          ),
          0
        ) AS total_credit

      FROM accounts a

      INNER JOIN ff_account_links l
        ON l.account_id = a.id
       AND l.is_primary = 1

      INNER JOIN ff_account_groups g
        ON g.id = l.group_id

      WHERE g.group_kind IN (
        'ASSET',
        'LIABILITY',
        'EQUITY'
      )

      ORDER BY
        g.group_kind,
        g.group_code,
        a.name
      ''',
      [asOfIso, asOfIso],
    );

    final result = <FFBalanceSheetRow>[];

    for (final row in rows) {
      final nature = row['account_nature']?.toString().toUpperCase() ?? '';

      final opening = _toDouble(row['opening_balance']);

      final debit = _toDouble(row['total_debit']);

      final credit = _toDouble(row['total_credit']);

      final balance = nature == 'CREDIT'
          ? opening + credit - debit
          : opening + debit - credit;

      result.add(
        FFBalanceSheetRow(
          accountId: (row['id'] as num).toInt(),
          accountName: row['name']?.toString() ?? '',
          accountType: row['type']?.toString() ?? '',
          groupCode: row['group_code']?.toString() ?? '',
          groupKind: row['group_kind']?.toString() ?? '',
          accountNature: nature,
          balance: balance,
        ),
      );
    }

    return result;
  }

  Future<double> _loadCurrentInventoryValue(DatabaseExecutor db) async {
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(stock_value), 0) AS total
      FROM products
      ''');

    return _toDouble(result.first['total']);
  }

  Future<double> _loadOpeningDifference(DatabaseExecutor db) async {
    final rows = await db.rawQuery('''
      SELECT
        a.type,
        COALESCE(g.account_nature, '') AS account_nature,

        CASE
          WHEN a.type = 'CUSTOMER_RECEIVABLE'
            THEN COALESCE(
              (
                SELECT SUM(opening_balance)
                FROM customers
              ),
              0
            )

          WHEN a.type = 'SUPPLIER_PAYABLE'
            THEN COALESCE(
              (
                SELECT SUM(opening_balance)
                FROM suppliers
              ),
              0
            )

          ELSE COALESCE(a.opening_balance, 0)
        END AS opening_balance

      FROM accounts a

      INNER JOIN ff_account_links l
        ON l.account_id = a.id
       AND l.is_primary = 1

      INNER JOIN ff_account_groups g
        ON g.id = l.group_id
      ''');

    double debit = 0;
    double credit = 0;

    for (final row in rows) {
      final amount = _toDouble(row['opening_balance']);

      final nature = row['account_nature']?.toString().toUpperCase() ?? '';

      if (nature == 'DEBIT') {
        debit += amount;
      } else if (nature == 'CREDIT') {
        credit += amount;
      }
    }

    return debit - credit;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
