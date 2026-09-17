import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

enum AuditStatus { pass, warning, error }

class AuditFinding {
  final String code;
  final String category;
  final AuditStatus status;
  final String title;
  final String message;
  final double? expected;
  final double? actual;
  final List<String> details;

  const AuditFinding({
    required this.code,
    required this.category,
    required this.status,
    required this.title,
    required this.message,
    this.expected,
    this.actual,
    this.details = const [],
  });
}

class InternalAuditService {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<Database> get _db => _databaseHelper.database;

  // ============================================================
  // RUN FULL INTERNAL AUDIT
  //
  // READ-ONLY.
  // This service NEVER changes business data.
  // ============================================================

  Future<List<AuditFinding>> runFullAudit() async {
    final findings = <AuditFinding>[];

    findings.addAll(await _auditGeneralIntegrity());
    findings.addAll(await _auditIncomeExpense());
    findings.addAll(await _auditSupplierPayments());
    findings.addAll(await _auditSales());
    findings.addAll(await _auditPurchases());
    findings.addAll(await _auditProduction());
    findings.addAll(await _auditFundTransfers());
    findings.addAll(await _auditStock());
    findings.addAll(await _auditAccounts());
    findings.addAll(await _auditCustomerSupplierBalances());

    return findings;
  }

  // ============================================================
  // #0 GENERAL DATABASE INTEGRITY
  // ============================================================

  Future<List<AuditFinding>> _auditGeneralIntegrity() async {
    final db = await _db;
    final findings = <AuditFinding>[];

    final integrity = await db.rawQuery('PRAGMA integrity_check');

    final integrityValue = integrity.isNotEmpty
        ? integrity.first.values.first
        : null;

    if (integrityValue == 'ok') {
      findings.add(
        const AuditFinding(
          code: 'DB_INTEGRITY',
          category: 'General',
          status: AuditStatus.pass,
          title: 'Database integrity',
          message: 'SQLite integrity check passed.',
        ),
      );
    } else {
      findings.add(
        AuditFinding(
          code: 'DB_INTEGRITY',
          category: 'General',
          status: AuditStatus.error,
          title: 'Database integrity',
          message: 'SQLite integrity check failed: $integrityValue',
        ),
      );
    }

    final negativeStock = await db.rawQuery('''
      SELECT id, name, stock, stock_value
      FROM products
      WHERE stock < 0
         OR stock_value < 0
      ORDER BY id
    ''');

    findings.add(
      AuditFinding(
        code: 'NEGATIVE_STOCK',
        category: 'General',
        status: negativeStock.isEmpty ? AuditStatus.pass : AuditStatus.error,
        title: 'Negative stock/value',
        message: negativeStock.isEmpty
            ? 'No product has negative stock or stock value.'
            : '${negativeStock.length} product(s) have negative stock or stock value.',
        details: negativeStock.map((row) {
          return '${row['name']} — stock: ${row['stock']}, '
              'stock value: ${row['stock_value']}';
        }).toList(),
      ),
    );

    return findings;
  }

  // ============================================================
  // #1 INCOME / EXPENSE
  // ============================================================

  Future<List<AuditFinding>> _auditIncomeExpense() async {
    final db = await _db;
    final findings = <AuditFinding>[];

    final incomeNegative = await db.rawQuery('''
      SELECT id, amount
      FROM incomes
      WHERE amount < 0
      ORDER BY id
    ''');

    final expenseNegative = await db.rawQuery('''
      SELECT id, amount
      FROM expenses
      WHERE amount < 0
      ORDER BY id
    ''');

    final details = <String>[
      ...incomeNegative.map(
        (row) => 'Income #${row['id']} — amount: ${row['amount']}',
      ),
      ...expenseNegative.map(
        (row) => 'Expense #${row['id']} — amount: ${row['amount']}',
      ),
    ];

    final problemCount = incomeNegative.length + expenseNegative.length;

    findings.add(
      AuditFinding(
        code: 'INCOME_EXPENSE_VALUES',
        category: 'Income/Expense',
        status: problemCount == 0 ? AuditStatus.pass : AuditStatus.error,
        title: 'Income/expense values',
        message: problemCount == 0
            ? 'Income and expense amounts are valid.'
            : '$problemCount invalid income/expense record(s) found.',
        details: details,
      ),
    );

    return findings;
  }

  // ============================================================
  // #2 SUPPLIER PAYMENT
  // ============================================================

  Future<List<AuditFinding>> _auditSupplierPayments() async {
    final db = await _db;
    final findings = <AuditFinding>[];

    final orphanSupplier = await db.rawQuery('''
      SELECT
        sp.id,
        sp.supplier_id,
        sp.amount
      FROM supplier_payments sp
      LEFT JOIN suppliers s ON s.id = sp.supplier_id
      WHERE s.id IS NULL
      ORDER BY sp.id
    ''');

    final orphanAccount = await db.rawQuery('''
      SELECT
        sp.id,
        sp.account_id,
        sp.amount
      FROM supplier_payments sp
      LEFT JOIN accounts a ON a.id = sp.account_id
      WHERE sp.account_id IS NOT NULL
        AND a.id IS NULL
      ORDER BY sp.id
    ''');

    final invalidAmount = await db.rawQuery('''
      SELECT id, amount
      FROM supplier_payments
      WHERE amount <= 0
      ORDER BY id
    ''');

    final details = <String>[
      ...orphanSupplier.map(
        (row) =>
            'Payment #${row['id']} — missing supplier #${row['supplier_id']}, '
            'amount: ${row['amount']}',
      ),
      ...orphanAccount.map(
        (row) =>
            'Payment #${row['id']} — missing account #${row['account_id']}, '
            'amount: ${row['amount']}',
      ),
      ...invalidAmount.map(
        (row) => 'Payment #${row['id']} — invalid amount: ${row['amount']}',
      ),
    ];

    final problems =
        orphanSupplier.length + orphanAccount.length + invalidAmount.length;

    findings.add(
      AuditFinding(
        code: 'SUPPLIER_PAYMENT_INTEGRITY',
        category: 'Supplier Payment',
        status: problems == 0 ? AuditStatus.pass : AuditStatus.error,
        title: 'Supplier payment integrity',
        message: problems == 0
            ? 'Supplier payments have valid references and amounts.'
            : '$problems supplier payment issue(s) found.',
        details: details,
      ),
    );

    return findings;
  }

  // ============================================================
  // #3 SALES
  // ============================================================

  Future<List<AuditFinding>> _auditSales() async {
    final db = await _db;
    final findings = <AuditFinding>[];

    final orphanItems = await db.rawQuery('''
      SELECT
        si.id,
        si.sale_id
      FROM sale_items si
      LEFT JOIN sales s ON s.id = si.sale_id
      WHERE s.id IS NULL
      ORDER BY si.id
    ''');

    final orphanCustomer = await db.rawQuery('''
      SELECT
        s.id,
        s.customer_id,
        s.grand_total
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE c.id IS NULL
      ORDER BY s.id
    ''');

    final totalsMismatch = await db.rawQuery('''
      SELECT
        id,
        grand_total,
        paid,
        due
      FROM sales
      WHERE ABS(
        grand_total - (paid + due)
      ) > 0.01
      ORDER BY id
    ''');

    final details = <String>[
      ...orphanItems.map(
        (row) => 'Sale item #${row['id']} — missing sale #${row['sale_id']}',
      ),
      ...orphanCustomer.map(
        (row) =>
            'Sale #${row['id']} — missing customer #${row['customer_id']}, '
            'total: ${row['grand_total']}',
      ),
      ...totalsMismatch.map(
        (row) =>
            'Sale #${row['id']} — total: ${row['grand_total']}, '
            'paid: ${row['paid']}, due: ${row['due']}',
      ),
    ];

    final problems =
        orphanItems.length + orphanCustomer.length + totalsMismatch.length;

    findings.add(
      AuditFinding(
        code: 'SALES_INTEGRITY',
        category: 'Sales',
        status: problems == 0 ? AuditStatus.pass : AuditStatus.error,
        title: 'Sales integrity',
        message: problems == 0
            ? 'Sales references and payment totals are consistent.'
            : '$problems sales issue(s) found.',
        details: details,
      ),
    );

    return findings;
  }

  // ============================================================
  // #4 PURCHASES
  // ============================================================

  Future<List<AuditFinding>> _auditPurchases() async {
    final db = await _db;
    final findings = <AuditFinding>[];

    final orphanItems = await db.rawQuery('''
      SELECT
        pi.id,
        pi.purchase_id
      FROM purchase_items pi
      LEFT JOIN purchases p ON p.id = pi.purchase_id
      WHERE p.id IS NULL
      ORDER BY pi.id
    ''');

    final orphanSupplier = await db.rawQuery('''
      SELECT
        p.id,
        p.supplier_id,
        p.grand_total
      FROM purchases p
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      WHERE s.id IS NULL
      ORDER BY p.id
    ''');

    final totalsMismatch = await db.rawQuery('''
      SELECT
        id,
        grand_total,
        paid,
        due
      FROM purchases
      WHERE ABS(
        grand_total - (paid + due)
      ) > 0.01
      ORDER BY id
    ''');

    final details = <String>[
      ...orphanItems.map(
        (row) =>
            'Purchase item #${row['id']} — missing purchase #${row['purchase_id']}',
      ),
      ...orphanSupplier.map(
        (row) =>
            'Purchase #${row['id']} — missing supplier #${row['supplier_id']}, '
            'total: ${row['grand_total']}',
      ),
      ...totalsMismatch.map(
        (row) =>
            'Purchase #${row['id']} — total: ${row['grand_total']}, '
            'paid: ${row['paid']}, due: ${row['due']}',
      ),
    ];

    final problems =
        orphanItems.length + orphanSupplier.length + totalsMismatch.length;

    findings.add(
      AuditFinding(
        code: 'PURCHASE_INTEGRITY',
        category: 'Purchase',
        status: problems == 0 ? AuditStatus.pass : AuditStatus.error,
        title: 'Purchase integrity',
        message: problems == 0
            ? 'Purchase references and payment totals are consistent.'
            : '$problems purchase issue(s) found.',
        details: details,
      ),
    );

    return findings;
  }

  // ============================================================
  // #5 PRODUCTION
  // ============================================================

  Future<List<AuditFinding>> _auditProduction() async {
    final db = await _db;
    final findings = <AuditFinding>[];

    final orphanItems = await db.rawQuery('''
      SELECT
        pi.id,
        pi.production_id
      FROM production_items pi
      LEFT JOIN productions p ON p.id = pi.production_id
      WHERE p.id IS NULL
      ORDER BY pi.id
    ''');

    final orphanCosts = await db.rawQuery('''
      SELECT
        pc.id,
        pc.production_id
      FROM production_costs pc
      LEFT JOIN productions p ON p.id = pc.production_id
      WHERE p.id IS NULL
      ORDER BY pc.id
    ''');

    final orphanOutput = await db.rawQuery('''
      SELECT
        p.id,
        p.production_no,
        p.product_id,
        p.quantity
      FROM productions p
      LEFT JOIN products pr ON pr.id = p.product_id
      WHERE pr.id IS NULL
      ORDER BY p.id
    ''');

    final details = <String>[
      ...orphanItems.map(
        (row) =>
            'Production item #${row['id']} — missing production #${row['production_id']}',
      ),
      ...orphanCosts.map(
        (row) =>
            'Production cost #${row['id']} — missing production #${row['production_id']}',
      ),
      ...orphanOutput.map(
        (row) =>
            'Production #${row['id']} (${row['production_no'] ?? ''}) — '
            'missing finished product #${row['product_id']}, '
            'quantity: ${row['quantity']}',
      ),
    ];

    final problems =
        orphanItems.length + orphanCosts.length + orphanOutput.length;

    findings.add(
      AuditFinding(
        code: 'PRODUCTION_INTEGRITY',
        category: 'Production',
        status: problems == 0 ? AuditStatus.pass : AuditStatus.error,
        title: 'Production integrity',
        message: problems == 0
            ? 'Production references are consistent.'
            : '$problems production issue(s) found.',
        details: details,
      ),
    );

    return findings;
  }

  // ============================================================
  // #6 FUND TRANSFER
  // ============================================================

  Future<List<AuditFinding>> _auditFundTransfers() async {
    final db = await _db;
    final findings = <AuditFinding>[];

    final transfers = await db.rawQuery('''
      SELECT
        COUNT(*) AS count,
        COALESCE(SUM(debit), 0) AS debit,
        COALESCE(SUM(credit), 0) AS credit
      FROM account_transactions
      WHERE transaction_type IN (
        'FUND_TRANSFER_IN',
        'FUND_TRANSFER_OUT'
      )
    ''');

    final count = _toInt(transfers.first['count']);
    final debit = _toDouble(transfers.first['debit']);
    final credit = _toDouble(transfers.first['credit']);

    final valid = (debit - credit).abs() <= 0.01;

    findings.add(
      AuditFinding(
        code: 'FUND_TRANSFER_INTEGRITY',
        category: 'Fund Transfer',
        status: valid ? AuditStatus.pass : AuditStatus.error,
        title: 'Fund transfer integrity',
        message: valid
            ? 'Fund transfer debit and credit totals balance.'
            : 'Fund transfer debit/credit totals do not balance.',
        expected: credit,
        actual: debit,
        details: valid
            ? [
                'Transfer records: $count',
                'Debit total: $debit',
                'Credit total: $credit',
              ]
            : [
                'Transfer records: $count',
                'Expected debit: $credit',
                'Actual debit: $debit',
                'Difference: ${debit - credit}',
              ],
      ),
    );

    return findings;
  }

  // ============================================================
  // #7 STOCK RECONSTRUCTION
  //
  // Opening + Purchase + Production Output
  // - Sales - Production Consumption
  //
  // WARNING only for historical mismatches.
  // ============================================================

  Future<List<AuditFinding>> _auditStock() async {
    final db = await _db;
    final findings = <AuditFinding>[];

    final rows = await db.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.stock AS stored_stock,

        COALESCE((
          SELECT SUM(quantity)
          FROM opening_stock_entries o
          WHERE o.product_id = p.id
        ), 0) AS opening_qty,

        COALESCE((
          SELECT SUM(pi.qty)
          FROM purchase_items pi
          INNER JOIN purchases pu
            ON pu.id = pi.purchase_id
          WHERE pi.product_id = p.id
        ), 0) AS purchase_qty,

        COALESCE((
          SELECT SUM(pr.quantity)
          FROM productions pr
          WHERE pr.product_id = p.id
        ), 0) AS production_qty,

        COALESCE((
          SELECT SUM(si.qty)
          FROM sale_items si
          INNER JOIN sales s
            ON s.id = si.sale_id
          WHERE si.product_id = p.id
        ), 0) AS sales_qty,

        COALESCE((
          SELECT SUM(pi.quantity)
          FROM production_items pi
          WHERE pi.material_product_id = p.id
        ), 0) AS consumed_qty

      FROM products p
      ORDER BY p.id
    ''');

    final mismatchDetails = <String>[];

    for (final row in rows) {
      final stored = _toDouble(row['stored_stock']);
      final opening = _toDouble(row['opening_qty']);
      final purchased = _toDouble(row['purchase_qty']);
      final produced = _toDouble(row['production_qty']);
      final sold = _toDouble(row['sales_qty']);
      final consumed = _toDouble(row['consumed_qty']);

      final reconstructed = opening + purchased + produced - sold - consumed;

      final difference = stored - reconstructed;

      if (difference.abs() > 0.01) {
        mismatchDetails.add(
          'Product: ${row['name']} | '
          'Expected: ${_formatNumber(reconstructed)} | '
          'Actual: ${_formatNumber(stored)} | '
          'Difference: ${_formatSigned(difference)} | '
          'Opening: ${_formatNumber(opening)}, '
          'Purchased: ${_formatNumber(purchased)}, '
          'Produced: ${_formatNumber(produced)}, '
          'Sold: ${_formatNumber(sold)}, '
          'Consumed: ${_formatNumber(consumed)}',
        );
      }
    }

    findings.add(
      AuditFinding(
        code: 'STOCK_RECONSTRUCTION',
        category: 'Stock',
        status: mismatchDetails.isEmpty
            ? AuditStatus.pass
            : AuditStatus.warning,
        title: 'Stock reconstruction',
        message: mismatchDetails.isEmpty
            ? 'Stored stock matches reconstructed stock.'
            : '${mismatchDetails.length} product(s) have historical stock mismatch.',
        details: mismatchDetails,
      ),
    );

    return findings;
  }

  // ============================================================
  // #8 ACCOUNT INTEGRITY
  // ============================================================

  Future<List<AuditFinding>> _auditAccounts() async {
    final db = await _db;
    final findings = <AuditFinding>[];

    final rows = await db.rawQuery('''
      SELECT
        a.id,
        a.name,
        a.balance AS stored_balance,
        a.opening_balance,

        COALESCE((
          SELECT SUM(at.credit - at.debit)
          FROM account_transactions at
          WHERE at.account_id = a.id
            AND at.transaction_type NOT IN (
              'OPENING_BALANCE',
              'OPENING'
            )
        ), 0) AS movement

      FROM accounts a
      ORDER BY a.id
    ''');

    final mismatchDetails = <String>[];

    for (final row in rows) {
      final stored = _toDouble(row['stored_balance']);
      final opening = _toDouble(row['opening_balance']);
      final movement = _toDouble(row['movement']);

      final ledger = opening + movement;
      final difference = stored - ledger;

      if (difference.abs() > 0.01) {
        mismatchDetails.add(
          'Account: ${row['name']} | '
          'Expected ledger: ${_formatNumber(ledger)} | '
          'Stored: ${_formatNumber(stored)} | '
          'Difference: ${_formatSigned(difference)} | '
          'Opening: ${_formatNumber(opening)} | '
          'Movement: ${_formatSigned(movement)}',
        );
      }
    }

    findings.add(
      AuditFinding(
        code: 'ACCOUNT_INTEGRITY',
        category: 'Account',
        status: mismatchDetails.isEmpty
            ? AuditStatus.pass
            : AuditStatus.warning,
        title: 'Account balance integrity',
        message: mismatchDetails.isEmpty
            ? 'Stored account balances match ledger balances.'
            : '${mismatchDetails.length} account(s) have stored-vs-ledger mismatch.',
        details: mismatchDetails,
      ),
    );

    return findings;
  }

  // ============================================================
  // #9 CUSTOMER / SUPPLIER BALANCE RECONSTRUCTION
  // ============================================================

  Future<List<AuditFinding>> _auditCustomerSupplierBalances() async {
    final db = await _db;
    final findings = <AuditFinding>[];

    final customers = await db.rawQuery('''
      SELECT
        c.id,
        c.name,
        c.balance AS stored_balance,
        c.opening_balance,

        COALESCE((
          SELECT SUM(s.grand_total)
          FROM sales s
          WHERE s.customer_id = c.id
        ), 0) AS sales_total,

        COALESCE((
          SELECT SUM(cp.amount)
          FROM customer_payments cp
          WHERE cp.customer_id = c.id
        ), 0) AS payments_total

      FROM customers c
      ORDER BY c.id
    ''');

    final customerDetails = <String>[];

    for (final row in customers) {
      final stored = _toDouble(row['stored_balance']);
      final opening = _toDouble(row['opening_balance']);
      final sales = _toDouble(row['sales_total']);
      final payments = _toDouble(row['payments_total']);

      final reconstructed = opening + sales - payments;
      final difference = stored - reconstructed;

      if (difference.abs() > 0.01) {
        customerDetails.add(
          'Customer: ${row['name']} | '
          'Expected: ${_formatNumber(reconstructed)} | '
          'Stored: ${_formatNumber(stored)} | '
          'Difference: ${_formatSigned(difference)} | '
          'Opening: ${_formatNumber(opening)}, '
          'Sales: ${_formatNumber(sales)}, '
          'Payments: ${_formatNumber(payments)}',
        );
      }
    }

    final suppliers = await db.rawQuery('''
      SELECT
        s.id,
        s.name,
        s.balance AS stored_balance,
        s.opening_balance,

        COALESCE((
          SELECT SUM(p.grand_total)
          FROM purchases p
          WHERE p.supplier_id = s.id
        ), 0) AS purchase_total,

        COALESCE((
          SELECT SUM(sp.amount)
          FROM supplier_payments sp
          WHERE sp.supplier_id = s.id
        ), 0) AS payments_total

      FROM suppliers s
      ORDER BY s.id
    ''');

    final supplierDetails = <String>[];

    for (final row in suppliers) {
      final stored = _toDouble(row['stored_balance']);
      final opening = _toDouble(row['opening_balance']);
      final purchases = _toDouble(row['purchase_total']);
      final payments = _toDouble(row['payments_total']);

      final reconstructed = opening + purchases - payments;
      final difference = stored - reconstructed;

      if (difference.abs() > 0.01) {
        supplierDetails.add(
          'Supplier: ${row['name']} | '
          'Expected: ${_formatNumber(reconstructed)} | '
          'Stored: ${_formatNumber(stored)} | '
          'Difference: ${_formatSigned(difference)} | '
          'Opening: ${_formatNumber(opening)}, '
          'Purchases: ${_formatNumber(purchases)}, '
          'Payments: ${_formatNumber(payments)}',
        );
      }
    }

    findings.add(
      AuditFinding(
        code: 'CUSTOMER_BALANCE_RECONSTRUCTION',
        category: 'Customer',
        status: customerDetails.isEmpty
            ? AuditStatus.pass
            : AuditStatus.warning,
        title: 'Customer balance reconstruction',
        message: customerDetails.isEmpty
            ? 'Customer stored balances match reconstructed balances.'
            : '${customerDetails.length} customer(s) have historical balance mismatch.',
        details: customerDetails,
      ),
    );

    findings.add(
      AuditFinding(
        code: 'SUPPLIER_BALANCE_RECONSTRUCTION',
        category: 'Supplier',
        status: supplierDetails.isEmpty
            ? AuditStatus.pass
            : AuditStatus.warning,
        title: 'Supplier balance reconstruction',
        message: supplierDetails.isEmpty
            ? 'Supplier stored balances match reconstructed balances.'
            : '${supplierDetails.length} supplier(s) have historical balance mismatch.',
        details: supplierDetails,
      ),
    );

    return findings;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double _toDouble(Object? value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatSigned(double value) {
    final number = _formatNumber(value.abs());

    if (value > 0) {
      return '+$number';
    }

    if (value < 0) {
      return '-$number';
    }

    return '0';
  }
}
