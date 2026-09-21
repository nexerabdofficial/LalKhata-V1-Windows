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
import '../services/ff/ff_cash_flow_service.dart';
import '../services/storage_service.dart';

class CashFlowPdf {
  CashFlowPdf._();

  static final StorageService _storageService = StorageService.instance;

  static Future<pw.MemoryImage?> _loadImage(String? path) async {
    try {
      if (path == null || path.trim().isEmpty) return null;

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

  static Future<Uint8List> generate({
    required DateTime from,
    required DateTime to,
  }) async {
    final report = await FFCashFlowService.instance.getReport(
      from: from,
      to: to,
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

    String date(String value) {
      final parsed = DateTime.tryParse(value);

      if (parsed == null) return value;

      return DateFormat('dd MMM yyyy').format(parsed);
    }

    pw.Widget summaryCell(String label, double amount) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: .4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                money(amount),
                style: pw.TextStyle(font: bold, fontSize: 9),
              ),
            ],
          ),
        ),
      );
    }

    pw.Widget controlRow(String label, double amount, {bool strong = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: strong ? bold : regular,
                  fontSize: 7.4,
                ),
              ),
            ),
            pw.Text(
              money(amount),
              style: pw.TextStyle(font: strong ? bold : regular, fontSize: 7.4),
            ),
          ],
        ),
      );
    }

    final rows = report.rows.map((row) {
      final transfer = row.isInternalTransfer;

      final incoming = !transfer && row.debit > 0;

      final inflow = transfer ? 0.0 : row.debit;
      final outflow = transfer ? 0.0 : row.credit;

      final voucher = row.voucherNo?.trim().isNotEmpty == true
          ? row.voucherNo!
          : row.transactionType;

      final description = row.note?.trim().isNotEmpty == true
          ? row.note!
          : row.description?.trim().isNotEmpty == true
          ? row.description!
          : row.transactionType;

      return [
        date(row.transactionDate),
        voucher,
        row.accountName,
        transfer
            ? 'Internal Transfer'
            : incoming
            ? 'Cash In'
            : 'Cash Out',
        description,
        inflow == 0 ? '' : money(inflow),
        outflow == 0 ? '' : money(outflow),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(22, 18, 22, 18),
        header: (_) {
          return pw.Column(
            children: [
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
                      'CASH FLOW STATEMENT',
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
              pw.SizedBox(height: 7),
            ],
          );
        },
        footer: (_) {
          return pw.Container(
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
                  'Cash Flow Statement',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 6.8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        build: (_) => [
          pw.Row(
            children: [
              summaryCell('Opening Cash', report.openingBalance),
              pw.SizedBox(width: 4),
              summaryCell('Cash In', report.cashIn),
              pw.SizedBox(width: 4),
              summaryCell('Cash Out', report.cashOut),
              pw.SizedBox(width: 4),
              summaryCell('Closing Cash', report.closingBalance),
            ],
          ),

          pw.SizedBox(height: 7),

          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: .4),
            ),
            child: pw.Column(
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  color: const PdfColor.fromInt(0xffeef4e8),
                  child: pw.Text(
                    'CASH CONTROL',
                    style: pw.TextStyle(font: bold, fontSize: 8),
                  ),
                ),
                controlRow('Opening Balance', report.openingBalance),
                controlRow('Net Cash Flow', report.netCashFlow),
                controlRow('Expected Closing', report.expectedClosing),
                controlRow('Actual Closing', report.closingBalance),
                pw.Divider(height: 1, color: PdfColors.grey400),
                controlRow(
                  'Control Difference',
                  report.controlDifference,
                  strong: true,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 8),

          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: const PdfColor.fromInt(0xff173f35),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'CASH MOVEMENTS',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 8,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.Text(
                  'Internal Transfer: '
                  '${money(report.internalTransfers)}',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 7,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),

          if (rows.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(25),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'No cash flow transactions found.',
                style: pw.TextStyle(font: regular, fontSize: 8),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Date',
                'Voucher',
                'Account',
                'Type',
                'Particulars',
                'In',
                'Out',
              ],
              data: rows,
              headerStyle: pw.TextStyle(
                font: bold,
                fontSize: 6.8,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xff173f35),
              ),
              cellStyle: pw.TextStyle(font: regular, fontSize: 6.4),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 3,
                vertical: 3.5,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: .35),
              columnWidths: {
                0: const pw.FixedColumnWidth(52),
                1: const pw.FixedColumnWidth(67),
                2: const pw.FixedColumnWidth(70),
                3: const pw.FixedColumnWidth(55),
                4: const pw.FlexColumnWidth(),
                5: const pw.FixedColumnWidth(55),
                6: const pw.FixedColumnWidth(55),
              },
            ),

          pw.SizedBox(height: 6),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Generated: '
              '${DateFormat('dd MMM yyyy  hh:mm a').format(DateTime.now())}',
              style: pw.TextStyle(
                font: regular,
                fontSize: 6.5,
                color: PdfColors.grey700,
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

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
        'Cash_Flow_'
        '${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      ),
    );

    await file.writeAsBytes(bytes, flush: true);

    return file;
  }
}
