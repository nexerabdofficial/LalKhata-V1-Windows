import 'package:flutter/material.dart';
import '../../services/refresh_service.dart';
import '../../models/expense.dart';
import '../../services/expense_repository.dart';
import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../../models/account_transaction.dart';
import '../../services/account_transaction_repository.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _categoryController = TextEditingController();

  final _amountController = TextEditingController();

  final _noteController = TextEditingController();

  final ExpenseRepository _repository = ExpenseRepository();
  final AccountTransactionRepository _transactionRepository =
      AccountTransactionRepository();

  bool _isSaving = false;
  final AccountRepository _accountRepository = AccountRepository();

  List<Account> _accounts = [];

  int? _selectedAccountId;
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

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());

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
      _isSaving = true;
    });

    try {
      final now = DateTime.now().toIso8601String();

      // Generate voucher
      final voucherNo = await _repository.getNextExpenseVoucherNo();

      // Save expense
      await _repository.insertExpense(
        Expense(
          category: _categoryController.text.trim(),
          amount: amount,
          accountId: _selectedAccountId,
          voucherNo: voucherNo,
          expenseDate: now,
          note: _noteController.text.trim(),
          createdAt: now,
        ),
      );

      // Add account ledger transaction
      await _transactionRepository.insertTransaction(
        AccountTransaction(
          accountId: _selectedAccountId!,
          transactionType: "EXPENSE",
          referenceType: "EXPENSE",
          referenceId: null,
          voucherNo: voucherNo,
          debit: amount,
          credit: 0,
          transactionDate: now,
          note: _categoryController.text.trim(),
          createdAt: now,
        ),
      );

      RefreshService.notify();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("✅ Expense Saved — $voucherNo")));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save expense: $e")));
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
      appBar: AppBar(title: const Text("Add Expense")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter category";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedAccountId,
                decoration: const InputDecoration(
                  labelText: "Paid From",
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
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: "Amount",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter amount";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Note",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveExpense,
                  child: const Text("Save Expense"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
