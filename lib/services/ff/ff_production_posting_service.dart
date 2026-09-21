import 'package:sqflite/sqflite.dart';

import 'ff_journal_models.dart';
import 'ff_journal_service.dart';
import 'ff_system_accounts.dart';

class FFProductionPostingService {
  FFProductionPostingService._();

  static final FFProductionPostingService instance =
      FFProductionPostingService._();

  final FFJournalService _journalService = FFJournalService.instance;

  Future<int> _resolveInventoryAccountId(DatabaseExecutor db) async {
    final existing = await db.query(
      'accounts',
      columns: ['id'],
      where: 'type = ?',
      whereArgs: [FFSystemAccountCodes.inventory],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return (existing.first['id'] as num).toInt();
    }

    throw StateError('FF Inventory system account not found.');
  }

  Future<void> postProductionWithExecutor(
    DatabaseExecutor db, {
    required int productionId,
    required double materialCost,
    required String transactionDate,
    String? productionNo,
    String? note,
  }) async {
    if (materialCost <= 0) {
      throw ArgumentError(
        'Production material cost must be greater than zero.',
      );
    }

    final inventoryId = await _resolveInventoryAccountId(db);

    final voucherNo = (productionNo ?? '').trim().isNotEmpty
        ? productionNo!.trim()
        : 'PROD-${productionId.toString().padLeft(6, '0')}';

    await _journalService.createJournalWithExecutor(
      db,
      FFJournalEntry(
        transactionType: 'PRODUCTION',
        voucherNo: voucherNo,
        transactionDate: transactionDate,
        referenceType: 'PRODUCTION',
        referenceId: productionId,
        description: (note ?? '').trim().isNotEmpty
            ? (note ?? '').trim()
            : 'Production',
        createdAt: DateTime.now().toIso8601String(),
        lines: [
          FFJournalLine(
            accountId: inventoryId,
            entityType: 'PRODUCTION_FINISHED',
            entityId: productionId,
            debit: materialCost,
            credit: 0,
            note: 'Finished product inventory',
          ),
          FFJournalLine(
            accountId: inventoryId,
            entityType: 'PRODUCTION_MATERIAL',
            entityId: productionId,
            debit: 0,
            credit: materialCost,
            note: 'Raw material inventory consumed',
          ),
        ],
      ),
    );
  }
}
