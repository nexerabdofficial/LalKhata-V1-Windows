import '../models/account_transaction.dart';
import 'account_transaction_repository.dart';

class AccountLedgerService {
  final AccountTransactionRepository _repository =
      AccountTransactionRepository();

  /// Creates a debit transaction for an account.
  ///
  /// Debit means money/value goes OUT of the account.
  Future<int> recordDebit({
    required int accountId,
    required double amount,
    required String transactionType,
    String? referenceType,
    int? referenceId,
    String? voucherNo,
    required String transactionDate,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Debit amount must be greater than zero.');
    }

    final transaction = AccountTransaction(
      accountId: accountId,
      transactionType: transactionType,
      referenceType: referenceType,
      referenceId: referenceId,
      voucherNo: voucherNo,
      debit: amount,
      credit: 0,
      transactionDate: transactionDate,
      note: note,
      createdAt: DateTime.now().toIso8601String(),
    );

    return await _repository.insertTransaction(transaction);
  }

  /// Creates a credit transaction for an account.
  ///
  /// Credit means money/value comes INTO the account.
  Future<int> recordCredit({
    required int accountId,
    required double amount,
    required String transactionType,
    String? referenceType,
    int? referenceId,
    String? voucherNo,
    required String transactionDate,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Credit amount must be greater than zero.');
    }

    final transaction = AccountTransaction(
      accountId: accountId,
      transactionType: transactionType,
      referenceType: referenceType,
      referenceId: referenceId,
      voucherNo: voucherNo,
      debit: 0,
      credit: amount,
      transactionDate: transactionDate,
      note: note,
      createdAt: DateTime.now().toIso8601String(),
    );

    return await _repository.insertTransaction(transaction);
  }

  /// Deletes all ledger transactions created
  /// for a particular source record.
  Future<int> deleteByReference({
    required String referenceType,
    required int referenceId,
  }) async {
    return await _repository.deleteTransactionsByReference(
      referenceType: referenceType,
      referenceId: referenceId,
    );
  }

  /// Returns all ledger transactions.
  Future<List<AccountTransaction>> getAllTransactions() async {
    return await _repository.getAllTransactions();
  }

  /// Returns all transactions belonging to an account.
  Future<List<AccountTransaction>> getAccountTransactions(int accountId) async {
    return await _repository.getTransactionsByAccount(accountId);
  }

  /// Returns transactions for an account within
  /// the selected date range.
  Future<List<AccountTransaction>> getAccountTransactionsByDateRange({
    required int accountId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return await _repository.getTransactionsByDateRange(
      accountId: accountId,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  Future<double> getAccountBalanceFromLedger(int accountId) async {
    final transactions = await _repository.getTransactionsByAccount(accountId);

    double balance = 0;

    for (final transaction in transactions) {
      balance += transaction.credit;
      balance -= transaction.debit;
    }

    return balance;
  }
  // ============================================================
  // FUND TRANSFER
  // ============================================================

  Future<void> transferFunds({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required String voucherNo,
    required String transactionDate,
    String? note,
  }) async {
    if (fromAccountId == toAccountId) {
      throw ArgumentError(
        'Source and destination accounts cannot be the same.',
      );
    }

    if (amount <= 0) {
      throw ArgumentError('Transfer amount must be greater than zero.');
    }

    await _repository.transferFunds(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      voucherNo: voucherNo,
      transactionDate: transactionDate,
      note: note,
    );
  }
}
