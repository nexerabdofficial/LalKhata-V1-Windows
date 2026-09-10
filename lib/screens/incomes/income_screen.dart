import 'package:flutter/material.dart';

import '../../models/income.dart';
import '../../services/income_repository.dart';
import 'add_income_screen.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() =>
      _IncomeScreenState();
}

class _IncomeScreenState
    extends State<IncomeScreen> {
  final IncomeRepository _repository =
      IncomeRepository();

  List<Income> _incomes = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadIncomes();
  }

  Future<void> _loadIncomes() async {
    final data =
        await _repository.getIncomes();

    if (!mounted) return;

    setState(() {
      _incomes = data;
      _loading = false;
    });
  }

  Future<void> _deleteIncome(
      Income income) async {
    await _repository.deleteIncome(
      income.id!,
    );

    await _loadIncomes();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text("✅ Income Deleted"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Income"),
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
                  const AddIncomeScreen(),
            ),
          );

          if (result == true) {
            await _loadIncomes();
          }
        },
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _incomes.isEmpty
              ? const Center(
                  child: Text(
                    "No Income Found",
                  ),
                )
              : ListView.builder(
                  itemCount:
                      _incomes.length,
                  itemBuilder:
                      (context, index) {
                    final income =
                        _incomes[index];

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
                            Icons.payments,
                          ),
                        ),
                        title: Text(
                          income.category,
                        ),
                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              income.incomeDate
                                  .split("T")
                                  .first,
                            ),
                            if ((income.note ??
                                    "")
                                .isNotEmpty)
                              Text(
                                income.note!,
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Text(
                              "৳${income.amount.toStringAsFixed(2)}",
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Colors.green,
                              ),
                            ),
                            IconButton(
                              icon:
                                  const Icon(
                                Icons.delete,
                                color:
                                    Colors.red,
                              ),
                              onPressed:
                                  () =>
                                      _deleteIncome(
                                income,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}