import 'package:flutter/material.dart';

import '../../models/income.dart';
import '../../services/income_repository.dart';

class IncomeReportScreen extends StatefulWidget {
  const IncomeReportScreen({super.key});

  @override
  State<IncomeReportScreen> createState() =>
      _IncomeReportScreenState();
}

class _IncomeReportScreenState
    extends State<IncomeReportScreen> {
  final IncomeRepository _repository =
      IncomeRepository();

  List<Income> incomes = [];

  bool loading = true;

  double totalIncome = 0;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<void> _loadReport() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      _errorMessage = null;
    });

    try {
      final total =
          await _repository.getTotalIncome();

      final incomeList =
          await _repository.getIncomes();

      if (!mounted) return;

      setState(() {
        totalIncome = total;
        incomes = incomeList;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        totalIncome = 0;
        incomes = [];
        loading = false;
        _errorMessage =
            'Failed to load income report.';
      });

      debugPrint(
        'Income Report Error: $e',
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Income Report",
        ),
        actions: [
          IconButton(
            onPressed:
                loading ? null : _loadReport,
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip: "Refresh",
          ),
        ],
      ),

      // ==========================================================
      // LOADING
      // ==========================================================

      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )

          // ========================================================
          // ERROR
          // ========================================================

          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      24,
                    ),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons
                              .error_outline,
                          size: 56,
                          color: Colors.red,
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        Text(
                          _errorMessage!,
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        FilledButton.icon(
                          onPressed:
                              _loadReport,
                          icon:
                              const Icon(
                            Icons.refresh,
                          ),
                          label:
                              const Text(
                            "Try Again",
                          ),
                        ),
                      ],
                    ),
                  ),
                )

          // ========================================================
          // REPORT
          // ========================================================

          : Padding(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // TOTAL INCOME
                  // ==================================================

                  Center(
                    child: Column(
                      children: [
                        const Text(
                          "Total Income",
                          style:
                              TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        Text(
                          "৳ ${totalIncome.toStringAsFixed(2)}",
                          style:
                              const TextStyle(
                            fontSize: 32,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  // ==================================================
                  // HISTORY TITLE
                  // ==================================================

                  const Text(
                    "Income History",
                    style:
                        TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  // ==================================================
                  // INCOME LIST
                  // ==================================================

                  Expanded(
                    child: incomes.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons
                                      .receipt_long_outlined,
                                  size: 56,
                                  color:
                                      Colors.grey,
                                ),

                                SizedBox(
                                  height: 12,
                                ),

                                Text(
                                  "No income found.",
                                  style:
                                      TextStyle(
                                    fontSize:
                                        16,
                                    fontWeight:
                                        FontWeight
                                            .w500,
                                  ),
                                ),

                                SizedBox(
                                  height: 4,
                                ),

                                Text(
                                  "Income records will appear here.",
                                  style:
                                      TextStyle(
                                    fontSize:
                                        13,
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount:
                                incomes.length,
                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              final income =
                                  incomes[
                                      index];

                              return Card(
                                elevation: 2,
                                margin:
                                    const EdgeInsets
                                        .only(
                                  bottom: 10,
                                ),
                                child:
                                    ListTile(
                                  leading:
                                      CircleAvatar(
                                    backgroundColor:
                                        Colors
                                            .green
                                            .shade100,
                                    child:
                                        const Icon(
                                      Icons
                                          .attach_money,
                                      color: Colors
                                          .green,
                                    ),
                                  ),

                                  title:
                                      Text(
                                    income
                                        .category,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),

                                  subtitle:
                                      Text(
                                    income
                                        .incomeDate,
                                  ),

                                  trailing:
                                      Text(
                                    "৳${income.amount.toStringAsFixed(2)}",
                                    style:
                                        const TextStyle(
                                      color: Colors
                                          .green,
                                      fontWeight:
                                          FontWeight
                                              .bold,
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