import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/expense.dart';
import 'refresh_service.dart';

class ExpenseRepository {
  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  // ============================================================
  // INSERT EXPENSE
  // ============================================================

  Future<int> insertExpense(
    Expense expense,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final id = await db.transaction((txn) async {
      final id = await txn.insert(
        'expenses',
        expense.toMap(),
        conflictAlgorithm:
            ConflictAlgorithm.replace,
      );

      if (expense.accountId != null) {
        await txn.rawUpdate(
          '''
          UPDATE accounts
          SET balance = balance - ?
          WHERE id = ?
          ''',
          [
            expense.amount,
            expense.accountId,
          ],
        );
      }

      return id;
    });

    RefreshService.notify();

    return id;
  }

  // ============================================================
  // NEXT EXPENSE VOUCHER NO
  // ============================================================

  Future<String> getNextExpenseVoucherNo() async {
    final db =
        await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM expenses
    ''');

    final total =
        (result.first['total'] as num?)?.toInt() ?? 0;

    return 'EX#${total + 1}';
  }

  // ============================================================
  // GET ALL EXPENSES
  // ============================================================

  Future<List<Expense>> getExpenses() async {
    final Database db =
        await _databaseHelper.database;

    final List<Map<String, dynamic>> maps =
        await db.query(
      'expenses',
      orderBy: 'expense_date DESC',
    );

    return maps
        .map(
          (e) => Expense.fromMap(e),
        )
        .toList();
  }

  // ============================================================
  // DELETE EXPENSE
  // ============================================================

  Future<int> deleteExpense(
    int id,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final data = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (data.isEmpty) {
      return 0;
    }

    final expense =
        Expense.fromMap(data.first);

    final result =
        await db.transaction((txn) async {
      if (expense.accountId != null) {
        await txn.rawUpdate(
          '''
          UPDATE accounts
          SET balance = balance + ?
          WHERE id = ?
          ''',
          [
            expense.amount,
            expense.accountId,
          ],
        );
      }

      return await txn.delete(
        'expenses',
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    RefreshService.notify();

    return result;
  }

  // ============================================================
  // TOTAL EXPENSE
  // ============================================================

  Future<double> getTotalExpense() async {
    final Database db =
        await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) AS total
      FROM expenses
      ''',
    );

    final total =
        result.first['total'];

    if (total == null) {
      return 0;
    }

    return (total as num).toDouble();
  }

  // ============================================================
  // CATEGORY-WISE EXPENSE SUMMARY
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getExpenseCategorySummary({
    required String startDate,
    required String endDate,
  }) async {
    final db =
        await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        category,
        SUM(amount) AS total
      FROM expenses
      WHERE expense_date >= ?
        AND expense_date < date(?, '+1 day')
      GROUP BY category
      ORDER BY category ASC
      ''',
      [
        startDate,
        endDate,
      ],
    );

    return result;
  }

  // ============================================================
  // CATEGORY-WISE EXPENSE DETAILS
  // ============================================================

  Future<List<Expense>>
      getExpenseByCategory({
    required String category,
    required String startDate,
    required String endDate,
  }) async {
    final db =
        await _databaseHelper.database;

    final result = await db.query(
      'expenses',
      where: '''
        category = ?
        AND expense_date >= ?
        AND expense_date < date(?, '+1 day')
      ''',
      whereArgs: [
        category,
        startDate,
        endDate,
      ],
      orderBy:
          'expense_date ASC, id ASC',
    );

    return result
        .map(
          (e) => Expense.fromMap(e),
        )
        .toList();
  }
}