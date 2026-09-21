import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../services/ff/ff_custom_group_service.dart';
import 'add_account_group_screen.dart';

class ManageAccountGroupsScreen extends StatefulWidget {
  const ManageAccountGroupsScreen({super.key});

  @override
  State<ManageAccountGroupsScreen> createState() =>
      _ManageAccountGroupsScreenState();
}

class _ManageAccountGroupsScreenState extends State<ManageAccountGroupsScreen> {
  final FFCustomGroupService _service = FFCustomGroupService.instance;

  List<FFAccountGroupOption> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final all = await _service.getSelectableGroups();

      if (!mounted) return;

      setState(() {
        _groups = all.where((g) => !g.isSystem).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      _message('Failed to load groups: $e');
    }
  }

  Future<void> _rename(FFAccountGroupOption group) async {
    final controller = TextEditingController(text: group.name);

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Group'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(dialogContext, value);
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name == null || name == group.name) return;

    try {
      final db = await DatabaseHelper.instance.database;

      final duplicate = await db.rawQuery(
        '''
        SELECT id
        FROM ff_account_groups
        WHERE parent_id = ?
          AND id <> ?
          AND LOWER(TRIM(name)) = LOWER(TRIM(?))
          AND is_active = 1
        LIMIT 1
        ''',
        [group.parentId, group.id, name],
      );

      if (duplicate.isNotEmpty) {
        throw StateError(
          'A group with this name already exists under the same parent.',
        );
      }

      final changed = await db.update(
        'ff_account_groups',
        {'name': name},
        where: 'id = ? AND is_system = 0',
        whereArgs: [group.id],
      );

      if (changed != 1) {
        throw StateError('System groups cannot be changed.');
      }

      await _load();
    } catch (e) {
      if (!mounted) return;
      _message('Rename failed: $e');
    }
  }

  Future<void> _deactivate(FFAccountGroupOption group) async {
    try {
      final db = await DatabaseHelper.instance.database;

      final childCount = await db.rawQuery(
        '''
        SELECT COUNT(*) AS total
        FROM ff_account_groups
        WHERE parent_id = ?
          AND is_active = 1
        ''',
        [group.id],
      );

      final accountCount = await db.rawQuery(
        '''
        SELECT COUNT(*) AS total
        FROM ff_account_links
        WHERE group_id = ?
        ''',
        [group.id],
      );

      final children = (childCount.first['total'] as num?)?.toInt() ?? 0;

      final accounts = (accountCount.first['total'] as num?)?.toInt() ?? 0;

      if (children > 0 || accounts > 0) {
        _message(
          'Cannot deactivate this group. '
          'It is being used by $accounts account(s) '
          'and has $children active subgroup(s).',
        );
        return;
      }

      if (!mounted) return;

      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Deactivate Group?'),
                content: Text(
                  '"${group.name}" will no longer appear '
                  'when creating accounts.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Deactivate'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!confirmed) return;

      await db.update(
        'ff_account_groups',
        {'is_active': 0},
        where: 'id = ? AND is_system = 0',
        whereArgs: [group.id],
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      _message('Failed: $e');
    }
  }

  Future<void> _add() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAccountGroupScreen()),
    );

    if (result == true) {
      await _load();
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Groups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
          ? const Center(
              child: Text(
                'No custom groups yet.\n'
                'Create one using New Group.',
                textAlign: TextAlign.center,
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                itemCount: _groups.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final group = _groups[index];

                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.account_tree_outlined),
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${group.groupKind} • '
                      '${group.accountNature}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'rename') {
                          _rename(group);
                        } else if (value == 'deactivate') {
                          _deactivate(group);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(
                          value: 'deactivate',
                          child: Text('Deactivate'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
