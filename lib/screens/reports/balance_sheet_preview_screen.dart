import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../pdf/balance_sheet_pdf.dart';
import '../../services/ff/ff_balance_sheet_service.dart';

class BalanceSheetPreviewScreen extends StatefulWidget {
  final FFBalanceSheetReport report;

  const BalanceSheetPreviewScreen({super.key, required this.report});

  @override
  State<BalanceSheetPreviewScreen> createState() =>
      _BalanceSheetPreviewScreenState();
}

class _BalanceSheetPreviewScreenState extends State<BalanceSheetPreviewScreen> {
  bool _saving = false;
  bool _printing = false;

  Future<Uint8List> _buildPdf() {
    return BalanceSheetPdf.generate(report: widget.report);
  }

  Future<void> _savePdf() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final file = await BalanceSheetPdf.savePdf(report: widget.report);

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
        name: 'Balance_Sheet.pdf',
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
        title: const Text(
          'Balance Sheet',
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
        pdfFileName: 'Balance_Sheet.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load Balance Sheet preview.\n\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
