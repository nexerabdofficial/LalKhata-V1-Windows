import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/customer.dart';
import '../models/customer_ledger.dart';
import '../models/account_transaction.dart';
import 'refresh_service.dart';
import 'ff/ff_party_payment_posting_service.dart';
import 'ff/ff_party_account_service.dart';

class CustomerRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  final FFPartyPaymentPostingService _ffPartyPaymentPostingService =
      FFPartyPaymentPostingService.instance;

  final FFPartyAccountService _ffPartyAccountService =
      FFPartyAccountService.instance;

  Future<int> insertCustomer(Customer customer) async {
    final Database db = await _databaseHelper.database;

    return db.transaction((txn) async {
      final data = customer.toMap()..remove('id');

      final customerId = await txn.insert(
        'customers',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await _ffPartyAccountService.ensureCustomerAccountWithExecutor(
        txn,
        customerId,
      );

      return customerId;
    });
  }

  Future<List<Customer>> getCustomers() async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query('customers', orderBy: 'id DESC');

    final List<Customer> customers = [];

    for (final map in maps) {
      final customer = Customer.fromMap(map);

      final balance = await getCustomerBalance(customer.id!);

      customers.add(
        Customer(
          id: customer.id,
          name: customer.name,
          phone: customer.phone,
          address: customer.address,
          balance: balance,
          openingBalance: customer.openingBalance,
          openingDate: customer.openingDate,
        ),
      );
    }

    return customers;
  }

  Future<double> getCustomerBalance(int customerId) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(
          (
            SELECT opening_balance
            FROM customers
            WHERE id = ?
          ),
          0
        )
        +
        COALESCE(
          (
            SELECT SUM(grand_total)
            FROM sales
            WHERE customer_id = ?
          ),
          0
        )
        -
        COALESCE(
          (
            SELECT SUM(amount)
            FROM customer_payments
            WHERE customer_id = ?
          ),
          0
        ) AS balance
      ''',
      [customerId, customerId, customerId],
    );

    return ((result.first['balance'] ?? 0) as num).toDouble();
  }

  Future<int> updateCustomer(Customer customer) async {
    if (customer.id == null) {
      throw ArgumentError('Customer ID is required for update.');
    }

    final Database db = await _databaseHelper.database;

    return db.transaction((txn) async {
      final data = customer.toMap()..remove('id');

      final updated = await txn.update(
        'customers',
        data,
        where: 'id = ?',
        whereArgs: [customer.id],
      );

      if (updated > 0) {
        await _ffPartyAccountService.syncCustomerAccountWithExecutor(
          txn,
          customer.id!,
        );
      }

      return updated;
    });
  }

  Future<int> deleteCustomer(int id) async {
    final Database db = await _databaseHelper.database;

    final customer = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (customer.isEmpty) {
      throw Exception("Customer not found.");
    }

    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Customer>> getDueCustomers() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT
        c.id,
        c.name,
        c.phone,
        c.address,
        c.opening_balance,
        (
          COALESCE(c.opening_balance, 0)
          +
          COALESCE(
            (
              SELECT SUM(s.grand_total)
              FROM sales s
              WHERE s.customer_id = c.id
            ),
            0
          )
          -
          COALESCE(
            (
              SELECT SUM(cp.amount)
              FROM customer_payments cp
              WHERE cp.customer_id = c.id
            ),
            0
          )
        ) AS balance
      FROM customers c
      WHERE (
        COALESCE(c.opening_balance, 0)
        +
        COALESCE(
          (
            SELECT SUM(s.grand_total)
            FROM sales s
            WHERE s.customer_id = c.id
          ),
          0
        )
        -
        COALESCE(
          (
            SELECT SUM(cp.amount)
            FROM customer_payments cp
            WHERE cp.customer_id = c.id
          ),
          0
        )
      ) > 0
      ORDER BY c.name ASC
      ''');

    return result.map((e) => Customer.fromMap(e)).toList();
  }

  // ============================================================
  // CUSTOMER PAYMENT
  // ============================================================

  Future<int> saveCustomerPayment({
    required int customerId,
    required double amount,
    required String voucherNo,
    required int accountId,
    required String paymentMethod,
    String note = "",
  }) async {
    final db = await _databaseHelper.database;

    final now = DateTime.now().toIso8601String();

    final paymentId = await db.transaction((txn) async {
      // 1. Save customer payment
      final id = await txn.insert('customer_payments', {
        'customer_id': customerId,
        'voucher_no': voucherNo,
        'amount': amount,
        'account_id': accountId,
        'payment_method': paymentMethod,
        'note': note,
        'created_at': now,
      });

      // 2. Decrease customer balance
      await txn.rawUpdate(
        '''
      UPDATE customers
      SET balance = balance - ?
      WHERE id = ?
      ''',
        [amount, customerId],
      );

      // 3. Increase account balance
      await txn.rawUpdate(
        '''
      UPDATE accounts
      SET balance = balance + ?
      WHERE id = ?
      ''',
        [amount, accountId],
      );

      // 4. Add account ledger transaction
      final transaction = AccountTransaction(
        accountId: accountId,
        transactionType: 'CUSTOMER_PAYMENT',
        referenceType: 'CUSTOMER_PAYMENT',
        referenceId: id,
        voucherNo: voucherNo,
        debit: 0,
        credit: amount,
        transactionDate: now,
        note: note.isNotEmpty ? note : 'Customer Payment',
        createdAt: now,
      );

      await txn.insert('account_transactions', transaction.toMap());

      // ------------------------------------------------------
      // 5. FF CENTRAL JOURNAL
      //
      // Dr Cash / Bank / MFS
      // Cr Customer Receivable
      // ------------------------------------------------------

      await _ffPartyPaymentPostingService.postCustomerCollectionWithExecutor(
        txn,
        paymentId: id,
        customerId: customerId,
        accountId: accountId,
        amount: amount,
        voucherNo: voucherNo,
        transactionDate: now,
        note: note,
      );

      return id;
    });

    // 5. Refresh dashboard/accounts/ledger
    RefreshService.notify();

    return paymentId;
  }

  Future<bool> customerNameExists(String name) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'customers',
      where: 'LOWER(name) = ?',
      whereArgs: [name.toLowerCase()],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<bool> customerNameExistsForUpdate({
    required String name,
    required int customerId,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'customers',
      where: 'LOWER(name) = ? AND id != ?',
      whereArgs: [name.toLowerCase(), customerId],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<bool> customerExists(String name, {int? ignoreId}) async {
    final db = await _databaseHelper.database;

    String where = 'LOWER(name) = ?';

    final List<Object?> args = [name.toLowerCase()];

    if (ignoreId != null) {
      where += ' AND id != ?';
      args.add(ignoreId);
    }

    final result = await db.query(
      'customers',
      where: where,
      whereArgs: args,
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<double> getTotalDue() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT
        COALESCE(
          SUM(
            COALESCE(c.opening_balance, 0)
            +
            COALESCE(
              (
                SELECT SUM(s.grand_total)
                FROM sales s
                WHERE s.customer_id = c.id
              ),
              0
            )
            -
            COALESCE(
              (
                SELECT SUM(cp.amount)
                FROM customer_payments cp
                WHERE cp.customer_id = c.id
              ),
              0
            )
          ),
          0
        ) AS total
      FROM customers c
      ''');

    return ((result.first['total'] ?? 0) as num).toDouble();
  }

  // ============================================================
  // CUSTOMER LEDGER
  // ============================================================

  Future<List<CustomerLedger>> getCustomerLedger(int customerId) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        opening_date AS date,
        'Opening Balance' AS particular,
        'OPENING' AS reference,
        CASE
          WHEN COALESCE(opening_balance, 0) >= 0
            THEN COALESCE(opening_balance, 0)
          ELSE 0.0
        END AS debit,
        CASE
          WHEN COALESCE(opening_balance, 0) < 0
            THEN ABS(opening_balance)
          ELSE 0.0
        END AS credit,
        0 AS sort_order
      FROM customers
      WHERE id = ?

      UNION ALL

      SELECT
        sale_date AS date,
        'Sale' AS particular,
        invoice_no AS reference,
        grand_total AS debit,
        0.0 AS credit,
        1 AS sort_order
      FROM sales
      WHERE customer_id = ?

      UNION ALL

      SELECT
        created_at AS date,
        'Payment' AS particular,
        voucher_no AS reference,
        0.0 AS debit,
        amount AS credit,
        1 AS sort_order
      FROM customer_payments
      WHERE customer_id = ?

      ORDER BY sort_order ASC, date ASC
      ''',
      [customerId, customerId, customerId],
    );

    return result.map((e) => CustomerLedger.fromMap(e)).toList();
  }

  Future<String> getNextCustomerPaymentVoucherNo() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
    SELECT voucher_no
    FROM customer_payments
    WHERE voucher_no LIKE 'CP#%'
    ORDER BY id DESC
    LIMIT 1
  ''');

    if (result.isEmpty) {
      return 'CP#1';
    }

    final lastVoucher = result.first['voucher_no']?.toString() ?? '';

    final number = int.tryParse(lastVoucher.replaceFirst('CP#', '')) ?? 0;

    return 'CP#${number + 1}';
  }

  Future<double> getCustomerBalanceBeforeSale({
    required int customerId,
    required int saleId,
  }) async {
    final db = await _databaseHelper.database;

    final saleResult = await db.query(
      'sales',
      columns: ['sale_date'],
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );

    if (saleResult.isEmpty) {
      return 0;
    }

    final saleDate = saleResult.first['sale_date'].toString();

    final result = await db.rawQuery(
      '''
    SELECT
      (
        SELECT IFNULL(opening_balance, 0)
        FROM customers
        WHERE id = ?
      )
      +
      (
        SELECT IFNULL(SUM(grand_total), 0)
        FROM sales
        WHERE customer_id = ?
          AND (
            sale_date < ?
            OR (
              sale_date = ?
              AND id < ?
            )
          )
      )
      -
      (
        SELECT IFNULL(SUM(amount), 0)
        FROM customer_payments
        WHERE customer_id = ?
          AND created_at < ?
      ) AS balance
    ''',
      [
        customerId,
        customerId,
        saleDate,
        saleDate,
        saleId,
        customerId,
        saleDate,
      ],
    );

    if (result.isEmpty) {
      return 0;
    }

    return (result.first['balance'] as num?)?.toDouble() ?? 0;
  }
}
