import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../../services/ff/ff_receive_payment_service.dart';
import '../../services/refresh_service.dart';

enum FFMoneyEntryMode { receive, payment }

class FFReceivePaymentEntryScreen extends StatefulWidget {
  final FFMoneyEntryMode mode;

  const FFReceivePaymentEntryScreen({super.key, required this.mode});

  @override
  State<FFReceivePaymentEntryScreen> createState() =>
      _FFReceivePaymentEntryScreenState();
}

class _FFReceivePaymentEntryScreenState
    extends State<FFReceivePaymentEntryScreen> {
  final AccountRepository _accountRepository = AccountRepository();

  final FFReceivePaymentService _service = FFReceivePaymentService.instance;

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  List<Account> _moneyAccounts = [];
  List<Account> _ledgerAccounts = [];

  Account? _selectedMoneyAccount;
  Account? _selectedLedgerAccount;

  DateTime _transactionDate = DateTime.now();

  bool _loading = true;
  bool _saving = false;

  bool get _isReceive => widget.mode == FFMoneyEntryMode.receive;

  String get _title => _isReceive ? 'Receive' : 'Payment';

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
      final accounts = await _accountRepository.getAccounts();
      final db = await DatabaseHelper.instance.database;

      final moneyIds = <int>{};

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

      final ledgerAccounts = accounts
          .where(
            (account) => account.id != null && !moneyIds.contains(account.id),
          )
          .toList();

      ledgerAccounts.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (!mounted) return;

      setState(() {
        _moneyAccounts = moneyAccounts;
        _ledgerAccounts = ledgerAccounts;

        if (_moneyAccounts.isNotEmpty) {
          _selectedMoneyAccount = _moneyAccounts.first;
        }

        if (_ledgerAccounts.isNotEmpty) {
          _selectedLedgerAccount = _ledgerAccounts.first;
        }

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load accounts: $e')));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _transactionDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        DateTime.now().hour,
        DateTime.now().minute,
        DateTime.now().second,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (amount <= 0) {
      _message('Enter a valid amount.');
      return;
    }

    final moneyAccount = _selectedMoneyAccount;
    final ledgerAccount = _selectedLedgerAccount;

    if (moneyAccount?.id == null) {
      _message('Select Cash, Bank or MFS account.');
      return;
    }

    if (ledgerAccount?.id == null) {
      _message('Select a ledger account.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final voucherNo = _isReceive
          ? await _service.getNextReceiveVoucherNo()
          : await _service.getNextPaymentVoucherNo();

      final date = _transactionDate.toIso8601String();
      final note = _noteController.text.trim();

      if (_isReceive) {
        await _service.receive(
          receivingAccountId: moneyAccount!.id!,
          ledgerAccountId: ledgerAccount!.id!,
          amount: amount,
          voucherNo: voucherNo,
          transactionDate: date,
          note: note,
        );
      } else {
        await _service.payment(
          payingAccountId: moneyAccount!.id!,
          ledgerAccountId: ledgerAccount!.id!,
          amount: amount,
          voucherNo: voucherNo,
          transactionDate: date,
          note: note,
        );
      }

      RefreshService.notify();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_title saved successfully.\nVoucher: $voucherNo'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _message('Failed to save $_title: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<Account>(
                    initialValue: _selectedLedgerAccount,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _isReceive
                          ? 'Receive From / Ledger'
                          : 'Pay To / Ledger',
                      prefixIcon: const Icon(Icons.menu_book_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    items: _ledgerAccounts.map((account) {
                      return DropdownMenuItem<Account>(
                        value: account,
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedLedgerAccount = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Account>(
                    initialValue: _selectedMoneyAccount,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _isReceive ? 'Receive To' : 'Pay From',
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    items: _moneyAccounts.map((account) {
                      return DropdownMenuItem<Account>(
                        value: account,
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedMoneyAccount = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '৳ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Transaction Date'),
                    subtitle: Text(
                      '${_transactionDate.day}/'
                      '${_transactionDate.month}/'
                      '${_transactionDate.year}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _saving ? null : _pickDate,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    enabled: !_saving,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _isReceive
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                            ),
                      label: Text(
                        _saving ? 'Saving...' : 'Save $_title',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
