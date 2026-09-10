import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/account.dart';

class AccountRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // ============================================================
  // CREATE ACCOUNT
  // ============================================================

  Future<int> insertAccount(Account account) async {
    final Database db = await _databaseHelper.database;

    final id = await db.insert(
      'accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Keep stored balance synchronized.
    await refreshStoredBalance(id);

    return id;
  }

  // ============================================================
  // GET ACCOUNTS
  // ============================================================

  Future<List<Account>> getAccounts() async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'accounts',
      orderBy: 'name ASC',
    );

    final List<Account> accounts = [];

    for (final map in maps) {
      final account = Account.fromMap(map);

      final balance = await _calculateLedgerBalance(
        account.id!,
      );

      accounts.add(
        Account(
          id: account.id,
          name: account.name,
          type: account.type,
          balance: balance,
          openingBalance: account.openingBalance,
          openingDate: account.openingDate,
          createdAt: account.createdAt,
        ),
      );
    }

    return accounts;
  }

  // ============================================================
  // GET SINGLE ACCOUNT
  // ============================================================

  Future<Account?> getAccountById(int id) async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    final account = Account.fromMap(maps.first);

    final balance = await _calculateLedgerBalance(id);

    return Account(
      id: account.id,
      name: account.name,
      type: account.type,
      balance: balance,
      openingBalance: account.openingBalance,
      openingDate: account.openingDate,
      createdAt: account.createdAt,
    );
  }

  // ============================================================
  // CALCULATE ACCOUNT BALANCE
  //
  // Account balance rule:
  //
  // Opening Balance
  // + Credit
  // - Debit
  //
  // Example:
  //
  // Bank opening = 1000
  // Supplier payment = Debit 50
  //
  // Bank balance = 950
  //
  // Money received = Credit 50
  //
  // Bank balance = 1050
  //
  // OPENING_BALANCE transactions are ignored because
  // opening_balance is already stored in accounts table.
  // ============================================================

  Future<double> _calculateLedgerBalance(
    int accountId,
  ) async {
    final Database db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(
          (
            SELECT opening_balance
            FROM accounts
            WHERE id = ?
          ),
          0
        )
        +
        COALESCE(
          (
            SELECT SUM(
              COALESCE(credit, 0)
              -
              COALESCE(debit, 0)
            )
            FROM account_transactions
            WHERE account_id = ?
            AND transaction_type NOT IN (
              'OPENING_BALANCE',
              'OPENING'
            )
          ),
          0
        ) AS balance
      ''',
      [
        accountId,
        accountId,
      ],
    );

    final value = result.first['balance'];

    if (value == null) {
      return 0.0;
    }

    return (value as num).toDouble();
  }

  // ============================================================
  // PUBLIC ACCOUNT BALANCE
  // ============================================================

  Future<double> getAccountBalance(
    int accountId,
  ) async {
    return await _calculateLedgerBalance(accountId);
  }

  // ============================================================
  // LEGACY BALANCE METHODS
  //
  // DO NOT manually change account balance.
  //
  // The account balance is calculated from the ledger.
  // These methods remain only for compatibility with older code.
  // ============================================================

  Future<void> updateBalance({
    required int accountId,
    required double amount,
    required bool isReceive,
  }) async {
    // Intentionally empty.
    //
    // Actual balance comes from account_transactions.
  }

  Future<void> addBalance(
    int accountId,
    double amount,
  ) async {
    // Intentionally empty.
  }

  Future<void> increaseBalance({
    required int accountId,
    required double amount,
  }) async {
    // Intentionally empty.
  }

  Future<void> decreaseBalance({
    required int accountId,
    required double amount,
  }) async {
    // Intentionally empty.
    //
    // IMPORTANT:
    // Do NOT manually subtract supplier payment here.
    //
    // PaySupplierScreen creates:
    //
    // debit = payment amount
    // credit = 0
    //
    // That transaction automatically reduces the account balance.
  }

  // ============================================================
  // UPDATE ACCOUNT
  // ============================================================

  Future<int> updateAccount(
    Account account,
  ) async {
    final Database db = await _databaseHelper.database;

    final result = await db.update(
      'accounts',
      {
        'name': account.name,
        'type': account.type,
        'opening_balance': account.openingBalance,
        'opening_date': account.openingDate,
        'created_at': account.createdAt,
      },
      where: 'id = ?',
      whereArgs: [account.id],
    );

    if (account.id != null) {
      await refreshStoredBalance(account.id!);
    }

    return result;
  }

  // ============================================================
  // DELETE ACCOUNT
  // ============================================================

  Future<int> deleteAccount(
    int id,
  ) async {
    final Database db = await _databaseHelper.database;

    return await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // ACCOUNT NAME CHECK
  // ============================================================

  Future<bool> accountNameExists(
    String name,
  ) async {
    final Database db = await _databaseHelper.database;

    final result = await db.query(
      'accounts',
      where: 'LOWER(name) = ?',
      whereArgs: [
        name.toLowerCase(),
      ],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<bool> accountNameExistsForUpdate({
    required String name,
    required int accountId,
  }) async {
    final Database db = await _databaseHelper.database;

    final result = await db.query(
      'accounts',
      where: 'LOWER(name) = ? AND id != ?',
      whereArgs: [
        name.toLowerCase(),
        accountId,
      ],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // ============================================================
  // TOTAL BALANCE
  //
  // Total =
  // All account opening balances
  // + all credits
  // - all debits
  // ============================================================

  Future<double> getTotalBalance() async {
    final Database db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(
          (
            SELECT SUM(
              COALESCE(opening_balance, 0)
            )
            FROM accounts
          ),
          0
        )
        +
        COALESCE(
          (
            SELECT SUM(
              COALESCE(credit, 0)
              -
              COALESCE(debit, 0)
            )
            FROM account_transactions
            WHERE transaction_type NOT IN (
              'OPENING_BALANCE',
              'OPENING'
            )
          ),
          0
        ) AS total
      ''',
    );

    final value = result.first['total'];

    if (value == null) {
      return 0.0;
    }

    return (value as num).toDouble();
  }

  // ============================================================
  // BALANCE BY ACCOUNT TYPE
  // ============================================================

  Future<double> getBalanceByType(
    String type,
  ) async {
    final Database db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(
          (
            SELECT SUM(
              COALESCE(opening_balance, 0)
            )
            FROM accounts
            WHERE type = ?
          ),
          0
        )
        +
        COALESCE(
          (
            SELECT SUM(
              COALESCE(at.credit, 0)
              -
              COALESCE(at.debit, 0)
            )
            FROM account_transactions at
            INNER JOIN accounts a
              ON a.id = at.account_id
            WHERE a.type = ?
            AND at.transaction_type NOT IN (
              'OPENING_BALANCE',
              'OPENING'
            )
          ),
          0
        ) AS total
      ''',
      [
        type,
        type,
      ],
    );

    final value = result.first['total'];

    if (value == null) {
      return 0.0;
    }

    return (value as num).toDouble();
  }

  // ============================================================
  // REFRESH STORED BALANCE
  //
  // The UI should use calculated balance.
  //
  // This method only keeps accounts.balance synchronized
  // for old modules that may still read the stored column.
  // ============================================================

  Future<void> refreshStoredBalance(
    int accountId,
  ) async {
    final Database db = await _databaseHelper.database;

    final balance = await _calculateLedgerBalance(
      accountId,
    );

    await db.update(
      'accounts',
      {
        'balance': balance,
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  // ============================================================
  // REFRESH ALL STORED BALANCES
  // ============================================================

  Future<void> refreshAllStoredBalances() async {
    final Database db = await _databaseHelper.database;

    final accounts = await db.query(
      'accounts',
      columns: ['id'],
    );

    for (final account in accounts) {
      final rawId = account['id'];

      if (rawId == null) {
        continue;
      }

      final id = rawId is int
          ? rawId
          : int.tryParse(rawId.toString());

      if (id == null) {
        continue;
      }

      final balance = await _calculateLedgerBalance(id);

      await db.update(
        'accounts',
        {
          'balance': balance,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}