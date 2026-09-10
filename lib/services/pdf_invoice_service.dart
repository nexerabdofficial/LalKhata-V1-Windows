import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/customer.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/product.dart';
import 'storage_service.dart';

class PdfInvoiceService {
  final StorageService _storageService =
      StorageService.instance;

  Future<File> generateInvoice({
    required Sale sale,
    required Customer customer,
    required List<SaleItem> items,
    required List<Product> products,
  }) async {
    final pdf = pw.Document();

    // ============================================================
    // INVOICE DATE
    // ============================================================

    final invoiceDate = DateFormat(
      "dd MMM yyyy",
    ).format(
      DateTime.parse(sale.saleDate),
    );

    // ============================================================
    // PAGE CONTENT
    // ============================================================

    final invoiceContent = pw.Container(
      width: PdfPageFormat.a4.width - 48,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ========================================================
          // COMPANY NAME
          // ========================================================

          pw.Center(
            child: pw.Text(
              "NEXERA INVENTORY",
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

          pw.SizedBox(height: 4),

          // ========================================================
          // INVOICE TITLE
          // ========================================================

          pw.Center(
            child: pw.Text(
              "SALES INVOICE",
              style: const pw.TextStyle(
                fontSize: 14,
              ),
            ),
          ),

          pw.SizedBox(height: 8),

          pw.Divider(),

          pw.SizedBox(height: 10),

          // ========================================================
          // CUSTOMER + INVOICE INFORMATION
          // ========================================================

          pw.Row(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            children: [
              // ----------------------------------------------------
              // CUSTOMER
              // ----------------------------------------------------

              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      "Customer : ${customer.name}",
                    ),

                    pw.SizedBox(height: 3),

                    pw.Text(
                      "Phone : ${customer.phone ?? ""}",
                    ),

                    pw.SizedBox(height: 3),

                    pw.Text(
                      "Address : ${customer.address ?? ""}",
                    ),
                  ],
                ),
              ),

              pw.SizedBox(width: 20),

              // ----------------------------------------------------
              // INVOICE INFO
              // ----------------------------------------------------

              pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.end,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    "Invoice : ${sale.invoiceNo}",
                  ),

                  pw.SizedBox(height: 3),

                  pw.Text(
                    invoiceDate,
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // ========================================================
          // OPTIONAL: SIMPLE ITEM TABLE
          //
          // This keeps the invoice useful even when this service
          // receives the item/product lists.
          // ========================================================

          if (items.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              columnWidths: const {
                0: pw.FixedColumnWidth(35),
                1: pw.FlexColumnWidth(4),
                2: pw.FixedColumnWidth(55),
                3: pw.FixedColumnWidth(75),
              },
              children: [
                // --------------------------------------------------
                // TABLE HEADER
                // --------------------------------------------------

                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  children: [
                    _tableCell(
                      "SL",
                      bold: true,
                    ),
                    _tableCell(
                      "Product",
                      bold: true,
                    ),
                    _tableCell(
                      "Qty",
                      bold: true,
                      align: pw.TextAlign.center,
                    ),
                    _tableCell(
                      "Amount",
                      bold: true,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),

                // --------------------------------------------------
                // ITEMS
                // --------------------------------------------------

                ...List.generate(
                  items.length,
                  (index) {
                    final item = items[index];

                    final productName =
                        _getProductName(
                      item,
                      products,
                    );

                    final quantity =
                        _getQuantity(item);

                    final amount =
                        _getAmount(item);

                    return pw.TableRow(
                      children: [
                        _tableCell(
                          "${index + 1}",
                          align: pw.TextAlign.center,
                        ),

                        _tableCell(
                          productName,
                        ),

                        _tableCell(
                          quantity,
                          align: pw.TextAlign.center,
                        ),

                        _tableCell(
                          amount,
                          align: pw.TextAlign.right,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),

          pw.SizedBox(height: 20),

          // ========================================================
          // TOTAL
          // ========================================================

          pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Grand Total",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      _formatAmount(
                        sale.grandTotal,
                      ),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // ========================================================
          // FOOTER
          // ========================================================

          pw.Divider(),

          pw.SizedBox(height: 8),

          pw.Center(
            child: pw.Text(
              "Thank you for your business",
              style: const pw.TextStyle(
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );

    // ============================================================
    // FORCE SINGLE PAGE
    // ============================================================

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Center(
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topCenter,
              child: invoiceContent,
            ),
          );
        },
      ),
    );

    // ============================================================
    // DETERMINE INVOICE SAVE DIRECTORY
    // ============================================================

    Directory targetDirectory;

    // ------------------------------------------------------------
    // 1. USER SELECTED INVOICE FOLDER
    // ------------------------------------------------------------

    final selectedFolder =
        await _storageService.getInvoiceFolder();

    if (selectedFolder != null &&
        selectedFolder.trim().isNotEmpty) {
      targetDirectory =
          Directory(selectedFolder);

      if (!await targetDirectory.exists()) {
        await targetDirectory.create(
          recursive: true,
        );
      }
    }

    // ------------------------------------------------------------
    // 2. ANDROID DEFAULT FOLDER
    // ------------------------------------------------------------

    else if (Platform.isAndroid) {
      final externalDirectory =
          await getExternalStorageDirectory();

      if (externalDirectory == null) {
        throw Exception(
          'Unable to access Android storage.',
        );
      }

      targetDirectory = Directory(
        p.join(
          externalDirectory.path,
          'LalKhata',
          'Invoices',
        ),
      );

      if (!await targetDirectory.exists()) {
        await targetDirectory.create(
          recursive: true,
        );
      }
    }

    // ------------------------------------------------------------
    // 3. DESKTOP FALLBACK
    // ------------------------------------------------------------

    else {
      final documentsDirectory =
          await getApplicationDocumentsDirectory();

      targetDirectory = Directory(
        p.join(
          documentsDirectory.path,
          'LalKhata',
          'Invoices',
        ),
      );

      if (!await targetDirectory.exists()) {
        await targetDirectory.create(
          recursive: true,
        );
      }
    }

    // ============================================================
    // CREATE PDF FILE
    // ============================================================

    final invoiceNo =
        sale.invoiceNo?.trim().isNotEmpty == true
            ? sale.invoiceNo!.trim()
            : sale.id.toString();

    final fileName =
        'Invoice_$invoiceNo.pdf';

    final file = File(
      p.join(
        targetDirectory.path,
        fileName,
      ),
    );

    // ============================================================
    // SAVE PDF
    // ============================================================

    await file.writeAsBytes(
      await pdf.save(),
      flush: true,
    );

    return file;
  }

  // ============================================================
  // TABLE CELL
  // ============================================================

  static pw.Widget _tableCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 6,
      ),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight:
              bold ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT NAME
  // ============================================================

  String _getProductName(
    SaleItem item,
    List<Product> products,
  ) {
    try {
      final product = products.firstWhere(
        (product) => product.id == item.productId,
      );

      return product.name;
    } catch (_) {
      return "Product";
    }
  }

  // ============================================================
  // QUANTITY
  // ============================================================

  String _getQuantity(
    SaleItem item,
  ) {
    try {
      final dynamic value =
          (item as dynamic).quantity;

      return value.toString();
    } catch (_) {
      return "";
    }
  }

  // ============================================================
  // AMOUNT
  // ============================================================

  String _getAmount(
    SaleItem item,
  ) {
    try {
      final dynamic value =
          (item as dynamic).total;

      if (value is num) {
        return _formatAmount(value);
      }

      return value.toString();
    } catch (_) {
      return "";
    }
  }

  // ============================================================
  // FORMAT AMOUNT
  // ============================================================

  static String _formatAmount(
    num value,
  ) {
    return "Tk ${NumberFormat(
      "#,##0.00",
    ).format(value)}";
  }
}