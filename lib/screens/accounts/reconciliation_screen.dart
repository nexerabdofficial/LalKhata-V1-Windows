import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/account_transaction.dart';
import '../../services/account_repository.dart';
import '../../services/account_transaction_repository.dart';

class ReconciliationScreen extends StatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> {
  final AccountRepository _accountRepository = AccountRepository();

  final AccountTransactionRepository _transactionRepository =
      AccountTransactionRepository();

  final TextEditingController _actualController = TextEditingController();

  List<Account> _accounts = [];
  Account? _selectedAccount;

  double _systemBalance = 0;
  double _actualBalance = 0;
  double _difference = 0;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _actualController.addListener(_calculateDifference);
  }

  @override
  void dispose() {
    _actualController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _accountRepository.getAccounts();

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _selectedAccount = accounts.isNotEmpty ? accounts.first : null;
        _loading = false;
      });

      if (_selectedAccount != null) {
        await _loadSystemBalance(_selectedAccount!);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Failed to load accounts: $e', error: true);
    }
  }

  Future<void> _loadSystemBalance(Account account) async {
    final accountId = account.id;
    if (accountId == null) {
      throw StateError('Selected account has no ID.');
    }

    final transactions = await _transactionRepository.getTransactionsByAccount(
      accountId,
    );

    double balance = account.openingBalance;

    for (final transaction in transactions) {
      balance += transaction.credit;
      balance -= transaction.debit;
    }

    if (!mounted) return;

    setState(() {
      _systemBalance = balance;
      _calculateDifference();
    });
  }

  void _calculateDifference() {
    final actual = double.tryParse(_actualController.text.trim()) ?? 0;

    if (!mounted) return;

    setState(() {
      _actualBalance = actual;
      _difference = _actualBalance - _systemBalance;
    });
  }

  Future<String> _generateVoucherNo() async {
    final transactions = await _transactionRepository.getAllTransactions();

    int maxNumber = 0;

    for (final transaction in transactions) {
      if (transaction.referenceType != 'RECONCILIATION') {
        continue;
      }

      final voucher = transaction.voucherNo?.trim() ?? '';

      final match = RegExp(r'^RECON#(\d+)$').firstMatch(voucher);

      if (match == null) continue;

      final number = int.tryParse(match.group(1)!) ?? 0;

      if (number > maxNumber) {
        maxNumber = number;
      }
    }

    return 'RECON#${maxNumber + 1}';
  }

  Future<void> _saveAdjustment() async {
    if (_selectedAccount == null) return;

    if (_difference.abs() < 0.005) {
      _showMessage('No adjustment is required.', error: true);
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final voucher = await _generateVoucherNo();

      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final createdAt = now.toIso8601String();

      final adjustmentAmount = _difference.abs();

      final transaction = AccountTransaction(
        accountId: _selectedAccount!.id!,
        transactionType: 'RECONCILIATION_ADJUSTMENT',
        referenceType: 'RECONCILIATION',
        referenceId: null,
        voucherNo: voucher,
        debit: _difference < 0 ? adjustmentAmount : 0,
        credit: _difference > 0 ? adjustmentAmount : 0,
        transactionDate: date,
        note: 'Balance reconciliation adjustment',
        createdAt: createdAt,
      );

      await _transactionRepository.insertTransaction(transaction);

      if (!mounted) return;

      _actualController.clear();

      await _loadSystemBalance(_selectedAccount!);

      _showMessage('Reconciliation saved: $voucher');
    } catch (e) {
      if (!mounted) return;

      _showMessage('Failed to save reconciliation: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  String _formatAmount(double value) {
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final differenceIsPositive = _difference > 0.004;
    final differenceIsNegative = _difference < -0.004;

    return Scaffold(
      appBar: AppBar(title: const Text('Reconciliation')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? const Center(child: Text('No account found.'))
          : RefreshIndicator(
              onRefresh: () async {
                if (_selectedAccount != null) {
                  await _loadSystemBalance(_selectedAccount!);
                }
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Account>(
                            initialValue: _selectedAccount,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                            ),
                            items: _accounts
                                .map(
                                  (account) => DropdownMenuItem<Account>(
                                    value: account,
                                    child: Text(account.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (account) async {
                              if (account == null) {
                                return;
                              }

                              setState(() {
                                _selectedAccount = account;
                                _actualController.clear();
                              });

                              await _loadSystemBalance(account);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _BalanceRow(
                            label: 'System Balance',
                            value: '৳ ${_formatAmount(_systemBalance)}',
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _actualController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Actual Balance',
                              prefixText: '৳ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: differenceIsNegative
                                  ? Colors.red.withValues(alpha: 0.08)
                                  : differenceIsPositive
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : Colors.grey.withValues(alpha: 0.08),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Difference',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '৳ ${_formatAmount(_difference)}',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: differenceIsNegative
                                        ? Colors.red
                                        : differenceIsPositive
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _saving || _difference.abs() < 0.005
                          ? null
                          : _saveAdjustment,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_saving ? 'Saving...' : 'Save Adjustment'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final String value;

  const _BalanceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
