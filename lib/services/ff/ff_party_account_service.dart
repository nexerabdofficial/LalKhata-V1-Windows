import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import 'ff_system_accounts.dart';

class FFPartyAccountService {
  FFPartyAccountService._();

  static final FFPartyAccountService instance = FFPartyAccountService._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // ============================================================
  // ENSURE CUSTOMER LEDGER
  // ============================================================

  Future<int> ensureCustomerAccount(int customerId) async {
    final db = await _databaseHelper.database;

    return db.transaction(
      (txn) => ensureCustomerAccountWithExecutor(txn, customerId),
    );
  }

  Future<int> ensureCustomerAccountWithExecutor(
    DatabaseExecutor db,
    int customerId,
  ) async {
    final existing = await _findLinkedAccount(
      db,
      partyType: 'CUSTOMER',
      partyId: customerId,
    );

    if (existing != null) {
      return existing;
    }

    final rows = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Customer not found: $customerId');
    }

    final row = rows.first;

    return _createPartyAccount(
      db,
      partyType: 'CUSTOMER',
      partyId: customerId,
      name: row['name']?.toString() ?? 'Customer $customerId',
      accountType: 'CUSTOMER',
      openingBalance: ((row['opening_balance'] ?? 0) as num).toDouble(),
      openingDate: row['opening_date']?.toString() ?? '',
      groupCode: FFSystemGroupCodes.customerReceivable,
    );
  }

  // ============================================================
  // ENSURE SUPPLIER LEDGER
  // ============================================================

  Future<int> ensureSupplierAccount(int supplierId) async {
    final db = await _databaseHelper.database;

    return db.transaction(
      (txn) => ensureSupplierAccountWithExecutor(txn, supplierId),
    );
  }

  Future<int> ensureSupplierAccountWithExecutor(
    DatabaseExecutor db,
    int supplierId,
  ) async {
    final existing = await _findLinkedAccount(
      db,
      partyType: 'SUPPLIER',
      partyId: supplierId,
    );

    if (existing != null) {
      return existing;
    }

    final rows = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [supplierId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Supplier not found: $supplierId');
    }

    final row = rows.first;

    return _createPartyAccount(
      db,
      partyType: 'SUPPLIER',
      partyId: supplierId,
      name: row['name']?.toString() ?? 'Supplier $supplierId',
      accountType: 'SUPPLIER',
      openingBalance: ((row['opening_balance'] ?? 0) as num).toDouble(),
      openingDate: row['opening_date']?.toString() ?? '',
      groupCode: FFSystemGroupCodes.supplierPayable,
    );
  }

  // ============================================================
  // RESOLVE
  // ============================================================

  Future<int?> getCustomerAccountId(
    int customerId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _databaseHelper.database;

    return _findLinkedAccount(db, partyType: 'CUSTOMER', partyId: customerId);
  }

  Future<int?> getSupplierAccountId(
    int supplierId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _databaseHelper.database;

    return _findLinkedAccount(db, partyType: 'SUPPLIER', partyId: supplierId);
  }

  // ============================================================
  // SYNC CUSTOMER
  // ============================================================

  Future<void> syncCustomerAccountWithExecutor(
    DatabaseExecutor db,
    int customerId,
  ) async {
    final accountId = await ensureCustomerAccountWithExecutor(db, customerId);

    final rows = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return;
    }

    final row = rows.first;

    await db.update(
      'accounts',
      {
        'name': row['name']?.toString() ?? 'Customer $customerId',
        'opening_balance': ((row['opening_balance'] ?? 0) as num).toDouble(),
        'opening_date': row['opening_date']?.toString() ?? '',
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  // ============================================================
  // SYNC SUPPLIER
  // ============================================================

  Future<void> syncSupplierAccountWithExecutor(
    DatabaseExecutor db,
    int supplierId,
  ) async {
    final accountId = await ensureSupplierAccountWithExecutor(db, supplierId);

    final rows = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [supplierId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return;
    }

    final row = rows.first;

    await db.update(
      'accounts',
      {
        'name': row['name']?.toString() ?? 'Supplier $supplierId',
        'opening_balance': ((row['opening_balance'] ?? 0) as num).toDouble(),
        'opening_date': row['opening_date']?.toString() ?? '',
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  // ============================================================
  // BACKFILL
  // ============================================================

  Future<void> backfillAll() async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      final customers = await txn.query('customers', columns: ['id']);

      for (final row in customers) {
        final id = (row['id'] as num).toInt();

        await ensureCustomerAccountWithExecutor(txn, id);
      }

      final suppliers = await txn.query('suppliers', columns: ['id']);

      for (final row in suppliers) {
        final id = (row['id'] as num).toInt();

        await ensureSupplierAccountWithExecutor(txn, id);
      }
    });
  }

  // ============================================================
  // INTERNAL
  // ============================================================

  Future<int?> _findLinkedAccount(
    DatabaseExecutor db, {
    required String partyType,
    required int partyId,
  }) async {
    final rows = await db.query(
      'ff_party_account_links',
      columns: ['account_id'],
      where: 'party_type = ? AND party_id = ?',
      whereArgs: [partyType, partyId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return (rows.first['account_id'] as num).toInt();
  }

  Future<int> _createPartyAccount(
    DatabaseExecutor db, {
    required String partyType,
    required int partyId,
    required String name,
    required String accountType,
    required double openingBalance,
    required String openingDate,
    required String groupCode,
  }) async {
    final existing = await _findLinkedAccount(
      db,
      partyType: partyType,
      partyId: partyId,
    );

    if (existing != null) {
      return existing;
    }

    final groupRows = await db.query(
      'ff_account_groups',
      columns: ['id'],
      where: 'group_code = ?',
      whereArgs: [groupCode],
      limit: 1,
    );

    if (groupRows.isEmpty) {
      throw StateError('FF account group not found: $groupCode');
    }

    final groupId = (groupRows.first['id'] as num).toInt();

    final now = DateTime.now().toIso8601String();

    final accountId = await db.insert('accounts', {
      'name': name.trim(),
      'type': accountType,
      'opening_balance': openingBalance,
      'opening_date': openingDate,
      'balance': openingBalance,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.abort);

    await db.insert('ff_account_links', {
      'account_id': accountId,
      'group_id': groupId,
      'is_primary': 1,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.abort);

    await db.insert('ff_party_account_links', {
      'party_type': partyType,
      'party_id': partyId,
      'account_id': accountId,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.abort);

    return accountId;
  }
}
