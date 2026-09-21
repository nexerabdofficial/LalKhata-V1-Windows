import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/product.dart';
import '../../pdf/stock_report_pdf.dart';

class StockReportPreviewScreen extends StatefulWidget {
  final List<Product> products;
  final bool isMaterial;

  const StockReportPreviewScreen({
    super.key,
    required this.products,
    required this.isMaterial,
  });

  @override
  State<StockReportPreviewScreen> createState() =>
      _StockReportPreviewScreenState();
}

class _StockReportPreviewScreenState extends State<StockReportPreviewScreen> {
  bool _saving = false;
  bool _printing = false;

  String get reportName =>
      widget.isMaterial ? 'Material Stock Report' : 'Product Stock Report';

  Future<Uint8List> _buildPdf() {
    return StockReportPdf.generate(
      products: widget.products,
      isMaterial: widget.isMaterial,
    );
  }

  Future<void> _savePdf() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final file = await StockReportPdf.savePdf(
        products: widget.products,
        isMaterial: widget.isMaterial,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report saved:\n${file.path}')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save report: $e')));
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
        name: '${reportName.replaceAll(' ', '_')}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not print report: $e')));
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock Report',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.isMaterial ? 'Material Stock' : 'Product Stock',
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
        maxPageWidth: 600,
        previewPageMargin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: '${reportName.replaceAll(' ', '_')}.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load stock report preview.\n\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
