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
      title: 'INCOME / REVENUE',
      total: report.totalIncome,
      children: [
        _groupRow('Sales / Operating Revenue', report.salesIncome),

        if (salesAccounts.isEmpty)
          _accountRow('Sales Income', report.salesIncome)
        else
          ...salesAccounts.map(
            (row) => _accountRow(row.accountName, row.amount),
          ),

        if (_visible(report.otherIncome) || otherIncomeAccounts.isNotEmpty) ...[
          _groupRow('Other Income', report.otherIncome),

          if (otherIncomeAccounts.isEmpty)
            _accountRow('Other Income', report.otherIncome)
          else
            ...otherIncomeAccounts.map(
              (row) => _accountRow(row.accountName, row.amount),
            ),
        ],

        _groupRow('Total Revenue', report.totalIncome),

        const SizedBox(height: 8),

        _groupRow('Gross Profit', report.grossProfit),

        _accountRow('Sales Revenue', report.salesIncome),

        _accountRow('Less: Cost of Goods Sold', -report.cogs),

        const Spacer(),

        _resultRow(
          report.netProfit >= 0 ? 'NET PROFIT' : 'NET LOSS',
          report.netProfit,
        ),
      ],
    );
  }

  // ============================================================
  // RIGHT — COST / EXPENSE
  // ============================================================

  Widget _expensePanel(FFProfitStatement report) {
    final expenses = report.expenseAccounts
        .where((e) => _visible(e.amount))
        .toList();

    return _panel(
      title: 'COST & EXPENSES',
      total: report.cogs + report.operatingExpenses,
      children: [
        _groupRow('Cost of Sales', report.cogs),

        _accountRow('Cost of Goods Sold', report.cogs),

        _groupRow('Operating Expenses', report.operatingExpenses),

        if (expenses.isEmpty)
          _accountRow('Operating Expenses', report.operatingExpenses)
        else
          ...expenses.map((row) => _accountRow(row.accountName, row.amount)),

        _groupRow(
          'Total Cost & Expenses',
          report.cogs + report.operatingExpenses,
        ),

        const Spacer(),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xfff3f5ef),
            border: Border(top: BorderSide(color: Colors.grey.shade400)),
          ),
          child: Column(
            children: [
              _miniSummary('Gross Profit', report.grossProfit),
              const SizedBox(height: 5),
              _miniSummary('Other Income', report.otherIncome),
              const SizedBox(height: 5),
              _miniSummary('Operating Expenses', report.operatingExpenses),
            ],
          ),
        ),
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

                      SizedBox(
                        height: constraints.maxHeight > 650
                            ? constraints.maxHeight - 180
                            : 620,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _incomePanel(report)),
                            const SizedBox(width: 2),
                            Expanded(child: _expensePanel(report)),
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
