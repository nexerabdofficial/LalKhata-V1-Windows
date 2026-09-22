import 'package:flutter/material.dart';

import '../../gab/gab_branding.dart';
import '../../services/ff/ff_balance_sheet_service.dart';
import 'balance_sheet_preview_screen.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  final FFBalanceSheetService _service = FFBalanceSheetService.instance;

  FFBalanceSheetReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBalanceSheet();
  }

  Future<void> _loadBalanceSheet() async {
    setState(() => _loading = true);

    try {
      final report = await _service.getReport();

      if (!mounted) return;

      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load Balance Sheet: $e')),
      );
    }
  }

  String _money(double value) {
    final negative = value < 0;
    final amount = value.abs().toStringAsFixed(2);

    return negative ? '-৳ $amount' : '৳ $amount';
  }

  bool _visible(double value) {
    return value.abs() > 0.000001;
  }

  // ============================================================
  // ERP CLASSIFICATION
  // ============================================================

  List<FFBalanceSheetRow> get _fixedAssets {
    final report = _report;
    if (report == null) return [];

    return report.assets.where((row) {
      return row.groupCode == 'FIXED_ASSETS' ||
          row.accountType == 'FIXED_ASSET';
    }).toList();
  }

  List<FFBalanceSheetRow> get _cashBankMfs {
    final report = _report;
    if (report == null) return [];

    return report.assets.where((row) {
      return row.groupCode == 'CASH' ||
          row.groupCode == 'BANK' ||
          row.groupCode == 'MFS' ||
          row.accountType == 'CASH' ||
          row.accountType == 'BANK' ||
          row.accountType == 'MOBILE_BANKING';
    }).toList();
  }

  List<FFBalanceSheetRow> get _receivables {
    final report = _report;
    if (report == null) return [];

    return report.assets.where((row) {
      return row.groupCode == 'CUSTOMER_RECEIVABLE' ||
          row.accountType == 'CUSTOMER' ||
          row.accountType == 'CUSTOMER_RECEIVABLE';
    }).toList();
  }

  List<FFBalanceSheetRow> get _loanReceivables {
    final report = _report;
    if (report == null) return [];

    return report.assets.where((row) {
      return row.groupCode == 'LOAN_RECEIVABLE' ||
          row.accountType == 'LOAN_RECEIVABLE';
    }).toList();
  }

  List<FFBalanceSheetRow> get _otherAssets {
    final report = _report;
    if (report == null) return [];

    final used = <int>{
      ..._fixedAssets.map((e) => e.accountId),
      ..._cashBankMfs.map((e) => e.accountId),
      ..._receivables.map((e) => e.accountId),
      ..._loanReceivables.map((e) => e.accountId),
    };

    return report.assets.where((row) {
      return row.accountType != 'INVENTORY' && !used.contains(row.accountId);
    }).toList();
  }

  List<FFBalanceSheetRow> get _supplierPayables {
    final report = _report;
    if (report == null) return [];

    return report.liabilities.where((row) {
      return row.groupCode == 'SUPPLIER_PAYABLE' ||
          row.accountType == 'SUPPLIER' ||
          row.accountType == 'SUPPLIER_PAYABLE';
    }).toList();
  }

  List<FFBalanceSheetRow> get _loanPayables {
    final report = _report;
    if (report == null) return [];

    return report.liabilities.where((row) {
      return row.groupCode == 'LOAN_PAYABLE' ||
          row.accountType == 'LOAN_PAYABLE';
    }).toList();
  }

  List<FFBalanceSheetRow> get _otherLiabilities {
    final report = _report;
    if (report == null) return [];

    final used = <int>{
      ..._supplierPayables.map((e) => e.accountId),
      ..._loanPayables.map((e) => e.accountId),
    };

    return report.liabilities
        .where((row) => !used.contains(row.accountId))
        .toList();
  }

  // ============================================================
  // ROW
  // ============================================================

  Widget _ledgerRow(
    String name,
    double amount, {
    bool strong = false,
    bool indent = true,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 18 : 10, 5, 10, 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
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

  Widget _groupTitle(String title, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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

  double _sum(List<FFBalanceSheetRow> rows) {
    return rows.fold<double>(0, (total, row) => total + row.balance);
  }

  Widget _rows(List<FFBalanceSheetRow> rows) {
    final visible = rows.where((e) => _visible(e.balance)).toList();

    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: visible
          .map((row) => _ledgerRow(row.accountName, row.balance))
          .toList(),
    );
  }

  // ============================================================
  // LEFT SIDE
  // ============================================================

  Widget _liabilitySide(FFBalanceSheetReport report) {
    final capitalRows = report.equity
        .where((e) => _visible(e.balance))
        .toList();

    final capitalValue = report.ledgerEquity + report.currentProfit;

    return _erpPanel(
      heading: 'CAPITAL & LIABILITIES',
      total: report.liabilitiesAndEquity,
      children: [
        _groupTitle('Capital & Reserves', capitalValue),

        _rows(capitalRows),

        if (_visible(report.currentProfit))
          _ledgerRow(
            report.currentProfit >= 0 ? 'Current Profit' : 'Current Loss',
            report.currentProfit,
          ),

        if (_loanPayables.any((e) => _visible(e.balance))) ...[
          _groupTitle('Loans', _sum(_loanPayables)),
          _rows(_loanPayables),
        ],

        if (_supplierPayables.any((e) => _visible(e.balance))) ...[
          _groupTitle('Sundry Creditors / Payables', _sum(_supplierPayables)),
          _rows(_supplierPayables),
        ],

        if (_otherLiabilities.any((e) => _visible(e.balance))) ...[
          _groupTitle('Other Current Liabilities', _sum(_otherLiabilities)),
          _rows(_otherLiabilities),
        ],
      ],
    );
  }

  // ============================================================
  // RIGHT SIDE
  // ============================================================

  Widget _assetSide(FFBalanceSheetReport report) {
    return _erpPanel(
      heading: 'ASSETS',
      total: report.totalAssets,
      children: [
        if (_fixedAssets.any((e) => _visible(e.balance))) ...[
          _groupTitle('Fixed Assets', _sum(_fixedAssets)),
          _rows(_fixedAssets),
        ],

        _groupTitle('Current Assets', report.totalAssets - _sum(_fixedAssets)),

        if (_cashBankMfs.any((e) => _visible(e.balance))) ...[
          _groupTitle('Cash / Bank / MFS', _sum(_cashBankMfs)),
          _rows(_cashBankMfs),
        ],

        if (_receivables.any((e) => _visible(e.balance))) ...[
          _groupTitle('Sundry Debtors / Receivables', _sum(_receivables)),
          _rows(_receivables),
        ],

        if (_loanReceivables.any((e) => _visible(e.balance))) ...[
          _groupTitle('Loans & Advances', _sum(_loanReceivables)),
          _rows(_loanReceivables),
        ],

        _groupTitle('Closing Stock', report.inventoryValue),

        _ledgerRow('Inventory / Stock', report.inventoryValue),

        if (_otherAssets.any((e) => _visible(e.balance))) ...[
          _groupTitle('Other Current Assets', _sum(_otherAssets)),
          _rows(_otherAssets),
        ],
      ],
    );
  }

  // ============================================================
  // ERP PANEL
  // ============================================================

  Widget _erpPanel({
    required String heading,
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
                    heading,
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

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xfff3f5ef),
              border: Border(top: BorderSide(color: Colors.grey.shade400)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _money(total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTROL BAR
  // ============================================================

  Widget _controlBar(FFBalanceSheetReport report) {
    final difference = report.accountingDifference;

    final balanced = difference.abs() < 0.005;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: balanced ? const Color(0xffedf7ef) : const Color(0xfffff7e6),
        border: Border.all(
          color: balanced ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            balanced ? Icons.check_circle_outline : Icons.info_outline,
            size: 19,
            color: balanced ? Colors.green.shade700 : Colors.orange.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              balanced
                  ? 'Balance Sheet is balanced.'
                  : 'Opening / accounting difference: '
                        '${_money(difference)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: balanced
                    ? Colors.green.shade800
                    : Colors.orange.shade900,
              ),
            ),
          ),
          Text(
            'Assets ${_money(report.totalAssets)}   |   '
            'Capital & Liabilities '
            '${_money(report.liabilitiesAndEquity)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE-ONLY BALANCE SHEET
  // Desktop widgets/layout are intentionally untouched.
  // ============================================================

  Widget _mobileErpPanel({
    required String heading,
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
                    heading,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _money(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xfff3f5ef),
              border: Border(top: BorderSide(color: Colors.grey.shade400)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _money(total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileLiabilitySide(FFBalanceSheetReport report) {
    final capitalRows = report.equity
        .where((e) => _visible(e.balance))
        .toList();

    final capitalValue = report.ledgerEquity + report.currentProfit;

    return _mobileErpPanel(
      heading: 'CAPITAL & LIABILITIES',
      total: report.liabilitiesAndEquity,
      children: [
        _groupTitle('Capital & Reserves', capitalValue),

        _rows(capitalRows),

        if (_visible(report.currentProfit))
          _ledgerRow(
            report.currentProfit >= 0 ? 'Current Profit' : 'Current Loss',
            report.currentProfit,
          ),

        if (_loanPayables.any((e) => _visible(e.balance))) ...[
          _groupTitle('Loans', _sum(_loanPayables)),
          _rows(_loanPayables),
        ],

        if (_supplierPayables.any((e) => _visible(e.balance))) ...[
          _groupTitle('Sundry Creditors / Payables', _sum(_supplierPayables)),
          _rows(_supplierPayables),
        ],

        if (_otherLiabilities.any((e) => _visible(e.balance))) ...[
          _groupTitle('Other Current Liabilities', _sum(_otherLiabilities)),
          _rows(_otherLiabilities),
        ],
      ],
    );
  }

  Widget _mobileAssetSide(FFBalanceSheetReport report) {
    return _mobileErpPanel(
      heading: 'ASSETS',
      total: report.totalAssets,
      children: [
        if (_fixedAssets.any((e) => _visible(e.balance))) ...[
          _groupTitle('Fixed Assets', _sum(_fixedAssets)),
          _rows(_fixedAssets),
        ],

        _groupTitle('Current Assets', report.totalAssets - _sum(_fixedAssets)),

        if (_cashBankMfs.any((e) => _visible(e.balance))) ...[
          _groupTitle('Cash / Bank / MFS', _sum(_cashBankMfs)),
          _rows(_cashBankMfs),
        ],

        if (_receivables.any((e) => _visible(e.balance))) ...[
          _groupTitle('Sundry Debtors / Receivables', _sum(_receivables)),
          _rows(_receivables),
        ],

        if (_loanReceivables.any((e) => _visible(e.balance))) ...[
          _groupTitle('Loans & Advances', _sum(_loanReceivables)),
          _rows(_loanReceivables),
        ],

        _groupTitle('Closing Stock', report.inventoryValue),

        _ledgerRow('Inventory / Stock', report.inventoryValue),

        if (_otherAssets.any((e) => _visible(e.balance))) ...[
          _groupTitle('Other Current Assets', _sum(_otherAssets)),
          _rows(_otherAssets),
        ],
      ],
    );
  }

  Widget _mobileBalanceSheetHeader() {
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
          const SizedBox(height: 3),
          const Text(
            'Balance Sheet',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          const Text(
            'Statement of Financial Position',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _mobileControlBar(FFBalanceSheetReport report) {
    final difference = report.accountingDifference;
    final balanced = difference.abs() < 0.005;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: balanced ? const Color(0xffedf7ef) : const Color(0xfffff7e6),
        border: Border.all(
          color: balanced ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                balanced ? Icons.check_circle_outline : Icons.info_outline,
                size: 19,
                color: balanced
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  balanced
                      ? 'Balance Sheet is balanced.'
                      : 'Opening / accounting difference: '
                            '${_money(difference)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: balanced
                        ? Colors.green.shade800
                        : Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _mobileSummaryLine('Assets', report.totalAssets),
          const SizedBox(height: 5),
          _mobileSummaryLine(
            'Capital & Liabilities',
            report.liabilitiesAndEquity,
          ),
        ],
      ),
    );
  }

  Widget _mobileSummaryLine(String label, double amount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _money(amount),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _mobileBalanceSheet(FFBalanceSheetReport report) {
    return RefreshIndicator(
      onRefresh: _loadBalanceSheet,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _mobileBalanceSheetHeader(),
          const SizedBox(height: 8),
          _mobileLiabilitySide(report),
          const SizedBox(height: 8),
          _mobileAssetSide(report),
          const SizedBox(height: 8),
          _mobileControlBar(report),
          const SizedBox(height: 20),
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
          'Balance Sheet',
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
                        builder: (_) =>
                            BalanceSheetPreviewScreen(report: report),
                      ),
                    );
                  },
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadBalanceSheet,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : report == null
          ? const Center(child: Text('No Balance Sheet data.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 700) {
                  return _mobileBalanceSheet(report);
                }

                // DESKTOP / PC:
                // Original layout below is intentionally unchanged.
                return RefreshIndicator(
                  onRefresh: _loadBalanceSheet,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(14),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                                    'Balance Sheet',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'Statement of Financial Position',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        height: constraints.maxHeight > 650
                            ? constraints.maxHeight - 180
                            : 620,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _liabilitySide(report)),
                            const SizedBox(width: 2),
                            Expanded(child: _assetSide(report)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      _controlBar(report),

                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
