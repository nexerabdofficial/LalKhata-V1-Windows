import '../models/account.dart';
import 'account_repository.dart';
import 'account_ledger_service.dart';
import 'ff/ff_account_hierarchy_service.dart';
import 'ff/ff_system_accounts.dart';

class AccountService {
  final AccountRepository _accountRepository = AccountRepository();

  final AccountLedgerService _ledgerService = AccountLedgerService();

  final FFAccountHierarchyService _hierarchyService =
      FFAccountHierarchyService.instance;

  final FFSystemAccounts _systemAccounts = FFSystemAccounts.instance;

  // ============================================================
  // CREATE ACCOUNT
  // ============================================================

  Future<int> createAccount(Account account, {int? groupId}) async {
    _validateUserAccountType(account.type);

    await _systemAccounts.ensureFoundation();

    final accountId = await _accountRepository.insertAccount(account);

    try {
      if (groupId != null) {
        await _hierarchyService.linkAccount(
          accountId: accountId,
          groupId: groupId,
          isPrimary: true,
        );
      } else {
        await _linkAccountToFFGroup(
          accountId: accountId,
          accountType: account.type,
        );
      }
    } catch (e) {
      // Do not leave an unclassified user account behind.
      await _accountRepository.deleteAccount(accountId);

      rethrow;
    }

    // Opening balance is already stored in accounts.
    //
    // DO NOT create a separate legacy account transaction here.
    // AccountLedgerScreen already displays opening balance
    // separately and AccountRepository includes opening_balance
    // in its balance calculation.

    return accountId;
  }

  // ============================================================
  // UPDATE ACCOUNT
  // ============================================================

  Future<void> updateAccount(Account account) async {
    if (account.id == null) {
      throw ArgumentError('Account ID is required for update.');
    }

    final existing = await _accountRepository.getAccountById(account.id!);

    if (existing == null) {
      throw StateError('Account not found: ${account.id}');
    }

    if (_isSystemControlledType(existing.type)) {
      throw StateError('System-controlled accounts cannot be edited manually.');
    }

    _validateUserAccountType(account.type);

    await _systemAccounts.ensureFoundation();

    // Resolve the target group BEFORE changing the account.
    // This prevents a partial update if FF classification
    // is invalid or missing.
    final groupCode = _groupCodeForAccountType(account.type);

    final group = await _hierarchyService.getGroupByCode(groupCode);

    if (group == null || group.id == null) {
      throw StateError('FF account group not found: $groupCode');
    }

    await _accountRepository.updateAccount(account);

    await _hierarchyService.linkAccount(
      accountId: account.id!,
      groupId: group.id!,
      isPrimary: true,
    );
  }

  // ============================================================
  // GET ACCOUNT
  // ============================================================

  Future<Account?> getAccountById(int accountId) async {
    return await _accountRepository.getAccountById(accountId);
  }

  Future<List<Account>> getAccounts() async {
    return await _accountRepository.getAccounts();
  }

  // ============================================================
  // DELETE ACCOUNT
  // ============================================================

  Future<void> deleteAccount(int accountId) async {
    final account = await _accountRepository.getAccountById(accountId);

    if (account == null) {
      return;
    }

    if (_isSystemControlledType(account.type)) {
      throw StateError('System-controlled accounts cannot be deleted.');
    }

    // Existing compatibility cleanup.
    await _ledgerService.deleteByReference(
      referenceType: 'ACCOUNT',
      referenceId: accountId,
    );

    await _accountRepository.deleteAccount(accountId);
  }

  // ============================================================
  // FF GROUP LINKING
  // ============================================================

  Future<void> _linkAccountToFFGroup({
    required int accountId,
    required String accountType,
  }) async {
    final groupCode = _groupCodeForAccountType(accountType);

    final group = await _hierarchyService.getGroupByCode(groupCode);

    if (group == null || group.id == null) {
      throw StateError('FF account group not found: $groupCode');
    }

    await _hierarchyService.linkAccount(
      accountId: accountId,
      groupId: group.id!,
      isPrimary: true,
    );
  }

  // ============================================================
  // USER ACCOUNT TYPE -> FF GROUP
  // ============================================================

  String _groupCodeForAccountType(String accountType) {
    switch (accountType.trim().toUpperCase()) {
      case 'CASH':
        return FFSystemGroupCodes.cash;

      case 'BANK':
        return FFSystemGroupCodes.bank;

      case 'MOBILE_BANKING':
      case 'MFS':
        return FFSystemGroupCodes.mfs;

      case 'OTHER_CURRENT_ASSET':
        return FFSystemGroupCodes.currentAssets;

      case 'FIXED_ASSET':
        return FFSystemGroupCodes.fixedAssets;

      case 'OTHER_LIABILITY':
        return FFSystemGroupCodes.otherLiabilities;

      case 'OWNER_CAPITAL':
        return FFSystemGroupCodes.ownerCapital;

      case 'OTHER_INCOME':
        return FFSystemGroupCodes.otherIncome;

      case 'OPERATING_EXPENSE':
        return FFSystemGroupCodes.operatingExpense;

      default:
        throw ArgumentError('Unsupported user account type: $accountType');
    }
  }

  // ============================================================
  // USER-CREATABLE TYPES
  // ============================================================

  void _validateUserAccountType(String accountType) {
    const allowedTypes = <String>{
      'CASH',
      'BANK',
      'MOBILE_BANKING',
      'MFS',
      'OTHER_CURRENT_ASSET',
      'FIXED_ASSET',
      'OTHER_LIABILITY',
      'OWNER_CAPITAL',
      'OTHER_INCOME',
      'OPERATING_EXPENSE',
    };

    final normalized = accountType.trim().toUpperCase();

    if (!allowedTypes.contains(normalized)) {
      throw ArgumentError(
        'This account type cannot be created manually: '
        '$accountType',
      );
    }
  }

  // ============================================================
  // SYSTEM-CONTROLLED LEDGERS
  // ============================================================

  bool _isSystemControlledType(String accountType) {
    const systemTypes = <String>{
      'CUSTOMER_RECEIVABLE',
      'SUPPLIER_PAYABLE',
      'INVENTORY',
      'SALES_INCOME',
      'OWNER_WITHDRAWAL',
      'RETAINED_EARNINGS',
      'LOAN_RECEIVABLE',
      'LOAN_PAYABLE',
    };

    return systemTypes.contains(accountType.trim().toUpperCase());
  }
}
