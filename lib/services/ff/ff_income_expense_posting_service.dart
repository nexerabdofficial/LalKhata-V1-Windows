import 'package:sqflite/sqflite.dart';

import 'ff_journal_models.dart';
import 'ff_journal_service.dart';
import 'ff_system_accounts.dart';

class FFIncomeExpensePostingService {
  FFIncomeExpensePostingService._();

  static final FFIncomeExpensePostingService instance =
      FFIncomeExpensePostingService._();

  final FFJournalService _journalService = FFJournalService.instance;

  // ============================================================
  // INCOME
  //
  // Dr Cash / Bank / MFS
  // Cr Other Income
  // ============================================================

  Future<int> postIncomeWithExecutor(
    DatabaseExecutor db, {
    required int incomeId,
    required int accountId,
    required double amount,
    required String voucherNo,
    required String transactionDate,
    required String category,
    String note = '',
  }) async {
    if (incomeId <= 0) {
      throw ArgumentError('Invalid income ID.');
    }

    if (accountId <= 0) {
      throw ArgumentError('Invalid income receipt account.');
    }

    if (amount <= 0) {
      throw ArgumentError('Income amount must be greater than zero.');
    }

    final incomeAccountId = await _resolveSystemAccountId(
      db,
      FFSystemGroupCodes.otherIncome,
    );

    return _journalService.createJournalWithExecutor(
      db,
      FFJournalEntry(
        transactionType: 'INCOME',
        voucherNo: voucherNo,
        transactionDate: transactionDate,
        referenceType: 'INCOME',
        referenceId: incomeId,
        description: category.trim().isNotEmpty
            ? category.trim()
            : 'Other Income',
        createdAt: DateTime.now().toIso8601String(),
        lines: [
          FFJournalLine(
            accountId: accountId,
            debit: amount,
            credit: 0,
            note: note.trim().isNotEmpty ? note.trim() : category,
          ),
          FFJournalLine(
            accountId: incomeAccountId,
            debit: 0,
            credit: amount,
            note: category.trim().isNotEmpty ? category.trim() : 'Other Income',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXPENSE
  //
  // Dr Operating Expense
  // Cr Cash / Bank / MFS
  // ============================================================

  Future<int> postExpenseWithExecutor(
    DatabaseExecutor db, {
    required int expenseId,
    required int accountId,
    required double amount,
    required String voucherNo,
    required String transactionDate,
    required String category,
    String note = '',
  }) async {
    if (expenseId <= 0) {
      throw ArgumentError('Invalid expense ID.');
    }

    if (accountId <= 0) {
      throw ArgumentError('Invalid expense payment account.');
    }

    if (amount <= 0) {
      throw ArgumentError('Expense amount must be greater than zero.');
    }

    final expenseAccountId = await _resolveSystemAccountId(
      db,
      FFSystemGroupCodes.operatingExpense,
    );

    return _journalService.createJournalWithExecutor(
      db,
      FFJournalEntry(
        transactionType: 'EXPENSE',
        voucherNo: voucherNo,
        transactionDate: transactionDate,
        referenceType: 'EXPENSE',
        referenceId: expenseId,
        description: category.trim().isNotEmpty
            ? category.trim()
            : 'Operating Expense',
        createdAt: DateTime.now().toIso8601String(),
        lines: [
          FFJournalLine(
            accountId: expenseAccountId,
            debit: amount,
            credit: 0,
            note: category.trim().isNotEmpty
                ? category.trim()
                : 'Operating Expense',
          ),
          FFJournalLine(
            accountId: accountId,
            debit: 0,
            credit: amount,
            note: note.trim().isNotEmpty ? note.trim() : category,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SYSTEM ACCOUNT RESOLVER
  //
  // Here group code == system account type for these
  // system-controlled accounts.
  // ============================================================

  Future<int> _resolveSystemAccountId(
    DatabaseExecutor db,
    String accountType,
  ) async {
    final rows = await db.query(
      'accounts',
      columns: ['id'],
      where: 'type = ?',
      whereArgs: [accountType],
      orderBy: 'id ASC',
      limit: 1,
    );

    if (rows.isEmpty) {
      // Income/Expense groups existed from the first FF seed,
      // but their matching system ledgers may not yet exist.
      final groupRows = await db.query(
        'ff_account_groups',
        columns: ['id', 'name'],
        where: 'group_code = ?',
        whereArgs: [accountType],
        limit: 1,
      );

      if (groupRows.isEmpty) {
        throw StateError('FF account group not found: $accountType');
      }

      final groupId = (groupRows.first['id'] as num).toInt();

      final groupName = groupRows.first['name']?.toString() ?? accountType;

      final newAccountId = await db.insert('accounts', {
        'name': groupName,
        'type': accountType,
        'balance': 0.0,
        'opening_balance': 0.0,
        'opening_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);

      await db.insert('ff_account_links', {
        'account_id': newAccountId,
        'group_id': groupId,
        'is_primary': 1,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      return newAccountId;
    }

    return (rows.first['id'] as num).toInt();
  }
}
