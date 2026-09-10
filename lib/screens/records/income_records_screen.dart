import 'package:flutter/material.dart';

class IncomeRecordsScreen extends StatelessWidget {
  const IncomeRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Income Records"),
      ),
      body: const Center(
        child: Text(
          "Income Records Coming Soon",
        ),
      ),
    );
  }
}