import 'package:flutter/material.dart';

import '../../models/income.dart';
import '../../models/expense.dart';
import '../../services/income_repository.dart';
import '../../services/expense_repository.dart';

class IncomeExpenseReportScreen extends StatefulWidget {
  const IncomeExpenseReportScreen({
    super.key,
  });

  @override
  State<IncomeExpenseReportScreen> createState() =>
      _IncomeExpenseReportScreenState();
}

class _IncomeExpenseReportScreenState
    extends State<IncomeExpenseReportScreen> {
  final IncomeRepository _incomeRepository =
      IncomeRepository();

  final ExpenseRepository _expenseRepository =
      ExpenseRepository();

  DateTime _startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  String _type = 'All';

  bool _loading = true;

  List<Map<String, dynamic>> _incomeCategories = [];
  List<Map<String, dynamic>> _expenseCategories = [];

  double _totalIncome = 0;
  double _totalExpense = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
    });

    final startDate = _formatDate(_startDate);
    final endDate = _formatDate(_endDate);

    List<Map<String, dynamic>> incomeCategories = [];
    List<Map<String, dynamic>> expenseCategories = [];

    double totalIncome = 0;
    double totalExpense = 0;

    if (_type == 'All' || _type == 'Income') {
      incomeCategories =
          await _incomeRepository.getIncomeCategorySummary(
        startDate: startDate,
        endDate: endDate,
      );

      for (final item in incomeCategories) {
        totalIncome +=
            (item['total'] as num?)?.toDouble() ?? 0;
      }
    }

    if (_type == 'All' || _type == 'Expense') {
      expenseCategories =
          await _expenseRepository.getExpenseCategorySummary(
        startDate: startDate,
        endDate: endDate,
      );

      for (final item in expenseCategories) {
        totalExpense +=
            (item['total'] as num?)?.toDouble() ?? 0;
      }
    }

    if (!mounted) return;

    setState(() {
      _incomeCategories = incomeCategories;
      _expenseCategories = expenseCategories;

      _totalIncome = totalIncome;
      _totalExpense = totalExpense;

      _loading = false;
    });
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // DISPLAY DATE
  // ============================================================

  String _displayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  // ============================================================
  // START DATE
  // ============================================================

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) return;

    setState(() {
      _startDate = selected;

      if (_startDate.isAfter(_endDate)) {
        _endDate = selected;
      }
    });

    await _loadReport();
  }

  // ============================================================
  // END DATE
  // ============================================================

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (selected == null) return;

    setState(() {
      _endDate = selected;
    });

    await _loadReport();
  }

  // ============================================================
  // TYPE FILTER
  // ============================================================

  Future<void> _changeType(String value) async {
    if (_type == value) return;

    setState(() {
      _type = value;
    });

    await _loadReport();
  }

  // ============================================================
  // CATEGORY DETAIL
  // ============================================================

  Future<void> _openIncomeCategory(
    String category,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            IncomeCategoryDetailScreen(
          category: category,
          startDate: _formatDate(_startDate),
          endDate: _formatDate(_endDate),
        ),
      ),
    );
  }

  Future<void> _openExpenseCategory(
    String category,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ExpenseCategoryDetailScreen(
          category: category,
          startDate: _formatDate(_startDate),
          endDate: _formatDate(_endDate),
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '৳${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY CARD
  // ============================================================

  Widget _categoryCard({
    required String category,
    required double amount,
    required bool isIncome,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            isIncome
                ? Icons.arrow_downward
                : Icons.arrow_upward,
          ),
        ),
        title: Text(
          category,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: const Text(
          'Tap to view transactions',
        ),
        trailing: Text(
          '৳${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isIncome
                ? Colors.green
                : Colors.red,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final net =
        _totalIncome - _totalExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Income & Expense Report',
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // ==================================================
                  // DATE FILTER
                  // ==================================================

                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap:
                                  _selectStartDate,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  const Text(
                                    'From',
                                    style: TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    _displayDate(
                                      _startDate,
                                    ),
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward,
                          ),
                          Expanded(
                            child: InkWell(
                              onTap:
                                  _selectEndDate,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .end,
                                children: [
                                  const Text(
                                    'To',
                                    style: TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    _displayDate(
                                      _endDate,
                                    ),
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ==================================================
                  // TYPE FILTER
                  // ==================================================

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'All',
                        label: Text('All'),
                        icon: Icon(
                          Icons.dashboard,
                        ),
                      ),
                      ButtonSegment<String>(
                        value: 'Income',
                        label: Text('Income'),
                        icon: Icon(
                          Icons.arrow_downward,
                        ),
                      ),
                      ButtonSegment<String>(
                        value: 'Expense',
                        label: Text('Expense'),
                        icon: Icon(
                          Icons.arrow_upward,
                        ),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged:
                        (selection) {
                      _changeType(
                        selection.first,
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // SUMMARY
                  // ==================================================

                  Row(
                    children: [
                      if (_type == 'All' ||
                          _type == 'Income')
                        _summaryCard(
                          title: 'Income',
                          amount: _totalIncome,
                          icon: Icons
                              .trending_down,
                        ),
                      if (_type == 'All' ||
                          _type == 'Expense') ...[
                        if (_type == 'All')
                          const SizedBox(width: 8),
                        _summaryCard(
                          title: 'Expense',
                          amount: _totalExpense,
                          icon: Icons
                              .trending_up,
                        ),
                      ],
                    ],
                  ),

                  if (_type == 'All') ...[
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.account_balance,
                        ),
                        title: const Text(
                          'Net Income',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          '৳${net.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                            color: net >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ==================================================
                  // INCOME CATEGORIES
                  // ==================================================

                  if (_type == 'All' ||
                      _type == 'Income') ...[
                    const Text(
                      'Income by Category',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_incomeCategories.isEmpty)
                      const Card(
                        child: Padding(
                          padding:
                              EdgeInsets.all(16),
                          child: Text(
                            'No income found for this period.',
                          ),
                        ),
                      )
                    else
                      ..._incomeCategories.map(
                        (item) {
                          final category =
                              item['category']
                                  .toString();

                          final amount =
                              (item['total']
                                          as num?)
                                      ?.toDouble() ??
                                  0;

                          return _categoryCard(
                            category: category,
                            amount: amount,
                            isIncome: true,
                            onTap: () =>
                                _openIncomeCategory(
                              category,
                            ),
                          );
                        },
                      ),
                  ],

                  // ==================================================
                  // EXPENSE CATEGORIES
                  // ==================================================

                  if (_type == 'All' ||
                      _type == 'Expense') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Expense by Category',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_expenseCategories.isEmpty)
                      const Card(
                        child: Padding(
                          padding:
                              EdgeInsets.all(16),
                          child: Text(
                            'No expense found for this period.',
                          ),
                        ),
                      )
                    else
                      ..._expenseCategories.map(
                        (item) {
                          final category =
                              item['category']
                                  .toString();

                          final amount =
                              (item['total']
                                          as num?)
                                      ?.toDouble() ??
                                  0;

                          return _categoryCard(
                            category: category,
                            amount: amount,
                            isIncome: false,
                            onTap: () =>
                                _openExpenseCategory(
                              category,
                            ),
                          );
                        },
                      ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ==================================================================
// INCOME CATEGORY DETAIL
// ==================================================================

class IncomeCategoryDetailScreen
    extends StatefulWidget {
  final String category;
  final String startDate;
  final String endDate;

  const IncomeCategoryDetailScreen({
    super.key,
    required this.category,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<IncomeCategoryDetailScreen>
      createState() =>
          _IncomeCategoryDetailScreenState();
}

class _IncomeCategoryDetailScreenState
    extends State<IncomeCategoryDetailScreen> {
  final IncomeRepository _repository =
      IncomeRepository();

  bool _loading = true;

  List<Income> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data =
        await _repository.getIncomeByCategory(
      category: widget.category,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );

    if (!mounted) return;

    setState(() {
      _items = data;
      _loading = false;
    });
  }

  String _date(String value) {
    return value.split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: ListTile(
                    title: const Text(
                      'Category Total',
                    ),
                    subtitle: Text(
                      '${widget.startDate} → ${widget.endDate}',
                    ),
                    trailing: Text(
                      '৳${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No transactions found.',
                      ),
                    ),
                  )
                else
                  ..._items.map(
                    (income) {
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(
                              Icons.payments,
                            ),
                          ),
                          title: Text(
                            '৳${income.amount.toStringAsFixed(2)}',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                _date(
                                  income.incomeDate,
                                ),
                              ),
                              if ((income.note ?? '')
                                  .isNotEmpty)
                                Text(
                                  income.note!,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

// ==================================================================
// EXPENSE CATEGORY DETAIL
// ==================================================================

class ExpenseCategoryDetailScreen
    extends StatefulWidget {
  final String category;
  final String startDate;
  final String endDate;

  const ExpenseCategoryDetailScreen({
    super.key,
    required this.category,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<ExpenseCategoryDetailScreen>
      createState() =>
          _ExpenseCategoryDetailScreenState();
}

class _ExpenseCategoryDetailScreenState
    extends State<ExpenseCategoryDetailScreen> {
  final ExpenseRepository _repository =
      ExpenseRepository();

  bool _loading = true;

  List<Expense> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data =
        await _repository.getExpenseByCategory(
      category: widget.category,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );

    if (!mounted) return;

    setState(() {
      _items = data;
      _loading = false;
    });
  }

  String _date(String value) {
    return value.split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: ListTile(
                    title: const Text(
                      'Category Total',
                    ),
                    subtitle: Text(
                      '${widget.startDate} → ${widget.endDate}',
                    ),
                    trailing: Text(
                      '৳${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No transactions found.',
                      ),
                    ),
                  )
                else
                  ..._items.map(
                    (expense) {
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(
                              Icons.money_off,
                            ),
                          ),
                          title: Text(
                            '৳${expense.amount.toStringAsFixed(2)}',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                _date(
                                  expense.expenseDate,
                                ),
                              ),
                              if ((expense.note ?? '')
                                  .isNotEmpty)
                                Text(
                                  expense.note!,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}