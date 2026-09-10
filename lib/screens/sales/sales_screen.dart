import 'package:flutter/material.dart';

import '../../services/sale_repository.dart';
import 'sale_details_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    final sales = await _repository.getSales();

    if (!mounted) return;

    setState(() {
      _sales = sales;
      _loading = false;
    });
  }

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

  List<Map<String, dynamic>> get filteredSales {
    if (_search.trim().isEmpty) {
      return _sales;
    }

    final query = _search.trim().toLowerCase();

    return _sales.where((sale) {
      final customer =
          (sale['customer_name'] ?? "").toString().toLowerCase();

      final invoice =
          (sale['invoice_no'] ?? "").toString().toLowerCase();

      return customer.contains(query) || invoice.contains(query);
    }).toList();
  }

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

                  final cardHeight =
                      width >= 700 ? 78.0 : 72.0;

                  return Column(
                    children: [
                      // ==================================================
                      // SEARCH
                      // ==================================================
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          12,
                          horizontalPadding,
                          8,
                        ),
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText:
                                  "Search customer or invoice...",
                              prefixIcon:
                                  const Icon(Icons.search),
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
                      // KPI CARDS - 2 x 2
                      // ==================================================
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio:
                              width >= 700 ? 4.2 : 2.65,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          children: [
                            _kpiCard(
                              "Sales",
                              "৳${totalSales.toStringAsFixed(0)}",
                              Icons.payments,
                              Colors.green,
                              cardHeight,
                            ),
                            _kpiCard(
                              "Paid",
                              "৳${totalPaid.toStringAsFixed(0)}",
                              Icons.check_circle,
                              Colors.blue,
                              cardHeight,
                            ),
                            _kpiCard(
                              "Due",
                              "৳${totalDue.toStringAsFixed(0)}",
                              Icons.warning,
                              Colors.red,
                              cardHeight,
                            ),
                            _kpiCard(
                              "Bills",
                              totalTransactions.toString(),
                              Icons.receipt_long,
                              Colors.deepPurple,
                              cardHeight,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ==================================================
                      // SECTION TITLE
                      // ==================================================
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          4,
                          horizontalPadding,
                          6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 20,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "Sales Records",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (filteredSales.isNotEmpty)
                              Text(
                                "${filteredSales.length}",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // ==================================================
                      // RECORDS - ONLY THIS AREA SCROLLS
                      // ==================================================
                      Expanded(
                        child: filteredSales.isEmpty
                            ? const Center(
                                child: Text("No Sales Found"),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  0,
                                  horizontalPadding,
                                  12,
                                ),
                                itemCount: filteredSales.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 2),
                                itemBuilder: (context, index) {
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

  Widget _saleCard(
    BuildContext context,
    Map<String, dynamic> sale,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        Colors.blue.shade100,
                    child: Text(
                      "${sale['id']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Invoice : ${sale['invoice_no']}",
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _amountColumn(
                      "Total",
                      "৳${sale['grand_total']}",
                      null,
                    ),
                  ),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double height,
  ) {
    return SizedBox(
      height: height,
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    color.withOpacity(.12),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
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
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
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