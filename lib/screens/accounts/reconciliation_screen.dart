import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../../services/ff/ff_journal_models.dart';
import '../../services/ff/ff_journal_service.dart';
import '../../services/ff/ff_universal_ledger_service.dart';

class ReconciliationScreen extends StatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> {
  final AccountRepository _accountRepository = AccountRepository();

  final FFUniversalLedgerService _ledgerService =
      FFUniversalLedgerService.instance;

  final FFJournalService _journalService = FFJournalService.instance;

  final TextEditingController _actualController = TextEditingController();

  final TextEditingController _noteController = TextEditingController();

  List<Account> _moneyAccounts = [];
  List<Account> _adjustmentAccounts = [];

  Account? _selectedMoneyAccount;
  Account? _selectedAdjustmentAccount;

  double _systemBalance = 0;
  double _actualBalance = 0;
  double _difference = 0;

  bool _loading = true;
  bool _saving = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _actualController.addListener(_calculateDifference);

    _loadAccounts();
  }

  @override
  void dispose() {
    _actualController.removeListener(_calculateDifference);
    _actualController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  // ============================================================
  // ACCOUNT HELPERS
  // ============================================================

  bool _isMoneyAccount(Account account) {
    final type = account.type.trim().toUpperCase();

    return type == 'CASH' ||
        type == 'BANK' ||
        type == 'MFS' ||
        type == 'MOBILE_BANKING';
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _accountRepository.getAccounts();

      final moneyAccounts = accounts.where(_isMoneyAccount).toList();

      final adjustmentAccounts = accounts
          .where(
            (account) =>
                account.id != null &&
                !_isMoneyAccount(account) &&
                account.type.trim().toUpperCase() != 'CUSTOMER' &&
                account.type.trim().toUpperCase() != 'SUPPLIER',
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _moneyAccounts = moneyAccounts;
        _adjustmentAccounts = adjustmentAccounts;

        _selectedMoneyAccount = moneyAccounts.isNotEmpty
            ? moneyAccounts.first
            : null;

        _selectedAdjustmentAccount = null;

        _loading = false;
      });

      final account = _selectedMoneyAccount;

      if (account != null) {
        await _loadSystemBalance(account);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Failed to load reconciliation accounts: $e', error: true);
    }
  }

  // ============================================================
  // UNIVERSAL LEDGER BALANCE
  // ============================================================

  Future<void> _loadSystemBalance(Account account) async {
    final accountId = account.id;

    if (accountId == null) {
      throw StateError('Selected account has no ID.');
    }

    final summary = await _ledgerService.getSummary(
      accountId: accountId,
      normalBalance: 'DEBIT',
    );

    if (!mounted) return;

    setState(() {
      _systemBalance = summary.closingBalance;
    });

    _calculateDifference();
  }

  // ============================================================
  // DIFFERENCE
  // ============================================================

  void _calculateDifference() {
    final actual = double.tryParse(_actualController.text.trim()) ?? 0;

    if (!mounted) return;

    setState(() {
      _actualBalance = actual;
      _difference = _actualBalance - _systemBalance;
    });
  }

  // ============================================================
  // VOUCHER
  // ============================================================

  Future<String> _generateVoucherNo() async {
    final entries = await _journalService.getJournalEntries();

    int maxNumber = 0;

    for (final entry in entries) {
      final type = entry['transaction_type']?.toString().toUpperCase() ?? '';

      if (type != 'RECONCILIATION') {
        continue;
      }

      final voucher = entry['voucher_no']?.toString().trim() ?? '';

      final match = RegExp(r'^RECON-(\d+)$').firstMatch(voucher);

      if (match == null) continue;

      final number = int.tryParse(match.group(1) ?? '') ?? 0;

      if (number > maxNumber) {
        maxNumber = number;
      }
    }

    return 'RECON-${(maxNumber + 1).toString().padLeft(6, '0')}';
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveReconciliation() async {
    final moneyAccount = _selectedMoneyAccount;
    final adjustmentAccount = _selectedAdjustmentAccount;

    if (moneyAccount == null || moneyAccount.id == null) {
      _showMessage('Select a Cash, Bank or MFS account.', error: true);
      return;
    }

    if (_actualController.text.trim().isEmpty) {
      _showMessage('Enter statement / actual balance.', error: true);
      return;
    }

    if (_difference.abs() < 0.005) {
      _showMessage('Account is already reconciled.');
      return;
    }

    if (adjustmentAccount == null || adjustmentAccount.id == null) {
      _showMessage('Select an adjustment ledger.', error: true);
      return;
    }

    if (adjustmentAccount.id == moneyAccount.id) {
      _showMessage(
        'Adjustment ledger cannot be the same account.',
        error: true,
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final voucher = await _generateVoucherNo();

      final now = DateTime.now();
      final createdAt = now.toIso8601String();

      final amount = _difference.abs();

      final lines = <FFJournalLine>[];

      // --------------------------------------------------------
      // ACTUAL > LEDGER
      //
      // Dr Cash / Bank / MFS
      //    Cr Adjustment Ledger
      // --------------------------------------------------------

      if (_difference > 0) {
        lines.add(
          FFJournalLine(
            accountId: moneyAccount.id!,
            debit: amount,
            note: 'Reconciliation increase',
          ),
        );

        lines.add(
          FFJournalLine(
            accountId: adjustmentAccount.id!,
            credit: amount,
            note: 'Reconciliation counterpart',
          ),
        );
      }

      // --------------------------------------------------------
      // ACTUAL < LEDGER
      //
      // Dr Adjustment Ledger
      //    Cr Cash / Bank / MFS
      // --------------------------------------------------------

      if (_difference < 0) {
        lines.add(
          FFJournalLine(
            accountId: adjustmentAccount.id!,
            debit: amount,
            note: 'Reconciliation counterpart',
          ),
        );

        lines.add(
          FFJournalLine(
            accountId: moneyAccount.id!,
            credit: amount,
            note: 'Reconciliation decrease',
          ),
        );
      }

      final userNote = _noteController.text.trim();

      await _journalService.createJournal(
        FFJournalEntry(
          transactionType: 'RECONCILIATION',
          voucherNo: voucher,
          transactionDate: createdAt,
          referenceType: 'RECONCILIATION',
          referenceId: null,
          description: userNote.isEmpty ? 'Account reconciliation' : userNote,
          createdAt: createdAt,
          lines: lines,
        ),
      );

      await _loadSystemBalance(moneyAccount);

      if (!mounted) return;

      _actualController.text = _systemBalance.toStringAsFixed(2);

      _noteController.clear();

      _calculateDifference();

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

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  String _money(double value) {
    return '৳ ${value.toStringAsFixed(2)}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final differencePositive = _difference > 0.004;
    final differenceNegative = _difference < -0.004;
    final reconciled =
        _actualController.text.trim().isNotEmpty && _difference.abs() < 0.005;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Account Reconciliation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading
                ? null
                : () async {
                    final account = _selectedMoneyAccount;

                    if (account != null) {
                      await _loadSystemBalance(account);
                    }
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _moneyAccounts.isEmpty
          ? const Center(child: Text('No Cash, Bank or MFS account found.'))
          : RefreshIndicator(
              onRefresh: () async {
                final account = _selectedMoneyAccount;

                if (account != null) {
                  await _loadSystemBalance(account);
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ====================================
                          // ACCOUNT
                          // ====================================
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cash / Bank / MFS Account',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<Account>(
                                    initialValue: _selectedMoneyAccount,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(
                                        Icons.account_balance_wallet_outlined,
                                      ),
                                    ),
                                    items: _moneyAccounts
                                        .map(
                                          (account) =>
                                              DropdownMenuItem<Account>(
                                                value: account,
                                                child: Text(
                                                  account.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                        )
                                        .toList(),
                                    onChanged: _saving
                                        ? null
                                        : (account) async {
                                            if (account == null) {
                                              return;
                                            }

                                            setState(() {
                                              _selectedMoneyAccount = account;
                                              _actualController.clear();
                                              _selectedAdjustmentAccount = null;
                                            });

                                            await _loadSystemBalance(account);
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ====================================
                          // BALANCE
                          // ====================================
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _BalanceRow(
                                    label: 'Ledger Balance',
                                    value: _money(_systemBalance),
                                  ),
                                  const SizedBox(height: 18),
                                  TextField(
                                    controller: _actualController,
                                    enabled: !_saving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: false,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Statement / Actual Balance',
                                      prefixText: '৳ ',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: reconciled
                                          ? Colors.green.withValues(alpha: 0.08)
                                          : differenceNegative
                                          ? Colors.red.withValues(alpha: 0.08)
                                          : differencePositive
                                          ? Colors.orange.withValues(
                                              alpha: 0.08,
                                            )
                                          : Colors.grey.withValues(alpha: 0.08),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          reconciled
                                              ? 'Reconciled'
                                              : 'Difference',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _money(_difference),
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            color: reconciled
                                                ? Colors.green
                                                : differenceNegative
                                                ? Colors.red
                                                : differencePositive
                                                ? Colors.orange
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

                          const SizedBox(height: 14),

                          // ====================================
                          // COUNTERPART
                          // ====================================
                          if (_difference.abs() >= 0.005)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Adjustment Ledger',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Select the ledger that explains the difference.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<Account>(
                                      initialValue: _selectedAdjustmentAccount,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(
                                          Icons.account_tree_outlined,
                                        ),
                                      ),
                                      hint: const Text(
                                        'Select adjustment ledger',
                                      ),
                                      items: _adjustmentAccounts
                                          .map(
                                            (account) =>
                                                DropdownMenuItem<Account>(
                                                  value: account,
                                                  child: Text(
                                                    account.name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                          )
                                          .toList(),
                                      onChanged: _saving
                                          ? null
                                          : (account) {
                                              setState(() {
                                                _selectedAdjustmentAccount =
                                                    account;
                                              });
                                            },
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _noteController,
                                      enabled: !_saving,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        labelText: 'Note / Reason',
                                        hintText:
                                            'e.g. Bank charge, interest, cash shortage...',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (_difference.abs() >= 0.005)
                            const SizedBox(height: 18),

                          // ====================================
                          // SAVE
                          // ====================================
                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _saving || _difference.abs() < 0.005
                                  ? null
                                  : _saveReconciliation,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.balance_outlined),
                              label: Text(
                                _saving
                                    ? 'Saving...'
                                    : reconciled
                                    ? 'Reconciled'
                                    : 'Save Reconciliation',
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
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
