import 'package:flutter/material.dart';

import '../../services/keyboard_shortcut_service.dart';

class KeyboardShortcutsScreen extends StatefulWidget {
  const KeyboardShortcutsScreen({super.key});

  @override
  State<KeyboardShortcutsScreen> createState() =>
      _KeyboardShortcutsScreenState();
}

class _KeyboardShortcutsScreenState extends State<KeyboardShortcutsScreen> {
  Map<String, String> _values = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await KeyboardShortcutService.load();

    if (!mounted) return;

    setState(() {
      _values = values;
      _loading = false;
    });
  }

  Future<void> _edit(AppKeyboardShortcut item) async {
    final controller = TextEditingController(
      text: _values[item.id] ?? item.defaultKeys,
    );

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(item.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter a 2-key shortcut.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'Shortcut',
                  hintText: 'SS',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  Navigator.pop(dialogContext, value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (value == null) return;

    final error = await KeyboardShortcutService.saveShortcut(
      id: item.id,
      keys: value,
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    await _load();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${item.title} shortcut updated.')));
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset shortcuts?'),
          content: const Text(
            'All keyboard shortcuts will be restored to their default values.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await KeyboardShortcutService.resetToDefaults();
    await _load();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Keyboard shortcuts reset to defaults.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyboard Shortcuts'),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            onPressed: _loading ? null : _reset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.keyboard_alt_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Desktop keyboard shortcuts work outside '
                            'text-entry fields. Tap Edit to change any '
                            'shortcut.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...KeyboardShortcutService.shortcuts.map((item) {
                  final keys = _values[item.id] ?? item.defaultKeys;

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.keyboard_command_key),
                      title: Text(item.title),
                      subtitle: Text('Default: ${item.defaultKeys}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              keys,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _edit(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      onTap: () => _edit(item),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset to Default'),
                ),
              ],
            ),
    );
  }
}
