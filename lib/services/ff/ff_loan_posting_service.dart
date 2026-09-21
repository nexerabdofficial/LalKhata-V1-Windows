import 'package:sqflite/sqflite.dart';

import 'ff_journal_models.dart';
import 'ff_journal_service.dart';
import 'ff_system_accounts.dart';

class FFLoanPostingService {
  FFLoanPostingService._();

  static final FFLoanPostingService instance = FFLoanPostingService._();

  final FFJournalService _journalService = FFJournalService.instance;

  Future<int> _resolveSystemAccountId(
    DatabaseExecutor db,
    String groupCode,
  ) async {
    final existing = await db.query(
      'accounts',
      columns: ['id'],
      where: 'type = ?',
      whereArgs: [groupCode],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return (existing.first['id'] as num).toInt();
    }

    final groups = await db.query(
      'ff_account_groups',
      columns: ['id', 'name'],
      where: 'group_code = ?',
      whereArgs: [groupCode],
      limit: 1,
    );

    if (groups.isEmpty) {
      throw StateError('FF account group not found: $groupCode');
    }

    final groupId = (groups.first['id'] as num).toInt();

    final groupName = groups.first['name'] as String;

    final now = DateTime.now().toIso8601String();

    final accountId = await db.insert('accounts', {
      'name': groupName,
      'type': groupCode,
      'balance': 0.0,
      'opening_balance': 0.0,
      'opening_date': now,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.abort);

    await db.insert('ff_account_links', {
      'account_id': accountId,
      'group_id': groupId,
      'is_primary': 1,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    return accountId;
  }

  Future<void> postLoanWithExecutor(
    DatabaseExecutor db, {
    required int loanId,
    required String loanType,
    required int accountId,
    required double principalAmount,
    required String transactionDate,
    String? note,
  }) async {
    if (principalAmount <= 0) {
      throw ArgumentError('Loan principal must be greater than zero.');
    }

    final type = loanType.toUpperCase();

    if (type != 'GIVEN' && type != 'TAKEN') {
      throw ArgumentError('Invalid loan type.');
    }

    final voucherNo = 'LOAN-${loanId.toString().padLeft(6, '0')}';

    final lines = <FFJournalLine>[];

    if (type == 'GIVEN') {
      final loanReceivableId = await _resolveSystemAccountId(
        db,
        FFSystemGroupCodes.loanReceivable,
      );

      lines.addAll([
        FFJournalLine(
          accountId: loanReceivableId,
          entityType: 'LOAN',
          entityId: loanId,
          debit: principalAmount,
          credit: 0,
          note: note,
        ),
        FFJournalLine(
          accountId: accountId,
          debit: 0,
          credit: principalAmount,
          note: note,
        ),
      ]);
    } else {
      final loanPayableId = await _resolveSystemAccountId(
        db,
        FFSystemGroupCodes.loanPayable,
      );

      lines.addAll([
        FFJournalLine(
          accountId: accountId,
          debit: principalAmount,
          credit: 0,
          note: note,
        ),
        FFJournalLine(
          accountId: loanPayableId,
          entityType: 'LOAN',
          entityId: loanId,
          debit: 0,
          credit: principalAmount,
          note: note,
        ),
      ]);
    }

    await _journalService.createJournalWithExecutor(
      db,
      FFJournalEntry(
        transactionType: type == 'GIVEN' ? 'LOAN_GIVEN' : 'LOAN_TAKEN',
        voucherNo: voucherNo,
        transactionDate: transactionDate,
        referenceType: 'LOAN',
        referenceId: loanId,
        description: (note ?? '').trim().isNotEmpty
            ? (note ?? '').trim()
            : (type == 'GIVEN' ? 'Loan Given' : 'Loan Taken'),
        createdAt: DateTime.now().toIso8601String(),
        lines: lines,
      ),
    );
  }

  Future<void> postLoanPaymentWithExecutor(
    DatabaseExecutor db, {
    required int paymentId,
    required int loanId,
    required bool isGiven,
    required int accountId,
    required double totalAmount,
    required double principalAmount,
    required double interestAmount,
    required String voucherNo,
    required String transactionDate,
    String? note,
  }) async {
    final lines = <FFJournalLine>[];

    if (isGiven) {
      final loanReceivableId = await _resolveSystemAccountId(
        db,
        FFSystemGroupCodes.loanReceivable,
      );

      lines.add(
        FFJournalLine(
          accountId: accountId,
          debit: totalAmount,
          credit: 0,
          note: note,
        ),
      );

      if (principalAmount > 0) {
        lines.add(
          FFJournalLine(
            accountId: loanReceivableId,
            entityType: 'LOAN',
            entityId: loanId,
            debit: 0,
            credit: principalAmount,
            note: 'Loan principal collection',
          ),
        );
      }

      if (interestAmount > 0) {
        final incomeId = await _resolveSystemAccountId(
          db,
          FFSystemGroupCodes.otherIncome,
        );

        lines.add(
          FFJournalLine(
            accountId: incomeId,
            debit: 0,
            credit: interestAmount,
            note: 'Loan interest income',
          ),
        );
      }
    } else {
      final loanPayableId = await _resolveSystemAccountId(
        db,
        FFSystemGroupCodes.loanPayable,
      );

      if (principalAmount > 0) {
        lines.add(
          FFJournalLine(
            accountId: loanPayableId,
            entityType: 'LOAN',
            entityId: loanId,
            debit: principalAmount,
            credit: 0,
            note: 'Loan principal repayment',
          ),
        );
      }

      if (interestAmount > 0) {
        final expenseId = await _resolveSystemAccountId(
          db,
          FFSystemGroupCodes.operatingExpense,
        );

        lines.add(
          FFJournalLine(
            accountId: expenseId,
            debit: interestAmount,
            credit: 0,
            note: 'Loan interest expense',
          ),
        );
      }

      lines.add(
        FFJournalLine(
          accountId: accountId,
          debit: 0,
          credit: totalAmount,
          note: note,
        ),
      );
    }

    await _journalService.createJournalWithExecutor(
      db,
      FFJournalEntry(
        transactionType: isGiven ? 'LOAN_COLLECTION' : 'LOAN_REPAYMENT',
        voucherNo: voucherNo,
        transactionDate: transactionDate,
        referenceType: 'LOAN_PAYMENT',
        referenceId: paymentId,
        description: (note ?? '').trim().isNotEmpty
            ? (note ?? '').trim()
            : (isGiven ? 'Loan Collection' : 'Loan Repayment'),
        createdAt: DateTime.now().toIso8601String(),
        lines: lines,
      ),
    );
  }
}
