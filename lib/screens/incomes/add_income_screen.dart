import 'package:flutter/material.dart';

import '../../models/income.dart';
import '../../services/income_repository.dart';
import '../../models/account.dart';
import '../../services/account_repository.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _category = TextEditingController();

  final _amount = TextEditingController();

  final _note = TextEditingController();

  final IncomeRepository _repository = IncomeRepository();

  final AccountRepository _accountRepository = AccountRepository();

  List<Account> _accounts = [];

  int? _selectedAccountId;

  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amount.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter a valid amount.")));
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an account.")),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final now = DateTime.now().toIso8601String();

      final voucherNo = await _repository.getNextIncomeVoucherNo();

      await _repository.insertIncome(
        Income(
          category: _category.text.trim(),
          amount: amount,
          accountId: _selectedAccountId,
          incomeDate: now,
          note: _note.text.trim(),
          createdAt: now,
        ),
        voucherNo: voucherNo,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Income saved. Voucher: $voucherNo")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save income: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final data = await _accountRepository.getAccounts();

    if (!mounted) return;

    setState(() {
      _accounts = data;

      if (data.isNotEmpty) {
        _selectedAccountId = data.first.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Income")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: "Category"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedAccountId,
                decoration: const InputDecoration(
                  labelText: "Received To",
                  border: OutlineInputBorder(),
                ),
                items: _accounts.map((account) {
                  return DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAccountId = value;
                  });
                },
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: "Note"),
                maxLines: 3,
              ),

              const SizedBox(height: 30),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: const Text("Save Income"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
