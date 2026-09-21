import 'ff_journal_models.dart';
import 'ff_journal_service.dart';

class FFPostingEngine {
  FFPostingEngine._();

  static final FFPostingEngine instance = FFPostingEngine._();

  final FFJournalService _journalService = FFJournalService.instance;

  Future<int> post(FFJournalEntry entry) {
    return _journalService.createJournal(entry);
  }

  Future<List<Map<String, dynamic>>> ledger({
    required int accountId,
    String? fromDate,
    String? toDate,
  }) {
    return _journalService.getLedgerLines(
      accountId: accountId,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
