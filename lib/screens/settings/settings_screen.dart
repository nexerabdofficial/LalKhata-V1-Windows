import 'package:flutter/material.dart';

import '../../gab/gab_branding.dart';
import '../../services/backup_service.dart';
import '../../services/storage_service.dart';

import 'about_screen.dart';
import 'backup_restore_screen.dart';
import 'currency_screen.dart';
import 'license_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
  });

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {
  final StorageService _storageService =
      StorageService.instance;

  final BackupService _backupService =
      BackupService.instance;

  String? _backupFolder;

  String _businessName = '';

  bool _loading = true;
  bool _selectingBackupFolder = false;
  bool _creatingBackup = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // ============================================================
  // LOAD SETTINGS
  // ============================================================

  Future<void> _loadSettings() async {
    final backupFolder =
        await _storageService.getBackupFolder();

    final businessName =
        await GABBranding.getBusinessName();

    if (!mounted) return;

    setState(() {
      _backupFolder = backupFolder;
      _businessName = businessName;
      _loading = false;
    });
  }

  // ============================================================
  // SELECT BACKUP FOLDER
  // ============================================================

  Future<void> _selectBackupFolder() async {
    if (_selectingBackupFolder ||
        _creatingBackup) {
      return;
    }

    setState(() {
      _selectingBackupFolder = true;
    });

    try {
      final selectedPath =
          await _storageService
              .selectBackupFolder();

      if (!mounted) return;

      if (selectedPath != null &&
          selectedPath.trim().isNotEmpty) {
        setState(() {
          _backupFolder = selectedPath;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Backup folder saved successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to select backup folder: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _selectingBackupFolder = false;
        });
      }
    }
  }

  // ============================================================
  // CREATE BACKUP
  // ============================================================

  Future<void> _createBackup() async {
    if (_creatingBackup ||
        _selectingBackupFolder) {
      return;
    }

    final backupFolder =
        await _storageService
            .getBackupFolder();

    if (!mounted) return;

    if (backupFolder == null ||
        backupFolder.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a backup folder first.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _creatingBackup = true;
    });

    try {
      final success =
          await _backupService
              .backupDatabase();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Backup created successfully.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Backup failed.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Backup failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _creatingBackup = false;
        });
      }
    }
  }

  // ============================================================
  // CLEAR BACKUP FOLDER
  // ============================================================

  Future<void> _clearBackupFolder() async {
    if (_creatingBackup ||
        _selectingBackupFolder) {
      return;
    }

    final shouldClear =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Clear Backup Folder?',
          ),
          content: const Text(
            'The selected backup folder will be removed from the app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Clear',
              ),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) {
      return;
    }

    await _storageService
        .clearBackupFolder();

    if (!mounted) return;

    setState(() {
      _backupFolder = null;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Backup folder cleared.',
        ),
      ),
    );
  }

  // ============================================================
  // OPEN RESTORE
  // ============================================================

  Future<void> _openRestore() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const BackupRestoreScreen(),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final aboutName = _businessName.isEmpty
        ? 'About'
        : 'About $_businessName';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
        ),
      ),

      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : ListView(
              padding:
                  const EdgeInsets.all(16),
              children: [

                // ==================================================
                // BACKUP
                // ==================================================

                const Text(
                  'Backup',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [

                        // ------------------------------------------
                        // BACKUP FOLDER
                        // ------------------------------------------

                        Row(
                          children: [
                            const Icon(
                              Icons.backup,
                              size: 28,
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            const Expanded(
                              child: Text(
                                'Backup Folder',
                                style:
                                    TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        const Text(
                          'Choose where LalKhata will store backup files.',
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets
                                  .all(12),
                          decoration:
                              BoxDecoration(
                            border:
                                Border.all(
                              color: Theme.of(
                                      context)
                                  .dividerColor,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              8,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              const Icon(
                                Icons.folder,
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child: Text(
                                  _backupFolder ??
                                      'No backup folder selected',
                                  style:
                                      TextStyle(
                                    color:
                                        _backupFolder ==
                                                null
                                            ? Theme.of(
                                                    context)
                                                .colorScheme
                                                .onSurfaceVariant
                                            : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        Row(
                          children: [
                            Expanded(
                              child:
                                  FilledButton
                                      .icon(
                                onPressed:
                                    (_selectingBackupFolder ||
                                            _creatingBackup)
                                        ? null
                                        : _selectBackupFolder,
                                icon:
                                    _selectingBackupFolder
                                        ? const SizedBox(
                                            width:
                                                18,
                                            height:
                                                18,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth:
                                                  2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons
                                                .folder_open,
                                          ),
                                label:
                                    Text(
                                  _backupFolder ==
                                          null
                                      ? 'Select Folder'
                                      : 'Change Folder',
                                ),
                              ),
                            ),

                            if (_backupFolder !=
                                null) ...[
                              const SizedBox(
                                width: 10,
                              ),
                              IconButton(
                                tooltip:
                                    'Clear backup folder',
                                onPressed:
                                    (_creatingBackup ||
                                            _selectingBackupFolder)
                                        ? null
                                        : _clearBackupFolder,
                                icon:
                                    const Icon(
                                  Icons
                                      .delete_outline,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        SizedBox(
                          width:
                              double.infinity,
                          height: 50,
                          child:
                              FilledButton
                                  .icon(
                            onPressed:
                                (_creatingBackup ||
                                        _selectingBackupFolder)
                                    ? null
                                    : _createBackup,
                            icon:
                                _creatingBackup
                                    ? const SizedBox(
                                        width:
                                            20,
                                        height:
                                            20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons
                                            .cloud_upload,
                                      ),
                            label:
                                Text(
                              _creatingBackup
                                  ? 'Creating Backup...'
                                  : 'Create Backup',
                              style:
                                  const TextStyle(
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                // ==================================================
                // RESTORE
                // ==================================================

                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.restore,
                    ),
                    title: const Text(
                      'Restore Backup',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Restore your database from a backup file',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                    ),
                    onTap: _openRestore,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // LICENSE & DEVICES
                // ==================================================

                const Text(
                  'License',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons
                          .verified_user_outlined,
                    ),
                    title: const Text(
                      'License & Devices',
                    ),
                    subtitle: const Text(
                      'View license and device information',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const LicenseScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // GENERAL
                // ==================================================

                const Text(
                  'General',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Card(
                  child: Column(
                    children: [

                      // --------------------------------------------
                      // CURRENCY
                      // --------------------------------------------

                      ListTile(
                        leading: const Icon(
                          Icons
                              .currency_exchange,
                        ),
                        title: const Text(
                          'Currency',
                        ),
                        subtitle: const Text(
                          'BDT (৳)',
                        ),
                        trailing:
                            const Icon(
                          Icons
                              .arrow_forward_ios,
                          size: 18,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const CurrencyScreen(),
                            ),
                          );
                        },
                      ),

                      const Divider(
                        height: 1,
                      ),

                      // --------------------------------------------
                      // ABOUT
                      // --------------------------------------------

                      ListTile(
                        leading: const Icon(
                          Icons.info_outline,
                        ),
                        title: Text(
                          aboutName,
                        ),
                        subtitle: Text(
                          GABBranding
                              .appVersion,
                        ),
                        trailing:
                            const Icon(
                          Icons
                              .arrow_forward_ios,
                          size: 18,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AboutScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),
              ],
            ),
    );
  }
}