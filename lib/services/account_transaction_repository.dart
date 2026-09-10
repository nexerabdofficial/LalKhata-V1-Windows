import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/account_transaction.dart';

class AccountTransactionRepository {
  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  // ============================================================
  // INSERT TRANSACTION
  //
  // Duplicate protection:
  // For supplier payments, the same voucher cannot be inserted
  // twice.
  // ============================================================

  Future<int> insertTransaction(
    AccountTransaction transaction,
  ) async {
    final Database db =
        await _databaseHelper.database;

    // ----------------------------------------------------------
    // Supplier payment duplicate protection
    // ----------------------------------------------------------

    if (transaction.referenceType ==
            'SUPPLIER_PAYMENT' &&
        transaction.voucherNo != null &&
        transaction.voucherNo!
            .trim()
            .isNotEmpty) {
      final existing =
          await db.query(
        'account_transactions',
        columns: ['id'],
        where: '''
          reference_type = ?
          AND voucher_no = ?
        ''',
        whereArgs: [
          'SUPPLIER_PAYMENT',
          transaction.voucherNo,
        ],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return existing.first['id'] as int;
      }
    }

    return await db.insert(
      'account_transactions',
      transaction.toMap(),
      conflictAlgorithm:
          ConflictAlgorithm.abort,
    );
  }

  // ============================================================
  // GET TRANSACTIONS BY ACCOUNT
  //
  // Opening balance is already stored in accounts table.
  //
  // Balance:
  //
  // Opening + Credit - Debit
  // ============================================================

  Future<List<AccountTransaction>>
      getTransactionsByAccount(
    int accountId,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'account_transactions',
      where: '''
        account_id = ?
        AND transaction_type NOT IN (?, ?)
      ''',
      whereArgs: [
        accountId,
        'OPENING_BALANCE',
        'OPENING',
      ],
      orderBy:
          'transaction_date ASC, id ASC',
    );

    return maps
        .map(
          (map) =>
              AccountTransaction.fromMap(
            map,
          ),
        )
        .toList();
  }

  // ============================================================
  // GET ALL TRANSACTIONS
  // ============================================================

  Future<List<AccountTransaction>>
      getAllTransactions() async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'account_transactions',
      orderBy:
          'transaction_date ASC, id ASC',
    );

    return maps
        .map(
          (map) =>
              AccountTransaction.fromMap(
            map,
          ),
        )
        .toList();
  }

  // ============================================================
  // GET TRANSACTIONS BY DATE RANGE
  // ============================================================

  Future<List<AccountTransaction>>
      getTransactionsByDateRange({
    required int accountId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final Database db =
        await _databaseHelper.database;

    final from = DateTime(
      fromDate.year,
      fromDate.month,
      fromDate.day,
    ).toIso8601String();

    final to = DateTime(
      toDate.year,
      toDate.month,
      toDate.day,
      23,
      59,
      59,
      999,
    ).toIso8601String();

    final maps = await db.query(
      'account_transactions',
      where: '''
        account_id = ?
        AND transaction_date >= ?
        AND transaction_date <= ?
      ''',
      whereArgs: [
        accountId,
        from,
        to,
      ],
      orderBy:
          'transaction_date ASC, id ASC',
    );

    return maps
        .map(
          (map) =>
              AccountTransaction.fromMap(
            map,
          ),
        )
        .toList();
  }

  // ============================================================
  // GET SINGLE TRANSACTION
  // ============================================================

  Future<AccountTransaction?>
      getTransactionById(
    int id,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'account_transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return AccountTransaction.fromMap(
      maps.first,
    );
  }

  // ============================================================
  // DELETE TRANSACTION
  // ============================================================

  Future<int> deleteTransaction(
    int id,
  ) async {
    final Database db =
        await _databaseHelper.database;

    return await db.delete(
      'account_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // DELETE BY REFERENCE
  // ============================================================

  Future<int>
      deleteTransactionsByReference({
    required String referenceType,
    required int referenceId,
  }) async {
    final Database db =
        await _databaseHelper.database;

    return await db.delete(
      'account_transactions',
      where: '''
        reference_type = ?
        AND reference_id = ?
      ''',
      whereArgs: [
        referenceType,
        referenceId,
      ],
    );
  }

  // ============================================================
  // DELETE SUPPLIER PAYMENT TRANSACTION
  // ============================================================

  Future<int>
      deleteSupplierPaymentTransaction(
    String voucherNo,
  ) async {
    final Database db =
        await _databaseHelper.database;

    return await db.delete(
      'account_transactions',
      where: '''
        reference_type = ?
        AND voucher_no = ?
      ''',
      whereArgs: [
        'SUPPLIER_PAYMENT',
        voucherNo,
      ],
    );
  }

  // ============================================================
  // GET TRANSACTION BY VOUCHER
  // ============================================================

  Future<AccountTransaction?>
      getTransactionByVoucher(
    String voucherNo,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'account_transactions',
      where: 'voucher_no = ?',
      whereArgs: [voucherNo],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return AccountTransaction.fromMap(
      maps.first,
    );
  }

  // ============================================================
  // CHECK SUPPLIER PAYMENT TRANSACTION
  // ============================================================

  Future<bool>
      supplierPaymentTransactionExists(
    String voucherNo,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final result =
        await db.query(
      'account_transactions',
      columns: ['id'],
      where: '''
        reference_type = ?
        AND voucher_no = ?
      ''',
      whereArgs: [
        'SUPPLIER_PAYMENT',
        voucherNo,
      ],
      limit: 1,
    );

    return result.isNotEmpty;
  }
  // ============================================================
  // FUND TRANSFER
  //
  // Source Account:
  //   Debit  = amount
  //   Credit = 0
  //
  // Destination Account:
  //   Debit  = 0
  //   Credit = amount
  //
  // Both transactions use the same voucher number.
  //
  // IMPORTANT:
  // Both inserts happen inside ONE SQLite transaction.
  // If either insert fails, BOTH are rolled back.
  // ============================================================

  Future<void> transferFunds({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required String voucherNo,
    required String transactionDate,
    String? note,
  }) async {
    if (fromAccountId == toAccountId) {
      throw ArgumentError(
        'Source and destination accounts cannot be the same.',
      );
    }

    if (amount <= 0) {
      throw ArgumentError(
        'Transfer amount must be greater than zero.',
      );
    }

    final Database db =
        await _databaseHelper.database;

    await db.transaction(
      (txn) async {
        // ------------------------------------------------------
        // Verify source account exists
        // ------------------------------------------------------

        final source = await txn.query(
          'accounts',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [fromAccountId],
          limit: 1,
        );

        if (source.isEmpty) {
          throw StateError(
            'Source account does not exist.',
          );
        }

        // ------------------------------------------------------
        // Verify destination account exists
        // ------------------------------------------------------

        final destination = await txn.query(
          'accounts',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [toAccountId],
          limit: 1,
        );

        if (destination.isEmpty) {
          throw StateError(
            'Destination account does not exist.',
          );
        }

        // ------------------------------------------------------
        // Prevent duplicate transfer voucher
        // ------------------------------------------------------

        final existing = await txn.query(
          'account_transactions',
          columns: ['id'],
          where: '''
            reference_type = ?
            AND voucher_no = ?
          ''',
          whereArgs: [
            'FUND_TRANSFER',
            voucherNo,
          ],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          throw StateError(
            'This transfer voucher already exists.',
          );
        }

        final createdAt =
            DateTime.now().toIso8601String();

        // ------------------------------------------------------
        // SOURCE ACCOUNT
        // Money goes OUT
        // ------------------------------------------------------

        await txn.insert(
          'account_transactions',
          {
            'account_id': fromAccountId,
            'transaction_type': 'FUND_TRANSFER_OUT',
            'reference_type': 'FUND_TRANSFER',
            'reference_id': null,
            'voucher_no': voucherNo,
            'debit': amount,
            'credit': 0,
            'transaction_date': transactionDate,
            'note': note,
            'created_at': createdAt,
          },
          conflictAlgorithm:
              ConflictAlgorithm.abort,
        );

        // ------------------------------------------------------
        // DESTINATION ACCOUNT
        // Money comes IN
        // ------------------------------------------------------

        await txn.insert(
          'account_transactions',
          {
            'account_id': toAccountId,
            'transaction_type': 'FUND_TRANSFER_IN',
            'reference_type': 'FUND_TRANSFER',
            'reference_id': null,
            'voucher_no': voucherNo,
            'debit': 0,
            'credit': amount,
            'transaction_date': transactionDate,
            'note': note,
            'created_at': createdAt,
          },
          conflictAlgorithm:
              ConflictAlgorithm.abort,
        );
      },
    );
  }
}