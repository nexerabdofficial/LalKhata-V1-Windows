import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';

class FFTrialBalanceRow {
  final int accountId;
  final String accountName;
  final String accountType;
  final String groupName;
  final String groupKind;
  final String normalBalance;

  final double openingDebit;
  final double openingCredit;
  final double periodDebit;
  final double periodCredit;
  final double closingDebit;
  final double closingCredit;

  const FFTrialBalanceRow({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.groupName,
    required this.groupKind,
    required this.normalBalance,
    required this.openingDebit,
    required this.openingCredit,
    required this.periodDebit,
    required this.periodCredit,
    required this.closingDebit,
    required this.closingCredit,
  });
}

class FFTrialBalanceReport {
  final List<FFTrialBalanceRow> rows;

  final double openingDebit;
  final double openingCredit;
  final double periodDebit;
  final double periodCredit;
  final double closingDebit;
  final double closingCredit;

  const FFTrialBalanceReport({
    required this.rows,
    required this.openingDebit,
    required this.openingCredit,
    required this.periodDebit,
    required this.periodCredit,
    required this.closingDebit,
    required this.closingCredit,
  });

  double get openingDifference => openingDebit - openingCredit;

  double get periodDifference => periodDebit - periodCredit;

  double get closingDifference => closingDebit - closingCredit;

  bool get periodBalanced => periodDifference.abs() < 0.005;

  bool get closingBalanced => closingDifference.abs() < 0.005;
}

class FFTrialBalanceService {
  FFTrialBalanceService._();

  static final FFTrialBalanceService instance = FFTrialBalanceService._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<FFTrialBalanceReport> getReport({
    String? fromDate,
    String? toDate,
  }) async {
    final Database db = await _databaseHelper.database;

    final accountRows = await db.rawQuery('''
      SELECT
        a.id,
        a.name,
        a.type,
        COALESCE(a.opening_balance, 0) AS account_opening,
        COALESCE(g.name, '') AS group_name,
        COALESCE(g.group_kind, '') AS group_kind,
        COALESCE(g.account_nature, '') AS account_nature
      FROM accounts a
      LEFT JOIN ff_account_links l
        ON l.account_id = a.id
       AND l.is_primary = 1
      LEFT JOIN ff_account_groups g
        ON g.id = l.group_id
      ORDER BY
        COALESCE(g.group_kind, ''),
        COALESCE(g.name, ''),
        a.name
    ''');

    final rows = <FFTrialBalanceRow>[];

    double totalOpeningDebit = 0;
    double totalOpeningCredit = 0;
    double totalPeriodDebit = 0;
    double totalPeriodCredit = 0;
    double totalClosingDebit = 0;
    double totalClosingCredit = 0;

    for (final account in accountRows) {
      final accountId = (account['id'] as num).toInt();

      final accountType =
          account['type']?.toString().trim().toUpperCase() ?? '';

      final normalBalance =
          account['account_nature']?.toString().trim().toUpperCase() ?? '';

      if (normalBalance != 'DEBIT' && normalBalance != 'CREDIT') {
        continue;
      }

      double opening = _toDouble(account['account_opening']);

      // System AR opening comes from customers.
      if (accountType == 'CUSTOMER_RECEIVABLE') {
        final result = await db.rawQuery('''
          SELECT
            COALESCE(SUM(opening_balance), 0)
              AS total
          FROM customers
        ''');

        opening = _toDouble(result.first['total']);
      }

      // System AP opening comes from suppliers.
      if (accountType == 'SUPPLIER_PAYABLE') {
        final result = await db.rawQuery('''
          SELECT
            COALESCE(SUM(opening_balance), 0)
              AS total
          FROM suppliers
        ''');

        opening = _toDouble(result.first['total']);
      }

      double beforeDebit = 0;
      double beforeCredit = 0;
      double periodDebit = 0;
      double periodCredit = 0;

      final journalRows = await db.rawQuery(
        '''
        SELECT
          je.transaction_date,
          jl.debit,
          jl.credit
        FROM journal_lines jl
        INNER JOIN journal_entries je
          ON je.id = jl.journal_id
        WHERE jl.account_id = ?
          ${toDate != null ? 'AND je.transaction_date <= ?' : ''}
        ORDER BY je.transaction_date, jl.id
        ''',
        [accountId, if (toDate != null) toDate],
      );

      for (final journalRow in journalRows) {
        final date = journalRow['transaction_date']?.toString() ?? '';

        final debit = _toDouble(journalRow['debit']);

        final credit = _toDouble(journalRow['credit']);

        if (fromDate != null && date.compareTo(fromDate) < 0) {
          beforeDebit += debit;
          beforeCredit += credit;
        } else {
          periodDebit += debit;
          periodCredit += credit;
        }
      }

      // Opening for the selected period =
      // brought-forward master opening
      // + FF movement before fromDate.
      double openingSigned;

      if (normalBalance == 'DEBIT') {
        openingSigned = opening + beforeDebit - beforeCredit;
      } else {
        openingSigned = opening + beforeCredit - beforeDebit;
      }

      double openingDebit = 0;
      double openingCredit = 0;

      if (openingSigned >= 0) {
        if (normalBalance == 'DEBIT') {
          openingDebit = openingSigned;
        } else {
          openingCredit = openingSigned;
        }
      } else {
        if (normalBalance == 'DEBIT') {
          openingCredit = -openingSigned;
        } else {
          openingDebit = -openingSigned;
        }
      }

      final closingNet =
          openingDebit - openingCredit + periodDebit - periodCredit;

      final closingDebit = closingNet > 0 ? closingNet : 0.0;

      final closingCredit = closingNet < 0 ? -closingNet : 0.0;

      final hasValue =
          openingDebit.abs() > 0.000001 ||
          openingCredit.abs() > 0.000001 ||
          periodDebit.abs() > 0.000001 ||
          periodCredit.abs() > 0.000001 ||
          closingDebit.abs() > 0.000001 ||
          closingCredit.abs() > 0.000001;

      if (!hasValue) {
        continue;
      }

      rows.add(
        FFTrialBalanceRow(
          accountId: accountId,
          accountName: account['name']?.toString() ?? '',
          accountType: accountType,
          groupName: account['group_name']?.toString() ?? '',
          groupKind: account['group_kind']?.toString() ?? '',
          normalBalance: normalBalance,
          openingDebit: openingDebit,
          openingCredit: openingCredit,
          periodDebit: periodDebit,
          periodCredit: periodCredit,
          closingDebit: closingDebit,
          closingCredit: closingCredit,
        ),
      );

      totalOpeningDebit += openingDebit;
      totalOpeningCredit += openingCredit;
      totalPeriodDebit += periodDebit;
      totalPeriodCredit += periodCredit;
      totalClosingDebit += closingDebit;
      totalClosingCredit += closingCredit;
    }

    return FFTrialBalanceReport(
      rows: rows,
      openingDebit: totalOpeningDebit,
      openingCredit: totalOpeningCredit,
      periodDebit: totalPeriodDebit,
      periodCredit: totalPeriodCredit,
      closingDebit: totalClosingDebit,
      closingCredit: totalClosingCredit,
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
