import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/account.dart';
import '../../models/account_transaction.dart';
import '../../services/account_transaction_repository.dart';

class AccountLedgerScreen extends StatefulWidget {
  final Account account;

  const AccountLedgerScreen({
    super.key,
    required this.account,
  });

  @override
  State<AccountLedgerScreen> createState() =>
      _AccountLedgerScreenState();
}

class _AccountLedgerScreenState extends State<AccountLedgerScreen> {
  final AccountTransactionRepository _repository =
      AccountTransactionRepository();

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  List<AccountTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() {
      _loading = true;
    });

    try {
      final data = await _repository.getTransactionsByAccount(
        widget.account.id!,
      );

      if (!mounted) return;

      setState(() {
        _transactions = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load ledger: $e'),
        ),
      );
    }
  }

  double get _totalDebit {
    return _transactions.fold(
      0,
      (sum, item) => sum + item.debit,
    );
  }

  double get _totalCredit {
    return _transactions.fold(
      0,
      (sum, item) => sum + item.credit,
    );
  }

  double get _openingBalance {
    return widget.account.openingBalance;
  }

  double get _currentBalance {
    return widget.account.balance;
  }

  String _formatMoney(double value) {
    return NumberFormat('#,##0.##').format(value);
  }

  String _formatDate(String value) {
    try {
      return _dateFormat.format(DateTime.parse(value));
    } catch (_) {
      return value.length >= 10 ? value.substring(0, 10) : value;
    }
  }

String _voucher(AccountTransaction transaction) {
  if (transaction.transactionType == "OPENING_BALANCE") {
    return "OB";
  }

  if (transaction.voucherNo != null &&
      transaction.voucherNo!.trim().isNotEmpty) {
    return transaction.voucherNo!;
  }

  return '-';
}
  String _description(AccountTransaction transaction) {
    if (transaction.note != null &&
        transaction.note!.trim().isNotEmpty) {
      return transaction.note!;
    }

    return transaction.transactionType;
  }

double _balanceAfterTransactions(int index) {
  double balance = _openingBalance;

  for (int i = 0; i <= index; i++) {
    final transaction = _transactions[i];

    balance += transaction.credit;
    balance -= transaction.debit;
  }

  return balance;
}

  Color _amountColor(AccountTransaction transaction) {
    if (transaction.credit > 0) {
      return Colors.green;
    }

    if (transaction.debit > 0) {
      return Colors.red;
    }

    return Colors.grey;
  }

  String _amountText(AccountTransaction transaction) {
    if (transaction.credit > 0) {
      return '+৳${_formatMoney(transaction.credit)}';
    }

    if (transaction.debit > 0) {
      return '-৳${_formatMoney(transaction.debit)}';
    }

    return '৳0';
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    double runningBalance = _openingBalance;

    final rows = <List<String>>[
      [
        'Date',
        'Voucher',
        'Description',
        'Debit',
        'Credit',
        'Balance',
      ],
    ];

    for (final transaction in _transactions) {
      runningBalance += transaction.credit;
      runningBalance -= transaction.debit;

      rows.add([
        _formatDate(transaction.transactionDate),
        _voucher(transaction),
        _description(transaction),
        transaction.debit > 0
            ? _formatMoney(transaction.debit)
            : '',
        transaction.credit > 0
            ? _formatMoney(transaction.credit)
            : '',
        _formatMoney(runningBalance),
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) {
          return pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Account Ledger',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                widget.account.name,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Type: ${widget.account.type}',
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 9,
              ),
            ),
          );
        },
        build: (context) {
          return [
            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Opening Balance: ৳${_formatMoney(_openingBalance)}',
                ),
                pw.Text(
                  'Current Balance: ৳${_formatMoney(_currentBalance)}',
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: rows.first,
              data: rows.skip(1).toList(),
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 8,
              ),
              headerDecoration:
                  const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding:
                  const pw.EdgeInsets.all(5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.1),
                1: const pw.FlexColumnWidth(1.1),
                2: const pw.FlexColumnWidth(2.0),
                3: const pw.FlexColumnWidth(1.1),
                4: const pw.FlexColumnWidth(1.1),
                5: const pw.FlexColumnWidth(1.2),
              },
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Debit: ৳${_formatMoney(_totalDebit)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(width: 24),
                pw.Text(
                  'Total Credit: ৳${_formatMoney(_totalCredit)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async {
        return pdf.save();
      },
    );
  }

  Widget _buildSummary() {
    return Card(
      margin: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        6,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Opening Balance',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '৳${_formatMoney(_openingBalance)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Current Balance',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '৳${_formatMoney(_currentBalance)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
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

Widget _buildHeader() {
  return Container(
    margin: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 6,
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            'Date',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        SizedBox(
          width: 72,
          child: Text(
            'Voucher',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Expanded(
          child: Text(
            'Amount',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        SizedBox(
          width: 105,
          child: Text(
            'Balance',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildOpeningRow() {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 82,
              child: Text(
                _formatDate(widget.account.openingDate),
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),

            const SizedBox(
              width: 105,
              child: Text(
                'OB',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '+৳${_formatMoney(_openingBalance)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 105,
              child: Text(
                '৳${_formatMoney(_openingBalance)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildTransactionRow(
  AccountTransaction transaction,
  int index,
) {
  final balance = _balanceAfterTransactions(index);

  return Card(
    margin: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 3,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      child: Row(
  children: [
    SizedBox(
      width: 70,
      child: Text(
        _formatDate(
          transaction.transactionDate,
        ),
        style: const TextStyle(
          fontSize: 12,
        ),
      ),
    ),

    const SizedBox(width: 2),

    SizedBox(
      width: 72,
      child: Text(
        _voucher(transaction),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ),

    Expanded(
      child: Text(
        _amountText(transaction),
        textAlign: TextAlign.right,
        style: TextStyle(
          color: _amountColor(transaction),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    const SizedBox(width: 8),

    SizedBox(
      width: 105,
      child: Text(
        '৳${_formatMoney(balance)}',
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ],
)
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(
              Icons.picture_as_pdf,
            ),
            onPressed:
                _loading ? null : _exportPdf,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadLedger,
              child: ListView(
                padding: const EdgeInsets.only(
                  bottom: 24,
                ),
                children: [
                  _buildSummary(),
                  _buildHeader(),
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text(
                          'No transactions yet.',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ...List.generate(
                    _transactions.length,
                    (index) => _buildTransactionRow(
                      _transactions[index],
                      index,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Debit: ৳${_formatMoney(_totalDebit)}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Credit: ৳${_formatMoney(_totalCredit)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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