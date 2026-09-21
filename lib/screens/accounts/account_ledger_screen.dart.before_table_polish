import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/account.dart';
import '../../services/ff/ff_universal_ledger_service.dart';

class AccountLedgerScreen extends StatefulWidget {
  final Account account;

  const AccountLedgerScreen({super.key, required this.account});

  @override
  State<AccountLedgerScreen> createState() => _AccountLedgerScreenState();
}

class _AccountLedgerScreenState extends State<AccountLedgerScreen> {
  final FFUniversalLedgerService _ledgerService =
      FFUniversalLedgerService.instance;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  List<Map<String, dynamic>> _transactions = [];

  FFUniversalLedgerSummary? _summary;

  // ============================================================
  // LOAD FF UNIVERSAL LEDGER
  // ============================================================

  Future<void> _loadLedger() async {
    if (widget.account.id == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final results = await Future.wait([
        _ledgerService.getLedger(accountId: widget.account.id!),
        _ledgerService.getSummary(accountId: widget.account.id!),
      ]);

      if (!mounted) return;

      setState(() {
        _transactions = results[0] as List<Map<String, dynamic>>;
        _summary = results[1] as FFUniversalLedgerSummary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load FF ledger: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  // ============================================================
  // VALUES
  // ============================================================

  double get _openingBalance {
    return _summary?.openingBalance ?? 0;
  }

  double get _currentBalance {
    return _summary?.closingBalance ?? 0;
  }

  double get _totalDebit {
    return _summary?.totalDebit ?? 0;
  }

  double get _totalCredit {
    return _summary?.totalCredit ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // FORMAT
  // ============================================================

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

  String _voucher(Map<String, dynamic> row) {
    final voucher = row['voucher_no']?.toString().trim() ?? '';

    if (voucher.isNotEmpty) {
      return voucher;
    }

    return '-';
  }

  String _description(Map<String, dynamic> row) {
    final note = row['note']?.toString().trim() ?? '';

    if (note.isNotEmpty) {
      return note;
    }

    final description = row['description']?.toString().trim() ?? '';

    if (description.isNotEmpty) {
      return description;
    }

    return row['transaction_type']?.toString().trim() ?? '';
  }

  String _transactionDate(Map<String, dynamic> row) {
    return row['transaction_date']?.toString().trim() ?? '';
  }

  // ============================================================
  // AMOUNT PRESENTATION
  //
  // IMPORTANT:
  // Debit/Credit are accounting movements.
  // We do NOT use legacy "+credit -debit" logic here.
  // Running balance comes directly from FF Universal Ledger.
  // ============================================================

  Color _amountColor(Map<String, dynamic> row) {
    final debit = _toDouble(row['debit']);
    final credit = _toDouble(row['credit']);

    if (debit > 0) {
      return Colors.red;
    }

    if (credit > 0) {
      return Colors.green;
    }

    return Colors.grey;
  }

  String _amountText(Map<String, dynamic> row) {
    final debit = _toDouble(row['debit']);
    final credit = _toDouble(row['credit']);

    if (debit > 0) {
      return 'Dr ৳${_formatMoney(debit)}';
    }

    if (credit > 0) {
      return 'Cr ৳${_formatMoney(credit)}';
    }

    return '৳0';
  }

  // ============================================================
  // PDF
  // ============================================================

  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    final rows = <List<String>>[
      ['Date', 'Voucher', 'Description', 'Debit', 'Credit', 'Balance'],
    ];

    for (final transaction in _transactions) {
      final debit = _toDouble(transaction['debit']);

      final credit = _toDouble(transaction['credit']);

      final runningBalance = _toDouble(transaction['running_balance']);

      rows.add([
        _formatDate(_transactionDate(transaction)),
        _voucher(transaction),
        _description(transaction),
        debit > 0 ? _formatMoney(debit) : '',
        credit > 0 ? _formatMoney(credit) : '',
        _formatMoney(runningBalance),
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
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
              pw.Text('Type: ${widget.account.type}'),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          );
        },
        build: (context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Opening Balance: ${_formatMoney(_openingBalance)}'),
                pw.Text('Closing Balance: ${_formatMoney(_currentBalance)}'),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: rows.first,
              data: rows.skip(1).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.all(5),
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
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Debit: ${_formatMoney(_totalDebit)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(width: 24),
                pw.Text(
                  'Total Credit: ${_formatMoney(_totalCredit)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
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

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Opening Balance',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Closing Balance',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '৳${_formatMoney(_currentBalance)}',
                    style: const TextStyle(
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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 70,
            child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: 72,
            child: Text(
              'Voucher',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              'Dr / Cr',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 105,
            child: Text(
              'Balance',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OPENING ROW
  // ============================================================

  Widget _buildOpeningRow() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(
                _formatDate(widget.account.openingDate),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 2),
            const SizedBox(
              width: 72,
              child: Text(
                'OB',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                'Opening',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 105,
              child: Text(
                '৳${_formatMoney(_openingBalance)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TRANSACTION ROW
  // ============================================================

  Widget _buildTransactionRow(Map<String, dynamic> transaction) {
    final balance = _toDouble(transaction['running_balance']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(
                _formatDate(_transactionDate(transaction)),
                style: const TextStyle(fontSize: 12),
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
              child: Tooltip(
                message: _description(transaction),
                child: Text(
                  _amountText(transaction),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _amountColor(transaction),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 105,
              child: Text(
                '৳${_formatMoney(balance)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOTALS
  // ============================================================

  Widget _buildTotals() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Debit: ৳${_formatMoney(_totalDebit)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Credit: ৳${_formatMoney(_totalCredit)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _loading ? null : _exportPdf,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLedger,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _buildSummary(),
                  _buildHeader(),

                  if (_openingBalance != 0) _buildOpeningRow(),

                  if (_transactions.isEmpty && _openingBalance == 0)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text(
                          'No transactions yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),

                  ..._transactions.map(_buildTransactionRow),

                  const SizedBox(height: 12),

                  _buildTotals(),
                ],
              ),
            ),
    );
  }
}
