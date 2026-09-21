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
import '../services/profit_repository.dart';
import '../services/storage_service.dart';

class ProfitLossPdf {
  ProfitLossPdf._();

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

  static bool _visible(double value) {
    return value.abs() > 0.000001;
  }

  // ============================================================
  // GENERATE
  // ============================================================

  static Future<Uint8List> generate({
    required DateTime from,
    required DateTime to,
  }) async {
    final effectiveTo = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

    final report = await ProfitRepository().getProfitStatement(
      from: from,
      to: effectiveTo,
    );

    final regular = await PdfGoogleFonts.notoSansRegular();

    final bold = await PdfGoogleFonts.notoSansBold();

    final logo = await _logo();
    final qr = await _qr();

    final pdf = pw.Document();

    final number = NumberFormat('#,##0.00');

    String money(double value) {
      return value < 0
          ? '-Tk ${number.format(value.abs())}'
          : 'Tk ${number.format(value)}';
    }

    final salesAccounts = report.incomeAccounts
        .where((e) => e.groupCode == 'SALES_INCOME' && _visible(e.amount))
        .toList();

    final otherIncomeAccounts = report.incomeAccounts
        .where((e) => e.groupCode != 'SALES_INCOME' && _visible(e.amount))
        .toList();

    final expenseAccounts = report.expenseAccounts
        .where((e) => _visible(e.amount))
        .toList();

    // ==========================================================
    // ROWS
    // ==========================================================

    pw.Widget accountRow(String name, double amount, {bool strong = false}) {
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

    pw.Widget resultRow(String title, double amount) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: amount >= 0
              ? const PdfColor.fromInt(0xffedf7ef)
              : const PdfColor.fromInt(0xffffeeee),
          border: const pw.Border(
            top: pw.BorderSide(color: PdfColors.grey500, width: .5),
          ),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                title,
                style: pw.TextStyle(font: bold, fontSize: 8.5),
              ),
            ),
            pw.Text(
              money(amount),
              style: pw.TextStyle(font: bold, fontSize: 8.5),
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // LEFT
    // ==========================================================

    final left = <pw.Widget>[
      groupRow('Sales / Operating Revenue', report.salesIncome),

      if (salesAccounts.isEmpty)
        accountRow('Sales Income', report.salesIncome)
      else
        ...salesAccounts.map((e) => accountRow(e.accountName, e.amount)),

      if (_visible(report.otherIncome) || otherIncomeAccounts.isNotEmpty) ...[
        groupRow('Other Income', report.otherIncome),
        if (otherIncomeAccounts.isEmpty)
          accountRow('Other Income', report.otherIncome)
        else
          ...otherIncomeAccounts.map(
            (e) => accountRow(e.accountName, e.amount),
          ),
      ],

      groupRow('Total Revenue', report.totalIncome),

      pw.SizedBox(height: 8),

      groupRow('Gross Profit', report.grossProfit),

      accountRow('Sales Revenue', report.salesIncome),

      accountRow('Less: Cost of Goods Sold', -report.cogs),

      pw.Spacer(),

      resultRow(
        report.netProfit >= 0 ? 'NET PROFIT' : 'NET LOSS',
        report.netProfit,
      ),
    ];

    // ==========================================================
    // RIGHT
    // ==========================================================

    final right = <pw.Widget>[
      groupRow('Cost of Sales', report.cogs),

      accountRow('Cost of Goods Sold', report.cogs),

      groupRow('Operating Expenses', report.operatingExpenses),

      if (expenseAccounts.isEmpty)
        accountRow('Operating Expenses', report.operatingExpenses)
      else
        ...expenseAccounts.map((e) => accountRow(e.accountName, e.amount)),

      groupRow('Total Cost & Expenses', report.cogs + report.operatingExpenses),

      pw.Spacer(),

      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        color: const PdfColor.fromInt(0xfff3f5ef),
        child: pw.Column(
          children: [
            accountRow('Gross Profit', report.grossProfit, strong: true),
            accountRow('Other Income', report.otherIncome, strong: true),
            accountRow(
              'Operating Expenses',
              report.operatingExpenses,
              strong: true,
            ),
          ],
        ),
      ),
    ];

    // ==========================================================
    // PANEL
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
          ],
        ),
      );
    }

    // ==========================================================
    // PAGE
    // ==========================================================

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(22, 18, 22, 18),
        build: (_) {
          return pw.Column(
            children: [
              // HEADER
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

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                color: const PdfColor.fromInt(0xff173f35),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PROFIT & LOSS ACCOUNT',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      '${DateFormat('dd MMM yyyy').format(from)}'
                      '  to  '
                      '${DateFormat('dd MMM yyyy').format(to)}',
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

              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Expanded(
                      child: panel(
                        title: 'INCOME / REVENUE',
                        total: report.totalIncome,
                        children: left,
                      ),
                    ),

                    pw.SizedBox(width: 2),

                    pw.Expanded(
                      child: panel(
                        title: 'COST & EXPENSES',
                        total: report.cogs + report.operatingExpenses,
                        children: right,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: report.netProfit >= 0
                      ? const PdfColor.fromInt(0xffedf7ef)
                      : const PdfColor.fromInt(0xffffeeee),
                  border: pw.Border.all(color: PdfColors.grey400, width: .4),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        report.netProfit >= 0
                            ? 'NET PROFIT FOR THE PERIOD'
                            : 'NET LOSS FOR THE PERIOD',
                        style: pw.TextStyle(font: bold, fontSize: 8),
                      ),
                    ),
                    pw.Text(
                      money(report.netProfit),
                      style: pw.TextStyle(font: bold, fontSize: 9),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 5),

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
                      'Profit & Loss',
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

  static Future<File> savePdf({
    required DateTime from,
    required DateTime to,
  }) async {
    final bytes = await generate(from: from, to: to);

    final root = await getApplicationDocumentsDirectory();

    final folder = Directory(p.join(root.path, 'LalKhata', 'Reports'));

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File(
      p.join(
        folder.path,
        'Profit_Loss_'
        '${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      ),
    );

    await file.writeAsBytes(bytes, flush: true);

    return file;
  }
}
