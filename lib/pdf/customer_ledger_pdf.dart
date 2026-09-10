import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../gab/gab_branding.dart';
import '../models/customer_ledger.dart';

class CustomerLedgerPdf {
  static Future<void> generate({
    required String customerName,
    required List<CustomerLedger> ledger,
    required DateTime? fromDate,
    required DateTime? toDate,
    double previousBalance = 0,
  }) async {
    final pdf = pw.Document();

    // ============================================================
    // TOTALS
    // ============================================================

    double totalDebit = 0;
    double totalCredit = 0;

    for (final item in ledger) {
      // Opening Balance is not a period transaction.
      if (_isOpeningEntry(item)) {
        continue;
      }

      totalDebit += item.debit;
      totalCredit += item.credit;
    }

    // ============================================================
    // CURRENT BALANCE
    // ============================================================

    double runningBalance = previousBalance;

    for (final item in ledger) {
      // Previous balance already contains opening balance.
      if (_isOpeningEntry(item)) {
        continue;
      }

      runningBalance += item.debit;
      runningBalance -= item.credit;
    }

    // ============================================================
    // PERIOD
    // ============================================================

    final String period =
        fromDate == null && toDate == null
            ? 'All Transactions'
            : '${fromDate == null ? '-' : DateFormat('dd MMM yyyy').format(fromDate!)}'
                '  →  '
                '${toDate == null ? '-' : DateFormat('dd MMM yyyy').format(toDate!)}';

    // ============================================================
    // PDF PAGE
    // ============================================================

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            // ======================================================
            // HEADER
            // ======================================================

            pw.Text(
              GABBranding.businessName,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 6),

            pw.Text(
              'Customer Ledger Statement',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.Divider(),

            pw.Text(
              'Customer : $customerName',
            ),

            pw.Text(
              'Period : $period',
            ),

            pw.SizedBox(height: 20),

            // ======================================================
            // PREVIOUS BALANCE
            // ======================================================

            if (previousBalance != 0)
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(
                    color: PdfColors.grey400,
                    width: .5,
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      fromDate != null
                          ? 'Previous Balance'
                          : 'Opening Balance',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Tk. ${previousBalance.toStringAsFixed(0)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            if (previousBalance != 0)
              pw.SizedBox(height: 14),

            // ======================================================
            // LEDGER TABLE
            // ======================================================

            pw.Table.fromTextArray(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: .5,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue700,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(
                fontSize: 10,
              ),
              headers: const [
                'Date',
                'Voucher',
                'Amount',
                'Balance',
              ],
              data: _buildTableData(
                ledger,
                previousBalance,
              ),
            ),

            pw.SizedBox(height: 20),

            // ======================================================
            // SUMMARY
            // ======================================================

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 220,
                child: pw.Column(
                  children: [
                    _summaryRow(
                      'Total Sales',
                      totalDebit,
                    ),

                    _summaryRow(
                      'Total Received',
                      totalCredit,
                    ),

                    pw.Divider(),

                    _summaryRow(
                      'Current Due',
                      runningBalance,
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

    // ============================================================
    // SAVE TEMP FILE
    // ============================================================

    final dir = await getTemporaryDirectory();

    final file = File(
      '${dir.path}/Customer_Ledger.pdf',
    );

    await file.writeAsBytes(
      await pdf.save(),
    );

    // ============================================================
    // PRINT / PREVIEW
    // ============================================================

    await Printing.layoutPdf(
      onLayout: (_) async {
        return pdf.save();
      },
    );
  }

  // ============================================================
  // TABLE DATA
  // ============================================================

  static List<List<String>> _buildTableData(
    List<CustomerLedger> ledger,
    double previousBalance,
  ) {
    double balance = previousBalance;

    return ledger.map((item) {
      // Opening entry already included
      // in previousBalance.
      if (!_isOpeningEntry(item)) {
        balance += item.debit;
        balance -= item.credit;
      }

      final date = DateTime.tryParse(
        item.date,
      );

      final amount = item.debit > 0
          ? '+${item.debit.toStringAsFixed(0)}'
          : item.credit > 0
              ? '-${item.credit.toStringAsFixed(0)}'
              : '0';

      return [
        date == null
            ? '-'
            : DateFormat(
                'dd MMM yy',
              ).format(date),
        _voucher(item),
        amount,
        balance.toStringAsFixed(0),
      ];
    }).toList();
  }

  // ============================================================
  // OPENING ENTRY CHECK
  // ============================================================

  static bool _isOpeningEntry(
    CustomerLedger item,
  ) {
    final particular = item.particular
        .trim()
        .toLowerCase();

    final reference = item.reference
        .trim()
        .toLowerCase();

    return particular.contains('opening') ||
        reference == 'opening' ||
        reference == 'ob';
  }

  // ============================================================
  // VOUCHER
  // ============================================================

  static String _voucher(
    CustomerLedger item,
  ) {
    final reference = item.reference.trim();

    if (reference.isNotEmpty) {
      return reference;
    }

    if (_isOpeningEntry(item)) {
      return 'OB';
    }

    final particular = item.particular.trim();

    if (particular.isNotEmpty) {
      return particular;
    }

    return '-';
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  static pw.Widget _summaryRow(
    String title,
    double value, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        vertical: 3,
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: bold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            'Tk. ${value.toStringAsFixed(0)}',
            style: pw.TextStyle(
              fontWeight: bold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}