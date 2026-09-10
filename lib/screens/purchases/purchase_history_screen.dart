import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/purchase/purchase_history.dart';
import '../../services/purchase_repository.dart';
import 'purchase_details_screen.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() =>
      _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState
    extends State<PurchaseHistoryScreen> {
  final PurchaseRepository _purchaseRepository =
      PurchaseRepository();

  List<PurchaseHistory> _purchases = [];

  bool _isLoading = true;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    final purchases =
        await _purchaseRepository.getPurchases();

    if (!mounted) return;

    setState(() {
      _purchases = purchases;
      _isLoading = false;
    });
  }

  String _formatDate(String date) {
    return DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.parse(date));
  }

  double get totalPurchase => _purchases.fold(
        0,
        (sum, item) =>
            sum + item.purchase.grandTotal,
      );

  double get totalPaid => _purchases.fold(
        0,
        (sum, item) =>
            sum + item.purchase.paid,
      );

  double get totalDue => _purchases.fold(
        0,
        (sum, item) =>
            sum + item.purchase.due,
      );

  int get totalTransactions =>
      _purchases.length;

  List<PurchaseHistory> get _filteredPurchases {
    if (_search.trim().isEmpty) {
      return _purchases;
    }

    final query = _search.trim().toLowerCase();

    return _purchases.where((item) {
      return item.supplierName
              .toLowerCase()
              .contains(query) ||
          item.purchase.id
              .toString()
              .contains(_search.trim());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Purchase History"),
      ),
      body: _isLoading
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
                          12,
                          horizontalPadding,
                          8,
                        ),
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText:
                                  "Search supplier or ID...",
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
                      // KPI - 2 x 2
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
                              "Purchase",
                              "৳${totalPurchase.toStringAsFixed(0)}",
                              Icons.shopping_cart,
                              Colors.blue,
                            ),
                            _kpiCard(
                              "Paid",
                              "৳${totalPaid.toStringAsFixed(0)}",
                              Icons.check_circle,
                              Colors.green,
                            ),
                            _kpiCard(
                              "Due",
                              "৳${totalDue.toStringAsFixed(0)}",
                              Icons.warning,
                              Colors.red,
                            ),
                            _kpiCard(
                              "Bills",
                              totalTransactions.toString(),
                              Icons.receipt_long,
                              Colors.deepPurple,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ==================================================
                      // TITLE
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
                              Icons.shopping_cart,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "Purchase Records",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_filteredPurchases.isNotEmpty)
                              Text(
                                "${_filteredPurchases.length}",
                                style: TextStyle(
                                  color:
                                      Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // ==================================================
                      // LIST AREA ONLY SCROLLS
                      // ==================================================
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadPurchases,
                          child: _filteredPurchases.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 160),
                                    Center(
                                      child: Text(
                                        "No Purchase Found",
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.fromLTRB(
                                    horizontalPadding,
                                    0,
                                    horizontalPadding,
                                    12,
                                  ),
                                  itemCount:
                                      _filteredPurchases.length,
                                  separatorBuilder:
                                      (_, __) =>
                                          const SizedBox(
                                    height: 2,
                                  ),
                                  itemBuilder:
                                      (context, index) {
                                    final history =
                                        _filteredPurchases[
                                            index];

                                    final purchase =
                                        history.purchase;

                                    return _purchaseCard(
                                      context,
                                      history,
                                      purchase,
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _purchaseCard(
    BuildContext context,
    PurchaseHistory history,
    dynamic purchase,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 4,
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
              builder: (_) =>
                  PurchaseDetailsScreen(
                purchaseId: purchase.id!,
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
                        Colors.orange.withOpacity(.15),
                    child: Text(
                      purchase.id.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
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
                          history.supplierName,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(
                            purchase.purchaseDate,
                          ),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                Colors.grey.shade600,
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
                      "৳${purchase.grandTotal.toStringAsFixed(0)}",
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _amountColumn(
                      "Paid",
                      "৳${purchase.paid.toStringAsFixed(0)}",
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _amountColumn(
                      "Due",
                      "৳${purchase.due.toStringAsFixed(0)}",
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
    Color color,
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
  ) {
    return Card(
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
    );
  }
}