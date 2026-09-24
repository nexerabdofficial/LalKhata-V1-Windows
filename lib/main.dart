import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gab/gab_branding.dart';
import 'app.dart';
import 'services/ff/ff_system_accounts.dart';
import 'services/ff/ff_party_account_service.dart';
import 'services/ff/ff_cogs_backfill_service.dart';
import 'services/ff/ff_opening_stock_accounting_service.dart';

/// Global Route Observer
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

const bool kLalKhataSupportStartup = bool.fromEnvironment(
  'LALKHATA_SUPPORT_BUILD',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // SUPABASE INITIALIZATION
  // ==========================================================

  await Supabase.initialize(
    url: 'https://ipqmygqlowiimegescqv.supabase.co',
    publishableKey: 'sb_publishable_QoXkZh9hob9x8CNJgJZeGw_X4UAHRF_',
  );

  await GABBranding.load();

  debugPrint('SUPABASE DEBUG: Initialization completed.');

  // ==========================================================
  // SQFLITE FFI
  // ==========================================================

  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ==========================================================
  // NORMAL CUSTOMER BUILD DATABASE INITIALIZATION
  //
  // Support build intentionally skips this stage because no
  // customer/license database may be opened before the support
  // operator selects a customer backup.
  // ==========================================================

  if (!kLalKhataSupportStartup) {
    await FFSystemAccounts.instance.ensureFoundation();

    await FFPartyAccountService.instance.backfillAll();

    // Historical databases created before sale COGS journal posting
    // may be missing Dr COGS / Cr Inventory.
    await FFCogsBackfillService.instance.backfillMissingHistoricalCogs();

    // Historical opening-stock entries created before central
    // accounting posting are converted once and then skipped.
    await FFOpeningStockAccountingService.instance
        .backfillMissingHistoricalOpeningStock();
  }

  // ==========================================================
  // RUN APP
  // ==========================================================

  runApp(const NexeraInventoryApp());
}
