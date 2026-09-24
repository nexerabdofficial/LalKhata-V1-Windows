import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../services/ff/ff_cogs_backfill_service.dart';
import '../services/ff/ff_opening_stock_accounting_service.dart';
import '../services/ff/ff_party_account_service.dart';
import '../services/ff/ff_system_accounts.dart';

class SupportLauncherScreen extends StatefulWidget {
  const SupportLauncherScreen({super.key});

  @override
  State<SupportLauncherScreen> createState() => _SupportLauncherScreenState();
}

class _SupportLauncherScreenState extends State<SupportLauncherScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _openCustomerDatabase() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Open Customer LalKhata Database',
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['db'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        if (!mounted) return;

        setState(() {
          _loading = false;
        });

        return;
      }

      final sourcePath = result.files.single.path;

      if (sourcePath == null || sourcePath.trim().isEmpty) {
        throw Exception('Selected database file could not be accessed.');
      }

      // --------------------------------------------------------
      // Open COPY inside Nexera Support sandbox.
      // Customer license/device activation is NOT used.
      // --------------------------------------------------------

      await DatabaseHelper.instance.openSupportDatabaseFromFile(sourcePath);

      // --------------------------------------------------------
      // Run the same idempotent accounting preparation that the
      // normal app performs before showing Dashboard.
      // --------------------------------------------------------

      await FFSystemAccounts.instance.ensureFoundation();

      await FFPartyAccountService.instance.backfillAll();

      await FFCogsBackfillService.instance.backfillMissingHistoricalCogs();

      await FFOpeningStockAccountingService.instance
          .backfillMissingHistoricalOpeningStock();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      try {
        await DatabaseHelper.instance.closeSupportDatabase();
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nexera Support Mode')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.support_agent, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'LalKhata Support Workspace',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Open a customer database without activating '
                      'the customer license on this device.\n\n'
                      'The selected database is copied into a '
                      'separate support workspace before it is opened.',
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _openCustomerDatabase,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.folder_open),
                        label: Text(
                          _loading
                              ? 'Opening Database...'
                              : 'Open Customer Database',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SUPPORT BUILD • CUSTOMER DEVICE SLOT NOT USED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
