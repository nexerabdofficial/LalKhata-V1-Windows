import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import 'ff_journal_models.dart';

class FFJournalService {
  FFJournalService._();

  static final FFJournalService instance = FFJournalService._();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<int> createJournal(FFJournalEntry entry) async {
    _validate(entry);

    final db = await _db;

    return db.transaction((txn) => createJournalWithExecutor(txn, entry));
  }

  Future<int> createJournalWithExecutor(
    DatabaseExecutor db,
    FFJournalEntry entry,
  ) async {
    _validate(entry);

    final duplicate = await db.query(
      'journal_entries',
      columns: ['id'],
      where: 'transaction_type = ? AND voucher_no = ?',
      whereArgs: [entry.transactionType, entry.voucherNo],
      limit: 1,
    );

    if (duplicate.isNotEmpty) {
      throw Exception('Duplicate FF journal voucher: ${entry.voucherNo}');
    }

    final journalId = await db.insert('journal_entries', {
      'transaction_type': entry.transactionType,
      'voucher_no': entry.voucherNo,
      'transaction_date': entry.transactionDate,
      'reference_type': entry.referenceType,
      'reference_id': entry.referenceId,
      'description': entry.description,
      'created_at': entry.createdAt,
      'total_debit': entry.totalDebit,
      'total_credit': entry.totalCredit,
    });

    for (final line in entry.lines) {
      await db.insert('journal_lines', line.toMap(journalId));
    }

    return journalId;
  }

  Future<void> deleteJournalByReferenceWithExecutor(
    DatabaseExecutor db, {
    required String referenceType,
    required int referenceId,
  }) async {
    final rows = await db.query(
      'journal_entries',
      columns: ['id'],
      where: 'reference_type = ? AND reference_id = ?',
      whereArgs: [referenceType, referenceId],
    );

    for (final row in rows) {
      final journalId = (row['id'] as num).toInt();

      await db.delete(
        'journal_lines',
        where: 'journal_id = ?',
        whereArgs: [journalId],
      );

      await db.delete(
        'journal_entries',
        where: 'id = ?',
        whereArgs: [journalId],
      );
    }
  }

  Future<int?> getJournalIdByReference({
    required String referenceType,
    required int referenceId,
  }) async {
    final db = await _db;

    final rows = await db.query(
      'journal_entries',
      columns: ['id'],
      where: 'reference_type = ? AND reference_id = ?',
      whereArgs: [referenceType, referenceId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<List<Map<String, dynamic>>> getJournalEntries({
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;

    String? where;
    final args = <dynamic>[];

    if (fromDate != null && toDate != null) {
      where = 'transaction_date BETWEEN ? AND ?';
      args.addAll([fromDate, toDate]);
    } else if (fromDate != null) {
      where = 'transaction_date >= ?';
      args.add(fromDate);
    } else if (toDate != null) {
      where = 'transaction_date <= ?';
      args.add(toDate);
    }

    return db.query(
      'journal_entries',
      where: where,
      whereArgs: args,
      orderBy: 'transaction_date ASC, id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getLedgerLines({
    required int accountId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;

    final where = <String>['jl.account_id = ?'];

    final args = <dynamic>[accountId];

    if (fromDate != null) {
      where.add('je.transaction_date >= ?');
      args.add(fromDate);
    }

    if (toDate != null) {
      where.add('je.transaction_date <= ?');
      args.add(toDate);
    }

    return db.rawQuery('''
      SELECT
        jl.id,
        jl.journal_id,
        jl.account_id,
        jl.entity_type,
        jl.entity_id,
        jl.debit,
        jl.credit,
        jl.note,
        je.transaction_type,
        je.voucher_no,
        je.transaction_date,
        je.reference_type,
        je.reference_id,
        je.description,
        je.created_at
      FROM journal_lines jl
      INNER JOIN journal_entries je
        ON je.id = jl.journal_id
      WHERE ${where.join(' AND ')}
      ORDER BY je.transaction_date ASC, jl.id ASC
      ''', args);
  }

  Future<void> deleteJournalById(int journalId) async {
    final db = await _db;

    await db.transaction((txn) async {
      await txn.delete(
        'journal_lines',
        where: 'journal_id = ?',
        whereArgs: [journalId],
      );

      await txn.delete(
        'journal_entries',
        where: 'id = ?',
        whereArgs: [journalId],
      );
    });
  }

  void _validate(FFJournalEntry entry) {
    if (entry.transactionType.trim().isEmpty) {
      throw ArgumentError('Transaction type is required.');
    }

    if (entry.voucherNo.trim().isEmpty) {
      throw ArgumentError('Voucher number is required.');
    }

    if (entry.transactionDate.trim().isEmpty) {
      throw ArgumentError('Transaction date is required.');
    }

    if (entry.lines.length < 2) {
      throw ArgumentError('A journal requires at least two lines.');
    }

    for (final line in entry.lines) {
      if (line.accountId <= 0) {
        throw ArgumentError('Invalid account ID.');
      }

      if (line.debit < 0 || line.credit < 0) {
        throw ArgumentError('Debit/Credit cannot be negative.');
      }

      if (line.debit > 0 && line.credit > 0) {
        throw ArgumentError(
          'A journal line cannot contain both debit and credit.',
        );
      }

      if (line.debit == 0 && line.credit == 0) {
        throw ArgumentError(
          'A journal line cannot have zero debit and credit.',
        );
      }

      if (line.entityId != null &&
          (line.entityType == null || line.entityType!.trim().isEmpty)) {
        throw ArgumentError(
          'Entity type is required when entity ID is provided.',
        );
      }
    }

    if (!entry.isBalanced) {
      throw ArgumentError(
        'Unbalanced journal: '
        'Debit=${entry.totalDebit}, Credit=${entry.totalCredit}',
      );
    }
  }
}
