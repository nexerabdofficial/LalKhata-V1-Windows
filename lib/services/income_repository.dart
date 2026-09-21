import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/income.dart';
import 'refresh_service.dart';
import 'ff/ff_income_expense_posting_service.dart';
import 'ff/ff_journal_service.dart';

class IncomeRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  final FFIncomeExpensePostingService _ffPostingService =
      FFIncomeExpensePostingService.instance;

  final FFJournalService _ffJournalService = FFJournalService.instance;

  // ============================================================
  // NEXT INCOME VOUCHER NO
  // ============================================================

  Future<String> getNextIncomeVoucherNo() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT voucher_no
      FROM incomes
      WHERE voucher_no LIKE 'IN#%'
      ORDER BY id DESC
      LIMIT 1
    ''');

    if (result.isEmpty) {
      return 'IN#1';
    }

    final lastVoucher = result.first['voucher_no']?.toString() ?? '';

    final number = int.tryParse(lastVoucher.replaceFirst('IN#', '')) ?? 0;

    return 'IN#${number + 1}';
  }

  // ============================================================
  // INSERT INCOME
  // ============================================================

  Future<int> insertIncome(Income income, {String? voucherNo}) async {
    final Database db = await _databaseHelper.database;

    final id = await db.transaction((txn) async {
      final map = income.toMap();

      if (voucherNo != null && voucherNo.trim().isNotEmpty) {
        map['voucher_no'] = voucherNo;
      }

      final id = await txn.insert(
        'incomes',
        map,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (income.accountId != null) {
        await txn.rawUpdate(
          '''
          UPDATE accounts
          SET balance = balance + ?
          WHERE id = ?
          ''',
          [income.amount, income.accountId],
        );

        await txn.insert('account_transactions', {
          'account_id': income.accountId,
          'transaction_type': 'INCOME',
          'reference_type': 'INCOME',
          'reference_id': id,
          'voucher_no': voucherNo,
          'debit': 0,
          'credit': income.amount,
          'transaction_date': income.incomeDate,
          'note': income.category,
          'created_at': income.createdAt,
        }, conflictAlgorithm: ConflictAlgorithm.abort);
      }

      if (income.accountId != null) {
        final effectiveVoucher =
            voucherNo != null && voucherNo.trim().isNotEmpty
            ? voucherNo.trim()
            : 'INCOME-$id';

        await _ffPostingService.postIncomeWithExecutor(
          txn,
          incomeId: id,
          accountId: income.accountId!,
          amount: income.amount,
          voucherNo: effectiveVoucher,
          transactionDate: income.incomeDate,
          category: income.category,
        );
      }

      return id;
    });

    RefreshService.notify();

    return id;
  }

  // ============================================================
  // GET ALL INCOMES
  // ============================================================

  Future<List<Income>> getIncomes() async {
    final db = await _databaseHelper.database;

    final result = await db.query('incomes', orderBy: 'income_date DESC');

    return result.map((e) => Income.fromMap(e)).toList();
  }

  // ============================================================
  // DELETE INCOME
  // ============================================================

  Future<void> deleteIncome(int id) async {
    final db = await _databaseHelper.database;

    final data = await db.query(
      'incomes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (data.isEmpty) {
      return;
    }

    final income = Income.fromMap(data.first);

    await db.transaction((txn) async {
      await _ffJournalService.deleteJournalByReferenceWithExecutor(
        txn,
        referenceType: 'INCOME',
        referenceId: id,
      );

      if (income.accountId != null) {
        await txn.rawUpdate(
          '''
          UPDATE accounts
          SET balance = balance - ?
          WHERE id = ?
          ''',
          [income.amount, income.accountId],
        );
      }

      await txn.delete(
        'account_transactions',
        where: '''
          reference_type = ?
          AND reference_id = ?
        ''',
        whereArgs: ['INCOME', id],
      );

      await txn.delete('incomes', where: 'id = ?', whereArgs: [id]);
    });

    RefreshService.notify();
  }

  // ============================================================
  // TOTAL INCOME
  // ============================================================

  Future<double> getTotalIncome() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT SUM(amount) AS total
      FROM incomes
    ''');

    final value = result.first['total'];

    if (value == null) {
      return 0;
    }

    return (value as num).toDouble();
  }

  // ============================================================
  // CATEGORY-WISE INCOME SUMMARY
  // ============================================================

  Future<List<Map<String, dynamic>>> getIncomeCategorySummary({
    required String startDate,
    required String endDate,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        category,
        SUM(amount) AS total
      FROM incomes
      WHERE income_date >= ?
        AND income_date < date(?, '+1 day')
      GROUP BY category
      ORDER BY category ASC
      ''',
      [startDate, endDate],
    );

    return result;
  }

  // ============================================================
  // CATEGORY-WISE INCOME DETAILS
  // ============================================================

  Future<List<Income>> getIncomeByCategory({
    required String category,
    required String startDate,
    required String endDate,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'incomes',
      where: '''
        category = ?
        AND income_date >= ?
        AND income_date < date(?, '+1 day')
      ''',
      whereArgs: [category, startDate, endDate],
      orderBy: 'income_date ASC, id ASC',
    );

    return result.map((e) => Income.fromMap(e)).toList();
  }
}
