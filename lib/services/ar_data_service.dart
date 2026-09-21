import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'ff/ff_cash_flow_service.dart';
import 'ff/ff_money_flow_service.dart';

class ARBestSellingProduct {
  final int productId;
  final String productName;
  final double quantity;

  const ARBestSellingProduct({
    required this.productId,
    required this.productName,
    required this.quantity,
  });
}

class ARDataService {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  final FFMoneyFlowService _moneyFlowService = FFMoneyFlowService.instance;

  final FFCashFlowService _cashFlowService = FFCashFlowService.instance;

  // ============================================================
  // DATABASE
  // ============================================================

  Future<Database> get _db => _databaseHelper.database;

  // ============================================================
  // DATE RANGE
  // ============================================================

  List<String> _todayRange() {
    final now = DateTime.now();

    final start = DateTime(now.year, now.month, now.day);

    final end = start.add(const Duration(days: 1));

    return [start.toIso8601String(), end.toIso8601String()];
  }

  // ============================================================
  // TODAY SALES
  // ============================================================

  Future<double> getTodaySales() async {
    final db = await _db;
    final range = _todayRange();

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(grand_total), 0) AS total
      FROM sales
      WHERE sale_date >= ?
        AND sale_date < ?
      ''', range);

    return _toDouble(result.first['total']);
  }

  // ============================================================
  // TODAY PURCHASE
  // ============================================================

  Future<double> getTodayPurchase() async {
    final db = await _db;
    final range = _todayRange();

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(grand_total), 0) AS total
      FROM purchases
      WHERE purchase_date >= ?
        AND purchase_date < ?
      ''', range);

    return _toDouble(result.first['total']);
  }

  // ============================================================
  // TODAY EXPENSE
  // ============================================================

  Future<double> getTodayExpense() async {
    final db = await _db;
    final range = _todayRange();

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE expense_date >= ?
        AND expense_date < ?
      ''', range);

    return _toDouble(result.first['total']);
  }

  // ============================================================
  // TODAY INCOME
  // ============================================================

  Future<double> getTodayIncome() async {
    final db = await _db;
    final range = _todayRange();

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM incomes
      WHERE income_date >= ?
        AND income_date < ?
      ''', range);

    return _toDouble(result.first['total']);
  }

  // ============================================================
  // MONEY RECEIVED
  //
  // Credit transactions that represent actual money coming
  // into the business.
  //
  // FUND_TRANSFER_IN is excluded because it is an internal
  // movement between business accounts.
  // ============================================================

  Future<double> getTodayMoneyReceived() async {
    final report = await _moneyFlowService.getTodayReport(received: true);

    return report.total;
  }

  // ============================================================
  // MONEY GIVEN
  //
  // Debit transactions that represent actual money going
  // out of the business.
  //
  // FUND_TRANSFER_OUT is excluded because it is an internal
  // movement between business accounts.
  // ============================================================

  Future<double> getTodayMoneyGiven() async {
    final report = await _moneyFlowService.getTodayReport(received: false);

    return report.total;
  }

  // ============================================================
  // CASH CLOSING
  //
  // Uses the existing AccountRepository ledger calculation.
  // No account balance logic is duplicated here.
  // ============================================================

  Future<double> getCashClosing() async {
    final now = DateTime.now();

    final start = DateTime(now.year, now.month, now.day);

    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final report = await _cashFlowService.getReport(from: start, to: end);

    return report.closingBalance;
  }

  // ============================================================
  // BEST SELLING PRODUCTS
  //
  // Based on quantity sold, not sales amount.
  // ============================================================

  Future<List<ARBestSellingProduct>> getBestSellingProducts({
    int limit = 5,
  }) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
      SELECT
        product_id,
        product_name,
        COALESCE(SUM(qty), 0) AS quantity
      FROM sale_items
      GROUP BY product_id, product_name
      ORDER BY quantity DESC
      LIMIT ?
      ''',
      [limit],
    );

    return result.map((row) {
      return ARBestSellingProduct(
        productId: _toInt(row['product_id']),
        productName: (row['product_name'] ?? '').toString(),
        quantity: _toDouble(row['quantity']),
      );
    }).toList();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double _toDouble(Object? value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(Object? value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }
}
