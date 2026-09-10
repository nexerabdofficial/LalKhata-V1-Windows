import 'package:flutter/material.dart';

import '../../services/backup_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState
    extends State<BackupRestoreScreen> {
  final BackupService _backupService =
      BackupService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Restore Database"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.restore,
                  color: Colors.green,
                  size: 30,
                ),
                title: const Text(
                  "Restore Database",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  "Restore data from a backup file",
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                ),
                onTap: () async {
                  final confirm =
                      await showDialog<bool>(
                    context: context,
                    builder: (context) =>
                        AlertDialog(
                      title: const Text(
                        "Restore Database",
                      ),
                      content: const Text(
                        "Current database will be replaced.\n\n"
                        "Are you sure you want to restore?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(
                            context,
                            false,
                          ),
                          child: const Text(
                            "Cancel",
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(
                            context,
                            true,
                          ),
                          child: const Text(
                            "Restore",
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  final success =
                      await _backupService
                          .restoreDatabase();

                  if (!mounted) return;

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? "Database restored successfully.\n"
                                "Please restart the app."
                            : "Restore cancelled.",
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}