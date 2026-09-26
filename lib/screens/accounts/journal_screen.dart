import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/account_transaction.dart';
import '../../services/account_repository.dart';
import '../../services/account_transaction_repository.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalLine {
  int? accountId;
  final TextEditingController amount = TextEditingController();

  void dispose() {
    amount.dispose();
  }
}

class _JournalScreenState extends State<JournalScreen> {
  final _formKey = GlobalKey<FormState>();

  final AccountRepository _accountRepository = AccountRepository();
  final AccountTransactionRepository _transactionRepository =
      AccountTransactionRepository();

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();

  List<Account> _accounts = [];

  final List<_JournalLine> _debitLines = [];
  final List<_JournalLine> _creditLines = [];

  bool _loading = true;
  bool _saving = false;

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    _dateController.text = _formatDate(_selectedDate);

    _debitLines.add(_JournalLine());
    _creditLines.add(_JournalLine());

    _loadAccounts();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _narrationController.dispose();

    for (final line in _debitLines) {
      line.dispose();
    }

    for (final line in _creditLines) {
      line.dispose();
    }

    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _accountRepository.getAccounts();

    if (!mounted) return;

    setState(() {
      _accounts = accounts;
      _loading = false;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _dateForDatabase() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      12,
    ).toIso8601String();
  }

  double _total(List<_JournalLine> lines) {
    return lines.fold<double>(
      0,
      (sum, line) => sum + (double.tryParse(line.amount.text.trim()) ?? 0),
    );
  }

  double get _totalDebit => _total(_debitLines);
  double get _totalCredit => _total(_creditLines);
  double get _difference => _totalDebit - _totalCredit;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _dateController.text = _formatDate(picked);
    });
  }

  void _autoBalanceAmount({required bool changedDebit}) {
    final sourceLines = changedDebit ? _debitLines : _creditLines;
    final targetLines = changedDebit ? _creditLines : _debitLines;

    // Auto-fill is only for the simple 1 Debit <-> 1 Credit case.
    // Multi-line journals remain fully manual.
    if (sourceLines.length != 1 || targetLines.length != 1) {
      return;
    }

    final sourceAmount =
        double.tryParse(sourceLines.first.amount.text.trim()) ?? 0;

    final target = targetLines.first;

    if (sourceAmount <= 0) {
      if (target.amount.text.isNotEmpty) {
        target.amount.clear();
      }
      return;
    }

    final formatted = _formatMoney(sourceAmount);

    if (target.amount.text != formatted) {
      target.amount.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _addDebitLine() {
    setState(() {
      _debitLines.add(_JournalLine());
    });
  }

  void _addCreditLine() {
    setState(() {
      _creditLines.add(_JournalLine());
    });
  }

  void _removeDebitLine(int index) {
    if (_debitLines.length == 1) return;

    final line = _debitLines.removeAt(index);
    line.dispose();

    setState(() {});
  }

  void _removeCreditLine(int index) {
    if (_creditLines.length == 1) return;

    final line = _creditLines.removeAt(index);
    line.dispose();

    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_accounts.isEmpty) {
      _showMessage('No account is available.');
      return;
    }

    for (final line in [..._debitLines, ..._creditLines]) {
      final amount = double.tryParse(line.amount.text.trim()) ?? 0;

      if (line.accountId == null) {
        _showMessage('Please select an account for every line.');
        return;
      }

      if (amount <= 0) {
        _showMessage('Every journal line must have a valid amount.');
        return;
      }
    }

    if (_totalDebit <= 0 || _totalCredit <= 0) {
      _showMessage('Debit and Credit must both be greater than zero.');
      return;
    }

    if ((_difference).abs() > 0.000001) {
      _showMessage(
        'Journal is not balanced. '
        'Debit: ${_formatMoney(_totalDebit)} | '
        'Credit: ${_formatMoney(_totalCredit)}',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final voucherNo = await _transactionRepository.getNextJournalVoucherNo();

      final now = DateTime.now().toIso8601String();
      final transactionDate = _dateForDatabase();

      final entries = <AccountTransaction>[];

      for (final line in _debitLines) {
        final amount = double.parse(line.amount.text.trim());

        entries.add(
          AccountTransaction(
            accountId: line.accountId!,
            transactionType: 'JOURNAL',
            referenceType: 'JOURNAL',
            referenceId: null,
            voucherNo: voucherNo,
            debit: amount,
            credit: 0,
            transactionDate: transactionDate,
            note: _narrationController.text.trim(),
            createdAt: now,
          ),
        );
      }

      for (final line in _creditLines) {
        final amount = double.parse(line.amount.text.trim());

        entries.add(
          AccountTransaction(
            accountId: line.accountId!,
            transactionType: 'JOURNAL',
            referenceType: 'JOURNAL',
            referenceId: null,
            voucherNo: voucherNo,
            debit: 0,
            credit: amount,
            transactionDate: transactionDate,
            note: _narrationController.text.trim(),
            createdAt: now,
          ),
        );
      }

      await _transactionRepository.createJournal(entries: entries);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Journal saved — $voucherNo')));

      // Stay on Journal for continuous entry.
      for (final line in _debitLines) {
        line.amount.dispose();
      }
      for (final line in _creditLines) {
        line.amount.dispose();
      }

      setState(() {
        _narrationController.clear();
        _selectedDate = DateTime.now();
        _dateController.text = _formatDate(_selectedDate);

        _debitLines
          ..clear()
          ..add(_JournalLine());

        _creditLines
          ..clear()
          ..add(_JournalLine());
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save journal: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  Widget _accountDropdown(_JournalLine line) {
    final selectedAccount = line.accountId == null
        ? null
        : _accounts.cast<Account?>().firstWhere(
            (account) => account?.id == line.accountId,
            orElse: () => null,
          );

    return FormField<int>(
      initialValue: line.accountId,
      validator: (_) {
        if (line.accountId == null) {
          return 'Select account';
        }
        return null;
      },
      builder: (field) {
        return InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            final selected = await showDialog<Account>(
              context: context,
              builder: (dialogContext) {
                String query = '';

                return StatefulBuilder(
                  builder: (context, setDialogState) {
                    final normalizedQuery = query.trim().toLowerCase();

                    final filtered = normalizedQuery.isEmpty
                        ? _accounts
                        : _accounts.where((account) {
                            final name = account.name.toLowerCase();
                            final type = account.type.toLowerCase();

                            return name.contains(normalizedQuery) ||
                                type.contains(normalizedQuery);
                          }).toList();

                    return AlertDialog(
                      title: const Text('Select Account'),
                      content: SizedBox(
                        width: 520,
                        height: 520,
                        child: Column(
                          children: [
                            TextField(
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'Search account...',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                setDialogState(() {
                                  query = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: filtered.isEmpty
                                  ? const Center(
                                      child: Text('No account found'),
                                    )
                                  : ListView.separated(
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final account = filtered[index];

                                        return ListTile(
                                          dense: true,
                                          title: Text(account.name),
                                          subtitle: account.type.trim().isEmpty
                                              ? null
                                              : Text(account.type),
                                          trailing: account.id == line.accountId
                                              ? const Icon(Icons.check)
                                              : null,
                                          onTap: () {
                                            Navigator.pop(
                                              dialogContext,
                                              account,
                                            );
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancel'),
                        ),
                      ],
                    );
                  },
                );
              },
            );

            if (selected == null || !mounted) return;

            setState(() {
              line.accountId = selected.id;
            });

            field.didChange(selected.id);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: 'Select account',
              border: const OutlineInputBorder(),
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.search),
            ),
            isEmpty: selectedAccount == null,
            child: selectedAccount == null
                ? null
                : Text(
                    selectedAccount.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        );
      },
    );
  }

  Widget _journalLine({
    required _JournalLine line,
    required bool debit,
    required int index,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _accountDropdown(line)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: line.amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: debit ? 'Debit' : 'Credit',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                _autoBalanceAmount(changedDebit: debit);
                setState(() {});
              },
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');

                if (amount == null || amount <= 0) {
                  return 'Required';
                }

                return null;
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Remove',
            onPressed:
                _debitLines.length == 1 && debit ||
                    _creditLines.length == 1 && !debit
                ? null
                : onRemove,
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Color color,
    required List<_JournalLine> lines,
    required bool debit,
    required VoidCallback onAdd,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(.12),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...lines.asMap().entries.map(
              (entry) => _journalLine(
                line: entry.value,
                debit: debit,
                index: entry.key,
                onRemove: () {
                  if (debit) {
                    _removeDebitLine(entry.key);
                  } else {
                    _removeCreditLine(entry.key);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    final balanced =
        _totalDebit > 0 && _totalCredit > 0 && _difference.abs() <= 0.000001;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _summaryItem(
                    'Total Debit',
                    _formatMoney(_totalDebit),
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryItem(
                    'Total Credit',
                    _formatMoney(_totalCredit),
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: balanced
                    ? Colors.green.withOpacity(.08)
                    : Colors.orange.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    balanced ? Icons.check_circle_outline : Icons.balance,
                    color: balanced ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      balanced
                          ? 'Journal Balanced'
                          : 'Difference: ${_formatMoney(_difference.abs())}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: balanced ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _dateController,
                            readOnly: true,
                            onTap: _pickDate,
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _narrationController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Narration',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _section(
                    title: 'Debit',
                    icon: Icons.arrow_downward_rounded,
                    color: Colors.red,
                    lines: _debitLines,
                    debit: true,
                    onAdd: _addDebitLine,
                  ),
                  _section(
                    title: 'Credit',
                    icon: Icons.arrow_upward_rounded,
                    color: Colors.green,
                    lines: _creditLines,
                    debit: false,
                    onAdd: _addCreditLine,
                  ),
                  _summary(),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save Journal'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
