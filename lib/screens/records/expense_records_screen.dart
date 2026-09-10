import 'package:flutter/material.dart';

class ExpenseReportScreen extends StatelessWidget {
  const ExpenseReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Report"),
      ),
      body: const Center(
        child: Text("Expense Report Coming Soon"),
      ),
    );
  }
}