import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/account.dart';
import '../../models/account_transaction.dart';
import '../../services/account_repository.dart';
import '../../services/account_transaction_repository.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key});

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  final AccountRepository _accountRepository = AccountRepository();

  final AccountTransactionRepository _transactionRepository =
      AccountTransactionRepository();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  bool _loading = true;

  List<Account> _accounts = [];
  List<AccountTransaction> _transactions = [];

  double _cashIn = 0;
  double _cashOut = 0;

  final NumberFormat _moneyFormat = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final accounts = await _accountRepository.getAccounts();

      final allTransactions = await _transactionRepository.getAllTransactions();

      final start = DateTime(_startDate.year, _startDate.month, _startDate.day);

      final end = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
        999,
      );

      final transactions = allTransactions.where((transaction) {
        final date = DateTime.tryParse(transaction.transactionDate);

        if (date == null) return false;

        return !date.isBefore(start) &&
            !date.isAfter(end) &&
            transaction.transactionType != 'OPENING_BALANCE' &&
            transaction.transactionType != 'OPENING';
      }).toList();

      double cashIn = 0;
      double cashOut = 0;

      for (final transaction in transactions) {
        cashIn += transaction.credit;
        cashOut += transaction.debit;
      }

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _transactions = transactions;
        _cashIn = cashIn;
        _cashOut = cashOut;
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

  // ============================================================
  // DATE HELPERS
  // ============================================================

  String _displayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatMoney(double amount) {
    return _moneyFormat.format(amount);
  }

  String _accountName(int accountId) {
    for (final account in _accounts) {
      if (account.id == accountId) {
        return account.name;
      }
    }

    return 'Unknown Account';
  }

  // ============================================================
  // DATE PICKERS
  // ============================================================

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

  // ============================================================
  // SUMMARY CARD
  // ============================================================

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
              Icon(icon, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '৳ ${_formatMoney(amount)}',
                      style: const TextStyle(
                        fontSize: 18,
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

  // ============================================================
  // TRANSACTION CARD
  // ============================================================

  Widget _transactionCard(AccountTransaction transaction) {
    final isIn = transaction.credit > 0;

    final amount = isIn ? transaction.credit : transaction.debit;

    final voucher = transaction.voucherNo?.trim().isNotEmpty == true
        ? transaction.voucherNo!
        : transaction.transactionType;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, size: 22),
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
                    '${_accountName(transaction.accountId)} • '
                    '${_displayDate(DateTime.parse(transaction.transactionDate))}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (transaction.note != null &&
                      transaction.note!.trim().isNotEmpty)
                    Text(
                      transaction.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${isIn ? '+' : '-'} ৳ ${_formatMoney(amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isIn ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final netFlow = _cashIn - _cashOut;

    return Scaffold(
      appBar: AppBar(title: const Text('Cash Flow')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
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
                          amount: _cashIn,
                          icon: Icons.arrow_downward,
                        ),
                        const SizedBox(width: 8),
                        _summaryCard(
                          title: 'Cash Out',
                          amount: _cashOut,
                          icon: Icons.arrow_upward,
                        ),
                      ],
                    ),
                  ),

                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, size: 28),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Net Cash Flow',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '৳ ${_formatMoney(netFlow)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: netFlow >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text('No cash flow transactions found.'),
                      ),
                    )
                  else
                    ..._transactions.map(_transactionCard),
                ],
              ),
            ),
    );
  }
}
