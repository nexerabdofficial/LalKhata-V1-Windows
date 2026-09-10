import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../gab/gab_branding.dart';
import '../models/supplier_ledger.dart';

class SupplierLedgerPdf {
  static Future<void> generate({
    required String supplierName,
    required List<SupplierLedger> ledger,
    required DateTime? fromDate,
    required DateTime? toDate,
    double openingBalance = 0,
  }) async {
    final pdf = pw.Document();

    double totalDebit = 0;
    double totalCredit = 0;

    // ============================================================
    // RUNNING BALANCE
    // ============================================================

    double runningBalance = openingBalance;

    for (final item in ledger) {
      totalDebit += item.debit;
      totalCredit += item.credit;

      runningBalance += item.debit;
      runningBalance -= item.credit;
    }

    // ============================================================
    // PERIOD
    // ============================================================

    final period =
        fromDate == null && toDate == null
            ? "All Transactions"
            : "${fromDate == null ? "-" : DateFormat("dd MMM yyyy").format(fromDate!)}"
                "  →  "
                "${toDate == null ? "-" : DateFormat("dd MMM yyyy").format(toDate!)}";

    // ============================================================
    // PDF PAGE
    // ============================================================

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),

        build: (context) => [
          // ========================================================
          // HEADER
          // ========================================================

          pw.Text(
            GABBranding.businessName,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 6),

          pw.Text(
            "Supplier Ledger Statement",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.Divider(),

          pw.Text(
            "Supplier : $supplierName",
          ),

          pw.Text(
            "Period : $period",
          ),

          pw.SizedBox(height: 20),

          // ========================================================
          // OPENING / PREVIOUS BALANCE
          // ========================================================

          if (openingBalance != 0)
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
                        ? "Previous Balance"
                        : "Opening Balance",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Tk. ${openingBalance.toStringAsFixed(0)}",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (openingBalance != 0)
            pw.SizedBox(height: 14),

          // ========================================================
          // LEDGER TABLE
          // ========================================================

          pw.Table.fromTextArray(
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: .5,
            ),

            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),

            headerDecoration:
                const pw.BoxDecoration(
              color: PdfColors.blue700,
            ),

            cellAlignment:
                pw.Alignment.centerLeft,

            cellStyle: const pw.TextStyle(
              fontSize: 10,
            ),

            headers: const [
              "Date",
              "Voucher",
              "Amount",
              "Balance",
            ],

            data: (() {
              // IMPORTANT:
              // Start from opening/previous balance.
              double balance = openingBalance;

              return ledger.map((item) {
                balance += item.debit;
                balance -= item.credit;

                final date =
                    DateTime.tryParse(item.date);

                return [
                  date == null
                      ? "-"
                      : DateFormat("dd MMM yy")
                          .format(date),

                  item.reference.isEmpty
                      ? item.particular
                      : item.reference,

                  item.debit > 0
                      ? "+${item.debit.toStringAsFixed(0)}"
                      : item.credit > 0
                          ? "-${item.credit.toStringAsFixed(0)}"
                          : "0",

                  balance.toStringAsFixed(0),
                ];
              }).toList();
            })(),
          ),

          pw.SizedBox(height: 20),

          // ========================================================
          // SUMMARY
          // ========================================================

          pw.Align(
            alignment:
                pw.Alignment.centerRight,
            child: pw.Container(
              width: 220,
              child: pw.Column(
                children: [
                  _summaryRow(
                    "Total Purchase",
                    totalDebit,
                  ),

                  _summaryRow(
                    "Total Paid",
                    totalCredit,
                  ),

                  pw.Divider(),

                  _summaryRow(
                    "Current Due",
                    runningBalance,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // ============================================================
    // SAVE TEMP FILE
    // ============================================================

    final dir =
        await getTemporaryDirectory();

    final file = File(
      "${dir.path}/Supplier_Ledger.pdf",
    );

    await file.writeAsBytes(
      await pdf.save(),
    );

    // ============================================================
    // PRINT / PREVIEW
    // ============================================================

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
    );
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
      padding:
          const pw.EdgeInsets.symmetric(
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
            "Tk. ${value.toStringAsFixed(0)}",
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