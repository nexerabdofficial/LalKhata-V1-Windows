import 'package:flutter/material.dart';

import '../../services/ff/ff_custom_group_service.dart';

class AddAccountGroupScreen extends StatefulWidget {
  const AddAccountGroupScreen({super.key});

  @override
  State<AddAccountGroupScreen> createState() => _AddAccountGroupScreenState();
}

class _AddAccountGroupScreenState extends State<AddAccountGroupScreen> {
  final _nameController = TextEditingController();

  final FFCustomGroupService _service = FFCustomGroupService.instance;

  List<FFAccountGroupOption> _parents = [];

  FFAccountGroupOption? _selectedParent;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final groups = await _service.getPossibleParents();

      if (!mounted) return;

      setState(() {
        _parents = groups;

        if (groups.isNotEmpty) {
          _selectedParent = groups.first;
        }

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _message('Failed to load groups: $e');
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final parent = _selectedParent;

    if (name.isEmpty) {
      _message('Enter group name.');
      return;
    }

    if (parent == null) {
      _message('Select a parent group.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _service.createCustomGroup(name: name, parentId: parent.id);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _message('Failed to create group: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Account Group')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      hintText: 'Example: Advertising Expense',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<FFAccountGroupOption>(
                    initialValue: _selectedParent,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Under',
                      border: OutlineInputBorder(),
                    ),
                    items: _parents.map((group) {
                      return DropdownMenuItem<FFAccountGroupOption>(
                        value: group,
                        child: Text(
                          '${group.name} • ${group.groupKind}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedParent = value;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  if (_selectedParent != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Accounting Nature: '
                          '${_selectedParent!.accountNature}\n'
                          'Category: '
                          '${_selectedParent!.groupKind}',
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.create_new_folder_outlined),
                      label: Text(_saving ? 'Saving...' : 'Create Group'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
