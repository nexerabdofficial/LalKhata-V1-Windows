import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/ff/ff_cash_flow_service.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key});

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  final FFCashFlowService _service = FFCashFlowService.instance;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  bool _loading = true;

  FFCashFlowReport? _report;

  final NumberFormat _moneyFormat = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final report = await _service.getReport(from: _startDate, to: _endDate);

      if (!mounted) return;

      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load Cash Flow: $e')));
    }
  }

  String _displayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  String _formatMoney(double amount) {
    return _moneyFormat.format(amount);
  }

  String _money(double amount) {
    final negative = amount < 0;
    final value = amount.abs();

    return negative ? '-৳ ${_formatMoney(value)}' : '৳ ${_formatMoney(value)}';
  }

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) return;

    setState(() {
      _startDate = selected;

      if (_startDate.isAfter(_endDate)) {
        _endDate = selected;
      }
    });

    await _loadReport();
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (selected == null) return;

    setState(() {
      _endDate = selected;
    });

    await _loadReport();
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 27),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _money(amount),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transactionCard(FFCashFlowRow row) {
    final isTransfer = row.isInternalTransfer;

    final isIn = !isTransfer && row.debit > 0;

    final amount = isTransfer
        ? row.transferAmount
        : isIn
        ? row.debit
        : row.credit;

    final parsedDate = DateTime.tryParse(row.transactionDate);

    final voucher = row.voucherNo?.trim().isNotEmpty == true
        ? row.voucherNo!
        : row.transactionType;

    final description = row.note?.trim().isNotEmpty == true
        ? row.note!
        : row.description?.trim().isNotEmpty == true
        ? row.description!
        : row.transactionType;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(
              isTransfer
                  ? Icons.swap_horiz_rounded
                  : isIn
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucher,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${row.accountName}'
                    '${parsedDate == null ? '' : ' • ${_displayDate(parsedDate)}'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (description.trim().isNotEmpty)
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isTransfer
                  ? _money(amount)
                  : '${isIn ? '+' : '-'} ${_money(amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isTransfer
                    ? Colors.blueGrey
                    : isIn
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlCard(FFCashFlowReport report) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cash Reconciliation',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _controlRow('Opening Cash', report.openingBalance),
            _controlRow('Net Cash Flow', report.netCashFlow),
            _controlRow('Expected Closing', report.expectedClosing),
            _controlRow('Actual Closing', report.closingBalance),
            const Divider(),
            _controlRow(
              'Difference',
              report.controlDifference,
              bold: true,
              color: report.isReconciled ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlRow(
    String title,
    double value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Flow'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadReport,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : report == null
          ? const Center(child: Text('No Cash Flow data.'))
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectStartDate,
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(_displayDate(_startDate)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectEndDate,
                            icon: const Icon(Icons.event, size: 18),
                            label: Text(_displayDate(_endDate)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _summaryCard(
                          title: 'Cash In',
                          amount: report.cashIn,
                          icon: Icons.arrow_downward_rounded,
                        ),
                        const SizedBox(width: 8),
                        _summaryCard(
                          title: 'Cash Out',
                          amount: report.cashOut,
                          icon: Icons.arrow_upward_rounded,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _summaryCard(
                          title: 'Net Flow',
                          amount: report.netCashFlow,
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                        const SizedBox(width: 8),
                        _summaryCard(
                          title: 'Internal Transfer',
                          amount: report.internalTransfers,
                          icon: Icons.swap_horiz_rounded,
                        ),
                      ],
                    ),
                  ),
                  _controlCard(report),
                  if (report.rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text('No cash flow transactions found.'),
                      ),
                    )
                  else
                    ...report.rows.map(_transactionCard),
                ],
              ),
            ),
    );
  }
}
