import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gab/gab_branding.dart';
import 'app.dart';

/// Global Route Observer
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

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

  debugPrint(
    'SUPABASE DEBUG: Initialization completed.',
  );

  // ==========================================================
  // SQFLITE FFI
  // ==========================================================

  if (!kIsWeb &&
      (Platform.isLinux ||
          Platform.isWindows ||
          Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ==========================================================
  // RUN APP
  // ==========================================================

  runApp(
    const NexeraInventoryApp(),
  );
}