import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../../services/account_service.dart';

class AddAccountScreen extends StatefulWidget {
  final Account? account;

  const AddAccountScreen({super.key, this.account});

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

  String _type = "BANK";

  bool _isSaving = false;

  bool get isEdit => widget.account != null;

  final Map<String, String> _accountTypes = {
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

  Future<void> _saveAccount() async {
    if (_isSaving) return;

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

        await _accountService.updateAccount(account);
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

        await _accountService.createAccount(account);
      }

      if (!mounted) return;

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
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Account Name",
                  hintText: "Example: bKash Personal",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
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

              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: "Account Type",
                  border: OutlineInputBorder(),
                ),
                items: _accountTypes.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _type = value;
                  });
                },
              ),

              const Spacer(),

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
          ),
        ),
      ),
    );
  }
}
