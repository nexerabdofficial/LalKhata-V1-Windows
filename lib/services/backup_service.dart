import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'storage_service.dart';

class BackupService {
  BackupService();

  static final BackupService instance = BackupService();

  final StorageService _storageService = StorageService.instance;
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // ============================================================
  // ACTIVE DATABASE
  // ============================================================

  Future<String> getDatabaseFile() async {
    return _databaseHelper.getActiveDatabasePath();
  }

  Future<File> getDatabase() async {
    return _databaseHelper.getActiveDatabaseFile();
  }

  // ============================================================
  // CREATE BACKUP
  // ============================================================

  Future<bool> backupDatabase() async {
    try {
      final dbFile = await getDatabase();

      if (!await dbFile.exists()) {
        return false;
      }

      final backupFolder = await _storageService.getBackupFolder();

      if (backupFolder == null || backupFolder.trim().isEmpty) {
        return false;
      }

      final targetDir = Directory(backupFolder);

      if (!await targetDir.exists()) {
        return false;
      }

      // Flush WAL into the main SQLite file before copying.
      final db = await _databaseHelper.database;

      try {
        await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {}

      final now = DateTime.now();

      final fileName =
          'Nexera_Backup_'
          '${now.year}'
          '${_twoDigits(now.month)}'
          '${_twoDigits(now.day)}_'
          '${_twoDigits(now.hour)}'
          '${_twoDigits(now.minute)}'
          '${_twoDigits(now.second)}'
          '.db';

      final backupPath = p.join(targetDir.path, fileName);

      await dbFile.copy(backupPath);

      final backupFile = File(backupPath);

      if (!await backupFile.exists()) {
        return false;
      }

      if (await backupFile.length() <= 0) {
        return false;
      }

      return await _validateBackupFile(backupFile);
    } catch (e) {
      print('Backup error: $e');
      return false;
    }
  }

  // ============================================================
  // RESTORE DATABASE
  // ============================================================

  Future<bool> restoreDatabase() async {
    File? safetyBackup;

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select LalKhata Backup',
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['db'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        return false;
      }

      final selectedPath = result.files.single.path;

      if (selectedPath == null || selectedPath.trim().isEmpty) {
        return false;
      }

      final backupFile = File(selectedPath);

      if (!await backupFile.exists()) {
        return false;
      }

      // ----------------------------------------------------------
      // Validate selected SQLite DB BEFORE touching current DB.
      // ----------------------------------------------------------

      if (!await _validateBackupFile(backupFile)) {
        throw Exception('Selected file is not a valid LalKhata database.');
      }

      final activeDbFile = await getDatabase();

      // ----------------------------------------------------------
      // Flush current database.
      // ----------------------------------------------------------

      try {
        final currentDb = await _databaseHelper.database;
        await currentDb.rawQuery('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {}

      // ----------------------------------------------------------
      // Automatic safety copy of CURRENT database.
      // This remains beside the active DB and can be recovered
      // manually if restore is interrupted.
      // ----------------------------------------------------------

      if (await activeDbFile.exists()) {
        final stamp = DateTime.now().millisecondsSinceEpoch;

        safetyBackup = File('${activeDbFile.path}.before_restore_$stamp');

        await activeDbFile.copy(safetyBackup.path);
      }

      // ----------------------------------------------------------
      // IMPORTANT:
      // Close the REAL DatabaseHelper connection.
      // ----------------------------------------------------------

      await _databaseHelper.closeDatabase();

      // ----------------------------------------------------------
      // Remove SQLite side files belonging to previous DB.
      // ----------------------------------------------------------

      await _deleteIfExists(File('${activeDbFile.path}-wal'));

      await _deleteIfExists(File('${activeDbFile.path}-shm'));

      await _deleteIfExists(File('${activeDbFile.path}-journal'));

      // ----------------------------------------------------------
      // Restore into CURRENT LICENSE database path.
      //
      // Backup filename/license/platform does NOT matter.
      // Windows -> Android
      // Android -> Windows
      // PC -> PC
      // Mobile -> Mobile
      // ----------------------------------------------------------

      final tempRestore = File('${activeDbFile.path}.restore_tmp');

      await _deleteIfExists(tempRestore);

      await backupFile.copy(tempRestore.path);

      // Validate copied temp file before replacing active DB.
      if (!await _validateBackupFile(tempRestore)) {
        await _deleteIfExists(tempRestore);

        throw Exception('Restore copy validation failed.');
      }

      await _deleteIfExists(activeDbFile);

      await tempRestore.rename(activeDbFile.path);

      // ----------------------------------------------------------
      // Reopen through DatabaseHelper.
      //
      // If backup is an older supported schema, normal sqflite
      // migration upgrades it to current DB version.
      // ----------------------------------------------------------

      await _databaseHelper.reopenActiveDatabase();

      // ----------------------------------------------------------
      // Final integrity check on ACTIVE database.
      // ----------------------------------------------------------

      final restoredDb = await _databaseHelper.database;

      final integrity = await restoredDb.rawQuery('PRAGMA integrity_check');

      final integrityValue = integrity.isNotEmpty
          ? integrity.first.values.first?.toString().toLowerCase()
          : null;

      if (integrityValue != 'ok') {
        throw Exception('Restored database integrity check failed.');
      }

      return true;
    } catch (e) {
      print('Restore error: $e');

      // ----------------------------------------------------------
      // RECOVERY
      //
      // If we had already made a safety backup and active DB is
      // damaged/missing, restore the previous local database.
      // ----------------------------------------------------------

      if (safetyBackup != null && await safetyBackup.exists()) {
        try {
          await _databaseHelper.closeDatabase();

          final activeDbFile = await getDatabase();

          await _deleteIfExists(File('${activeDbFile.path}-wal'));

          await _deleteIfExists(File('${activeDbFile.path}-shm'));

          await _deleteIfExists(File('${activeDbFile.path}-journal'));

          await _deleteIfExists(activeDbFile);

          await safetyBackup.copy(activeDbFile.path);

          await _databaseHelper.reopenActiveDatabase();
        } catch (recoveryError) {
          print('Restore recovery error: $recoveryError');
        }
      }

      return false;
    }
  }

  // ============================================================
  // VALIDATE LALKHATA DATABASE
  // ============================================================

  Future<bool> _validateBackupFile(File file) async {
    Database? db;

    try {
      if (!await file.exists()) {
        return false;
      }

      if (await file.length() <= 0) {
        return false;
      }

      db = await openDatabase(file.path, readOnly: true, singleInstance: false);

      final integrity = await db.rawQuery('PRAGMA integrity_check');

      if (integrity.isEmpty) {
        return false;
      }

      final integrityValue = integrity.first.values.first
          ?.toString()
          .trim()
          .toLowerCase();

      if (integrityValue != 'ok') {
        return false;
      }

      final tables = await db.rawQuery('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
      ''');

      final tableNames = tables
          .map((row) => row['name']?.toString().toLowerCase())
          .whereType<String>()
          .toSet();

      // Core tables common to LalKhata business databases.
      const requiredTables = <String>{
        'products',
        'customers',
        'suppliers',
        'sales',
        'purchases',
        'accounts',
      };

      if (!requiredTables.every(tableNames.contains)) {
        return false;
      }

      return true;
    } catch (e) {
      print('Backup validation error: $e');
      return false;
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  }

  // ============================================================
  // FILE HELPER
  // ============================================================

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ============================================================
  // TIMESTAMP HELPER
  // ============================================================

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}
