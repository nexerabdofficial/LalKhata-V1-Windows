import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

class FFProfitAccountRow {
  final int accountId;
  final String accountName;
  final String groupCode;
  final double amount;

  const FFProfitAccountRow({
    required this.accountId,
    required this.accountName,
    required this.groupCode,
    required this.amount,
  });
}

class FFProfitStatement {
  final List<FFProfitAccountRow> incomeAccounts;
  final List<FFProfitAccountRow> expenseAccounts;

  final double salesIncome;
  final double otherIncome;
  final double cogs;
  final double operatingExpenses;

  final double openingStock;
  final double purchaseAccounts;
  final double closingStock;

  const FFProfitStatement({
    required this.incomeAccounts,
    required this.expenseAccounts,
    required this.salesIncome,
    required this.otherIncome,
    required this.cogs,
    required this.operatingExpenses,
    required this.openingStock,
    required this.purchaseAccounts,
    required this.closingStock,
  });

  double get totalIncome => salesIncome + otherIncome;

  // Existing costing remains authoritative.
  double get grossProfit => salesIncome - cogs;

  double get netProfit => grossProfit + otherIncome - operatingExpenses;
}

class ProfitRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // ============================================================
  // FF PROFIT & LOSS
  // ============================================================

  Future<FFProfitStatement> getProfitStatement({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;

    final fromIso = from.toIso8601String();
    final toIso = to.toIso8601String();

    final incomeRows = await _loadIncomeAccounts(db, fromIso, toIso);

    final expenseRows = await _loadExpenseAccounts(db, fromIso, toIso);

    double salesIncome = 0;
    double otherIncome = 0;

    for (final row in incomeRows) {
      if (row.groupCode == 'SALES_INCOME') {
        salesIncome += row.amount;
      } else {
        otherIncome += row.amount;
      }
    }

    double operatingExpenses = 0;

    for (final row in expenseRows) {
      // COGS is intentionally excluded from operating expenses.
      //
      // Profit & Loss uses the sale-time cost snapshot stored in
      // sale_items.purchase_price as its single costing source.
      // The COGS journal account remains authoritative for the
      // accounting ledger / Balance Sheet inventory movement.
      if (row.groupCode == 'COST_OF_GOODS_SOLD') {
        continue;
      }

      operatingExpenses += row.amount;
    }

    // Always use the exact sale-time weighted-average cost snapshot.
    //
    // This keeps historical, new and mixed date ranges consistent
    // and avoids both missing COGS and double-counting journal COGS.
    final cogs = await _getCogs(db, fromIso, toIso);

    final openingStock = await _getInventoryBalanceBefore(db, fromIso);

    final purchaseAccounts = await _getPurchaseInventoryMovement(
      db,
      fromIso,
      toIso,
    );

    // Trading presentation only.
    //
    // Existing sale-time weighted-average COGS remains untouched.
    // This identity simply exposes the same stock movement in
    // Opening Stock / Purchases / Closing Stock form.
    final closingStock = openingStock + purchaseAccounts - cogs;

    return FFProfitStatement(
      incomeAccounts: incomeRows,
      expenseAccounts: expenseRows,
      salesIncome: salesIncome,
      otherIncome: otherIncome,
      cogs: cogs,
      operatingExpenses: operatingExpenses,
      openingStock: openingStock,
      purchaseAccounts: purchaseAccounts,
      closingStock: closingStock,
    );
  }

  // ============================================================
  // FF INCOME ACCOUNTS
  // CREDIT - DEBIT
  // ============================================================

  Future<List<FFProfitAccountRow>> _loadIncomeAccounts(
    DatabaseExecutor db,
    String fromIso,
    String toIso,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        a.id AS account_id,
        a.name AS account_name,
        COALESCE(g.group_code, '') AS group_code,
        COALESCE(SUM(jl.credit), 0) -
        COALESCE(SUM(jl.debit), 0) AS amount
      FROM accounts a

      INNER JOIN ff_account_links l
        ON l.account_id = a.id
       AND l.is_primary = 1

      INNER JOIN ff_account_groups g
        ON g.id = l.group_id

      INNER JOIN journal_lines jl
        ON jl.account_id = a.id

      INNER JOIN journal_entries je
        ON je.id = jl.journal_id

      WHERE g.group_kind = 'INCOME'
        AND je.transaction_date BETWEEN ? AND ?

      GROUP BY
        a.id,
        a.name,
        g.group_code

      HAVING ABS(
        COALESCE(SUM(jl.credit), 0) -
        COALESCE(SUM(jl.debit), 0)
      ) > 0.000001

      ORDER BY a.name
      ''',
      [fromIso, toIso],
    );

    return rows
        .map(
          (row) => FFProfitAccountRow(
            accountId: (row['account_id'] as num).toInt(),
            accountName: row['account_name']?.toString() ?? '',
            groupCode: row['group_code']?.toString() ?? '',
            amount: _toDouble(row['amount']),
          ),
        )
        .toList();
  }

  // ============================================================
  // FF EXPENSE ACCOUNTS
  // DEBIT - CREDIT
  // ============================================================

  Future<List<FFProfitAccountRow>> _loadExpenseAccounts(
    DatabaseExecutor db,
    String fromIso,
    String toIso,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        a.id AS account_id,
        a.name AS account_name,
        COALESCE(g.group_code, '') AS group_code,
        COALESCE(SUM(jl.debit), 0) -
        COALESCE(SUM(jl.credit), 0) AS amount
      FROM accounts a

      INNER JOIN ff_account_links l
        ON l.account_id = a.id
       AND l.is_primary = 1

      INNER JOIN ff_account_groups g
        ON g.id = l.group_id

      INNER JOIN journal_lines jl
        ON jl.account_id = a.id

      INNER JOIN journal_entries je
        ON je.id = jl.journal_id

      WHERE g.group_kind = 'EXPENSE'
        AND je.transaction_date BETWEEN ? AND ?

      GROUP BY
        a.id,
        a.name,
        g.group_code

      HAVING ABS(
        COALESCE(SUM(jl.debit), 0) -
        COALESCE(SUM(jl.credit), 0)
      ) > 0.000001

      ORDER BY a.name
      ''',
      [fromIso, toIso],
    );

    return rows
        .map(
          (row) => FFProfitAccountRow(
            accountId: (row['account_id'] as num).toInt(),
            accountName: row['account_name']?.toString() ?? '',
            groupCode: row['group_code']?.toString() ?? '',
            amount: _toDouble(row['amount']),
          ),
        )
        .toList();
  }

  // ============================================================
  // TRADING ACCOUNT STOCK FIGURES
  // ============================================================

  Future<int?> _getInventoryAccountId(DatabaseExecutor db) async {
    final rows = await db.rawQuery('''
      SELECT a.id
      FROM accounts a
      INNER JOIN ff_account_links l
        ON l.account_id = a.id
       AND l.is_primary = 1
      INNER JOIN ff_account_groups g
        ON g.id = l.group_id
      WHERE UPPER(a.type) = 'INVENTORY'
         OR UPPER(g.group_code) = 'INVENTORY'
      ORDER BY a.id
      LIMIT 1
      ''');

    if (rows.isEmpty) {
      return null;
    }

    return (rows.first['id'] as num).toInt();
  }

  Future<double> _getInventoryBalanceBefore(
    DatabaseExecutor db,
    String fromIso,
  ) async {
    final inventoryAccountId = await _getInventoryAccountId(db);

    if (inventoryAccountId == null) {
      return 0;
    }

    final accountRows = await db.query(
      'accounts',
      columns: ['opening_balance'],
      where: 'id = ?',
      whereArgs: [inventoryAccountId],
      limit: 1,
    );

    final opening = accountRows.isEmpty
        ? 0.0
        : _toDouble(accountRows.first['opening_balance']);

    final movementRows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(jl.debit), 0) -
        COALESCE(SUM(jl.credit), 0) AS movement
      FROM journal_lines jl
      INNER JOIN journal_entries je
        ON je.id = jl.journal_id
      WHERE jl.account_id = ?
        AND je.transaction_date < ?
      ''',
      [inventoryAccountId, fromIso],
    );

    return opening + _toDouble(movementRows.first['movement']);
  }

  Future<double> _getPurchaseInventoryMovement(
    DatabaseExecutor db,
    String fromIso,
    String toIso,
  ) async {
    final inventoryAccountId = await _getInventoryAccountId(db);

    if (inventoryAccountId == null) {
      return 0;
    }

    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(jl.debit), 0) -
        COALESCE(SUM(jl.credit), 0) AS amount
      FROM journal_lines jl
      INNER JOIN journal_entries je
        ON je.id = jl.journal_id
      WHERE jl.account_id = ?
        AND UPPER(je.transaction_type) = 'PURCHASE'
        AND je.transaction_date BETWEEN ? AND ?
      ''',
      [inventoryAccountId, fromIso, toIso],
    );

    return _toDouble(rows.first['amount']);
  }

  // ============================================================
  // COGS
  //
  // IMPORTANT:
  // sale_items.purchase_price is the sale-time weighted-average
  // cost snapshot written by SaleRepository.
  //
  // Do not replace this with current product purchase price.
  // ============================================================

  Future<double> _getCogs(
    DatabaseExecutor db,
    String fromIso,
    String toIso,
  ) async {
    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(
          SUM(si.qty * si.purchase_price),
          0
        ) AS total

      FROM sale_items si

      INNER JOIN sales s
        ON s.id = si.sale_id

      WHERE s.sale_date BETWEEN ? AND ?
      ''',
      [fromIso, toIso],
    );

    return _toDouble(result.first['total']);
  }

  // ============================================================
  // LEGACY PUBLIC API
  //
  // Kept for existing UI compatibility.
  // Data now follows FF P&L rules.
  // ============================================================

  Future<double> getTotalSales({
    required DateTime from,
    required DateTime to,
  }) async {
    final report = await getProfitStatement(from: from, to: to);

    return report.salesIncome;
  }

  Future<double> getCostOfGoodsSold({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;

    return _getCogs(db, from.toIso8601String(), to.toIso8601String());
  }

  Future<double> getGrossProfit({
    required DateTime from,
    required DateTime to,
  }) async {
    final report = await getProfitStatement(from: from, to: to);

    return report.grossProfit;
  }

  Future<double> getTotalIncome({
    required DateTime from,
    required DateTime to,
  }) async {
    final report = await getProfitStatement(from: from, to: to);

    return report.otherIncome;
  }

  Future<double> getTotalExpense({
    required DateTime from,
    required DateTime to,
  }) async {
    final report = await getProfitStatement(from: from, to: to);

    return report.operatingExpenses;
  }

  Future<double> getNetProfit({
    required DateTime from,
    required DateTime to,
  }) async {
    final report = await getProfitStatement(from: from, to: to);

    return report.netProfit;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
