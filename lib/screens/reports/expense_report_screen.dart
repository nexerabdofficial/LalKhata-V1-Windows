import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../services/expense_repository.dart';

class ExpenseReportScreen extends StatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  State<ExpenseReportScreen> createState() =>
      _ExpenseReportScreenState();
}

class _ExpenseReportScreenState
    extends State<ExpenseReportScreen> {
  final ExpenseRepository _repository =
    ExpenseRepository();

List<Expense> expenses = [];

bool loading = true;

double totalExpense = 0;

@override
void initState() {
  super.initState();
  _loadReport();
}

  Future<void> _loadReport() async {
  totalExpense =
      await _repository.getTotalExpense();

  expenses =
      await _repository.getExpenses();

  if (!mounted) return;

  setState(() {
    loading = false;
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Income Report"),
      ),
      body: loading
    ? const Center(
        child: CircularProgressIndicator(),
      )
    : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            Center(
              child: Column(
                children: [

                  const Text(
                    "Total Expense",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "৳ ${totalExpense.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.red,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Expense History",
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Expanded(
              child: expenses.isEmpty
                  ? const Center(
                      child: Text(
                        "No expense found.",
                      ),
                    )
                  : ListView.builder(
                      itemCount:
                          expenses.length,
                      itemBuilder:
                          (context, index) {

                        final expense =
                            expenses[index];

                        return Card(
                          margin:
                              const EdgeInsets.only(
                            bottom: 10,
                          ),
                          child: ListTile(
                            leading:
                                CircleAvatar(
                              backgroundColor:
                                  Colors.red.shade100,
                              child:
                                  const Icon(
                                Icons.money_off,
                                color:
                                    Colors.red,
                              ),
                            ),

                            title: Text(
                              expense.category,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            subtitle: Text(
                              expense.expenseDate,
                            ),

                            trailing: Text(
                              "৳${expense.amount.toStringAsFixed(2)}",
                              style:
                                  const TextStyle(
                                color:
                                    Colors.red,
                                fontWeight:
                                    FontWeight.bold,
                              ),
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