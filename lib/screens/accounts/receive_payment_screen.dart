import 'package:flutter/material.dart';

import '../../database/database_helper.dart';

import '../../models/account.dart';
import '../../models/customer.dart';
import '../../services/customer_repository.dart';
import '../../services/refresh_service.dart';
import '../../services/account_repository.dart';

class ReceivePaymentScreen extends StatefulWidget {
  final Customer customer;

  const ReceivePaymentScreen({super.key, required this.customer});

  @override
  State<ReceivePaymentScreen> createState() => _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState extends State<ReceivePaymentScreen> {
  final CustomerRepository _repository = CustomerRepository();

  final AccountRepository _accountRepository = AccountRepository();

  final TextEditingController _amountController = TextEditingController();

  List<Account> _accounts = [];

  Account? _selectedAccount;

  bool _loadingAccounts = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

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

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _receivePayment() async {
    // ============================================================
    // IMPORTANT:
    // Prevent double click / rapid click.
    // ============================================================
    if (_isSaving) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payment amount.')),
      );
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account.')),
      );
      return;
    }

    // Optional safety check.
    if (amount > widget.customer.balance + 0.000001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment cannot be greater than customer due '
            '(৳${widget.customer.balance.toStringAsFixed(2)}).',
          ),
        ),
      );
      return;
    }

    // Lock immediately BEFORE any await.
    setState(() {
      _isSaving = true;
    });

    try {
      // ============================================================
      // Generate voucher only once.
      // Because _isSaving is already true, another click cannot
      // reach this point while this operation is running.
      // ============================================================
      final voucherNo = await _repository.getNextCustomerPaymentVoucherNo();

      final accountId = _selectedAccount!.id!;

      // ============================================================
      // 1. Save customer payment
      // ============================================================
      await _repository.saveCustomerPayment(
        customerId: widget.customer.id!,
        amount: amount,
        voucherNo: voucherNo,
        accountId: accountId,
        paymentMethod: _selectedAccount!.name,
      );

      // ============================================================
      // 2. Create account ledger transaction
      //
      // Customer payment = money comes INTO the account
      // therefore CREDIT.
      // ============================================================

      // ============================================================
      // 3. Refresh all listening screens.
      // Dashboard / Account list / Customer list etc.
      // ============================================================
      RefreshService.notify();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment received successfully.\n'
            'Voucher: $voucherNo',
          ),
        ),
      );

      // Stay on Receive Payment for another entry.
      setState(() {
        _amountController.clear();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to receive payment: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ======================================================
            // CUSTOMER
            // ======================================================
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                widget.customer.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Current Due: '
                '৳${widget.customer.balance.toStringAsFixed(2)}',
              ),
            ),

            const SizedBox(height: 20),

            // ======================================================
            // AMOUNT
            // ======================================================
            TextField(
              controller: _amountController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Receive Amount',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ======================================================
            // ACCOUNT
            // ======================================================
            if (_loadingAccounts)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              )
            else
              DropdownButtonFormField<Account>(
                initialValue: _selectedAccount,
                decoration: const InputDecoration(
                  labelText: 'Receive To Account',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                items: _accounts.map((account) {
                  return DropdownMenuItem<Account>(
                    value: account,
                    child: Text(account.name),
                  );
                }).toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _selectedAccount = value;
                        });
                      },
              ),

            const SizedBox(height: 24),

            // ======================================================
            // RECEIVE BUTTON
            // ======================================================
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_isSaving || _loadingAccounts)
                    ? null
                    : _receivePayment,
                child: _isSaving
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Receive Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
