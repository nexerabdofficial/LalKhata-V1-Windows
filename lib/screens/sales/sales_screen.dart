import 'package:flutter/material.dart';

import '../../services/sale_repository.dart';
import 'sale_details_screen.dart';

enum SalesDateFilter {
  all,
  today,
  yesterday,
  thisWeek,
  thisMonth,
  custom,
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SaleRepository _repository = SaleRepository();

  List<Map<String, dynamic>> _sales = [];

  bool _loading = true;
  String _search = "";

  SalesDateFilter _dateFilter = SalesDateFilter.all;

  DateTime? _customFromDate;
  DateTime? _customToDate;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  // ============================================================
  // LOAD SALES
  // ============================================================

  Future<void> _loadSales() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      List<Map<String, dynamic>> sales;

      switch (_dateFilter) {
        case SalesDateFilter.all:
          sales = await _repository.getSales();
          break;

        case SalesDateFilter.today:
          final today = DateTime.now();

          sales = await _repository.getSalesByDateRange(
            fromDate: _formatDate(today),
            toDate: _formatDate(today),
          );
          break;

        case SalesDateFilter.yesterday:
          final yesterday =
              DateTime.now().subtract(const Duration(days: 1));

          sales = await _repository.getSalesByDateRange(
            fromDate: _formatDate(yesterday),
            toDate: _formatDate(yesterday),
          );
          break;

        case SalesDateFilter.thisWeek:
          final now = DateTime.now();

          // Monday = start of week
          final from =
              now.subtract(Duration(days: now.weekday - 1));

          sales = await _repository.getSalesByDateRange(
            fromDate: _formatDate(from),
            toDate: _formatDate(now),
          );
          break;

        case SalesDateFilter.thisMonth:
          final now = DateTime.now();

          final from = DateTime(
            now.year,
            now.month,
            1,
          );

          sales = await _repository.getSalesByDateRange(
            fromDate: _formatDate(from),
            toDate: _formatDate(now),
          );
          break;

        case SalesDateFilter.custom:
          if (_customFromDate == null ||
              _customToDate == null) {
            sales = await _repository.getSales();
          } else {
            sales = await _repository.getSalesByDateRange(
              fromDate: _formatDate(_customFromDate!),
              toDate: _formatDate(_customToDate!),
            );
          }
          break;
      }

      if (!mounted) return;

      setState(() {
        _sales = sales;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to load sales: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  // ============================================================
  // DATE FILTER LABEL
  // ============================================================

  String get _dateFilterLabel {
    switch (_dateFilter) {
      case SalesDateFilter.all:
        return "All";

      case SalesDateFilter.today:
        return "Today";

      case SalesDateFilter.yesterday:
        return "Yesterday";

      case SalesDateFilter.thisWeek:
        return "This Week";

      case SalesDateFilter.thisMonth:
        return "This Month";

      case SalesDateFilter.custom:
        if (_customFromDate == null ||
            _customToDate == null) {
          return "Custom";
        }

        return "${_displayDate(_customFromDate!)} - "
            "${_displayDate(_customToDate!)}";
    }
  }

  String _displayDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  // ============================================================
  // CHANGE DATE FILTER
  // ============================================================

  Future<void> _changeDateFilter(
    SalesDateFilter filter,
  ) async {
    if (filter == SalesDateFilter.custom) {
      await _selectCustomDateRange();
      return;
    }

    setState(() {
      _dateFilter = filter;
    });

    await _loadSales();
  }

  // ============================================================
  // CUSTOM DATE RANGE
  // ============================================================

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();

    final initialStart =
        _customFromDate ?? now;

    final initialEnd =
        _customToDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialDateRange: DateTimeRange(
        start: initialStart.isBefore(initialEnd)
            ? initialStart
            : initialEnd,
        end: initialEnd.isAfter(initialStart)
            ? initialEnd
            : initialStart,
      ),
      helpText: "Select Sales Date Range",
      saveText: "APPLY",
      cancelText: "CANCEL",
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _customFromDate = picked.start;
      _customToDate = picked.end;
      _dateFilter = SalesDateFilter.custom;
    });

    await _loadSales();
  }

  // ============================================================
  // KPI
  // ============================================================

  double get totalSales {
    return _sales.fold(
      0,
      (sum, sale) =>
          sum + (sale['grand_total'] as num).toDouble(),
    );
  }

  double get totalPaid {
    return _sales.fold(
      0,
      (sum, sale) =>
          sum + (sale['paid'] as num).toDouble(),
    );
  }

  double get totalDue {
    return _sales.fold(
      0,
      (sum, sale) =>
          sum + (sale['due'] as num).toDouble(),
    );
  }

  int get totalTransactions => _sales.length;

  // ============================================================
  // SEARCH
  // ============================================================

  List<Map<String, dynamic>> get filteredSales {
    if (_search.trim().isEmpty) {
      return _sales;
    }

    final query = _search.trim().toLowerCase();

    return _sales.where((sale) {
      final customer =
          (sale['customer_name'] ?? "")
              .toString()
              .toLowerCase();

      final invoice =
          (sale['invoice_no'] ?? "")
              .toString()
              .toLowerCase();

      return customer.contains(query) ||
          invoice.contains(query);
    }).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales History"),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;

                  final horizontalPadding =
                      width >= 900 ? 24.0 : 12.0;

                  return Column(
                    children: [
                      // ==================================================
                      // SEARCH
                      // ==================================================

                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          10,
                          horizontalPadding,
                          6,
                        ),
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText:
                                  "Search customer or invoice...",
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 21,
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _search = value;
                              });
                            },
                          ),
                        ),
                      ),

                      // ==================================================
                      // DATE FILTER
                      // ==================================================

                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          2,
                          horizontalPadding,
                          6,
                        ),
                        child: SizedBox(
                          height: 36,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                size: 19,
                              ),
                              const SizedBox(width: 7),

                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection:
                                      Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _dateChip(
                                        "All",
                                        SalesDateFilter.all,
                                      ),
                                      _dateChip(
                                        "Today",
                                        SalesDateFilter.today,
                                      ),
                                      _dateChip(
                                        "Yesterday",
                                        SalesDateFilter.yesterday,
                                      ),
                                      _dateChip(
                                        "This Week",
                                        SalesDateFilter.thisWeek,
                                      ),
                                      _dateChip(
                                        "This Month",
                                        SalesDateFilter.thisMonth,
                                      ),
                                      _dateChip(
                                        "Custom",
                                        SalesDateFilter.custom,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ==================================================
                      // KPI CARDS
                      // ==================================================

                      Padding(
  padding: EdgeInsets.symmetric(
    horizontal: horizontalPadding,
  ),
  child: LayoutBuilder(
    builder: (context, cardConstraints) {
      final isPhone = cardConstraints.maxWidth < 600;

      if (isPhone) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    "Sales",
                    "৳${totalSales.toStringAsFixed(0)}",
                    Icons.payments,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _kpiCard(
                    "Paid",
                    "৳${totalPaid.toStringAsFixed(0)}",
                    Icons.check_circle,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    "Due",
                    "৳${totalDue.toStringAsFixed(0)}",
                    Icons.warning,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _kpiCard(
                    "Bills",
                    totalTransactions.toString(),
                    Icons.receipt_long,
                    Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ],
        );
      }

      return Row(
        children: [
          Expanded(
            child: _kpiCard(
              "Sales",
              "৳${totalSales.toStringAsFixed(0)}",
              Icons.payments,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpiCard(
              "Paid",
              "৳${totalPaid.toStringAsFixed(0)}",
              Icons.check_circle,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpiCard(
              "Due",
              "৳${totalDue.toStringAsFixed(0)}",
              Icons.warning,
              Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpiCard(
              "Bills",
              totalTransactions.toString(),
              Icons.receipt_long,
              Colors.deepPurple,
            ),
          ),
        ],
      );
    },
  ),
),

                      const SizedBox(height: 7),

                      // ==================================================
                      // RECORD HEADER
                      // ==================================================

                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          2,
                          horizontalPadding,
                          5,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 20,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),

                            Expanded(
                              child: Text(
                                "Sales Records",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Current date filter
                            Text(
                              _dateFilterLabel,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),

                            const SizedBox(width: 8),

                            if (filteredSales.isNotEmpty)
                              Text(
                                "${filteredSales.length}",
                                style: TextStyle(
                                  color:
                                      Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // ==================================================
                      // SALES LIST
                      // ==================================================

                      Expanded(
                        child: filteredSales.isEmpty
                            ? const Center(
                                child: Text(
                                  "No Sales Found",
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  0,
                                  horizontalPadding,
                                  12,
                                ),
                                itemCount:
                                    filteredSales.length,
                                separatorBuilder:
                                    (_, __) =>
                                        const SizedBox(
                                  height: 2,
                                ),
                                itemBuilder:
                                    (context, index) {
                                  final sale =
                                      filteredSales[index];

                                  return _saleCard(
                                    context,
                                    sale,
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  // ============================================================
  // DATE CHIP
  // ============================================================

  Widget _dateChip(
    String label,
    SalesDateFilter filter,
  ) {
    final selected = _dateFilter == filter;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected
                ? FontWeight.bold
                : FontWeight.w500,
          ),
        ),
        selected: selected,
        onSelected: (_) {
          _changeDateFilter(filter);
        },
        visualDensity: const VisualDensity(
          horizontal: -2,
          vertical: -2,
        ),
        materialTapTargetSize:
            MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 0,
        ),
      ),
    );
  }

  // ============================================================
  // SALE CARD
  // ============================================================

  Widget _saleCard(
    BuildContext context,
    Map<String, dynamic> sale,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 3,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SaleDetailsScreen(
                saleId: sale['id'],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 9,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius:
                          BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "${sale['id']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale['customer_name'] ??
                              "Unknown Customer",
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          "Invoice : ${sale['invoice_no']}",
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    "৳${sale['grand_total']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 7),

              Row(
                children: [
                  Expanded(
                    child: _amountColumn(
                      "Paid",
                      "৳${sale['paid']}",
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _amountColumn(
                      "Due",
                      "৳${sale['due']}",
                      Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _amountColumn(
                      "Total",
                      "৳${sale['grand_total']}",
                      null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AMOUNT COLUMN
  // ============================================================

  Widget _amountColumn(
    String title,
    String value,
    Color? color,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // KPI CARD
  // ============================================================

  Widget _kpiCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      height: 60,
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 6,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor:
                    color.withOpacity(.12),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      title,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}