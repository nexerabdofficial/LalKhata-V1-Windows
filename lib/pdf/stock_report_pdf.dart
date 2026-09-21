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
import '../models/product.dart';
import '../services/storage_service.dart';

class StockReportPdf {
  StockReportPdf._();

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
    return _loadImageFromPath(await _storageService.getInvoiceLogoPath());
  }

  static Future<pw.MemoryImage?> _loadInvoiceQr() async {
    return _loadImageFromPath(await _storageService.getInvoiceQrPath());
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

  static double _averageCost(Product product) {
    if (product.stock <= 0) return 0;
    return product.stockValue / product.stock;
  }

  static String _stockStatus(int stock) {
    if (stock <= 0) return 'OUT';
    if (stock <= 10) return 'LOW';
    return 'OK';
  }

  static Future<Uint8List> generate({
    required List<Product> products,
    required bool isMaterial,
  }) async {
    final pdf = pw.Document();

    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final businessLogo = await _loadBusinessLogo();
    final invoiceQr = await _loadInvoiceQr();

    final money = NumberFormat('#,##0.00');

    String taka(num value) => 'Tk ${money.format(value)}';

    final companyName = GABBranding.businessName;
    final companyAddress = GABBranding.address;
    final companyPhone = GABBranding.phone;
    final companyEmail = GABBranding.email;
    final companyTagline = GABBranding.tagline;

    final generatedAt = DateFormat(
      'dd MMM yyyy  hh:mm a',
    ).format(DateTime.now());

    final totalValue = products.fold<double>(
      0,
      (sum, product) => sum + product.stockValue,
    );

    final inStock = products.where((e) => e.stock > 10).length;

    final lowStock = products.where((e) => e.stock > 0 && e.stock <= 10).length;

    final outStock = products.where((e) => e.stock <= 0).length;

    final data = products.map((product) {
      return [
        product.name,
        product.stock.toString(),
        taka(_averageCost(product)),
        if (!isMaterial) taka(product.sellingPrice),
        taka(product.stockValue),
        _stockStatus(product.stock),
      ];
    }).toList();

    final headers = <String>[
      isMaterial ? 'Material' : 'Product',
      'Stock',
      'Avg. Cost',
      if (!isMaterial) 'Sell Price',
      'Stock Value',
      'Status',
    ];

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

        build: (_) => [
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
            color: PdfColors.blue900,
            child: pw.Text(
              isMaterial ? 'MATERIAL STOCK REPORT' : 'PRODUCT STOCK REPORT',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 13,
                color: PdfColors.white,
              ),
            ),
          ),

          pw.SizedBox(height: 8),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Generated: $generatedAt',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
          ),

          pw.SizedBox(height: 8),

          pw.Row(
            children: [
              _summaryBox(
                'Items',
                products.length.toString(),
                regularFont,
                boldFont,
              ),
              pw.SizedBox(width: 6),
              _summaryBox(
                'In Stock',
                inStock.toString(),
                regularFont,
                boldFont,
              ),
              pw.SizedBox(width: 6),
              _summaryBox(
                'Low Stock',
                lowStock.toString(),
                regularFont,
                boldFont,
              ),
              pw.SizedBox(width: 6),
              _summaryBox(
                'Out Stock',
                outStock.toString(),
                regularFont,
                boldFont,
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontSize: 7.5,
              color: PdfColors.blue900,
            ),
            cellStyle: pw.TextStyle(font: regularFont, fontSize: 7.3),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 5,
            ),
          ),

          pw.SizedBox(height: 10),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Stock Value',
                    style: pw.TextStyle(font: boldFont, fontSize: 8.5),
                  ),
                  pw.Text(
                    taka(totalValue),
                    style: pw.TextStyle(font: boldFont, fontSize: 8.5),
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

  static pw.Widget _summaryBox(
    String label,
    String value,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Column(
          children: [
            pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 10)),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 7,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<File> savePdf({
    required List<Product> products,
    required bool isMaterial,
  }) async {
    final bytes = await generate(products: products, isMaterial: isMaterial);

    final directory = await getApplicationDocumentsDirectory();

    final folder = Directory(p.join(directory.path, 'LalKhata', 'Reports'));

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final type = isMaterial ? 'Material' : 'Product';

    final file = File(
      p.join(
        folder.path,
        '${type}_Stock_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      ),
    );

    await file.writeAsBytes(bytes, flush: true);

    return file;
  }
}
