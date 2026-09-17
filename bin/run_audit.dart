import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexera_inventory/services/internal_audit_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final service = InternalAuditService();
  final findings = await service.runFullAudit();

  for (final f in findings) {
    print(
      '[${f.status.name.toUpperCase()}] '
      '${f.code} | ${f.title} | ${f.message}',
    );
  }
}
