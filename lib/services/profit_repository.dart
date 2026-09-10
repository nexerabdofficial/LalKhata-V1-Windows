import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

class ProfitRepository {
  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  Future<double> getTotalSales({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(grand_total),0) AS total
      FROM sales
      WHERE sale_date BETWEEN ? AND ?
      ''',
      [
        from.toIso8601String(),
        to.toIso8601String(),
      ],
    );

    return ((result.first['total'] ?? 0) as num)
        .toDouble();
  }

  Future<double> getTotalExpense({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount),0) AS total
      FROM expenses
      WHERE expense_date BETWEEN ? AND ?
      ''',
      [
        from.toIso8601String(),
        to.toIso8601String(),
      ],
    );

    return ((result.first['total'] ?? 0) as num)
        .toDouble();
  }

  Future<double> getTotalIncome({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount),0) AS total
      FROM incomes
      WHERE income_date BETWEEN ? AND ?
      ''',
      [
        from.toIso8601String(),
        to.toIso8601String(),
      ],
    );

    return ((result.first['total'] ?? 0) as num)
        .toDouble();
  }

  Future<double> getCostOfGoodsSold({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
      COALESCE(
        SUM(qty * purchase_price),
        0
      ) AS total
      FROM sale_items
      WHERE sale_id IN (
        SELECT id
        FROM sales
        WHERE sale_date BETWEEN ? AND ?
      )
      ''',
      [
        from.toIso8601String(),
        to.toIso8601String(),
      ],
    );

    return ((result.first['total'] ?? 0) as num)
        .toDouble();
  }
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