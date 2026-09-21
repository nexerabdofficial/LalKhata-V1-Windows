import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import 'ff_journal_models.dart';
import 'ff_journal_service.dart';
import 'ff_system_accounts.dart';

class FFOpeningStockAccountingService {
  FFOpeningStockAccountingService._();

  static final FFOpeningStockAccountingService instance =
      FFOpeningStockAccountingService._();

  final FFJournalService _journalService = FFJournalService.instance;

  // ============================================================
  // POST ONE OPENING STOCK ENTRY
  // ============================================================

  Future<void> postOpeningStockWithExecutor(
    DatabaseExecutor db, {
    required int openingStockEntryId,
    required double amount,
    required String transactionDate,
    required String createdAt,
    bool historicalBackfill = false,
  }) async {
    if (amount <= 0.000001) return;

    final existing = await db.rawQuery(
      '''
      SELECT id
      FROM journal_entries
      WHERE reference_type = 'OPENING_STOCK'
        AND reference_id = ?
      LIMIT 1
      ''',
      [openingStockEntryId],
    );

    if (existing.isNotEmpty) return;

    final inventoryId = await _accountId(db, FFSystemAccountCodes.inventory);

    final obeId = await _accountId(
      db,
      FFSystemAccountCodes.openingBalanceEquity,
    );

    await _journalService.createJournalWithExecutor(
      db,
      FFJournalEntry(
        transactionType: 'OPENING_STOCK',
        voucherNo: 'OPEN-STOCK-$openingStockEntryId',
        transactionDate: transactionDate,
        referenceType: 'OPENING_STOCK',
        referenceId: openingStockEntryId,
        description: 'Opening stock',
        createdAt: createdAt,
        lines: [
          FFJournalLine(
            accountId: inventoryId,
            debit: amount,
            note: 'Opening inventory',
          ),
          FFJournalLine(
            accountId: obeId,
            credit: amount,
            note: 'Opening balance equity',
          ),
        ],
      ),
    );

    // Historical databases already carried an OBE master opening
    // that balanced their opening structure before opening-stock
    // journals existed. Reduce that master opening exactly once
    // when converting the historical stock entry to a journal.
    if (historicalBackfill) {
      final rows = await db.query(
        'accounts',
        columns: ['opening_balance'],
        where: 'id = ?',
        whereArgs: [obeId],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('Opening Balance Equity account not found.');
      }

      final raw = rows.first['opening_balance'];

      final currentOpening = raw is num
          ? raw.toDouble()
          : double.tryParse(raw?.toString() ?? '') ?? 0.0;

      final adjusted = currentOpening - amount;

      if (adjusted < -0.000001) {
        throw StateError(
          'Historical opening stock exceeds Opening Balance Equity.',
        );
      }

      await db.update(
        'accounts',
        {'opening_balance': adjusted.abs() < 0.000001 ? 0.0 : adjusted},
        where: 'id = ?',
        whereArgs: [obeId],
      );
    }
  }

  // ============================================================
  // HISTORICAL BACKFILL
  // ============================================================

  Future<int> backfillMissingHistoricalOpeningStock() async {
    final db = await DatabaseHelper.instance.database;

    await FFSystemAccounts.instance.ensureFoundation();

    return db.transaction((txn) async {
      final entries = await txn.query(
        'opening_stock_entries',
        orderBy: 'id ASC',
      );

      int created = 0;

      for (final entry in entries) {
        final id = (entry['id'] as num).toInt();

        final existing = await txn.rawQuery(
          '''
          SELECT id
          FROM journal_entries
          WHERE reference_type = 'OPENING_STOCK'
            AND reference_id = ?
          LIMIT 1
          ''',
          [id],
        );

        if (existing.isNotEmpty) continue;

        final rawAmount = entry['total_value'];

        final amount = rawAmount is num
            ? rawAmount.toDouble()
            : double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;

        if (amount <= 0.000001) continue;

        final transactionDate = entry['opening_date']?.toString().trim() ?? '';

        if (transactionDate.isEmpty) continue;

        final createdAt = entry['created_at']?.toString().trim() ?? '';

        await postOpeningStockWithExecutor(
          txn,
          openingStockEntryId: id,
          amount: amount,
          transactionDate: transactionDate,
          createdAt: createdAt.isEmpty ? transactionDate : createdAt,
          historicalBackfill: true,
        );

        created++;
      }

      return created;
    });
  }

  Future<int> _accountId(DatabaseExecutor db, String type) async {
    final rows = await db.query(
      'accounts',
      columns: ['id'],
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'id ASC',
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Required system account not found: $type');
    }

    return (rows.first['id'] as num).toInt();
  }
}
