import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import 'ff_journal_models.dart';
import 'ff_journal_service.dart';

class FFReceivePaymentService {
  FFReceivePaymentService._();

  static final FFReceivePaymentService instance = FFReceivePaymentService._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final FFJournalService _journalService = FFJournalService.instance;

  // ============================================================
  // RECEIVE
  //
  // Dr Cash / Bank / MFS
  // Cr Selected Ledger
  //
  // If selected ledger is CUSTOMER:
  // also save customer_payments for legacy compatibility.
  // ============================================================

  Future<int> receive({
    required int receivingAccountId,
    required int ledgerAccountId,
    required double amount,
    required String voucherNo,
    required String transactionDate,
    String note = '',
  }) async {
    final db = await _databaseHelper.database;

    return db.transaction((txn) async {
      await _validate(
        txn,
        cashAccountId: receivingAccountId,
        ledgerAccountId: ledgerAccountId,
        amount: amount,
      );

      final party = await _getPartyLink(txn, ledgerAccountId);

      int? paymentId;

      if (party?.partyType == 'CUSTOMER') {
        paymentId = await txn.insert('customer_payments', {
          'customer_id': party!.partyId,
          'voucher_no': voucherNo,
          'amount': amount,
          'account_id': receivingAccountId,
          'payment_method': await _paymentMethod(txn, receivingAccountId),
          'note': note,
          'created_at': transactionDate,
        }, conflictAlgorithm: ConflictAlgorithm.abort);

        await txn.rawUpdate(
          '''
          UPDATE customers
          SET balance = balance - ?
          WHERE id = ?
          ''',
          [amount, party.partyId],
        );

        await _insertLegacyAccountTransaction(
          txn,
          accountId: receivingAccountId,
          transactionType: 'CUSTOMER_PAYMENT',
          referenceType: 'CUSTOMER_PAYMENT',
          referenceId: paymentId,
          voucherNo: voucherNo,
          debit: 0,
          credit: amount,
          transactionDate: transactionDate,
          note: note.trim().isEmpty ? 'Customer Payment' : note.trim(),
        );
      }

      return _createReceiveJournal(
        txn,
        receivingAccountId: receivingAccountId,
        ledgerAccountId: ledgerAccountId,
        amount: amount,
        voucherNo: voucherNo,
        transactionDate: transactionDate,
        referenceType: paymentId == null ? 'RECEIVE' : 'CUSTOMER_PAYMENT',
        referenceId: paymentId,
        note: note,
      );
    });
  }

  // ============================================================
  // PAYMENT
  //
  // Dr Selected Ledger
  // Cr Cash / Bank / MFS
  //
  // If selected ledger is SUPPLIER:
  // also save supplier_payments for legacy compatibility.
  // ============================================================

  Future<int> payment({
    required int payingAccountId,
    required int ledgerAccountId,
    required double amount,
    required String voucherNo,
    required String transactionDate,
    String note = '',
  }) async {
    final db = await _databaseHelper.database;

    return db.transaction((txn) async {
      await _validate(
        txn,
        cashAccountId: payingAccountId,
        ledgerAccountId: ledgerAccountId,
        amount: amount,
      );

      final party = await _getPartyLink(txn, ledgerAccountId);

      int? paymentId;

      if (party?.partyType == 'SUPPLIER') {
        paymentId = await txn.insert('supplier_payments', {
          'supplier_id': party!.partyId,
          'purchase_id': null,
          'voucher_no': voucherNo,
          'amount': amount,
          'account_id': payingAccountId,
          'payment_method': await _paymentMethod(txn, payingAccountId),
          'note': note,
          'created_at': transactionDate,
        }, conflictAlgorithm: ConflictAlgorithm.abort);

        await _insertLegacyAccountTransaction(
          txn,
          accountId: payingAccountId,
          transactionType: 'SUPPLIER_PAYMENT',
          referenceType: 'SUPPLIER_PAYMENT',
          referenceId: paymentId,
          voucherNo: voucherNo,
          debit: amount,
          credit: 0,
          transactionDate: transactionDate,
          note: note.trim().isEmpty ? 'Supplier Payment' : note.trim(),
        );
      }

      return _createPaymentJournal(
        txn,
        payingAccountId: payingAccountId,
        ledgerAccountId: ledgerAccountId,
        amount: amount,
        voucherNo: voucherNo,
        transactionDate: transactionDate,
        referenceType: paymentId == null ? 'PAYMENT' : 'SUPPLIER_PAYMENT',
        referenceId: paymentId,
        note: note,
      );
    });
  }

  // ============================================================
  // EXECUTOR RECEIVE
  // Pure FF version for internal atomic workflows.
  // ============================================================

  Future<int> receiveWithExecutor(
    DatabaseExecutor db, {
    required int receivingAccountId,
    required int ledgerAccountId,
    required double amount,
    required String voucherNo,
    required String transactionDate,
    String? referenceType,
    int? referenceId,
    String note = '',
  }) async {
    await _validate(
      db,
      cashAccountId: receivingAccountId,
      ledgerAccountId: ledgerAccountId,
      amount: amount,
    );

    return _createReceiveJournal(
      db,
      receivingAccountId: receivingAccountId,
      ledgerAccountId: ledgerAccountId,
      amount: amount,
      voucherNo: voucherNo,
      transactionDate: transactionDate,
      referenceType: referenceType ?? 'RECEIVE',
      referenceId: referenceId,
      note: note,
    );
  }

  // ============================================================
  // EXECUTOR PAYMENT
  // Pure FF version for internal atomic workflows.
  // ============================================================

  Future<int> paymentWithExecutor(
    DatabaseExecutor db, {
    required int payingAccountId,
    required int ledgerAccountId,
    required double amount,
    required String voucherNo,
    required String transactionDate,
    String? referenceType,
    int? referenceId,
    String note = '',
  }) async {
    await _validate(
      db,
      cashAccountId: payingAccountId,
      ledgerAccountId: ledgerAccountId,
      amount: amount,
    );

    return _createPaymentJournal(
      db,
      payingAccountId: payingAccountId,
      ledgerAccountId: ledgerAccountId,
      amount: amount,
      voucherNo: voucherNo,
      transactionDate: transactionDate,
      referenceType: referenceType ?? 'PAYMENT',
      referenceId: referenceId,
      note: note,
    );
  }

  // ============================================================
  // JOURNAL BUILDERS
  // ============================================================

  Future<int> _createReceiveJournal(
    DatabaseExecutor db, {
    required int receivingAccountId,
    required int ledgerAccountId,
    required double amount,
    required String voucherNo,
    required String transactionDate,
    required String referenceType,
    int? referenceId,
    required String note,
  }) {
    return _journalService.createJournalWithExecutor(
      db,
      FFJournalEntry(
        transactionType: 'RECEIVE',
        voucherNo: voucherNo,
        transactionDate: transactionDate,
        referenceType: referenceType,
        referenceId: referenceId,
        description: note.trim().isEmpty ? 'Receive' : note.trim(),
        createdAt: DateTime.now().toIso8601String(),
        lines: [
          FFJournalLine(
            accountId: receivingAccountId,
            debit: amount,
            credit: 0,
            note: note.trim().isEmpty ? 'Money received' : note.trim(),
          ),
          FFJournalLine(
            accountId: ledgerAccountId,
            debit: 0,
            credit: amount,
            note: note.trim().isEmpty ? 'Receive against ledger' : note.trim(),
          ),
        ],
      ),
    );
  }

  Future<int> _createPaymentJournal(
    DatabaseExecutor db, {
    required int payingAccountId,
    required int ledgerAccountId,
    required double amount,
    required String voucherNo,
    required String transactionDate,
    required String referenceType,
    int? referenceId,
    required String note,
  }) {
    return _journalService.createJournalWithExecutor(
      db,
      FFJournalEntry(
        transactionType: 'PAYMENT',
        voucherNo: voucherNo,
        transactionDate: transactionDate,
        referenceType: referenceType,
        referenceId: referenceId,
        description: note.trim().isEmpty ? 'Payment' : note.trim(),
        createdAt: DateTime.now().toIso8601String(),
        lines: [
          FFJournalLine(
            accountId: ledgerAccountId,
            debit: amount,
            credit: 0,
            note: note.trim().isEmpty ? 'Payment against ledger' : note.trim(),
          ),
          FFJournalLine(
            accountId: payingAccountId,
            debit: 0,
            credit: amount,
            note: note.trim().isEmpty ? 'Money paid' : note.trim(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NEXT VOUCHER
  // ============================================================

  Future<String> getNextReceiveVoucherNo() {
    return _getNextVoucher(prefix: 'RV#', transactionType: 'RECEIVE');
  }

  Future<String> getNextPaymentVoucherNo() {
    return _getNextVoucher(prefix: 'PV#', transactionType: 'PAYMENT');
  }

  Future<String> _getNextVoucher({
    required String prefix,
    required String transactionType,
  }) async {
    final db = await _databaseHelper.database;

    final rows = await db.rawQuery(
      '''
      SELECT voucher_no
      FROM journal_entries
      WHERE transaction_type = ?
        AND voucher_no LIKE ?
      ORDER BY id DESC
      LIMIT 1
      ''',
      [transactionType, '$prefix%'],
    );

    if (rows.isEmpty) {
      return '${prefix}1';
    }

    final last = rows.first['voucher_no']?.toString() ?? '';

    final number = int.tryParse(last.replaceFirst(prefix, '')) ?? 0;

    return '$prefix${number + 1}';
  }

  // ============================================================
  // PARTY LINK
  // ============================================================

  Future<_PartyLink?> _getPartyLink(DatabaseExecutor db, int accountId) async {
    final rows = await db.query(
      'ff_party_account_links',
      columns: ['party_type', 'party_id'],
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _PartyLink(
      partyType: rows.first['party_type'].toString().toUpperCase(),
      partyId: (rows.first['party_id'] as num).toInt(),
    );
  }

  // ============================================================
  // LEGACY ACCOUNT TRANSACTION
  // ============================================================

  Future<void> _insertLegacyAccountTransaction(
    DatabaseExecutor db, {
    required int accountId,
    required String transactionType,
    required String referenceType,
    required int referenceId,
    required String voucherNo,
    required double debit,
    required double credit,
    required String transactionDate,
    required String note,
  }) async {
    await db.insert('account_transactions', {
      'account_id': accountId,
      'transaction_type': transactionType,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'voucher_no': voucherNo,
      'debit': debit,
      'credit': credit,
      'transaction_date': transactionDate,
      'note': note,
      'created_at': transactionDate,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  // ============================================================
  // PAYMENT METHOD LABEL
  // ============================================================

  Future<String> _paymentMethod(DatabaseExecutor db, int accountId) async {
    final rows = await db.query(
      'accounts',
      columns: ['type'],
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return 'Account';
    }

    switch (rows.first['type']?.toString().toUpperCase()) {
      case 'CASH':
        return 'Cash';

      case 'BANK':
        return 'Bank';

      case 'MFS':
      case 'MOBILE_BANKING':
        return 'Mobile Banking';

      default:
        return 'Account';
    }
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  Future<void> _validate(
    DatabaseExecutor db, {
    required int cashAccountId,
    required int ledgerAccountId,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    if (cashAccountId <= 0 || ledgerAccountId <= 0) {
      throw ArgumentError('Invalid account.');
    }

    if (cashAccountId == ledgerAccountId) {
      throw ArgumentError(
        'Money account and ledger account cannot be the same.',
      );
    }

    final moneyRows = await db.rawQuery(
      '''
      SELECT
        a.id,
        a.type,
        g.group_code
      FROM accounts a
      LEFT JOIN ff_account_links l
        ON l.account_id = a.id
       AND l.is_primary = 1
      LEFT JOIN ff_account_groups g
        ON g.id = l.group_id
      WHERE a.id = ?
      LIMIT 1
      ''',
      [cashAccountId],
    );

    if (moneyRows.isEmpty) {
      throw StateError('Cash/Bank/MFS account not found.');
    }

    final groupCode = moneyRows.first['group_code']?.toString().toUpperCase();

    final accountType = moneyRows.first['type']?.toString().toUpperCase();

    const allowedGroups = {'CASH', 'BANK', 'MFS'};

    const allowedTypes = {'CASH', 'BANK', 'MFS', 'MOBILE_BANKING'};

    if (!allowedGroups.contains(groupCode) &&
        !allowedTypes.contains(accountType)) {
      throw StateError('Money account must be Cash, Bank or MFS.');
    }

    final ledgerRows = await db.query(
      'accounts',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [ledgerAccountId],
      limit: 1,
    );

    if (ledgerRows.isEmpty) {
      throw StateError('Selected ledger account not found.');
    }
  }
}

class _PartyLink {
  final String partyType;
  final int partyId;

  const _PartyLink({required this.partyType, required this.partyId});
}
