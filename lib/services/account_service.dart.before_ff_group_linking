import '../models/account.dart';
import 'account_repository.dart';
import 'account_ledger_service.dart';

class AccountService {
  final AccountRepository _accountRepository =
      AccountRepository();

  final AccountLedgerService _ledgerService =
      AccountLedgerService();

  Future createAccount(
    Account account,
  ) async {
    final accountId =
        await _accountRepository.insertAccount(
      account,
    );

    // IMPORTANT:
    // Opening Balance is already stored in:
    // accounts.balance
    // accounts.opening_balance
    //
    // AccountLedgerScreen also displays the opening
    // balance as the OB row.
    //
    // Therefore DO NOT create a separate
    // account_transactions entry here.
    //
    // Otherwise opening balance will appear twice
    // in the account ledger.

    return accountId;
  }

  Future updateAccount(
    Account account,
  ) async {
    await _accountRepository.updateAccount(
      account,
    );
  }

  Future<Account?> getAccountById(
    int accountId,
  ) async {
    return await _accountRepository.getAccountById(
      accountId,
    );
  }

  Future<List<Account>> getAccounts() async {
    return await _accountRepository.getAccounts();
  }

  Future deleteAccount(
    int accountId,
  ) async {
    // Delete ledger transactions belonging to
    // this account.
    await _ledgerService.deleteByReference(
      referenceType: 'ACCOUNT',
      referenceId: accountId,
    );

    await _accountRepository.deleteAccount(
      accountId,
    );
  }
}