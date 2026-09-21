import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/account.dart';
import '../../pdf/account_ledger_pdf.dart';

class AccountLedgerPreviewScreen extends StatefulWidget {
  final Account account;

  const AccountLedgerPreviewScreen({super.key, required this.account});

  @override
  State<AccountLedgerPreviewScreen> createState() =>
      _AccountLedgerPreviewScreenState();
}

class _AccountLedgerPreviewScreenState
    extends State<AccountLedgerPreviewScreen> {
  bool _saving = false;
  bool _printing = false;

  Future<Uint8List> _buildPdf() {
    return AccountLedgerPdf.generate(account: widget.account);
  }

  Future<void> _savePdf() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final file = await AccountLedgerPdf.savePdf(account: widget.account);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ledger saved:\n${file.path}')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save ledger: $e')));
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
        name: 'Account_Ledger_${widget.account.name}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not print ledger: $e')));
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
              'Account Ledger',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.account.name,
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
        pdfFileName: 'Account_Ledger_${widget.account.name}.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load ledger preview.\n\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
