import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/loan.dart';
import '../models/loan_payment.dart';

class LoanDao {
  LoanDao._();

  static final LoanDao instance = LoanDao._();

  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  // ============================================================
  // LOAN
  // ============================================================

  Future<int> insertLoan(
    DatabaseExecutor db,
    Loan loan,
  ) async {
    return await db.insert(
      'loans',
      loan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Loan>> getAllLoans() async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'loans',
      orderBy: 'loan_date DESC, id DESC',
    );

    return maps
        .map((map) => Loan.fromMap(map))
        .toList();
  }

  Future<Loan?> getLoanById(
    int loanId,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'loans',
      where: 'id = ?',
      whereArgs: [loanId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Loan.fromMap(maps.first);
  }

  Future<List<Loan>> getLoansByType(
    String loanType,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'loans',
      where: 'loan_type = ?',
      whereArgs: [loanType],
      orderBy: 'loan_date DESC, id DESC',
    );

    return maps
        .map((map) => Loan.fromMap(map))
        .toList();
  }

  Future<List<Loan>> getActiveLoans() async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'loans',
      where: 'status != ?',
      whereArgs: ['COMPLETED'],
      orderBy: 'loan_date DESC, id DESC',
    );

    return maps
        .map((map) => Loan.fromMap(map))
        .toList();
  }

  Future<int> updateLoan(
    DatabaseExecutor db,
    int loanId,
    Map<String, dynamic> values,
  ) async {
    return await db.update(
      'loans',
      values,
      where: 'id = ?',
      whereArgs: [loanId],
    );
  }

  Future<int> deleteLoan(
    DatabaseExecutor db,
    int loanId,
  ) async {
    return await db.delete(
      'loans',
      where: 'id = ?',
      whereArgs: [loanId],
    );
  }

  // ============================================================
  // LOAN PAYMENT
  // ============================================================

  Future<int> insertLoanPayment(
    DatabaseExecutor db,
    LoanPayment payment,
  ) async {
    return await db.insert(
      'loan_payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<LoanPayment?> getLoanPaymentById(
    int paymentId,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'loan_payments',
      where: 'id = ?',
      whereArgs: [paymentId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return LoanPayment.fromMap(
      maps.first,
    );
  }

  Future<List<LoanPayment>> getPaymentsByLoanId(
    int loanId,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'loan_payments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'payment_date ASC, id ASC',
    );

    return maps
        .map(
          (map) => LoanPayment.fromMap(map),
        )
        .toList();
  }

  Future<int> deleteLoanPayment(
    DatabaseExecutor db,
    int paymentId,
  ) async {
    return await db.delete(
      'loan_payments',
      where: 'id = ?',
      whereArgs: [paymentId],
    );
  }

  // ============================================================
  // PAYMENT TOTALS
  // ============================================================

  Future<double> getPaidPrincipal(
    int loanId,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(principal_amount),
        0
      ) AS total
      FROM loan_payments
      WHERE loan_id = ?
      ''',
      [loanId],
    );

    return (result.first['total'] as num?)
            ?.toDouble() ??
        0.0;
  }

  Future<double> getPaidInterest(
    int loanId,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(interest_amount),
        0
      ) AS total
      FROM loan_payments
      WHERE loan_id = ?
      ''',
      [loanId],
    );

    return (result.first['total'] as num?)
            ?.toDouble() ??
        0.0;
  }

  // ============================================================
  // LOAN STATISTICS
  // ============================================================

  Future<double> getTotalPrincipalByType(
    String loanType,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(principal_amount),
        0
      ) AS total
      FROM loans
      WHERE loan_type = ?
      ''',
      [loanType],
    );

    return (result.first['total'] as num?)
            ?.toDouble() ??
        0.0;
  }

  Future<double> getTotalOutstandingByType(
    String loanType,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(
          principal_amount - paid_amount
        ),
        0
      ) AS total
      FROM loans
      WHERE loan_type = ?
      AND status != 'COMPLETED'
      ''',
      [loanType],
    );

    return (result.first['total'] as num?)
            ?.toDouble() ??
        0.0;
  }

  Future<double> getTotalInterestByType(
    String loanType,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(interest_amount),
        0
      ) AS total
      FROM loans
      WHERE loan_type = ?
      ''',
      [loanType],
    );

    return (result.first['total'] as num?)
            ?.toDouble() ??
        0.0;
  }

  // ============================================================
  // TRANSACTION HELPER
  // ============================================================

  Future<T> transaction<T>(
    Future<T> Function(DatabaseExecutor txn) action,
  ) async {
    final Database db =
        await _databaseHelper.database;

    return await db.transaction(action);
  }
}