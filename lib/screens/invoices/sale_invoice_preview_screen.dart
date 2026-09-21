import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../pdf/sale_invoice_pdf.dart';

class SaleInvoicePreviewScreen extends StatefulWidget {
  final Sale sale;
  final Map<String, dynamic> saleInfo;
  final List<SaleItem> items;

  const SaleInvoicePreviewScreen({
    super.key,
    required this.sale,
    required this.saleInfo,
    required this.items,
  });

  @override
  State<SaleInvoicePreviewScreen> createState() =>
      _SaleInvoicePreviewScreenState();
}

class _SaleInvoicePreviewScreenState extends State<SaleInvoicePreviewScreen> {
  bool _saving = false;
  bool _printing = false;

  Future<Uint8List> _buildPdf() {
    return SaleInvoicePdf.generate(
      sale: widget.sale,
      saleInfo: widget.saleInfo,
      items: widget.items,
    );
  }

  Future<void> _savePdf() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final file = await SaleInvoicePdf.savePdf(
        sale: widget.sale,
        saleInfo: widget.saleInfo,
        items: widget.items,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invoice saved:\n${file.path}')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save invoice: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _printPdf() async {
    if (_printing) return;

    setState(() => _printing = true);

    try {
      final bytes = await _buildPdf();

      await Printing.layoutPdf(
        name: 'Invoice_$invoiceNo.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not print invoice: $e')));
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  String get invoiceNo {
    if (widget.sale.invoiceNo?.trim().isNotEmpty == true) {
      return widget.sale.invoiceNo!.trim();
    }

    return widget.sale.id?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Invoice',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              invoiceNo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Print',
            onPressed: _printing ? null : _printPdf,
            icon: _printing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Save PDF',
            onPressed: _saving ? null : _savePdf,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PdfPreview(
        build: (_) => _buildPdf(),

        // Same approved A4 preview size as Purchase Invoice.
        maxPageWidth: 600,
        previewPageMargin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),

        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,

        pdfFileName: 'Invoice_$invoiceNo.pdf',

        loadingWidget: const Center(child: CircularProgressIndicator()),

        onError: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load invoice preview.\n\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
