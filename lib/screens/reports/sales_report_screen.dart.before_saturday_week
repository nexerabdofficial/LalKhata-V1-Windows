import 'package:flutter/material.dart';

import '../../services/sale_repository.dart';

enum ReportFilter {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  custom,
}

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() =>
      _SalesReportScreenState();
}

class _SalesReportScreenState
    extends State<SalesReportScreen> {

  final SaleRepository _repository =
      SaleRepository();

  List<Map<String, dynamic>> _sales = [];

  bool _loading = true;
  ReportFilter _filter = ReportFilter.today;

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
  final now = DateTime.now();

  DateTime from;
  DateTime to;

  switch (_filter) {
    case ReportFilter.today:
      from = DateTime(now.year, now.month, now.day);
      to = from;
      break;

    case ReportFilter.yesterday:
      final d = now.subtract(const Duration(days: 1));
      from = DateTime(d.year, d.month, d.day);
      to = from;
      break;

    case ReportFilter.thisWeek:
      from = now.subtract(
        Duration(days: now.weekday - 1),
      );
      from = DateTime(
        from.year,
        from.month,
        from.day,
      );

      to = DateTime(
        now.year,
        now.month,
        now.day,
      );
      break;

    case ReportFilter.thisMonth:
      from = DateTime(now.year, now.month, 1);
      to = DateTime(
        now.year,
        now.month,
        now.day,
      );
      break;

    case ReportFilter.custom:
      if (_fromDate == null || _toDate == null) {
        return;
      }

      from = _fromDate!;
      to = _toDate!;
      break;
  }

  final sales =
      await _repository.getSalesByDateRange(
    fromDate:
        from.toIso8601String().split('T').first,
    toDate:
        to.toIso8601String().split('T').first,
  );

  if (!mounted) return;

  setState(() {
    _sales = sales;
    _loading = false;
  });
}
Future<void> _changeFilter(
  ReportFilter filter,
) async {
  _filter = filter;
  _loading = true;

  await _loadReport();
}

  double get totalSales {
    double total = 0;

    for (final sale in _sales) {
      total +=
          (sale['grand_total'] as num).toDouble();
    }

    return total;
  }
double get totalPaid {
  double total = 0;

  for (final sale in _sales) {
    total += (sale['paid'] as num).toDouble();
  }

  return total;
}

double get totalDue {
  double total = 0;

  for (final sale in _sales) {
    total += (sale['due'] as num).toDouble();
  }

  return total;
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Report"),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Padding(
  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        ChoiceChip(
          label: const Text("Today"),
          selected: _filter == ReportFilter.today,
          onSelected: (_) =>
              _changeFilter(ReportFilter.today),
        ),
        const SizedBox(width: 8),

        ChoiceChip(
          label: const Text("Yesterday"),
          selected: _filter == ReportFilter.yesterday,
          onSelected: (_) =>
              _changeFilter(ReportFilter.yesterday),
        ),
        const SizedBox(width: 8),

        ChoiceChip(
          label: const Text("This Week"),
          selected: _filter == ReportFilter.thisWeek,
          onSelected: (_) =>
              _changeFilter(ReportFilter.thisWeek),
        ),
        const SizedBox(width: 8),

        ChoiceChip(
          label: const Text("This Month"),
          selected: _filter == ReportFilter.thisMonth,
          onSelected: (_) =>
              _changeFilter(ReportFilter.thisMonth),
        ),
      ],
    ),
  ),
),

const SizedBox(height: 8),

                Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: const Text(
                      "Total Sales",
                    ),
                    trailing: Text(
                      "৳${totalSales.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                Card(
  margin: const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 5,
  ),
  child: ListTile(
    title: const Text("Total Paid"),
    trailing: Text(
      "৳${totalPaid.toStringAsFixed(2)}",
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),

Card(
  margin: const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 5,
  ),
  child: ListTile(
    title: const Text("Total Due"),
    trailing: Text(
      "৳${totalDue.toStringAsFixed(2)}",
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
    ),
  ),
),

Card(
  margin: const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 5,
  ),
  child: ListTile(
    title: const Text("Total Transactions"),
    trailing: Text(
      _sales.length.toString(),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),

                Expanded(
                  child: ListView.builder(
                    itemCount: _sales.length,
                    itemBuilder: (context, index) {

                      final sale = _sales[index];

                      return ListTile(
                        title: Text(
                          sale['customer_name'] ??
                              "Walk-in Customer",
                        ),
                        subtitle: Text(
                          sale['sale_date'],
                        ),
                        trailing: Text(
                          "৳${sale['grand_total']}",
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}