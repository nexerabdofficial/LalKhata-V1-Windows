import 'package:flutter/material.dart';

import '../../../database/database_helper.dart';

import '../../../models/account.dart';
import '../../../models/supplier.dart';
import '../../../services/account_repository.dart';
import '../../../services/refresh_service.dart';
import '../../../services/supplier_repository.dart';

class PaySupplierScreen extends StatefulWidget {
  final Supplier supplier;

  const PaySupplierScreen({super.key, required this.supplier});

  @override
  State<PaySupplierScreen> createState() => _PaySupplierScreenState();
}

class _PaySupplierScreenState extends State<PaySupplierScreen> {
  final SupplierRepository _supplierRepository = SupplierRepository();

  final AccountRepository _accountRepository = AccountRepository();

  late final TextEditingController _amountController;

  List<Account> _accounts = [];
  Account? _selectedAccount;

  bool _loadingAccounts = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController();

    _amountController.addListener(_refreshPreview);

    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.removeListener(_refreshPreview);
    _amountController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (!mounted) return;
    setState(() {});
  }

  // ============================================================
  // LOAD ACCOUNTS
  // ============================================================

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _accountRepository.getAccounts();

      final db = await DatabaseHelper.instance.database;

      final rows = await db.rawQuery('''
        SELECT DISTINCT a.id
        FROM accounts a
        LEFT JOIN ff_account_links l
          ON l.account_id = a.id
         AND l.is_primary = 1
        LEFT JOIN ff_account_groups g
          ON g.id = l.group_id
        WHERE UPPER(a.type) IN (
          'CASH',
          'BANK',
          'MFS',
          'MOBILE_BANKING'
        )
        OR UPPER(COALESCE(g.group_code, '')) IN (
          'CASH',
          'BANK',
          'MFS'
        )
      ''');

      final moneyIds = <int>{};

      for (final row in rows) {
        final id = row['id'];

        if (id is num) {
          moneyIds.add(id.toInt());
        }
      }

      final moneyAccounts = accounts
          .where(
            (account) => account.id != null && moneyIds.contains(account.id),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _accounts = moneyAccounts;
        _loadingAccounts = false;

        if (_accounts.isNotEmpty) {
          try {
            _selectedAccount = _accounts.firstWhere(
              (account) => account.type.toUpperCase() == 'CASH',
            );
          } catch (_) {
            _selectedAccount = _accounts.first;
          }
        } else {
          _selectedAccount = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingAccounts = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load accounts: $e')));
    }
  }

  // ============================================================
  // SAVE PAYMENT
  // ============================================================

  Future<void> _savePayment() async {
    if (_saving) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payment amount.')),
      );
      return;
    }

    if (amount > widget.supplier.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment cannot exceed current due '
            '(৳${widget.supplier.balance.toStringAsFixed(2)}).',
          ),
        ),
      );
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // ========================================================
      // IMPORTANT
      //
      // Supplier payment + account transaction are now saved
      // together inside ONE database transaction.
      //
      // Voucher generation also happens inside that transaction.
      //
      // This prevents:
      //
      // SP#1
      // SP#1
      //
      // or:
      //
      // Supplier payment saved
      // but account ledger failed
      //
      // ========================================================

      final voucherNo = await _supplierRepository
          .saveSupplierPaymentWithAccountTransaction(
            supplierId: widget.supplier.id!,
            amount: amount,
            accountId: _selectedAccount!.id!,
            paymentMethod: _selectedAccount!.type,
            note: 'Payment to ${widget.supplier.name}',
          );

      // ========================================================
      // Keep stored account balance synchronized.
      //
      // Actual balance is still ledger-driven.
      // ========================================================

      await _accountRepository.refreshStoredBalance(_selectedAccount!.id!);

      RefreshService.notify();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Supplier payment saved.\n'
            'Voucher: $voucherNo',
          ),
        ),
      );

      // Stay on Pay Supplier for another entry.
      setState(() {
        _amountController.clear();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save payment: $e')));
    }
  }

  // ============================================================
  // ACCOUNT DISPLAY
  // ============================================================

  String _accountLabel(Account account) {
    final balance = account.balance.toStringAsFixed(2);

    return '${account.name}  •  ৳$balance';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay Supplier')),
      body: _loadingAccounts
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------------
                  // SUPPLIER CARD
                  // ------------------------------------------------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            child: Icon(Icons.local_shipping),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.supplier.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.supplier.phone ?? '',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ------------------------------------------------
                  // CURRENT DUE
                  // ------------------------------------------------
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.red,
                      ),
                      title: const Text('Current Due'),
                      subtitle: const Text('Outstanding supplier balance'),
                      trailing: Text(
                        '৳${widget.supplier.balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ------------------------------------------------
                  // PAYMENT AMOUNT
                  // ------------------------------------------------
                  const Text(
                    'Payment Amount',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: _amountController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter payment amount',
                      prefixText: '৳ ',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ------------------------------------------------
                  // PAY FROM ACCOUNT
                  // ------------------------------------------------
                  const Text(
                    'Pay From Account',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<Account>(
                    initialValue: _selectedAccount,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.account_balance_wallet),
                      border: OutlineInputBorder(),
                    ),
                    items: _accounts
                        .map(
                          (account) => DropdownMenuItem<Account>(
                            value: account,
                            child: Text(
                              _accountLabel(account),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (account) {
                            setState(() {
                              _selectedAccount = account;
                            });
                          },
                  ),

                  const SizedBox(height: 28),

                  // ------------------------------------------------
                  // PAYMENT EFFECT PREVIEW
                  // ------------------------------------------------
                  if (_selectedAccount != null)
                    Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            _previewRow(
                              'Paying Supplier',
                              '৳${_amountController.text.isEmpty ? '0' : _amountController.text}',
                            ),
                            const Divider(),
                            _previewRow('From Account', _selectedAccount!.name),
                            const Divider(),
                            _previewRow(
                              'Supplier Due After Payment',
                              '৳${_calculateDueAfterPayment()}',
                            ),
                            const Divider(),
                            _previewRow(
                              'Account Balance After Payment',
                              '৳${_calculateAccountBalanceAfterPayment()}',
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ------------------------------------------------
                  // SAVE BUTTON
                  // ------------------------------------------------
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.payments),
                      label: Text(_saving ? 'Saving...' : 'Pay Supplier'),
                      onPressed: _saving ? null : _savePayment,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // PREVIEW ROW
  // ============================================================

  Widget _previewRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SUPPLIER DUE PREVIEW
  // ============================================================

  String _calculateDueAfterPayment() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    final due = widget.supplier.balance - amount;

    return (due < 0 ? 0 : due).toStringAsFixed(2);
  }

  // ============================================================
  // ACCOUNT BALANCE PREVIEW
  // ============================================================

  String _calculateAccountBalanceAfterPayment() {
    if (_selectedAccount == null) {
      return '0.00';
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    final balance = _selectedAccount!.balance - amount;

    return (balance < 0 ? 0 : balance).toStringAsFixed(2);
  }
}
