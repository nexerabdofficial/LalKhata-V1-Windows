import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../../services/account_service.dart';
import '../../services/ff/ff_custom_group_service.dart';
import 'add_account_group_screen.dart';
import '../customers/add_customer_screen.dart';
import '../suppliers/add_supplier_screen.dart';

class AddAccountScreen extends StatefulWidget {
  final Account? account;
  final bool stayAfterSave;

  const AddAccountScreen({super.key, this.account, this.stayAfterSave = false});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  final _openingBalanceController = TextEditingController(text: "0");

  DateTime _openingDate = DateTime.now();

  final AccountRepository _repository = AccountRepository();

  final AccountService _accountService = AccountService();

  final FFCustomGroupService _groupService = FFCustomGroupService.instance;

  List<FFAccountGroupOption> _groups = [];

  FFAccountGroupOption? _selectedGroup;

  String _type = "BANK";

  // New account starts with no type selected.
  // Edit mode continues to use the account's existing type.
  String? _newAccountType;

  bool _isSaving = false;

  bool get isEdit => widget.account != null;

  final Map<String, String> _accountTypes = {
    "CUSTOMER": "Customer / Receivable",
    "SUPPLIER": "Supplier / Payable",
    "CASH": "Cash",
    "BANK": "Bank",
    "MOBILE_BANKING": "MFS / Mobile Banking",
    "OTHER_CURRENT_ASSET": "Other Current Asset",
    "FIXED_ASSET": "Fixed Asset",
    "OTHER_LIABILITY": "Other Liability",
    "OWNER_CAPITAL": "Owner Capital",
    "OTHER_INCOME": "Income",
    "OPERATING_EXPENSE": "Expense",
  };

  @override
  void initState() {
    super.initState();

    _loadGroups();

    if (isEdit) {
      final account = widget.account!;

      _nameController.text = account.name;

      _type = account.type;

      // Legacy CARD accounts are migrated in the
      // edit UI to Other Current Asset.
      if (_type.toUpperCase() == "CARD") {
        _type = "OTHER_CURRENT_ASSET";
      }

      _openingBalanceController.text = account.openingBalance.toStringAsFixed(
        2,
      );

      final parsedDate = DateTime.tryParse(account.openingDate);

      if (parsedDate != null) {
        _openingDate = parsedDate;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();

    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _groupService.getSelectableGroups();

      if (!mounted) return;

      FFAccountGroupOption? selected;

      if (isEdit && widget.account?.id != null) {
        try {
          final primaryGroup = await _accountService.getPrimaryGroupForAccount(
            widget.account!.id!,
          );

          if (primaryGroup != null) {
            for (final group in groups) {
              if (group.id == primaryGroup.id) {
                selected = group;
                break;
              }
            }
          }
        } catch (_) {
          // Keep standard classification fallback available.
        }
      }

      if (!mounted) return;

      setState(() {
        _groups = groups;

        if (isEdit) {
          _selectedGroup = selected;
        }
      });
    } catch (_) {
      // Account creation can still use the standard type mapping.
    }
  }

  Future<void> _createGroup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAccountGroupScreen()),
    );

    if (result == true) {
      await _loadGroups();
    }
  }

  Future<void> _openPartyCreator(String type) async {
    final page = type == "CUSTOMER"
        ? const AddCustomerScreen()
        : const AddSupplierScreen();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    if (!mounted) return;

    if (result == true) {
      if (widget.stayAfterSave) {
        setState(() {
          _newAccountType = null;
          _type = "BANK";
          _selectedGroup = null;
        });

        return;
      }

      Navigator.pop(context, true);
    }
  }

  List<FFAccountGroupOption> get _compatibleCustomGroups {
    // This field is specifically "Custom Group", so never expose
    // system groups such as Cash, Bank, Inventory, etc.
    final customGroups = _groups.where((group) => !group.isSystem).toList();

    final type = (isEdit ? _type : _newAccountType)?.trim().toUpperCase();

    if (type == null || type.isEmpty) {
      return customGroups;
    }

    String? requiredKind;

    switch (type) {
      case 'CASH':
      case 'BANK':
      case 'MOBILE_BANKING':
      case 'MFS':
      case 'OTHER_CURRENT_ASSET':
      case 'FIXED_ASSET':
        requiredKind = 'ASSET';
        break;

      case 'OTHER_LIABILITY':
        requiredKind = 'LIABILITY';
        break;

      case 'OWNER_CAPITAL':
        requiredKind = 'EQUITY';
        break;

      case 'OTHER_INCOME':
        requiredKind = 'INCOME';
        break;

      case 'OPERATING_EXPENSE':
        requiredKind = 'EXPENSE';
        break;

      default:
        return customGroups;
    }

    return customGroups.where((group) {
      return group.groupKind.trim().toUpperCase() == requiredKind;
    }).toList();
  }

  bool get _isPartyCreation =>
      !isEdit &&
      (_newAccountType == "CUSTOMER" || _newAccountType == "SUPPLIER");

  bool get _showAccountDetails =>
      isEdit || (_newAccountType != null && !_isPartyCreation);

  Future<void> _handleTypeChange(String value) async {
    if (isEdit) {
      setState(() {
        _type = value;

        final selected = _selectedGroup;

        if (selected != null) {
          final stillCompatible = _compatibleCustomGroups.any(
            (group) => group.id == selected.id,
          );

          if (!stillCompatible) {
            _selectedGroup = null;
          }
        }
      });
      return;
    }

    setState(() {
      _newAccountType = value;
      _type = value;

      // A custom group belongs to an accounting classification.
      // Never carry an old selection into another account type.
      _selectedGroup = null;
    });

    if (_isPartyCreation) {
      await _openPartyCreator(value);

      // If party creation was cancelled, return Add Account
      // to its initial "Account Type only" state.
      if (mounted) {
        setState(() {
          _newAccountType = null;
          _type = "BANK";
        });
      }
    }
  }

  Future<void> _saveAccount() async {
    if (_isSaving) return;

    if (!isEdit && _newAccountType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select account type.")));
      return;
    }

    if (!isEdit && _isPartyCreation) {
      await _openPartyCreator(_type);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();

    final openingBalance =
        double.tryParse(_openingBalanceController.text.trim()) ?? 0;

    if (openingBalance < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Opening balance cannot be negative.")),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (isEdit) {
        final exists = await _repository.accountNameExistsForUpdate(
          name: name,
          accountId: widget.account!.id!,
        );

        if (exists) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account already exists.")),
          );

          return;
        }

        final account = Account(
          id: widget.account!.id,
          name: name,
          type: _type,
          balance: widget.account!.balance,
          openingBalance: openingBalance,
          openingDate: _openingDate.toIso8601String(),
          createdAt: widget.account!.createdAt,
        );

        await _accountService.updateAccount(
          account,
          groupId: _selectedGroup?.id,
        );
      } else {
        final exists = await _repository.accountNameExists(name);

        if (exists) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account already exists.")),
          );

          return;
        }

        final account = Account(
          name: name,
          type: _type,
          balance: openingBalance,
          openingBalance: openingBalance,
          openingDate: _openingDate.toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
        );

        await _accountService.createAccount(
          account,
          groupId: _selectedGroup?.id,
        );
      }

      if (!mounted) return;

      if (!isEdit && widget.stayAfterSave) {
        _nameController.clear();
        _openingBalanceController.text = "0";

        setState(() {
          _openingDate = DateTime.now();
          _newAccountType = null;
          _type = "BANK";
          _selectedGroup = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account saved successfully.")),
        );

        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save account: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? "Edit Account" : "Add Account")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ==================================================
              // ACCOUNT TYPE FIRST
              // ==================================================
              DropdownButtonFormField<String>(
                value: isEdit ? _type : _newAccountType,
                decoration: const InputDecoration(
                  labelText: "Account Type",
                  hintText: "Select account type",
                  border: OutlineInputBorder(),
                ),
                items: _accountTypes.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged:
                    isEdit &&
                        (widget.account!.type.toUpperCase() == "CUSTOMER" ||
                            widget.account!.type.toUpperCase() == "SUPPLIER")
                    ? null
                    : (value) {
                        if (value == null) return;
                        _handleTypeChange(value);
                      },
              ),

              // Customer/Supplier never use the generic
              // account-detail fields during creation.
              if (_showAccountDetails) ...[
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Account Name",
                    hintText: "Example: bKash Personal",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_isPartyCreation) return null;

                    if (value == null || value.trim().isEmpty) {
                      return "Enter account name";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _openingBalanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: "Opening Balance",
                    prefixText: "৳ ",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_isPartyCreation) return null;

                    if (value == null || value.trim().isEmpty) {
                      return "Enter opening balance";
                    }

                    final amount = double.tryParse(value.trim());

                    if (amount == null) {
                      return "Enter a valid amount";
                    }

                    if (amount < 0) {
                      return "Opening balance cannot be negative";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text("Opening Date"),
                  subtitle: Text(
                    "${_openingDate.day}/"
                    "${_openingDate.month}/"
                    "${_openingDate.year}",
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _openingDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );

                    if (picked != null) {
                      setState(() {
                        _openingDate = picked;
                      });
                    }
                  },
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<FFAccountGroupOption>(
                  initialValue: _selectedGroup,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Custom Group (Optional)",
                    hintText: "Use standard account classification",
                    border: OutlineInputBorder(),
                  ),
                  items: _compatibleCustomGroups.map((group) {
                    return DropdownMenuItem<FFAccountGroupOption>(
                      value: group,
                      child: Text(group.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGroup = value;
                    });
                  },
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: isEdit ? null : _createGroup,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text("Create Custom Group"),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAccount,
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isEdit ? "Update Account" : "Save Account",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
