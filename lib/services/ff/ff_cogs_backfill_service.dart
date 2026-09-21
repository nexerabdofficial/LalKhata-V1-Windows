import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import 'ff_journal_models.dart';
import 'ff_journal_service.dart';
import 'ff_system_accounts.dart';

class FFCogsBackfillService {
  FFCogsBackfillService._();

  static final FFCogsBackfillService instance = FFCogsBackfillService._();

  final FFJournalService _journalService = FFJournalService.instance;

  Future<int> backfillMissingHistoricalCogs() async {
    final db = await DatabaseHelper.instance.database;

    await FFSystemAccounts.instance.ensureFoundation();

    return backfillMissingHistoricalCogsWithExecutor(db);
  }

  Future<int> backfillMissingHistoricalCogsWithExecutor(Database db) async {
    return db.transaction((txn) async {
      final inventoryId = await _accountId(txn, FFSystemAccountCodes.inventory);

      final cogsId = await _accountId(
        txn,
        FFSystemAccountCodes.costOfGoodsSold,
      );

      final sales = await txn.rawQuery('''
        SELECT
          s.id,
          s.invoice_no,
          s.sale_date,
          s.created_at,
          COALESCE(
            SUM(si.qty * si.purchase_price),
            0
          ) AS sale_cost
        FROM sales s
        INNER JOIN sale_items si
          ON si.sale_id = s.id
        GROUP BY
          s.id,
          s.invoice_no,
          s.sale_date,
          s.created_at
        ORDER BY s.id ASC
        ''');

      int created = 0;

      for (final sale in sales) {
        final saleId = (sale['id'] as num).toInt();

        final rawCost = sale['sale_cost'];
        final saleCost = rawCost is num
            ? rawCost.toDouble()
            : double.tryParse(rawCost?.toString() ?? '') ?? 0.0;

        // No valid historical cost snapshot = do not invent COGS.
        if (saleCost <= 0.000001) {
          continue;
        }

        // --------------------------------------------------------
        // Already backfilled?
        // --------------------------------------------------------

        final backfillExists = await txn.rawQuery(
          '''
          SELECT je.id
          FROM journal_entries je
          WHERE je.reference_type = 'COGS_BACKFILL'
            AND je.reference_id = ?
          LIMIT 1
          ''',
          [saleId],
        );

        if (backfillExists.isNotEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // Does original SALE journal already contain COGS?
        // If yes, this sale is already correct.
        // --------------------------------------------------------

        final originalCogsExists = await txn.rawQuery(
          '''
          SELECT jl.id
          FROM journal_entries je
          INNER JOIN journal_lines jl
            ON jl.journal_id = je.id
          WHERE je.reference_type = 'SALE'
            AND je.reference_id = ?
            AND jl.account_id = ?
            AND jl.debit > 0.000001
          LIMIT 1
          ''',
          [saleId, cogsId],
        );

        if (originalCogsExists.isNotEmpty) {
          continue;
        }

        final invoiceNo = sale['invoice_no']?.toString().trim() ?? '';

        final saleDate = sale['sale_date']?.toString().trim() ?? '';

        if (saleDate.isEmpty) {
          continue;
        }

        final createdAt = sale['created_at']?.toString().trim();

        await _journalService.createJournalWithExecutor(
          txn,
          FFJournalEntry(
            transactionType: 'COGS_BACKFILL',
            voucherNo: 'COGS-BF-$saleId',
            transactionDate: saleDate,
            referenceType: 'COGS_BACKFILL',
            referenceId: saleId,
            description: invoiceNo.isEmpty
                ? 'Historical COGS adjustment'
                : 'Historical COGS adjustment - $invoiceNo',
            createdAt: createdAt == null || createdAt.isEmpty
                ? saleDate
                : createdAt,
            lines: [
              FFJournalLine(
                accountId: cogsId,
                debit: saleCost,
                note: 'Historical cost of goods sold',
              ),
              FFJournalLine(
                accountId: inventoryId,
                credit: saleCost,
                note: 'Historical inventory issued on sale',
              ),
            ],
          ),
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
