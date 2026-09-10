import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../../services/account_ledger_service.dart';

class FundTransferScreen extends StatefulWidget {
  const FundTransferScreen({super.key});

  @override
  State<FundTransferScreen> createState() =>
      _FundTransferScreenState();
}

class _FundTransferScreenState
    extends State<FundTransferScreen> {
  final AccountRepository _accountRepository =
      AccountRepository();

  final AccountLedgerService _ledgerService =
      AccountLedgerService();

  final TextEditingController _amountController =
      TextEditingController();

  final TextEditingController _noteController =
      TextEditingController();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  List<Account> _accounts = [];

  Account? _fromAccount;
  Account? _toAccount;

  DateTime _selectedDate = DateTime.now();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts =
          await _accountRepository.getAccounts();

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load accounts: $e',
          ),
        ),
      );
    }
  }

  String _formatMoney(double amount) {
    if (amount == amount.roundToDouble()) {
      return NumberFormat('#,##0').format(amount);
    }

    return NumberFormat('#,##0.##').format(amount);
  }

  String _generateVoucherNo() {
    final timestamp =
        DateTime.now().millisecondsSinceEpoch;

    return 'TRF-$timestamp';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_fromAccount == null) {
      _showError('Please select source account.');
      return;
    }

    if (_toAccount == null) {
      _showError('Please select destination account.');
      return;
    }

    if (_fromAccount!.id == _toAccount!.id) {
      _showError(
        'Source and destination accounts cannot be the same.',
      );
      return;
    }

    final amount =
        double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showError(
        'Please enter a valid transfer amount.',
      );
      return;
    }

    // ----------------------------------------------------------
    // Check source account balance
    // ----------------------------------------------------------

    final sourceBalance =
        await _accountRepository.getAccountBalance(
      _fromAccount!.id!,
    );

    if (amount > sourceBalance) {
      _showError(
        'Insufficient balance in ${_fromAccount!.name}. '
        'Available: ৳${_formatMoney(sourceBalance)}',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final voucherNo = _generateVoucherNo();

      await _ledgerService.transferFunds(
        fromAccountId: _fromAccount!.id!,
        toAccountId: _toAccount!.id!,
        amount: amount,
        voucherNo: voucherNo,
        transactionDate:
            DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            ).toIso8601String(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '৳${_formatMoney(amount)} transferred successfully.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transfer failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fund Transfer'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _accounts.length < 2
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'You need at least two accounts '
                      'to make a fund transfer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                      ),
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ------------------------------------------------
                      // FROM ACCOUNT
                      // ------------------------------------------------

                      DropdownButtonFormField<Account>(
                        value: _fromAccount,
                        decoration: InputDecoration(
                          labelText: 'From Account',
                          prefixIcon: const Icon(
                            Icons.account_balance_wallet,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                        items: _accounts.map(
                          (account) {
                            return DropdownMenuItem<Account>(
                              value: account,
                              child: Text(
                                '${account.name} '
                                '(৳${_formatMoney(account.balance)})',
                              ),
                            );
                          },
                        ).toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                setState(() {
                                  _fromAccount = value;
                                });
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Select source account';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ------------------------------------------------
                      // TO ACCOUNT
                      // ------------------------------------------------

                      DropdownButtonFormField<Account>(
                        value: _toAccount,
                        decoration: InputDecoration(
                          labelText: 'To Account',
                          prefixIcon: const Icon(
                            Icons.account_balance,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                        items: _accounts.map(
                          (account) {
                            return DropdownMenuItem<Account>(
                              value: account,
                              child: Text(
                                account.name,
                              ),
                            );
                          },
                        ).toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                setState(() {
                                  _toAccount = value;
                                });
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Select destination account';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ------------------------------------------------
                      // AMOUNT
                      // ------------------------------------------------

                      TextFormField(
                        controller: _amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '৳ ',
                          prefixIcon: const Icon(
                            Icons.payments,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Enter amount';
                          }

                          final amount =
                              double.tryParse(value.trim());

                          if (amount == null ||
                              amount <= 0) {
                            return 'Enter a valid amount';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ------------------------------------------------
                      // DATE
                      // ------------------------------------------------

                      InkWell(
                        onTap: _saving
                            ? null
                            : _selectDate,
                        borderRadius:
                            BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Transfer Date',
                            prefixIcon: const Icon(
                              Icons.calendar_today,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            DateFormat(
                              'dd MMM yyyy',
                            ).format(_selectedDate),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ------------------------------------------------
                      // NOTE
                      // ------------------------------------------------

                      TextFormField(
                        controller: _noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Note',
                          hintText:
                              'Optional transfer note',
                          prefixIcon: const Icon(
                            Icons.note_alt_outlined,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ------------------------------------------------
                      // TRANSFER BUTTON
                      // ------------------------------------------------

                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : _submitTransfer,
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.swap_horiz,
                                ),
                          label: Text(
                            _saving
                                ? 'Transferring...'
                                : 'Transfer Funds',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}