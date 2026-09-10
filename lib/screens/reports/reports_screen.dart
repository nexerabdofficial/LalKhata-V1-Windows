import 'package:flutter/material.dart';

import 'low_stock_screen.dart';
import 'stock_report_screen.dart';
import '../sales/sales_screen.dart';
import '../purchases/purchase_history_screen.dart';
import 'profit_report_screen.dart';
import 'balance_sheet_screen.dart';
import 'income_expense_report_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: const Text(
          "Reports",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24,
          ),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            // =========================
            // STOCK REPORT
            // =========================
            _reportCard(
              context,
              "Stock Report",
              Icons.inventory_2,
              Colors.blue,
              const StockReportScreen(),
            ),

            // =========================
            // PROFIT REPORT
            // =========================
            _reportCard(
              context,
              "Profit Report",
              Icons.trending_up,
              Colors.purple,
              const ProfitReportScreen(),
            ),

            // =========================
            // BALANCE SHEET
            // =========================
            _reportCard(
              context,
              "Balance Sheet",
              Icons.account_balance,
              Colors.teal,
              const BalanceSheetScreen(),
            ),

            // =========================
            // INCOME & EXPENSE REPORT
            // =========================
            _reportCard(
              context,
              "Income & Expense",
              Icons.bar_chart,
              Colors.deepOrange,
              const IncomeExpenseReportScreen(),
            ),

            // =========================
          ],
        ),
      ),
    );
  }

  Widget _reportCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget screen,
  ) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => screen,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    color.withOpacity(.12),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}