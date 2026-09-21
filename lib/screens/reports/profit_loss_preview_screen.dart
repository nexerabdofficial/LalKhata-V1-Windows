import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../pdf/profit_loss_pdf.dart';

class ProfitLossPreviewScreen extends StatefulWidget {
  final DateTime from;
  final DateTime to;

  const ProfitLossPreviewScreen({
    super.key,
    required this.from,
    required this.to,
  });

  @override
  State<ProfitLossPreviewScreen> createState() =>
      _ProfitLossPreviewScreenState();
}

class _ProfitLossPreviewScreenState extends State<ProfitLossPreviewScreen> {
  bool _saving = false;
  bool _printing = false;

  Future<Uint8List> _buildPdf() {
    return ProfitLossPdf.generate(from: widget.from, to: widget.to);
  }

  Future<void> _savePdf() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final file = await ProfitLossPdf.savePdf(
        from: widget.from,
        to: widget.to,
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
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _printPdf() async {
    if (_printing) return;

    setState(() => _printing = true);

    try {
      final bytes = await _buildPdf();

      await Printing.layoutPdf(
        name: 'Profit_Loss.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not print report: $e')));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profit & Loss',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
        pdfFileName: 'Profit_Loss.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
