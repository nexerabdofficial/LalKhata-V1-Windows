import 'package:flutter/material.dart';

import '../../gab/gab_branding.dart';
import '../../services/profit_repository.dart';
import 'profit_loss_preview_screen.dart';

class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen> {
  final ProfitRepository _repository = ProfitRepository();

  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _toDate = DateTime.now();

  FFProfitStatement? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final to = DateTime(
        _toDate.year,
        _toDate.month,
        _toDate.day,
        23,
        59,
        59,
        999,
      );

      final report = await _repository.getProfitStatement(
        from: _fromDate,
        to: to,
      );

      if (!mounted) return;

      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load Profit & Loss: $e')),
      );
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    if (picked.isAfter(_toDate)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('From date cannot be later than To date.'),
        ),
      );
      return;
    }

    _fromDate = picked;
    await _load();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    if (picked.isBefore(_fromDate)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('To date cannot be earlier than From date.'),
        ),
      );
      return;
    }

    _toDate = picked;
    await _load();
  }

  // ============================================================
  // FORMAT
  // ============================================================

  String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _money(double value) {
    final amount = value.abs().toStringAsFixed(2);

    return value < 0 ? '-৳ $amount' : '৳ $amount';
  }

  bool _visible(double value) => value.abs() > 0.000001;

  // ============================================================
  // ERP ROWS
  // ============================================================

  Widget _accountRow(
    String title,
    double amount, {
    bool strong = false,
    bool indent = true,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 22 : 12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: strong ? 13.5 : 12.5,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _money(amount),
            style: TextStyle(
              fontSize: strong ? 13.5 : 12.5,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupRow(String title, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xffeef4e8),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            _money(amount),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String title, double amount) {
    final positive = amount >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: positive ? const Color(0xffedf7ef) : const Color(0xffffeeee),
        border: Border(
          top: BorderSide(color: Colors.grey.shade400),
          bottom: BorderSide(color: Colors.grey.shade400),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            _money(amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: positive ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LEFT — REVENUE / PROFIT
  // ============================================================

  Widget _incomePanel(FFProfitStatement report) {
    final salesAccounts = report.incomeAccounts
        .where((e) => e.groupCode == 'SALES_INCOME' && _visible(e.amount))
        .toList();

    final otherIncomeAccounts = report.incomeAccounts
        .where((e) => e.groupCode != 'SALES_INCOME' && _visible(e.amount))
        .toList();

    return _panel(
      title: 'CREDIT',
      total: report.salesIncome + report.closingStock + report.otherIncome,
      children: [
        _groupRow('Sales Accounts', report.salesIncome),

        if (salesAccounts.isEmpty)
          _accountRow('Sales Income', report.salesIncome)
        else
          ...salesAccounts.map(
            (row) => _accountRow(row.accountName, row.amount),
          ),

        _groupRow('Closing Stock', report.closingStock),
        _accountRow('Inventory / Stock', report.closingStock),

        const SizedBox(height: 8),

        _groupRow('Gross Profit b/f', report.grossProfit),

        if (_visible(report.otherIncome) || otherIncomeAccounts.isNotEmpty) ...[
          _groupRow('Other Income', report.otherIncome),
          if (otherIncomeAccounts.isEmpty)
            _accountRow('Other Income', report.otherIncome)
          else
            ...otherIncomeAccounts.map(
              (row) => _accountRow(row.accountName, row.amount),
            ),
        ],

        const Spacer(),

        if (report.netProfit < 0)
          _resultRow('NET LOSS', report.netProfit.abs()),
      ],
    );
  }

  // ============================================================
  // RIGHT — COST / EXPENSE
  // ============================================================

  Widget _expensePanel(FFProfitStatement report) {
    final expenses = report.expenseAccounts
        .where((e) => e.groupCode != 'COST_OF_GOODS_SOLD' && _visible(e.amount))
        .toList();

    return _panel(
      title: 'DEBIT',
      total:
          report.openingStock +
          report.purchaseAccounts +
          report.operatingExpenses,
      children: [
        _groupRow('Opening Stock', report.openingStock),
        _accountRow('Inventory / Stock', report.openingStock),

        _groupRow('Purchase Accounts', report.purchaseAccounts),
        _accountRow('Purchases', report.purchaseAccounts),

        const SizedBox(height: 8),

        _groupRow('Gross Profit c/o', report.grossProfit),

        _groupRow(
          'Office / Administrative & Other Expenses',
          report.operatingExpenses,
        ),

        if (expenses.isEmpty)
          _accountRow('Operating Expenses', report.operatingExpenses)
        else
          ...expenses.map((row) => _accountRow(row.accountName, row.amount)),

        const Spacer(),

        if (report.netProfit >= 0) _resultRow('NET PROFIT', report.netProfit),
      ],
    );
  }

  Widget _miniSummary(String title, double value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          _money(value),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  // ============================================================
  // PANEL
  // ============================================================

  Widget _panel({
    required String title,
    required double total,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            color: const Color(0xff173f35),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _money(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // TALLY-STYLE TRADING + PROFIT & LOSS
  // ============================================================

  Widget _tallySide({
    required String heading,
    required List<Widget> children,
    required double total,
    bool mobile = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xff173f35),
            child: Text(
              heading,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...children,
          if (!mobile) const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xfff3f5ef),
              border: Border(top: BorderSide(color: Colors.grey.shade400)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'TOTAL',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _money(total),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tradingDebit(FFProfitStatement report, {bool mobile = false}) {
    final tradingTotal = report.salesIncome + report.closingStock;

    return _tallySide(
      heading: 'DEBIT',
      total: tradingTotal,
      mobile: mobile,
      children: [
        _groupRow('Opening Stock', report.openingStock),
        if (_visible(report.openingStock))
          _accountRow('Inventory / Stock', report.openingStock),

        _groupRow('Purchase Accounts', report.purchaseAccounts),
        if (_visible(report.purchaseAccounts))
          _accountRow('Purchases', report.purchaseAccounts),

        if (report.grossProfit >= 0)
          _groupRow('Gross Profit c/o', report.grossProfit)
        else
          _groupRow('Gross Loss c/o', report.grossProfit.abs()),
      ],
    );
  }

  Widget _tradingCredit(FFProfitStatement report, {bool mobile = false}) {
    final salesAccounts = report.incomeAccounts
        .where((e) => e.groupCode == 'SALES_INCOME' && _visible(e.amount))
        .toList();

    final tradingTotal = report.salesIncome + report.closingStock;

    return _tallySide(
      heading: 'CREDIT',
      total: tradingTotal,
      mobile: mobile,
      children: [
        _groupRow('Sales Accounts', report.salesIncome),

        if (salesAccounts.isEmpty)
          _accountRow('Sales Income', report.salesIncome)
        else
          ...salesAccounts.map(
            (row) => _accountRow(row.accountName, row.amount),
          ),

        _groupRow('Closing Stock', report.closingStock),
        if (_visible(report.closingStock))
          _accountRow('Inventory / Stock', report.closingStock),

        if (report.grossProfit < 0)
          _groupRow('Gross Loss c/o', report.grossProfit.abs()),
      ],
    );
  }

  Widget _profitLossDebit(FFProfitStatement report, {bool mobile = false}) {
    final expenses = report.expenseAccounts
        .where((e) => e.groupCode != 'COST_OF_GOODS_SOLD' && _visible(e.amount))
        .toList();

    final creditBase =
        (report.grossProfit > 0 ? report.grossProfit : 0) + report.otherIncome;

    final debitBase =
        report.operatingExpenses +
        (report.grossProfit < 0 ? report.grossProfit.abs() : 0);

    final netProfit = creditBase > debitBase ? creditBase - debitBase : 0.0;

    final sectionTotal = creditBase > debitBase ? creditBase : debitBase;

    return _tallySide(
      heading: 'DEBIT',
      total: sectionTotal,
      mobile: mobile,
      children: [
        if (report.grossProfit < 0)
          _groupRow('Gross Loss b/f', report.grossProfit.abs()),

        _groupRow(
          'Office / Administrative & Other Expenses',
          report.operatingExpenses,
        ),

        if (expenses.isEmpty && _visible(report.operatingExpenses))
          _accountRow('Operating Expenses', report.operatingExpenses)
        else
          ...expenses.map((row) => _accountRow(row.accountName, row.amount)),

        if (_visible(netProfit)) _resultRow('NET PROFIT', netProfit),
      ],
    );
  }

  Widget _profitLossCredit(FFProfitStatement report, {bool mobile = false}) {
    final otherIncomeAccounts = report.incomeAccounts
        .where((e) => e.groupCode != 'SALES_INCOME' && _visible(e.amount))
        .toList();

    final creditBase =
        (report.grossProfit > 0 ? report.grossProfit : 0) + report.otherIncome;

    final debitBase =
        report.operatingExpenses +
        (report.grossProfit < 0 ? report.grossProfit.abs() : 0);

    final netLoss = debitBase > creditBase ? debitBase - creditBase : 0.0;

    final sectionTotal = creditBase > debitBase ? creditBase : debitBase;

    return _tallySide(
      heading: 'CREDIT',
      total: sectionTotal,
      mobile: mobile,
      children: [
        if (report.grossProfit > 0)
          _groupRow('Gross Profit b/f', report.grossProfit),

        if (_visible(report.otherIncome) || otherIncomeAccounts.isNotEmpty) ...[
          _groupRow('Other Income', report.otherIncome),

          if (otherIncomeAccounts.isEmpty)
            _accountRow('Other Income', report.otherIncome)
          else
            ...otherIncomeAccounts.map(
              (row) => _accountRow(row.accountName, row.amount),
            ),
        ],

        if (_visible(netLoss)) _resultRow('NET LOSS', netLoss),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xff173f35),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  GABBranding.businessName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff173f35),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Profit & Loss Statement',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          OutlinedButton.icon(
            onPressed: _pickFrom,
            icon: const Icon(Icons.calendar_month_outlined, size: 17),
            label: Text('From  ${_date(_fromDate)}'),
          ),

          const SizedBox(width: 8),

          OutlinedButton.icon(
            onPressed: _pickTo,
            icon: const Icon(Icons.calendar_month_outlined, size: 17),
            label: Text('To  ${_date(_toDate)}'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE-ONLY HEADER
  // Desktop _header() is intentionally untouched.
  // ============================================================

  Widget _mobileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            GABBranding.businessName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xff173f35),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Profit & Loss Statement',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickFrom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('From', style: TextStyle(fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        _date(_fromDate),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickTo,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('To', style: TextStyle(fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        _date(_toDate),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileReportTitle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: const Color(0xff173f35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROFIT & LOSS ACCOUNT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${_date(_fromDate)}  to  ${_date(_toDate)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileIncomePanel(FFProfitStatement report) {
    final salesAccounts = report.incomeAccounts
        .where((e) => e.groupCode == 'SALES_INCOME' && _visible(e.amount))
        .toList();

    final otherIncomeAccounts = report.incomeAccounts
        .where((e) => e.groupCode != 'SALES_INCOME' && _visible(e.amount))
        .toList();

    return _panel(
      title: 'CREDIT',
      total: report.salesIncome + report.closingStock + report.otherIncome,
      children: [
        _groupRow('Sales Accounts', report.salesIncome),

        if (salesAccounts.isEmpty)
          _accountRow('Sales Income', report.salesIncome)
        else
          ...salesAccounts.map(
            (row) => _accountRow(row.accountName, row.amount),
          ),

        _groupRow('Closing Stock', report.closingStock),
        _accountRow('Inventory / Stock', report.closingStock),

        const SizedBox(height: 8),

        _groupRow('Gross Profit b/f', report.grossProfit),

        if (_visible(report.otherIncome) || otherIncomeAccounts.isNotEmpty) ...[
          _groupRow('Other Income', report.otherIncome),
          if (otherIncomeAccounts.isEmpty)
            _accountRow('Other Income', report.otherIncome)
          else
            ...otherIncomeAccounts.map(
              (row) => _accountRow(row.accountName, row.amount),
            ),
        ],

        if (report.netProfit < 0)
          _resultRow('NET LOSS', report.netProfit.abs()),
      ],
    );
  }

  Widget _mobileExpensePanel(FFProfitStatement report) {
    final expenses = report.expenseAccounts
        .where((e) => e.groupCode != 'COST_OF_GOODS_SOLD' && _visible(e.amount))
        .toList();

    return _panel(
      title: 'DEBIT',
      total:
          report.openingStock +
          report.purchaseAccounts +
          report.operatingExpenses,
      children: [
        _groupRow('Opening Stock', report.openingStock),
        _accountRow('Inventory / Stock', report.openingStock),

        _groupRow('Purchase Accounts', report.purchaseAccounts),
        _accountRow('Purchases', report.purchaseAccounts),

        const SizedBox(height: 8),

        _groupRow('Gross Profit c/o', report.grossProfit),

        _groupRow(
          'Office / Administrative & Other Expenses',
          report.operatingExpenses,
        ),

        if (expenses.isEmpty)
          _accountRow('Operating Expenses', report.operatingExpenses)
        else
          ...expenses.map((row) => _accountRow(row.accountName, row.amount)),

        if (report.netProfit >= 0) _resultRow('NET PROFIT', report.netProfit),
      ],
    );
  }

  Widget _mobileProfitLoss(FFProfitStatement report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _mobileHeader(),
        const SizedBox(height: 8),

        _sectionTitle('TRADING ACCOUNT'),
        const SizedBox(height: 2),
        _tradingDebit(report, mobile: true),
        const SizedBox(height: 4),
        _tradingCredit(report, mobile: true),

        const SizedBox(height: 10),

        _sectionTitle('PROFIT & LOSS ACCOUNT'),
        const SizedBox(height: 2),
        _profitLossDebit(report, mobile: true),
        const SizedBox(height: 4),
        _profitLossCredit(report, mobile: true),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      backgroundColor: const Color(0xfff6f4e8),
      appBar: AppBar(
        title: const Text(
          'Profit & Loss',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'PDF Preview',
            onPressed: _loading || report == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfitLossPreviewScreen(
                          from: _fromDate,
                          to: _toDate,
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : report == null
          ? const Center(child: Text('No Profit & Loss data.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 700) {
                  return RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      children: [
                        _mobileProfitLoss(report),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: report.netProfit >= 0
                                ? const Color(0xffedf7ef)
                                : const Color(0xffffeeee),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.netProfit >= 0
                                    ? 'Net Profit for the selected period'
                                    : 'Net Loss for the selected period',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _money(report.netProfit),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                }

                // DESKTOP / PC:
                // Original layout below is intentionally unchanged.
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(14),
                    children: [
                      _header(),

                      const SizedBox(height: 8),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        color: const Color(0xff173f35),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'PROFIT & LOSS ACCOUNT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${_date(_fromDate)}  to  ${_date(_toDate)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 2),

                      _sectionTitle('TRADING ACCOUNT'),

                      const SizedBox(height: 2),

                      SizedBox(
                        height: 280,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _tradingDebit(report)),
                            const SizedBox(width: 2),
                            Expanded(child: _tradingCredit(report)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      _sectionTitle('PROFIT & LOSS ACCOUNT'),

                      const SizedBox(height: 2),

                      SizedBox(
                        height: 280,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _profitLossDebit(report)),
                            const SizedBox(width: 2),
                            Expanded(child: _profitLossCredit(report)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: report.netProfit >= 0
                              ? const Color(0xffedf7ef)
                              : const Color(0xffffeeee),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                report.netProfit >= 0
                                    ? 'Net Profit for the selected period'
                                    : 'Net Loss for the selected period',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              _money(report.netProfit),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
