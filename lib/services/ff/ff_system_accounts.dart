import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import '../../models/account.dart';
import '../../models/ff_account_group.dart';

class FFSystemGroupCodes {
  FFSystemGroupCodes._();

  static const assets = 'ASSETS';
  static const currentAssets = 'CURRENT_ASSETS';
  static const fixedAssets = 'FIXED_ASSETS';

  static const cash = 'CASH';
  static const bank = 'BANK';
  static const mfs = 'MFS';

  static const customerReceivable = 'CUSTOMER_RECEIVABLE';
  static const loanReceivable = 'LOAN_RECEIVABLE';
  static const inventory = 'INVENTORY';
  static const prepaidExpense = 'PREPAID_EXPENSE';

  static const liabilities = 'LIABILITIES';
  static const supplierPayable = 'SUPPLIER_PAYABLE';
  static const loanPayable = 'LOAN_PAYABLE';
  static const outstandingExpense = 'OUTSTANDING_EXPENSE';
  static const otherLiabilities = 'OTHER_LIABILITIES';

  static const equity = 'EQUITY';
  static const ownerCapital = 'OWNER_CAPITAL';
  static const ownerWithdrawal = 'OWNER_WITHDRAWAL';
  static const retainedEarnings = 'RETAINED_EARNINGS';
  static const openingBalanceEquity = 'OPENING_BALANCE_EQUITY';

  static const income = 'INCOME';
  static const salesIncome = 'SALES_INCOME';
  static const serviceIncome = 'SERVICE_INCOME';
  static const otherIncome = 'OTHER_INCOME';

  static const expense = 'EXPENSE';
  static const costOfGoodsSold = 'COST_OF_GOODS_SOLD';
  static const operatingExpense = 'OPERATING_EXPENSE';
  static const sellingExpense = 'SELLING_EXPENSE';
  static const otherExpense = 'OTHER_EXPENSE';
}

class FFSystemAccountCodes {
  FFSystemAccountCodes._();

  static const customerReceivable = 'CUSTOMER_RECEIVABLE';
  static const supplierPayable = 'SUPPLIER_PAYABLE';
  static const inventory = 'INVENTORY';
  static const salesIncome = 'SALES_INCOME';
  static const ownerCapital = 'OWNER_CAPITAL';
  static const ownerWithdrawal = 'OWNER_WITHDRAWAL';
  static const retainedEarnings = 'RETAINED_EARNINGS';
  static const openingBalanceEquity = 'OPENING_BALANCE_EQUITY';
  static const costOfGoodsSold = 'COST_OF_GOODS_SOLD';

  static const prepaidExpense = 'PREPAID_EXPENSE';
  static const outstandingExpense = 'OUTSTANDING_EXPENSE';

  static const purchaseAdditionalCharge = 'PURCHASE_ADDITIONAL_CHARGE';

  static const purchaseDiscount = 'PURCHASE_DISCOUNT';
  static const salesDiscount = 'SALES_DISCOUNT';
}

class FFSystemAccounts {
  FFSystemAccounts._();

  static final FFSystemAccounts instance = FFSystemAccounts._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<void> ensureFoundation() async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      final assets = await _ensureGroup(
        txn,
        name: 'Assets',
        code: FFSystemGroupCodes.assets,
        kind: 'ASSET',
        nature: 'DEBIT',
      );

      final currentAssets = await _ensureGroup(
        txn,
        name: 'Current Assets',
        code: FFSystemGroupCodes.currentAssets,
        parentId: assets,
        kind: 'ASSET',
        nature: 'DEBIT',
      );

      final fixedAssets = await _ensureGroup(
        txn,
        name: 'Fixed Assets',
        code: FFSystemGroupCodes.fixedAssets,
        parentId: assets,
        kind: 'ASSET',
        nature: 'DEBIT',
      );

      await _ensureGroup(
        txn,
        name: 'Cash',
        code: FFSystemGroupCodes.cash,
        parentId: currentAssets,
        kind: 'ASSET',
        nature: 'DEBIT',
      );

      await _ensureGroup(
        txn,
        name: 'Bank',
        code: FFSystemGroupCodes.bank,
        parentId: currentAssets,
        kind: 'ASSET',
        nature: 'DEBIT',
      );

      await _ensureGroup(
        txn,
        name: 'MFS',
        code: FFSystemGroupCodes.mfs,
        parentId: currentAssets,
        kind: 'ASSET',
        nature: 'DEBIT',
      );

      final customerReceivableGroup = await _ensureGroup(
        txn,
        name: 'Customer Receivable',
        code: FFSystemGroupCodes.customerReceivable,
        parentId: currentAssets,
        kind: 'ASSET',
        nature: 'DEBIT',
      );

      await _ensureGroup(
        txn,
        name: 'Loan Receivable',
        code: FFSystemGroupCodes.loanReceivable,
        parentId: currentAssets,
        kind: 'ASSET',
        nature: 'DEBIT',
      );

      final inventoryGroup = await _ensureGroup(
        txn,
        name: 'Inventory',
        code: FFSystemGroupCodes.inventory,
        parentId: currentAssets,
        kind: 'ASSET',
        nature: 'DEBIT',
      );

      final prepaidExpenseGroup = await _ensureGroup(
        txn,
        name: 'Prepaid Expense',
        code: FFSystemGroupCodes.prepaidExpense,
        parentId: currentAssets,
        kind: 'ASSET',
        nature: 'DEBIT',
      );

      // Keep permanent hierarchy references validated.
      if (fixedAssets <= 0 || prepaidExpenseGroup <= 0) {
        throw StateError('Failed to create required asset groups.');
      }

      final liabilities = await _ensureGroup(
        txn,
        name: 'Liabilities',
        code: FFSystemGroupCodes.liabilities,
        kind: 'LIABILITY',
        nature: 'CREDIT',
      );

      final supplierPayableGroup = await _ensureGroup(
        txn,
        name: 'Supplier Payable',
        code: FFSystemGroupCodes.supplierPayable,
        parentId: liabilities,
        kind: 'LIABILITY',
        nature: 'CREDIT',
      );

      await _ensureGroup(
        txn,
        name: 'Loan Payable',
        code: FFSystemGroupCodes.loanPayable,
        parentId: liabilities,
        kind: 'LIABILITY',
        nature: 'CREDIT',
      );

      final outstandingExpenseGroup = await _ensureGroup(
        txn,
        name: 'Outstanding Expense',
        code: FFSystemGroupCodes.outstandingExpense,
        parentId: liabilities,
        kind: 'LIABILITY',
        nature: 'CREDIT',
      );

      await _ensureGroup(
        txn,
        name: 'Other Liabilities',
        code: FFSystemGroupCodes.otherLiabilities,
        parentId: liabilities,
        kind: 'LIABILITY',
        nature: 'CREDIT',
      );

      if (outstandingExpenseGroup <= 0) {
        throw StateError('Failed to create Outstanding Expense group.');
      }

      final equity = await _ensureGroup(
        txn,
        name: 'Equity',
        code: FFSystemGroupCodes.equity,
        kind: 'EQUITY',
        nature: 'CREDIT',
      );

      final ownerCapitalGroup = await _ensureGroup(
        txn,
        name: 'Owner Capital',
        code: FFSystemGroupCodes.ownerCapital,
        parentId: equity,
        kind: 'EQUITY',
        nature: 'CREDIT',
      );

      final ownerWithdrawalGroup = await _ensureGroup(
        txn,
        name: 'Owner Withdrawal',
        code: FFSystemGroupCodes.ownerWithdrawal,
        parentId: equity,
        kind: 'EQUITY',
        nature: 'DEBIT',
      );

      final retainedEarningsGroup = await _ensureGroup(
        txn,
        name: 'Retained Earnings',
        code: FFSystemGroupCodes.retainedEarnings,
        parentId: equity,
        kind: 'EQUITY',
        nature: 'CREDIT',
      );

      final openingBalanceEquityGroup = await _ensureGroup(
        txn,
        name: 'Opening Balance Equity',
        code: FFSystemGroupCodes.openingBalanceEquity,
        parentId: equity,
        kind: 'EQUITY',
        nature: 'CREDIT',
      );

      final income = await _ensureGroup(
        txn,
        name: 'Income',
        code: FFSystemGroupCodes.income,
        kind: 'INCOME',
        nature: 'CREDIT',
      );

      final salesIncomeGroup = await _ensureGroup(
        txn,
        name: 'Sales Income',
        code: FFSystemGroupCodes.salesIncome,
        parentId: income,
        kind: 'INCOME',
        nature: 'CREDIT',
      );

      await _ensureGroup(
        txn,
        name: 'Service Income',
        code: FFSystemGroupCodes.serviceIncome,
        parentId: income,
        kind: 'INCOME',
        nature: 'CREDIT',
      );

      final otherIncomeGroup = await _ensureGroup(
        txn,
        name: 'Other Income',
        code: FFSystemGroupCodes.otherIncome,
        parentId: income,
        kind: 'INCOME',
        nature: 'CREDIT',
      );

      final expense = await _ensureGroup(
        txn,
        name: 'Expense',
        code: FFSystemGroupCodes.expense,
        kind: 'EXPENSE',
        nature: 'DEBIT',
      );

      final costOfGoodsSoldGroup = await _ensureGroup(
        txn,
        name: 'Cost of Goods Sold',
        code: FFSystemGroupCodes.costOfGoodsSold,
        parentId: expense,
        kind: 'EXPENSE',
        nature: 'DEBIT',
      );

      final operatingExpenseGroup = await _ensureGroup(
        txn,
        name: 'Operating Expense',
        code: FFSystemGroupCodes.operatingExpense,
        parentId: expense,
        kind: 'EXPENSE',
        nature: 'DEBIT',
      );

      await _ensureGroup(
        txn,
        name: 'Selling Expense',
        code: FFSystemGroupCodes.sellingExpense,
        parentId: expense,
        kind: 'EXPENSE',
        nature: 'DEBIT',
      );

      final otherExpenseGroup = await _ensureGroup(
        txn,
        name: 'Other Expense',
        code: FFSystemGroupCodes.otherExpense,
        parentId: expense,
        kind: 'EXPENSE',
        nature: 'DEBIT',
      );

      await _ensureSystemAccount(
        txn,
        name: 'Prepaid Expense',
        type: FFSystemAccountCodes.prepaidExpense,
        groupId: prepaidExpenseGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Outstanding Expense',
        type: FFSystemAccountCodes.outstandingExpense,
        groupId: outstandingExpenseGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Customer Receivable',
        type: FFSystemAccountCodes.customerReceivable,
        groupId: customerReceivableGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Supplier Payable',
        type: FFSystemAccountCodes.supplierPayable,
        groupId: supplierPayableGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Inventory',
        type: FFSystemAccountCodes.inventory,
        groupId: inventoryGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Sales Income',
        type: FFSystemAccountCodes.salesIncome,
        groupId: salesIncomeGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Owner Capital',
        type: FFSystemAccountCodes.ownerCapital,
        groupId: ownerCapitalGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Owner Withdrawal',
        type: FFSystemAccountCodes.ownerWithdrawal,
        groupId: ownerWithdrawalGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Retained Earnings',
        type: FFSystemAccountCodes.retainedEarnings,
        groupId: retainedEarningsGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Opening Balance Equity',
        type: FFSystemAccountCodes.openingBalanceEquity,
        groupId: openingBalanceEquityGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Cost of Goods Sold',
        type: FFSystemAccountCodes.costOfGoodsSold,
        groupId: costOfGoodsSoldGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Purchase Additional Charge',
        type: FFSystemAccountCodes.purchaseAdditionalCharge,
        groupId: operatingExpenseGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Purchase Discount',
        type: FFSystemAccountCodes.purchaseDiscount,
        groupId: otherIncomeGroup,
      );

      await _ensureSystemAccount(
        txn,
        name: 'Sales Discount',
        type: FFSystemAccountCodes.salesDiscount,
        groupId: otherExpenseGroup,
      );

      await _linkExistingPaymentAccounts(txn);
    });
  }

  Future<int> resolveAccountId(String systemAccountCode) async {
    await ensureFoundation();

    final db = await _databaseHelper.database;

    final rows = await db.query(
      'accounts',
      columns: ['id'],
      where: 'type = ?',
      whereArgs: [systemAccountCode],
      orderBy: 'id ASC',
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('System account not found: $systemAccountCode');
    }

    return (rows.first['id'] as num).toInt();
  }

  Future<Account> resolveAccount(String systemAccountCode) async {
    await ensureFoundation();

    final db = await _databaseHelper.database;

    final rows = await db.query(
      'accounts',
      where: 'type = ?',
      whereArgs: [systemAccountCode],
      orderBy: 'id ASC',
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('System account not found: $systemAccountCode');
    }

    return Account.fromMap(rows.first);
  }

  Future<int?> resolveGroupId(String groupCode) async {
    await ensureFoundation();

    final db = await _databaseHelper.database;

    final rows = await db.query(
      'ff_account_groups',
      columns: ['id'],
      where: 'group_code = ?',
      whereArgs: [groupCode],
      orderBy: 'id ASC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return (rows.first['id'] as num).toInt();
  }

  Future<int> _ensureGroup(
    DatabaseExecutor db, {
    required String name,
    required String code,
    int? parentId,
    required String kind,
    required String nature,
  }) async {
    final existing = await db.query(
      'ff_account_groups',
      columns: ['id'],
      where: 'group_code = ?',
      whereArgs: [code],
      orderBy: 'id ASC',
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = (existing.first['id'] as num).toInt();

      await db.update(
        'ff_account_groups',
        {
          'name': name,
          'parent_id': parentId,
          'group_kind': kind,
          'account_nature': nature,
          'is_system': 1,
          'is_active': 1,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      return id;
    }

    return db.insert(
      'ff_account_groups',
      FFAccountGroup(
        name: name,
        parentId: parentId,
        groupCode: code,
        groupKind: kind,
        accountNature: nature,
        isSystem: true,
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
      ).toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> _ensureSystemAccount(
    DatabaseExecutor db, {
    required String name,
    required String type,
    required int groupId,
  }) async {
    final existing = await db.query(
      'accounts',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'id ASC',
      limit: 1,
    );

    late final int accountId;

    if (existing.isNotEmpty) {
      accountId = (existing.first['id'] as num).toInt();
    } else {
      accountId = await db.insert('accounts', {
        'name': name,
        'type': type,
        'opening_balance': 0.0,
        'opening_date': '',
        'balance': 0.0,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    }

    await _ensurePrimaryLink(db, accountId: accountId, groupId: groupId);

    return accountId;
  }

  Future<void> _linkExistingPaymentAccounts(DatabaseExecutor db) async {
    final groups = await db.query(
      'ff_account_groups',
      columns: ['id', 'group_code'],
      where: 'group_code IN (?, ?, ?)',
      whereArgs: [
        FFSystemGroupCodes.cash,
        FFSystemGroupCodes.bank,
        FFSystemGroupCodes.mfs,
      ],
    );

    final groupIds = <String, int>{};

    for (final row in groups) {
      groupIds[row['group_code'].toString()] = (row['id'] as num).toInt();
    }

    final accounts = await db.query(
      'accounts',
      columns: ['id', 'type'],
      where: 'type IN (?, ?, ?)',
      whereArgs: ['CASH', 'BANK', 'MOBILE_BANKING'],
    );

    for (final row in accounts) {
      final accountId = (row['id'] as num).toInt();
      final type = row['type'].toString();

      final groupCode = switch (type) {
        'CASH' => FFSystemGroupCodes.cash,
        'BANK' => FFSystemGroupCodes.bank,
        'MOBILE_BANKING' => FFSystemGroupCodes.mfs,
        _ => null,
      };

      if (groupCode == null) {
        continue;
      }

      final groupId = groupIds[groupCode];

      if (groupId == null) {
        continue;
      }

      await _ensurePrimaryLink(db, accountId: accountId, groupId: groupId);
    }
  }

  Future<void> _ensurePrimaryLink(
    DatabaseExecutor db, {
    required int accountId,
    required int groupId,
  }) async {
    await db.update(
      'ff_account_links',
      {'is_primary': 0},
      where: 'account_id = ?',
      whereArgs: [accountId],
    );

    final existing = await db.query(
      'ff_account_links',
      columns: ['id'],
      where: 'account_id = ? AND group_id = ?',
      whereArgs: [accountId, groupId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('ff_account_links', {
        'account_id': accountId,
        'group_id': groupId,
        'is_primary': 1,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    } else {
      await db.update(
        'ff_account_links',
        {'is_primary': 1},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }
}
