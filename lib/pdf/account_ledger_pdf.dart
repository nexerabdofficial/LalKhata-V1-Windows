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
import '../models/account.dart';
import '../services/storage_service.dart';
import '../services/ff/ff_universal_ledger_service.dart';

class AccountLedgerPdf {
  AccountLedgerPdf._();

  static final StorageService _storageService = StorageService.instance;

  static Future<pw.MemoryImage?> _loadImageFromPath(String? path) async {
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

  static Future<pw.MemoryImage?> _loadBusinessLogo() async {
    final path = await _storageService.getInvoiceLogoPath();
    return _loadImageFromPath(path);
  }

  static Future<pw.MemoryImage?> _loadInvoiceQr() async {
    final path = await _storageService.getInvoiceQrPath();
    return _loadImageFromPath(path);
  }

  static pw.Widget _brandingPlate({
    required pw.MemoryImage image,
    required bool isQr,
  }) {
    return pw.Container(
      width: isQr ? 72 : 118,
      height: isQr ? 72 : 58,
      alignment: pw.Alignment.center,
      child: pw.Image(image, fit: pw.BoxFit.contain),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatDate(dynamic value) {
    final raw = value?.toString() ?? '';

    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  static String _voucher(Map<String, dynamic> row) {
    for (final key in ['voucher_no', 'voucher', 'reference_no', 'reference']) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return '-';
  }

  static String _description(Map<String, dynamic> row, Account account) {
    final accountType = account.type.trim().toUpperCase();

    final debit = _toDouble(row['debit']);
    final credit = _toDouble(row['credit']);

    final transactionType =
        row['transaction_type']?.toString().trim().toUpperCase() ?? '';

    final referenceType =
        row['reference_type']?.toString().trim().toUpperCase() ?? '';

    final voucher = row['voucher_no']?.toString().trim().toUpperCase() ?? '';

    final counterparty = row['counterparty']?.toString().trim() ?? '';

    final note = row['note']?.toString().trim() ?? '';

    // Loan particulars — PDF display only.
    final loanPersonName = row['loan_person_name']?.toString().trim() ?? '';

    if (loanPersonName.isNotEmpty) {
      if (transactionType == 'LOAN_TAKEN') {
        return 'Received from $loanPersonName';
      }

      if (transactionType == 'LOAN_GIVEN') {
        return 'Given to $loanPersonName';
      }

      if (transactionType == 'LOAN_REPAYMENT') {
        return 'Paid to $loanPersonName';
      }

      if (transactionType == 'LOAN_COLLECTION') {
        return 'Received from $loanPersonName';
      }
    }

    if (accountType == 'CUSTOMER') {
      // A customer debit is normally the sale/receivable creation.
      if (debit > 0 &&
          (transactionType.contains('SALE') ||
              referenceType.contains('SALE') ||
              voucher.startsWith('INV') ||
              voucher.startsWith('SALE'))) {
        return 'Sale';
      }

      // Sales Discount journal — PDF display label only.
      if (credit > 0 &&
          row['discount_counterparty_type']?.toString().trim().toUpperCase() ==
              'SALES_DISCOUNT') {
        return 'Discount Given';
      }

      // Customer credit reduces receivable.
      if (credit > 0) {
        return 'Received';
      }

      if (debit > 0) {
        return 'Payment';
      }
    }

    if (accountType == 'SUPPLIER') {
      // A supplier credit is normally the purchase/payable creation.
      if (credit > 0 &&
          (transactionType.contains('PURCHASE') ||
              referenceType.contains('PURCHASE') ||
              voucher.startsWith('PUR') ||
              voucher.startsWith('PI'))) {
        return 'Purchase';
      }

      // Supplier debit reduces payable.
      if (debit > 0) {
        return 'Payment';
      }

      // Purchase Discount journal — PDF display label only.
      if (credit > 0 &&
          row['discount_counterparty_type']?.toString().trim().toUpperCase() ==
              'PURCHASE_DISCOUNT') {
        return 'Discount Received';
      }

      if (credit > 0) {
        return 'Received';
      }
    }

    // Cash / Bank / MFS / other account ledgers.
    if (debit > 0 && counterparty.isNotEmpty) {
      return 'Received from $counterparty';
    }

    if (credit > 0 && counterparty.isNotEmpty) {
      return 'Paid to $counterparty';
    }

    if (note.isNotEmpty) {
      return note;
    }

    for (final key in [
      'description',
      'particulars',
      'reference_type',
      'transaction_type',
    ]) {
      final value = row[key]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '-';
  }

  static String _transactionDate(Map<String, dynamic> row) {
    for (final key in [
      'transaction_date',
      'entry_date',
      'date',
      'created_at',
    ]) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  static String _safeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_');

    return cleaned.isEmpty ? 'Account' : cleaned;
  }

  static Future<Uint8List> generate({
    required Account account,
    String? fromDate,
    String? toDate,
  }) async {
    if (account.id == null) {
      throw StateError('Account ID is required.');
    }

    final ledgerService = FFUniversalLedgerService.instance;

    final results = await Future.wait([
      ledgerService.getLedger(
        accountId: account.id!,
        fromDate: fromDate,
        toDate: toDate,
      ),
      ledgerService.getSummary(
        accountId: account.id!,
        fromDate: fromDate,
        toDate: toDate,
      ),
      _loadBusinessLogo(),
      _loadInvoiceQr(),
    ]);

    final transactions = results[0] as List<Map<String, dynamic>>;

    final summary = results[1] as FFUniversalLedgerSummary;

    final businessLogo = results[2] as pw.MemoryImage?;
    final invoiceQr = results[3] as pw.MemoryImage?;

    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document();

    final money = NumberFormat('#,##0.00');

    String taka(double value) => 'Tk ${money.format(value)}';

    String balanceWithDrCr(double value) {
      if (value.abs() < 0.005) {
        return taka(0);
      }

      final isPositive = value > 0;

      final suffix = summary.normalBalance == 'CREDIT'
          ? (isPositive ? 'Cr' : 'Dr')
          : (isPositive ? 'Dr' : 'Cr');

      return '${taka(value.abs())} $suffix';
    }

    final companyName = GABBranding.businessName;
    final companyAddress = GABBranding.address;
    final companyPhone = GABBranding.phone;
    final companyEmail = GABBranding.email;
    final companyTagline = GABBranding.tagline;

    final generatedAt = DateFormat(
      'dd MMM yyyy  hh:mm a',
    ).format(DateTime.now());

    final rows = <List<String>>[];

    final isFiltered = fromDate != null;

    String periodLabel = 'All Transactions';

    if (fromDate != null && toDate != null) {
      try {
        periodLabel =
            '${DateFormat('dd MMM yyyy').format(DateTime.parse(fromDate))}'
            ' - '
            '${DateFormat('dd MMM yyyy').format(DateTime.parse(toDate))}';
      } catch (_) {
        periodLabel = '$fromDate - $toDate';
      }
    }

    if (summary.openingBalance != 0) {
      rows.add([
        isFiltered ? 'B/F' : _formatDate(account.openingDate),
        isFiltered ? 'B/F' : 'OB',
        isFiltered ? 'Balance Brought Forward' : 'Opening Balance',
        '',
        '',
        balanceWithDrCr(summary.openingBalance),
      ]);
    }

    for (final row in transactions) {
      final debit = _toDouble(row['debit']);
      final credit = _toDouble(row['credit']);
      final balance = _toDouble(row['running_balance']);

      rows.add([
        _formatDate(_transactionDate(row)),
        _voucher(row),
        _description(row, account),
        debit > 0 ? taka(debit) : '',
        credit > 0 ? taka(credit) : '',
        balanceWithDrCr(balance),
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 22),

        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
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
                            font: regularFont,
                            fontSize: 8,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.TextSpan(
                          text: 'Nexera IT BD',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 8,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  pw.SizedBox(),
                pw.Text(
                  'Page ${context.pageNumber} / ${context.pagesCount}',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },

        build: (context) => [
          if (businessLogo != null || invoiceQr != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: businessLogo != null && invoiceQr != null
                  ? pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _brandingPlate(image: businessLogo, isQr: false),
                        _brandingPlate(image: invoiceQr, isQr: true),
                      ],
                    )
                  : pw.Center(
                      child: _brandingPlate(
                        image: businessLogo ?? invoiceQr!,
                        isQr: invoiceQr != null,
                      ),
                    ),
            ),

          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  companyName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 18,
                    color: PdfColors.blue900,
                  ),
                ),
                if (companyTagline.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    companyTagline,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 8.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
                if (companyAddress.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    companyAddress,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regularFont, fontSize: 8.5),
                  ),
                ],
                if (companyPhone.trim().isNotEmpty ||
                    companyEmail.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    [
                      if (companyPhone.trim().isNotEmpty) companyPhone,
                      if (companyEmail.trim().isNotEmpty) companyEmail,
                    ].join('  |  '),
                    style: pw.TextStyle(font: regularFont, fontSize: 8.5),
                  ),
                ],
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 7),
            decoration: const pw.BoxDecoration(color: PdfColors.blue900),
            child: pw.Text(
              'ACCOUNT LEDGER',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 13,
                color: PdfColors.white,
              ),
            ),
          ),

          pw.SizedBox(height: 10),

          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        account.name,
                        style: pw.TextStyle(font: boldFont, fontSize: 11),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Type: ${account.type}',
                        style: pw.TextStyle(font: regularFont, fontSize: 8.5),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Period: $periodLabel',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 8.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated: $generatedAt',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Opening: ${balanceWithDrCr(summary.openingBalance)}',
                      style: pw.TextStyle(font: regularFont, fontSize: 8.5),
                    ),
                    pw.Text(
                      'Closing: ${balanceWithDrCr(summary.closingBalance)}',
                      style: pw.TextStyle(font: boldFont, fontSize: 8.5),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          pw.TableHelper.fromTextArray(
            headers: const [
              'Date',
              'Voucher',
              'Particulars',
              'Debit',
              'Credit',
              'Balance',
            ],
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontSize: 7.5,
              color: PdfColors.blue900,
            ),
            cellStyle: pw.TextStyle(font: regularFont, fontSize: 7.2),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 5,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.0),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(2.7),
              3: pw.FlexColumnWidth(1.15),
              4: pw.FlexColumnWidth(1.15),
              5: pw.FlexColumnWidth(1.3),
            },
          ),

          pw.SizedBox(height: 10),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 205,
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: [
                  _summaryRow(
                    'Total Debit',
                    taka(summary.totalDebit),
                    regularFont,
                    boldFont,
                  ),
                  pw.Divider(color: PdfColors.grey300, height: 8),
                  _summaryRow(
                    'Total Credit',
                    taka(summary.totalCredit),
                    regularFont,
                    boldFont,
                  ),
                  pw.Divider(color: PdfColors.grey300, height: 8),
                  _summaryRow(
                    'Balance',
                    balanceWithDrCr(summary.closingBalance),
                    regularFont,
                    boldFont,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 16),

          pw.Center(
            child: pw.Text(
              'Thank you for your business.',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ),

          pw.SizedBox(height: 10),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _summaryRow(
    String label,
    String value,
    pw.Font regularFont,
    pw.Font boldFont, {
    bool bold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: bold ? boldFont : regularFont,
            fontSize: 8.5,
          ),
        ),
        pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
      ],
    );
  }

  static Future<File> savePdf({
    required Account account,
    String? fromDate,
    String? toDate,
  }) async {
    final bytes = await generate(
      account: account,
      fromDate: fromDate,
      toDate: toDate,
    );

    final directory = await getApplicationDocumentsDirectory();

    final folder = Directory(p.join(directory.path, 'LalKhata', 'Ledgers'));

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File(
      p.join(
        folder.path,
        'Ledger_${_safeFileName(account.name)}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      ),
    );

    await file.writeAsBytes(bytes, flush: true);

    return file;
  }
}
