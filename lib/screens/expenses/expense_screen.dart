import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../services/expense_repository.dart';
import 'add_expense_screen.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() =>
      _ExpenseScreenState();
}

class _ExpenseScreenState
    extends State<ExpenseScreen> {
  final ExpenseRepository _repository =
      ExpenseRepository();

  List<Expense> _expenses = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final data =
        await _repository.getExpenses();

    if (!mounted) return;

    setState(() {
      _expenses = data;
      _loading = false;
    });
  }

  Future<void> _deleteExpense(
      Expense expense) async {
    await _repository.deleteExpense(
      expense.id!,
    );

    await _loadExpenses();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "✅ Expense Deleted",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expenses"),
      ),

      floatingActionButton:
          FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final result =
              await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const AddExpenseScreen(),
            ),
          );

          if (result == true) {
            await _loadExpenses();
          }
        },
      ),

      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _expenses.isEmpty
              ? const Center(
                  child: Text(
                    "No Expense Found",
                  ),
                )
              : ListView.builder(
                  itemCount:
                      _expenses.length,
                  itemBuilder:
                      (context, index) {
                    final expense =
                        _expenses[index];

                    return Card(
                      margin:
                          const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading:
                            const CircleAvatar(
                          child: Icon(
                            Icons.money_off,
                          ),
                        ),
                        title: Text(
                          expense.category,
                        ),
                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              expense.expenseDate
                                  .split("T")
                                  .first,
                            ),
                            if ((expense.note ??
                                    "")
                                .isNotEmpty)
                              Text(
  expense.note!,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
                          ],
                        ),
                        trailing: SizedBox(
  width: 90,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Expanded(
        child: Text(
          "৳${expense.amount.toStringAsFixed(2)}",
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ),
      IconButton(
        icon: const Icon(
          Icons.delete,
          color: Colors.red,
        ),
        onPressed: () {
          _deleteExpense(expense);
        },
      ),
    ],
  ),
),
                      ),
                    );
                  },
                ),
    );
  }
}