import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

class ProfitRepository {
  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  // ============================================================
  // TOTAL SALES
  // ============================================================

  Future<double> getTotalSales({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(grand_total), 0) AS total
      FROM sales
      WHERE DATE(sale_date)
            BETWEEN DATE(?) AND DATE(?)
      ''',
      [
        from.toIso8601String(),
        to.toIso8601String(),
      ],
    );

    return ((result.first['total'] ?? 0) as num)
        .toDouble();
  }

  // ============================================================
  // TOTAL PURCHASE
  // ============================================================

  Future<double> getTotalPurchase({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(grand_total), 0) AS total
      FROM purchases
      WHERE DATE(purchase_date)
            BETWEEN DATE(?) AND DATE(?)
      ''',
      [
        from.toIso8601String(),
        to.toIso8601String(),
      ],
    );

    return ((result.first['total'] ?? 0) as num)
        .toDouble();
  }

  // ============================================================
  // TOTAL EXPENSE
  // ============================================================

  Future<double> getTotalExpense({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE DATE(expense_date)
            BETWEEN DATE(?) AND DATE(?)
      ''',
      [
        from.toIso8601String(),
        to.toIso8601String(),
      ],
    );

    return ((result.first['total'] ?? 0) as num)
        .toDouble();
  }

  // ============================================================
  // OTHER INCOME
  // ============================================================

  Future<double> getTotalIncome({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(amount), 0) AS total
      FROM incomes
      WHERE DATE(income_date)
            BETWEEN DATE(?) AND DATE(?)
      ''',
      [
        from.toIso8601String(),
        to.toIso8601String(),
      ],
    );

    return ((result.first['total'] ?? 0) as num)
        .toDouble();
  }

  // ============================================================
  // COST OF GOODS SOLD
  // ============================================================

  Future<double> getCostOfGoodsSold({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(
          SUM(
            COALESCE(si.purchase_price, 0)
            * COALESCE(si.qty, 0)
          ),
          0
        ) AS total
      FROM sale_items si
      INNER JOIN sales s
        ON s.id = si.sale_id
      WHERE DATE(s.sale_date)
            BETWEEN DATE(?) AND DATE(?)
      ''',
      [
        from.toIso8601String(),
        to.toIso8601String(),
      ],
    );

    return ((result.first['total'] ?? 0) as num)
        .toDouble();
  }

  // ============================================================
  // GROSS PROFIT
  // ============================================================

  Future<double> getGrossProfit({
    required DateTime from,
    required DateTime to,
  }) async {
    final sales = await getTotalSales(
      from: from,
      to: to,
    );

    final cogs = await getCostOfGoodsSold(
      from: from,
      to: to,
    );

    return sales - cogs;
  }

  // ============================================================
  // NET PROFIT
  // ============================================================

  Future<double> getNetProfit({
    required DateTime from,
    required DateTime to,
  }) async {
    final gross = await getGrossProfit(
      from: from,
      to: to,
    );

    final income = await getTotalIncome(
      from: from,
      to: to,
    );

    final expense = await getTotalExpense(
      from: from,
      to: to,
    );

    return gross + income - expense;
  }
}