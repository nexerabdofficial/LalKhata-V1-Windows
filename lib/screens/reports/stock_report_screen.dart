import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_repository.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() =>
      _StockReportScreenState();
}

class _StockReportScreenState
    extends State<StockReportScreen> {
  final ProductRepository _repository =
      ProductRepository();

  List<Product> _products = [];

  bool _loading = true;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products =
        await _repository.getProducts();

    if (!mounted) return;

    setState(() {
      _products = products;
      _loading = false;
    });
  }

  List<Product> get filteredProducts {
    if (_search.trim().isEmpty) {
      return _products;
    }

    final query = _search.trim().toLowerCase();

    return _products.where((e) {
      return e.name.toLowerCase().contains(query);
    }).toList();
  }

  int get totalProducts => _products.length;

  int get inStock =>
      _products.where((e) => e.stock > 10).length;

  int get lowStock =>
      _products
          .where(
            (e) => e.stock > 0 && e.stock <= 10,
          )
          .length;

  int get outStock =>
      _products.where((e) => e.stock <= 0).length;

  double get totalStockValue {
    double total = 0;

    for (final p in _products) {
      total += p.stockValue;
    }

    return total;
  }

  // ============================================================
  // WEIGHTED AVERAGE COST
  // ============================================================

  double averageCost(Product product) {
    if (product.stock <= 0) {
      return 0;
    }

    return product.stockValue / product.stock;
  }

  Color stockColor(int stock) {
    if (stock <= 0) return Colors.red;
    if (stock <= 10) return Colors.orange;
    return Colors.green;
  }

  String stockText(int stock) {
    if (stock <= 0) return "OUT";
    if (stock <= 10) return "LOW";
    return "OK";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Report"),
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
                          12,
                          horizontalPadding,
                          8,
                        ),
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText:
                                  "Search product...",
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
                      // SUMMARY CARDS - 2 x 2
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
                            _summaryCard(
                              "Products",
                              totalProducts.toString(),
                              Colors.blue,
                            ),
                            _summaryCard(
                              "In Stock",
                              inStock.toString(),
                              Colors.green,
                            ),
                            _summaryCard(
                              "Low Stock",
                              lowStock.toString(),
                              Colors.orange,
                            ),
                            _summaryCard(
                              "Out Stock",
                              outStock.toString(),
                              Colors.red,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ==================================================
                      // TOTAL STOCK VALUE
                      // ==================================================
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: SizedBox(
                          height: 54,
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor:
                                        Colors.blue
                                            .withOpacity(.10),
                                    child: const Icon(
                                      Icons
                                          .account_balance_wallet,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      "Total Stock Value",
                                      style: TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "৳${totalStockValue.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ==================================================
                      // PRODUCT LIST
                      // ==================================================
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.inventory_2,
                              size: 20,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "Stock Records",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                            if (filteredProducts.isNotEmpty)
                              Text(
                                "${filteredProducts.length}",
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
                      // ONLY LIST AREA SCROLLS
                      // ==================================================
                      Expanded(
                        child: filteredProducts.isEmpty
                            ? const Center(
                                child: Text(
                                  "No Product Found",
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  0,
                                  horizontalPadding,
                                  12,
                                ),
                                itemCount:
                                    filteredProducts.length,
                                itemBuilder:
                                    (context, index) {
                                  final p =
                                      filteredProducts[
                                          index];

                                  return _productCard(p);
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

  Widget _productCard(Product p) {
    final color = stockColor(p.stock);
    final avgCost = averageCost(p);

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            // ==================================================
            // ICON
            // ==================================================
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  color.withOpacity(.12),
              child: Icon(
                Icons.inventory_2,
                color: color,
                size: 20,
              ),
            ),

            const SizedBox(width: 10),

            // ==================================================
            // PRODUCT DETAILS
            // ==================================================
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    "Average Cost : ৳${avgCost.toStringAsFixed(2)}",
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),

                  Text(
                    "Sell : ৳${p.sellingPrice.toStringAsFixed(2)}",
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),

                  Text(
                    "Value : ৳${p.stockValue.toStringAsFixed(2)}",
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),

                  const Text(
                    "Stock Value = Stock × Average Cost",
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ==================================================
            // STOCK STATUS
            // ==================================================
            Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  "${p.stock}",
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),

                const SizedBox(height: 5),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        color.withOpacity(.12),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    stockText(p.stock),
                    style: TextStyle(
                      color: color,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(
    String title,
    String value,
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
                Icons.inventory_2,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                      color: color,
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