import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'storage_service.dart';

class BackupService {
  BackupService();

  static final BackupService instance =
      BackupService();

  final StorageService _storageService =
      StorageService.instance;

  // ============================================================
  // DATABASE PATH
  // ============================================================

  Future<String> getDatabasePath() async {
    return await getDatabasesPath();
  }

  // ============================================================
  // DATABASE FILE PATH
  // ============================================================

  Future<String> getDatabaseFile() async {
    final dbPath =
        await getDatabasesPath();

    return p.join(
      dbPath,
      'nexera_inventory.db',
    );
  }

  // ============================================================
  // DATABASE FILE
  // ============================================================

  Future<File> getDatabase() async {
    final path =
        await getDatabaseFile();

    return File(path);
  }

  // ============================================================
  // CREATE BACKUP
  // ============================================================

  Future<bool> backupDatabase() async {
    try {
      final dbFile =
          await getDatabase();

      if (!await dbFile.exists()) {
        return false;
      }

      // ----------------------------------------------------------
      // Get user-selected backup folder
      // ----------------------------------------------------------

      String? backupFolder =
          await _storageService
              .getBackupFolder();

      // ----------------------------------------------------------
      // If no folder selected, stop.
      // We no longer silently use another folder.
      // ----------------------------------------------------------

      if (backupFolder == null ||
          backupFolder.trim().isEmpty) {
        return false;
      }

      final targetDir =
          Directory(backupFolder);

      if (!await targetDir.exists()) {
        return false;
      }

      // ----------------------------------------------------------
      // Generate backup filename
      // ----------------------------------------------------------

      final now =
          DateTime.now();

      final fileName =
          'Nexera_Backup_'
          '${now.year}'
          '${_twoDigits(now.month)}'
          '${_twoDigits(now.day)}_'
          '${_twoDigits(now.hour)}'
          '${_twoDigits(now.minute)}'
          '${_twoDigits(now.second)}'
          '.db';

      final backupPath =
          p.join(
        targetDir.path,
        fileName,
      );

      // ----------------------------------------------------------
      // Copy database
      // ----------------------------------------------------------

      await dbFile.copy(
        backupPath,
      );

      // ----------------------------------------------------------
      // Verify backup
      // ----------------------------------------------------------

      final backupFile =
          File(backupPath);

      if (!await backupFile.exists()) {
        return false;
      }

      final originalSize =
          await dbFile.length();

      final backupSize =
          await backupFile.length();

      if (originalSize != backupSize) {
        return false;
      }

      return true;
    } catch (e) {
      print(
        'Backup error: $e',
      );

      return false;
    }
  }

  // ============================================================
  // RESTORE DATABASE
  // ============================================================

  Future<bool> restoreDatabase() async {
    try {
      final result =
          await FilePicker.platform.pickFiles(
        dialogTitle:
            'Select Nexera Backup',
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result == null) {
        return false;
      }

      final backupPath =
          result.files.single.path;

      if (backupPath == null ||
          backupPath.trim().isEmpty) {
        return false;
      }

      final backupFile =
          File(backupPath);

      if (!await backupFile.exists()) {
        return false;
      }

      final dbFile =
          await getDatabase();

      // ----------------------------------------------------------
      // Close database before replacing file
      // ----------------------------------------------------------

      final database =
          await openDatabase(
        dbFile.path,
      );

      await database.close();

      // ----------------------------------------------------------
      // Replace database
      // ----------------------------------------------------------

      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      await backupFile.copy(
        dbFile.path,
      );

      return true;
    } catch (e) {
      print(
        'Restore error: $e',
      );

      return false;
    }
  }

  // ============================================================
  // TIMESTAMP HELPER
  // ============================================================

  String _twoDigits(
    int value,
  ) {
    return value
        .toString()
        .padLeft(2, '0');
  }
}