import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/ff/ff_trial_balance_service.dart';

class TrialBalanceScreen extends StatefulWidget {
  const TrialBalanceScreen({super.key});

  @override
  State<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
  final FFTrialBalanceService _service = FFTrialBalanceService.instance;

  FFTrialBalanceReport? _report;
  bool _loading = true;

  final NumberFormat _money = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      final report = await _service.getReport();

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load Trial Balance: $e')),
      );
    }
  }

  String _format(double value) {
    return _money.format(value);
  }

  Widget _amount(double value) {
    return Text(
      value.abs() < 0.000001 ? '-' : _format(value),
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _summaryCard(String title, double debit, double credit) {
    final difference = debit - credit;
    final balanced = difference.abs() < 0.005;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Debit: ৳${_format(debit)}'),
            const SizedBox(height: 4),
            Text('Credit: ৳${_format(credit)}'),
            const SizedBox(height: 6),
            Text(
              balanced
                  ? 'Difference: ৳0'
                  : 'Difference: ৳${_format(difference.abs())} ${difference > 0 ? 'Dr' : 'Cr'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: balanced ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table(FFTrialBalanceReport report) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Account')),
          DataColumn(label: Text('Group')),
          DataColumn(numeric: true, label: Text('Opening Dr')),
          DataColumn(numeric: true, label: Text('Opening Cr')),
          DataColumn(numeric: true, label: Text('Debit')),
          DataColumn(numeric: true, label: Text('Credit')),
          DataColumn(numeric: true, label: Text('Closing Dr')),
          DataColumn(numeric: true, label: Text('Closing Cr')),
        ],
        rows: [
          ...report.rows.map(
            (row) => DataRow(
              cells: [
                DataCell(Text(row.accountName)),
                DataCell(Text(row.groupName.isEmpty ? '-' : row.groupName)),
                DataCell(_amount(row.openingDebit)),
                DataCell(_amount(row.openingCredit)),
                DataCell(_amount(row.periodDebit)),
                DataCell(_amount(row.periodCredit)),
                DataCell(_amount(row.closingDebit)),
                DataCell(_amount(row.closingCredit)),
              ],
            ),
          ),

          DataRow(
            cells: [
              const DataCell(
                Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const DataCell(Text('')),
              DataCell(
                Text(
                  _format(report.openingDebit),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(
                Text(
                  _format(report.openingCredit),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(
                Text(
                  _format(report.periodDebit),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(
                Text(
                  _format(report.periodCredit),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(
                Text(
                  _format(report.closingDebit),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(
                Text(
                  _format(report.closingCredit),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE-ONLY TRIAL BALANCE
  // Desktop DataTable is intentionally untouched.
  // ============================================================

  Widget _mobileAmountPair(String title, double debit, double credit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Debit',
                  style: TextStyle(fontSize: 9.5, color: Colors.black54),
                ),
                Text(
                  debit.abs() < 0.000001 ? '-' : '৳${_format(debit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Credit',
                  style: TextStyle(fontSize: 9.5, color: Colors.black54),
                ),
                Text(
                  credit.abs() < 0.000001 ? '-' : '৳${_format(credit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileAccountCard(FFTrialBalanceRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.accountName,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              row.groupName.isEmpty ? '-' : row.groupName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
            ),
            const Divider(height: 16),
            _mobileAmountPair('Opening', row.openingDebit, row.openingCredit),
            _mobileAmountPair('Period', row.periodDebit, row.periodCredit),
            _mobileAmountPair('Closing', row.closingDebit, row.closingCredit),
          ],
        ),
      ),
    );
  }

  Widget _mobileTotals(FFTrialBalanceReport report) {
    return Card(
      margin: const EdgeInsets.only(top: 2),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xfff3f5ef),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TOTAL',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 16),
            _mobileAmountPair(
              'Opening',
              report.openingDebit,
              report.openingCredit,
            ),
            _mobileAmountPair(
              'Period',
              report.periodDebit,
              report.periodCredit,
            ),
            _mobileAmountPair(
              'Closing',
              report.closingDebit,
              report.closingCredit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileTrialBalance(FFTrialBalanceReport report) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _summaryCard(
            'Opening Position',
            report.openingDebit,
            report.openingCredit,
          ),
          _summaryCard(
            'Period Movement',
            report.periodDebit,
            report.periodCredit,
          ),
          _summaryCard(
            'Closing Position',
            report.closingDebit,
            report.closingCredit,
          ),
          const SizedBox(height: 8),
          ...report.rows.map(_mobileAccountCard),
          _mobileTotals(report),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trial Balance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : report == null
          ? const Center(child: Text('No Trial Balance data.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 700) {
                  return _mobileTrialBalance(report);
                }

                // DESKTOP / PC:
                // Original Trial Balance layout is unchanged.
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    children: [
                      _summaryCard(
                        'Opening Position',
                        report.openingDebit,
                        report.openingCredit,
                      ),
                      _summaryCard(
                        'Period Movement',
                        report.periodDebit,
                        report.periodCredit,
                      ),
                      _summaryCard(
                        'Closing Position',
                        report.closingDebit,
                        report.closingCredit,
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _table(report),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
