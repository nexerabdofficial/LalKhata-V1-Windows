import 'dart:io';
import 'dart:typed_data';

import '../config/app_build_config.dart';
import '../database/database_helper.dart';
import '../gab/gab_branding.dart';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/purchase.dart';
import '../models/purchase/purchase_item_history.dart';
import '../services/storage_service.dart';

class PurchaseInvoicePdf {
  PurchaseInvoicePdf._();

  static final StorageService _storageService = StorageService.instance;

  // ============================================================
  // BRANDING IMAGE
  // ============================================================

  static Future<pw.MemoryImage?> _loadImageFromPath(String? path) async {
    try {
      if (path == null || path.trim().isEmpty) {
        return null;
      }

      final file = File(path.trim());

      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        return null;
      }

      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<pw.MemoryImage?> _loadBusinessLogo() async {
    return _loadImageFromPath(await _storageService.getInvoiceLogoPath());
  }

  static Future<pw.MemoryImage?> _loadInvoiceQr() async {
    return _loadImageFromPath(await _storageService.getInvoiceQrPath());
  }

  // ============================================================
  // GENERATE
  // ============================================================

  static Future<Uint8List> generate({
    required Purchase purchase,
    required List<PurchaseItemHistory> items,
  }) async {
    final pdf = pw.Document();

    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final businessLogo = await _loadBusinessLogo();
    final invoiceQr = await _loadInvoiceQr();

    final db = await DatabaseHelper.instance.database;

    // ==========================================================
    // SUPPLIER
    // ==========================================================

    String supplierName = 'Supplier';
    String supplierPhone = '';
    String supplierAddress = '';
    double supplierBalance = 0;

    try {
      final rows = await db.query(
        'suppliers',
        columns: ['name', 'phone', 'address', 'balance'],
        where: 'id = ?',
        whereArgs: [purchase.supplierId],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final row = rows.first;

        final name = row['name']?.toString().trim() ?? '';

        supplierName = name.isEmpty ? 'Supplier' : name;
        supplierPhone = row['phone']?.toString() ?? '';
        supplierAddress = row['address']?.toString() ?? '';
        supplierBalance = ((row['balance'] ?? 0) as num).toDouble();
      }
    } catch (_) {
      // Supplier lookup must not block invoice generation.
    }

    // Current supplier balance already contains current invoice due.
    final previousDue = (supplierBalance - purchase.due)
        .clamp(0, double.infinity)
        .toDouble();

    // ==========================================================
    // PAYMENT ALLOCATIONS
    // ==========================================================

    final paymentBreakdown = <Map<String, dynamic>>[];

    if (purchase.id != null && purchase.id! > 0) {
      try {
        final rows = await db.rawQuery(
          '''
          SELECT
            pa.amount,
            pa.payment_method,
            a.name AS account_name
          FROM payment_allocations pa
          LEFT JOIN accounts a
            ON a.id = pa.account_id
          WHERE pa.reference_type = ?
            AND pa.reference_id = ?
          ORDER BY pa.id ASC
          ''',
          ['PURCHASE', purchase.id],
        );

        for (final row in rows) {
          final amount = ((row['amount'] ?? 0) as num).toDouble();

          if (amount <= 0) {
            continue;
          }

          final accountName = row['account_name']?.toString().trim() ?? '';

          final paymentMethod = row['payment_method']?.toString().trim() ?? '';

          paymentBreakdown.add({
            'name': accountName.isNotEmpty
                ? accountName
                : paymentMethod.isNotEmpty
                ? paymentMethod
                : 'Payment',
            'amount': amount,
          });
        }
      } catch (_) {
        // Payment breakdown must not block invoice generation.
      }
    }

    // ==========================================================
    // FORMAT / VALUES
    // ==========================================================

    final currency = NumberFormat('#,##0.00');

    String taka(num value) {
      return 'Tk ${currency.format(value)}';
    }

    final invoiceDate = DateFormat(
      'dd MMM yyyy  hh:mm a',
    ).format(DateTime.tryParse(purchase.purchaseDate) ?? DateTime.now());

    final invoiceNo = purchase.invoiceNo?.trim().isNotEmpty == true
        ? purchase.invoiceNo!.trim()
        : 'PUR-${purchase.id ?? ''}';

    final currentPurchase = purchase.grandTotal;

    final subtotal =
        currentPurchase - purchase.additionalCharge + purchase.invoiceDiscount;

    final totalPayable = previousDue + currentPurchase;

    final paidToday = purchase.paid;

    final finalDue = (totalPayable - paidToday)
        .clamp(0, double.infinity)
        .toDouble();

    // ==========================================================
    // RESPONSIVE SETTINGS — SAME STRATEGY AS SALES PDF
    // ==========================================================

    final itemCount = items.length;

    double headerFontSize;
    double normalFontSize;
    double tableFontSize;
    double tableVerticalPadding;
    double sectionSpacing;
    double supplierPadding;
    double summaryPadding;

    if (itemCount <= 4) {
      headerFontSize = 17;
      normalFontSize = 9;
      tableFontSize = 9;
      tableVerticalPadding = 7;
      sectionSpacing = 18;
      supplierPadding = 10;
      summaryPadding = 14;
    } else if (itemCount <= 8) {
      headerFontSize = 16;
      normalFontSize = 8.8;
      tableFontSize = 8.8;
      tableVerticalPadding = 6;
      sectionSpacing = 14;
      supplierPadding = 9;
      summaryPadding = 12;
    } else if (itemCount <= 12) {
      headerFontSize = 15;
      normalFontSize = 8.5;
      tableFontSize = 8.5;
      tableVerticalPadding = 5;
      sectionSpacing = 11;
      supplierPadding = 8;
      summaryPadding = 10;
    } else if (itemCount <= 18) {
      headerFontSize = 14;
      normalFontSize = 8;
      tableFontSize = 8;
      tableVerticalPadding = 4;
      sectionSpacing = 8;
      supplierPadding = 7;
      summaryPadding = 8;
    } else {
      headerFontSize = 13;
      normalFontSize = 7.5;
      tableFontSize = 7.5;
      tableVerticalPadding = 3;
      sectionSpacing = 6;
      supplierPadding = 6;
      summaryPadding = 7;
    }

    // ==========================================================
    // COMPANY
    // ==========================================================

    final companyName = GABBranding.businessName;
    final companyAddress = GABBranding.address;
    final companyPhone = GABBranding.phone;
    final companyEmail = GABBranding.email;
    final companyTagline = GABBranding.tagline;

    // ==========================================================
    // INVOICE CONTENT
    // IMPORTANT:
    // This intentionally follows the proven Sales PDF structure.
    // ==========================================================

    final invoiceContent = pw.Container(
      width: PdfPageFormat.a4.width - 32,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ====================================================
          // LOGO + QR
          // ====================================================
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
                        isQr: businessLogo == null,
                      ),
                    ),
            ),

          // ====================================================
          // HEADER
          // ====================================================
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue900,
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: headerFontSize,
                          color: PdfColors.white,
                        ),
                      ),

                      if (companyTagline.trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(
                            companyTagline,
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: normalFontSize,
                              color: PdfColors.white,
                            ),
                          ),
                        ),

                      pw.SizedBox(height: itemCount <= 8 ? 8 : 5),

                      if (companyAddress.trim().isNotEmpty)
                        pw.Text(
                          companyAddress,
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: normalFontSize,
                            color: PdfColors.white,
                          ),
                        ),

                      if (companyPhone.trim().isNotEmpty)
                        pw.Text(
                          companyPhone,
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: normalFontSize,
                            color: PdfColors.white,
                          ),
                        ),

                      if (companyEmail.trim().isNotEmpty)
                        pw.Text(
                          companyEmail,
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: normalFontSize,
                            color: PdfColors.white,
                          ),
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(width: 16),

                pw.Container(
                  width: 165,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Center(
                        child: pw.Text(
                          'PURCHASE INVOICE',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: itemCount <= 8 ? 14 : 12,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),

                      pw.Divider(height: itemCount <= 8 ? 8 : 5),

                      pw.Text(
                        'Invoice No',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: normalFontSize,
                        ),
                      ),

                      pw.Text(
                        invoiceNo,
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: normalFontSize,
                        ),
                      ),

                      pw.SizedBox(height: itemCount <= 8 ? 5 : 3),

                      pw.Text(
                        'Invoice Date',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: normalFontSize,
                        ),
                      ),

                      pw.Text(
                        invoiceDate,
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: normalFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: sectionSpacing),

          // ====================================================
          // SUPPLIER + PAYABLE
          // ====================================================
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: pw.EdgeInsets.all(supplierPadding),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.grey300, width: .7),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'BILL FROM',
                        style: pw.TextStyle(
                          font: boldFont,
                          color: PdfColors.blue900,
                          fontSize: itemCount <= 8 ? 11 : 10,
                        ),
                      ),

                      pw.SizedBox(height: itemCount <= 8 ? 6 : 4),

                      pw.Text(
                        supplierName,
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: normalFontSize + 1,
                        ),
                      ),

                      pw.SizedBox(height: 2),

                      pw.Text(
                        'Supplier ID : ${purchase.supplierId}',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: normalFontSize,
                        ),
                      ),

                      if (supplierPhone.isNotEmpty)
                        pw.Text(
                          'Phone : $supplierPhone',
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: normalFontSize,
                          ),
                        ),

                      if (supplierAddress.isNotEmpty)
                        pw.Text(
                          'Address : $supplierAddress',
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: normalFontSize,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(width: 12),

              pw.Container(
                width: 220,
                padding: pw.EdgeInsets.all(summaryPadding),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300, width: .6),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    _summaryRow(
                      'Invoice Total',
                      taka(currentPurchase),
                      regularFont,
                      boldFont,
                      fontSize: normalFontSize,
                      bold: true,
                    ),

                    pw.SizedBox(height: 3),

                    _summaryRow(
                      'Previous Due (BF)',
                      taka(previousDue),
                      regularFont,
                      boldFont,
                      fontSize: normalFontSize,
                    ),

                    pw.Divider(height: 7),

                    _summaryRow(
                      'Total Payable',
                      taka(totalPayable),
                      regularFont,
                      boldFont,
                      fontSize: normalFontSize,
                      bold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: sectionSpacing),

          // ====================================================
          // ITEMS
          // ====================================================
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
            columnWidths: {
              0: const pw.FixedColumnWidth(35),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FixedColumnWidth(55),
              3: const pw.FixedColumnWidth(75),
              4: const pw.FixedColumnWidth(85),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                children: [
                  _headerCell(
                    'SL',
                    boldFont,
                    fontSize: tableFontSize,
                    verticalPadding: tableVerticalPadding,
                  ),
                  _headerCell(
                    'PRODUCT',
                    boldFont,
                    fontSize: tableFontSize,
                    verticalPadding: tableVerticalPadding,
                  ),
                  _headerCell(
                    'QTY',
                    boldFont,
                    fontSize: tableFontSize,
                    verticalPadding: tableVerticalPadding,
                  ),
                  _headerCell(
                    'PRICE',
                    boldFont,
                    fontSize: tableFontSize,
                    verticalPadding: tableVerticalPadding,
                  ),
                  _headerCell(
                    'TOTAL',
                    boldFont,
                    fontSize: tableFontSize,
                    verticalPadding: tableVerticalPadding,
                  ),
                ],
              ),

              ...List.generate(items.length, (index) {
                final history = items[index];
                final item = history.item;

                return pw.TableRow(
                  children: [
                    _cell(
                      '${index + 1}',
                      regularFont,
                      fontSize: tableFontSize,
                      verticalPadding: tableVerticalPadding,
                      align: pw.TextAlign.center,
                    ),
                    _cell(
                      history.productName,
                      regularFont,
                      fontSize: tableFontSize,
                      verticalPadding: tableVerticalPadding,
                    ),
                    _cell(
                      item.qty.toString(),
                      regularFont,
                      fontSize: tableFontSize,
                      verticalPadding: tableVerticalPadding,
                      align: pw.TextAlign.center,
                    ),
                    _cell(
                      taka(item.purchasePrice),
                      regularFont,
                      fontSize: tableFontSize,
                      verticalPadding: tableVerticalPadding,
                      align: pw.TextAlign.right,
                    ),
                    _cell(
                      taka(item.subtotal),
                      boldFont,
                      fontSize: tableFontSize,
                      verticalPadding: tableVerticalPadding,
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: sectionSpacing),

          // ====================================================
          // PAYMENT SUMMARY
          // ====================================================
          pw.Container(
            padding: pw.EdgeInsets.all(summaryPadding),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey300, width: .7),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'PAYMENT SUMMARY',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: itemCount <= 8 ? 11 : 10,
                    color: PdfColors.blue900,
                  ),
                ),

                pw.SizedBox(height: itemCount <= 8 ? 6 : 4),

                _summaryRow(
                  'Subtotal',
                  taka(subtotal),
                  regularFont,
                  boldFont,
                  fontSize: normalFontSize,
                ),

                if (purchase.additionalCharge > 0)
                  _summaryRow(
                    'Additional Charge',
                    taka(purchase.additionalCharge),
                    regularFont,
                    boldFont,
                    fontSize: normalFontSize,
                  ),

                if (purchase.invoiceDiscount > 0)
                  _summaryRow(
                    'Invoice Discount',
                    '-${taka(purchase.invoiceDiscount)}',
                    regularFont,
                    boldFont,
                    fontSize: normalFontSize,
                  ),

                pw.Divider(height: 7),

                _summaryRow(
                  'Current Purchase',
                  taka(currentPurchase),
                  regularFont,
                  boldFont,
                  fontSize: normalFontSize,
                  bold: true,
                ),

                _summaryRow(
                  'Previous Due (BF)',
                  taka(previousDue),
                  regularFont,
                  boldFont,
                  fontSize: normalFontSize,
                ),

                _summaryRow(
                  'Total Payable',
                  taka(totalPayable),
                  regularFont,
                  boldFont,
                  fontSize: normalFontSize,
                  bold: true,
                ),

                pw.SizedBox(height: 3),

                _summaryRow(
                  'Payment Method',
                  paymentBreakdown.length > 1
                      ? 'Split Payment'
                      : purchase.paymentMethod,
                  regularFont,
                  boldFont,
                  fontSize: normalFontSize,
                ),

                if (paymentBreakdown.isNotEmpty) ...[
                  pw.SizedBox(height: 2),

                  ...paymentBreakdown.map((payment) {
                    final name = payment['name']?.toString() ?? 'Payment';

                    final amount = ((payment['amount'] ?? 0) as num).toDouble();

                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(
                        left: 10,
                        top: 1,
                        bottom: 1,
                      ),
                      child: _summaryRow(
                        '• $name',
                        taka(amount),
                        regularFont,
                        boldFont,
                        fontSize: normalFontSize,
                      ),
                    );
                  }),

                  pw.SizedBox(height: 2),
                ],

                _summaryRow(
                  'Paid Today',
                  taka(paidToday),
                  regularFont,
                  boldFont,
                  fontSize: normalFontSize,
                ),

                pw.Divider(height: 7),

                pw.Container(
                  padding: pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: itemCount <= 8 ? 8 : 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue900,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'BALANCE DUE',
                        style: pw.TextStyle(
                          font: boldFont,
                          color: PdfColors.white,
                          fontSize: itemCount <= 8 ? 11 : 10,
                        ),
                      ),
                      pw.Text(
                        taka(finalDue),
                        style: pw.TextStyle(
                          font: boldFont,
                          color: PdfColors.white,
                          fontSize: itemCount <= 8 ? 13 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // NOTE
          // ====================================================
          if ((purchase.note ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: sectionSpacing),
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.all(itemCount <= 8 ? 9 : 7),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    'NOTE',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: normalFontSize + 1,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    purchase.note ?? '',
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: normalFontSize,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ====================================================
          // AMOUNT IN WORDS
          // ====================================================
          pw.SizedBox(
            height: itemCount <= 4
                ? 16
                : itemCount <= 8
                ? 12
                : 8,
          ),

          pw.Text(
            'Amount in Words',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: normalFontSize + 1,
              color: PdfColors.blue900,
            ),
          ),

          pw.SizedBox(height: 3),

          pw.Text(
            '${_amountInWords(currentPurchase.toInt())} — For Today\'s Purchase',
            style: pw.TextStyle(font: regularFont, fontSize: normalFontSize),
          ),

          // ====================================================
          // SIGNATURE
          // ====================================================
          pw.SizedBox(
            height: itemCount <= 4
                ? 18
                : itemCount <= 8
                ? 13
                : 8,
          ),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(width: 150, child: pw.Divider(height: 7)),
                  pw.Text(
                    'Supplier Signature',
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: itemCount <= 8 ? 8 : 7,
                    ),
                  ),
                ],
              ),
              pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(width: 150, child: pw.Divider(height: 7)),
                  pw.Text(
                    'Authorized Signature',
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: itemCount <= 8 ? 8 : 7,
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(
            height: itemCount <= 4
                ? 14
                : itemCount <= 8
                ? 10
                : 7,
          ),

          pw.Center(
            child: pw.Text(
              'Thank you for your business.',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: itemCount <= 8 ? 9 : 8,
                color: PdfColors.grey700,
              ),
            ),
          ),

          // ====================================================
          // FOOTER
          // ====================================================
          pw.SizedBox(height: itemCount <= 8 ? 8 : 5),

          pw.Container(
            padding: const pw.EdgeInsets.only(top: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey400, width: .5),
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
                  'Page 1',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // ==========================================================
    // SAME PROVEN SINGLE-PAGE RENDERER AS SALES INVOICE
    // ==========================================================

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topCenter,
              child: invoiceContent,
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // BRANDING
  // ============================================================

  static pw.Widget _brandingPlate({
    required pw.MemoryImage image,
    required bool isQr,
  }) {
    return pw.Container(
      width: isQr ? 72 : 105,
      height: 58,
      alignment: pw.Alignment.center,
      child: pw.Image(
        image,
        fit: pw.BoxFit.contain,
        alignment: pw.Alignment.center,
      ),
    );
  }

  // ============================================================
  // HEADER CELL
  // ============================================================

  static pw.Widget _headerCell(
    String text,
    pw.Font font, {
    double fontSize = 9,
    double verticalPadding = 7,
  }) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: pw.EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: 5,
      ),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize,
          color: PdfColors.white,
        ),
      ),
    );
  }

  // ============================================================
  // CELL
  // ============================================================

  static pw.Widget _cell(
    String text,
    pw.Font font, {
    bool bold = false,
    double fontSize = 9,
    double verticalPadding = 7,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(
        horizontal: 6,
        vertical: verticalPadding,
      ),
      alignment: align == pw.TextAlign.right
          ? pw.Alignment.centerRight
          : align == pw.TextAlign.center
          ? pw.Alignment.center
          : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  static pw.Widget _summaryRow(
    String title,
    String value,
    pw.Font regularFont,
    pw.Font boldFont, {
    bool bold = false,
    double fontSize = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              title,
              style: pw.TextStyle(
                font: bold ? boldFont : regularFont,
                fontSize: fontSize,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              font: bold ? boldFont : regularFont,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AMOUNT IN WORDS
  // ============================================================

  static String _amountInWords(int number) {
    if (number == 0) {
      return 'Zero Taka Only';
    }

    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];

    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String convert(int n) {
      if (n < 20) {
        return ones[n];
      }

      if (n < 100) {
        return tens[n ~/ 10] + (n % 10 == 0 ? '' : ' ${ones[n % 10]}');
      }

      if (n < 1000) {
        return '${ones[n ~/ 100]} Hundred'
            '${n % 100 == 0 ? '' : ' ${convert(n % 100)}'}';
      }

      if (n < 100000) {
        return '${convert(n ~/ 1000)} Thousand'
            '${n % 1000 == 0 ? '' : ' ${convert(n % 1000)}'}';
      }

      if (n < 10000000) {
        return '${convert(n ~/ 100000)} Lakh'
            '${n % 100000 == 0 ? '' : ' ${convert(n % 100000)}'}';
      }

      return '${convert(n ~/ 10000000)} Crore'
          '${n % 10000000 == 0 ? '' : ' ${convert(n % 10000000)}'}';
    }

    return '${convert(number)} Taka Only';
  }

  // ============================================================
  // DIRECTORY
  // ============================================================

  static Future<Directory> _getInvoiceDirectory() async {
    final selectedFolder = await _storageService.getInvoiceFolder();

    if (selectedFolder != null && selectedFolder.trim().isNotEmpty) {
      final directory = Directory(selectedFolder.trim());

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      return directory;
    }

    if (Platform.isAndroid) {
      final externalDirectory = await getExternalStorageDirectory();

      if (externalDirectory == null) {
        throw Exception('Unable to access Android storage.');
      }

      final directory = Directory(
        p.join(externalDirectory.path, 'LalKhata', 'Purchase Invoices'),
      );

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      return directory;
    }

    final home = Platform.environment['HOME'];

    if (home != null && home.trim().isNotEmpty) {
      final directory = Directory(
        p.join(
          home,
          'Documents',
          GABBranding.businessName,
          'Purchase Invoices',
        ),
      );

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      return directory;
    }

    throw Exception('Unable to determine invoice storage directory.');
  }

  // ============================================================
  // PREVIEW
  // ============================================================

  static Future<void> preview({
    required Purchase purchase,
    required List<PurchaseItemHistory> items,
  }) async {
    await Printing.layoutPdf(
      name: 'Purchase_${purchase.invoiceNo ?? purchase.id}.pdf',
      onLayout: (_) async => generate(purchase: purchase, items: items),
    );
  }

  // ============================================================
  // SAVE
  // ============================================================

  static Future<File> savePdf({
    required Purchase purchase,
    required List<PurchaseItemHistory> items,
  }) async {
    final bytes = await generate(purchase: purchase, items: items);

    final documents = await _getInvoiceDirectory();

    final invoiceNo = purchase.invoiceNo?.trim().isNotEmpty == true
        ? purchase.invoiceNo!.trim()
        : purchase.id?.toString() ?? 'unknown';

    final file = File(p.join(documents.path, 'Purchase_$invoiceNo.pdf'));

    await file.writeAsBytes(bytes, flush: true);

    return file;
  }
}
