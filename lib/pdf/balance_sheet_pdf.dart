import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/app_build_config.dart';
import '../gab/gab_branding.dart';
import '../services/ff/ff_balance_sheet_service.dart';
import '../services/storage_service.dart';

class BalanceSheetPdf {
  BalanceSheetPdf._();

  static final StorageService _storageService = StorageService.instance;

  // ============================================================
  // BRANDING
  // ============================================================

  static Future<pw.MemoryImage?> _loadImage(String? path) async {
    try {
      if (path == null || path.trim().isEmpty) {
        return null;
      }

      final file = File(path.trim());

      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) return null;

      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<pw.MemoryImage?> _logo() async {
    return _loadImage(await _storageService.getInvoiceLogoPath());
  }

  static Future<pw.MemoryImage?> _qr() async {
    return _loadImage(await _storageService.getInvoiceQrPath());
  }

  static pw.Widget _imagePlate(pw.MemoryImage image, {required bool qr}) {
    return pw.Container(
      width: qr ? 58 : 105,
      height: qr ? 58 : 50,
      alignment: pw.Alignment.center,
      child: pw.Image(image, fit: pw.BoxFit.contain),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static bool _visible(double value) {
    return value.abs() > 0.000001;
  }

  static double _sum(List<FFBalanceSheetRow> rows) {
    return rows.fold<double>(0, (total, row) => total + row.balance);
  }

  // ============================================================
  // GENERATE
  // ============================================================

  static Future<Uint8List> generate({
    required FFBalanceSheetReport report,
  }) async {
    final regular = await PdfGoogleFonts.notoSansRegular();

    final bold = await PdfGoogleFonts.notoSansBold();

    final logo = await _logo();
    final qr = await _qr();

    final pdf = pw.Document();

    final formatter = NumberFormat('#,##0.00');

    String money(double value) {
      final amount = value.abs();

      return value < 0
          ? '-Tk ${formatter.format(amount)}'
          : 'Tk ${formatter.format(amount)}';
    }

    // ==========================================================
    // CLASSIFICATION — SAME AS ERP SCREEN
    // ==========================================================

    final fixedAssets = report.assets.where((row) {
      return row.groupCode == 'FIXED_ASSETS' ||
          row.accountType == 'FIXED_ASSET';
    }).toList();

    final cashBankMfs = report.assets.where((row) {
      return row.groupCode == 'CASH' ||
          row.groupCode == 'BANK' ||
          row.groupCode == 'MFS' ||
          row.accountType == 'CASH' ||
          row.accountType == 'BANK' ||
          row.accountType == 'MOBILE_BANKING';
    }).toList();

    final receivables = report.assets.where((row) {
      return row.groupCode == 'CUSTOMER_RECEIVABLE' ||
          row.accountType == 'CUSTOMER' ||
          row.accountType == 'CUSTOMER_RECEIVABLE';
    }).toList();

    final loanReceivables = report.assets.where((row) {
      return row.groupCode == 'LOAN_RECEIVABLE' ||
          row.accountType == 'LOAN_RECEIVABLE';
    }).toList();

    final usedAssets = <int>{
      ...fixedAssets.map((e) => e.accountId),
      ...cashBankMfs.map((e) => e.accountId),
      ...receivables.map((e) => e.accountId),
      ...loanReceivables.map((e) => e.accountId),
    };

    final otherAssets = report.assets.where((row) {
      return row.accountType != 'INVENTORY' &&
          !usedAssets.contains(row.accountId);
    }).toList();

    final supplierPayables = report.liabilities.where((row) {
      return row.groupCode == 'SUPPLIER_PAYABLE' ||
          row.accountType == 'SUPPLIER' ||
          row.accountType == 'SUPPLIER_PAYABLE';
    }).toList();

    final loanPayables = report.liabilities.where((row) {
      return row.groupCode == 'LOAN_PAYABLE' ||
          row.accountType == 'LOAN_PAYABLE';
    }).toList();

    final usedLiabilities = <int>{
      ...supplierPayables.map((e) => e.accountId),
      ...loanPayables.map((e) => e.accountId),
    };

    final otherLiabilities = report.liabilities.where((row) {
      return !usedLiabilities.contains(row.accountId);
    }).toList();

    final equityRows = report.equity.where((e) => _visible(e.balance)).toList();

    final capitalValue = report.ledgerEquity + report.currentProfit;

    // ==========================================================
    // ROW BUILDERS
    // ==========================================================

    pw.Widget ledgerRow(String name, double amount, {bool strong = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(12, 4, 8, 4),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                name,
                maxLines: 1,
                style: pw.TextStyle(
                  font: strong ? bold : regular,
                  fontSize: strong ? 8.2 : 7.4,
                ),
              ),
            ),
            pw.SizedBox(width: 5),
            pw.Text(
              money(amount),
              style: pw.TextStyle(
                font: strong ? bold : regular,
                fontSize: strong ? 8.2 : 7.4,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget groupRow(String name, double amount) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
        decoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xffeef4e8),
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey400, width: .35),
            bottom: pw.BorderSide(color: PdfColors.grey400, width: .35),
          ),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                name,
                style: pw.TextStyle(font: bold, fontSize: 7.8),
              ),
            ),
            pw.Text(
              money(amount),
              style: pw.TextStyle(font: bold, fontSize: 7.8),
            ),
          ],
        ),
      );
    }

    List<pw.Widget> accountRows(List<FFBalanceSheetRow> rows) {
      return rows
          .where((row) => _visible(row.balance))
          .map((row) => ledgerRow(row.accountName, row.balance))
          .toList();
    }

    // ==========================================================
    // LEFT CONTENT
    // ==========================================================

    final left = <pw.Widget>[
      groupRow('Capital & Reserves', capitalValue),

      ...accountRows(equityRows),

      if (_visible(report.currentProfit))
        ledgerRow(
          report.currentProfit >= 0 ? 'Current Profit' : 'Current Loss',
          report.currentProfit,
        ),

      if (loanPayables.any((e) => _visible(e.balance))) ...[
        groupRow('Loans', _sum(loanPayables)),
        ...accountRows(loanPayables),
      ],

      if (supplierPayables.any((e) => _visible(e.balance))) ...[
        groupRow('Sundry Creditors / Payables', _sum(supplierPayables)),
        ...accountRows(supplierPayables),
      ],

      if (otherLiabilities.any((e) => _visible(e.balance))) ...[
        groupRow('Other Current Liabilities', _sum(otherLiabilities)),
        ...accountRows(otherLiabilities),
      ],
    ];

    // ==========================================================
    // RIGHT CONTENT
    // ==========================================================

    final right = <pw.Widget>[
      if (fixedAssets.any((e) => _visible(e.balance))) ...[
        groupRow('Fixed Assets', _sum(fixedAssets)),
        ...accountRows(fixedAssets),
      ],

      groupRow('Current Assets', report.totalAssets - _sum(fixedAssets)),

      if (cashBankMfs.any((e) => _visible(e.balance))) ...[
        groupRow('Cash / Bank / MFS', _sum(cashBankMfs)),
        ...accountRows(cashBankMfs),
      ],

      if (receivables.any((e) => _visible(e.balance))) ...[
        groupRow('Sundry Debtors / Receivables', _sum(receivables)),
        ...accountRows(receivables),
      ],

      if (loanReceivables.any((e) => _visible(e.balance))) ...[
        groupRow('Loans & Advances', _sum(loanReceivables)),
        ...accountRows(loanReceivables),
      ],

      groupRow('Closing Stock', report.inventoryValue),

      ledgerRow('Inventory / Stock', report.inventoryValue),

      if (otherAssets.any((e) => _visible(e.balance))) ...[
        groupRow('Other Current Assets', _sum(otherAssets)),
        ...accountRows(otherAssets),
      ],
    ];

    // ==========================================================
    // ERP PANEL
    // ==========================================================

    pw.Widget panel({
      required String title,
      required double total,
      required List<pw.Widget> children,
    }) {
      return pw.Container(
        height: 455,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500, width: .55),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              color: const PdfColor.fromInt(0xff173f35),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      title,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 8.5,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.Text(
                    money(total),
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 8.5,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),

            ...children,

            pw.Spacer(),

            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xfff3f5ef),
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey500, width: .5),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(font: bold, fontSize: 8.3),
                    ),
                  ),
                  pw.Text(
                    money(total),
                    style: pw.TextStyle(font: bold, fontSize: 8.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final difference = report.accountingDifference;

    final balanced = difference.abs() < 0.005;

    // ==========================================================
    // PAGE
    // ==========================================================

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(22, 18, 22, 18),
        build: (context) {
          return pw.Column(
            children: [
              // ==================================================
              // BRAND HEADER
              // ==================================================
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 110,
                    child: logo != null
                        ? _imagePlate(logo, qr: false)
                        : pw.SizedBox(),
                  ),

                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          GABBranding.businessName,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 17,
                            color: const PdfColor.fromInt(0xff173f35),
                          ),
                        ),

                        if (GABBranding.tagline.trim().isNotEmpty)
                          pw.Text(
                            GABBranding.tagline,
                            style: pw.TextStyle(font: regular, fontSize: 7.5),
                          ),

                        if (GABBranding.address.trim().isNotEmpty)
                          pw.Text(
                            GABBranding.address,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: regular, fontSize: 7.2),
                          ),

                        pw.Text(
                          [
                            if (GABBranding.phone.trim().isNotEmpty)
                              GABBranding.phone,
                            if (GABBranding.email.trim().isNotEmpty)
                              GABBranding.email,
                          ].join('  |  '),
                          style: pw.TextStyle(font: regular, fontSize: 7.2),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(
                    width: 110,
                    child: qr != null
                        ? pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: _imagePlate(qr, qr: true),
                          )
                        : pw.SizedBox(),
                  ),
                ],
              ),

              pw.SizedBox(height: 7),

              // ==================================================
              // TITLE
              // ==================================================
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xff173f35),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'BALANCE SHEET',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'Statement of Financial Position',
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 7,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),

              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Generated: '
                  '${DateFormat('dd MMM yyyy  hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 6.8,
                    color: PdfColors.grey700,
                  ),
                ),
              ),

              pw.SizedBox(height: 6),

              // ==================================================
              // TWO-COLUMN ERP STATEMENT
              // ==================================================
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Expanded(
                      child: panel(
                        title: 'CAPITAL & LIABILITIES',
                        total: report.liabilitiesAndEquity,
                        children: left,
                      ),
                    ),

                    pw.SizedBox(width: 2),

                    pw.Expanded(
                      child: panel(
                        title: 'ASSETS',
                        total: report.totalAssets,
                        children: right,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),

              // ==================================================
              // CONTROL
              // ==================================================
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: pw.BoxDecoration(
                  color: balanced
                      ? const PdfColor.fromInt(0xffedf7ef)
                      : const PdfColor.fromInt(0xfffff7e6),
                  border: pw.Border.all(color: PdfColors.grey400, width: .4),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        balanced
                            ? 'Balance Sheet is balanced.'
                            : 'Opening / accounting difference: ${money(difference)}',
                        style: pw.TextStyle(font: bold, fontSize: 7),
                      ),
                    ),

                    pw.Text(
                      'Assets ${money(report.totalAssets)}   |   '
                      'Capital & Liabilities '
                      '${money(report.liabilitiesAndEquity)}',
                      style: pw.TextStyle(font: regular, fontSize: 6.7),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 5),

              // ==================================================
              // FOOTER
              // ==================================================
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey400, width: .4),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (AppBuildConfig.showDeveloperBranding)
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Developed by ',
                              style: pw.TextStyle(
                                font: regular,
                                fontSize: 6.8,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.TextSpan(
                              text: 'Nexera IT BD',
                              style: pw.TextStyle(
                                font: bold,
                                fontSize: 6.8,
                                color: const PdfColor.fromInt(0xff173f35),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      pw.SizedBox(),

                    pw.Text(
                      'Balance Sheet',
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 6.8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // SAVE
  // ============================================================

  static Future<File> savePdf({required FFBalanceSheetReport report}) async {
    final bytes = await generate(report: report);

    final root = await getApplicationDocumentsDirectory();

    final folder = Directory(p.join(root.path, 'LalKhata', 'Reports'));

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File(
      p.join(
        folder.path,
        'Balance_Sheet_'
        '${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      ),
    );

    await file.writeAsBytes(bytes, flush: true);

    return file;
  }
}
