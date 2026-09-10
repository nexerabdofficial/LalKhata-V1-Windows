import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();

  static final StorageService instance =
      StorageService._();

  static const String _invoiceFolderKey =
      'invoice_folder_path';

  static const String _backupFolderKey =
      'backup_folder_path';

  // ============================================================
  // SELECT INVOICE FOLDER
  // ============================================================

  Future<String?> selectInvoiceFolder() async {
    final selectedPath =
        await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Invoice Folder',
    );

    if (selectedPath == null ||
        selectedPath.trim().isEmpty) {
      return null;
    }

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _invoiceFolderKey,
      selectedPath,
    );

    return selectedPath;
  }

  // ============================================================
  // GET INVOICE FOLDER
  // ============================================================

  Future<String?> getInvoiceFolder() async {
    final prefs =
        await SharedPreferences.getInstance();

    final path =
        prefs.getString(_invoiceFolderKey);

    if (path == null ||
        path.trim().isEmpty) {
      return null;
    }

    return path;
  }

  // ============================================================
  // CLEAR INVOICE FOLDER
  // ============================================================

  Future<void> clearInvoiceFolder() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(_invoiceFolderKey);
  }

  // ============================================================
  // SELECT BACKUP FOLDER
  // ============================================================

  Future<String?> selectBackupFolder() async {
    final selectedPath =
        await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Backup Folder',
    );

    if (selectedPath == null ||
        selectedPath.trim().isEmpty) {
      return null;
    }

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _backupFolderKey,
      selectedPath,
    );

    return selectedPath;
  }

  // ============================================================
  // GET BACKUP FOLDER
  // ============================================================

  Future<String?> getBackupFolder() async {
    final prefs =
        await SharedPreferences.getInstance();

    final path =
        prefs.getString(_backupFolderKey);

    if (path == null ||
        path.trim().isEmpty) {
      return null;
    }

    return path;
  }

  // ============================================================
  // CLEAR BACKUP FOLDER
  // ============================================================

  Future<void> clearBackupFolder() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(_backupFolderKey);
  }

  // ============================================================
  // CHECK DIRECTORY
  // ============================================================

  Future<bool> directoryExists(
    String? path,
  ) async {
    if (path == null ||
        path.trim().isEmpty) {
      return false;
    }

    return Directory(path).exists();
  }

  // ============================================================
  // CHECK BACKUP FOLDER
  // ============================================================

  Future<bool> backupFolderExists() async {
    final path =
        await getBackupFolder();

    return directoryExists(path);
  }

  // ============================================================
  // CHECK INVOICE FOLDER
  // ============================================================

  Future<bool> invoiceFolderExists() async {
    final path =
        await getInvoiceFolder();

    return directoryExists(path);
  }
}