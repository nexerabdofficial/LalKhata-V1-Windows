import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_repository.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  final ProductRepository _repository = ProductRepository();

  List<Product> _products = [];

  bool _loading = true;
  String _search = "";

  // ============================================================
  // STOCK TYPE
  // ============================================================

  StockType _selectedType = StockType.product;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _repository.getProducts();

    if (!mounted) return;

    setState(() {
      _products = products;
      _loading = false;
    });
  }

  // ============================================================
  // PRODUCT TYPE HELPERS
  // ============================================================

  bool _isMaterial(Product product) {
    return product.productType == 'RAW_MATERIAL';
  }

  bool _isFinishedProduct(Product product) {
    return product.productType == 'FINISHED_PRODUCT' ||
        product.productType == 'BOTH';
  }

  List<Product> get materialProducts {
    return _products.where(_isMaterial).toList();
  }

  List<Product> get finishedProducts {
    return _products.where(_isFinishedProduct).toList();
  }

  List<Product> get selectedProducts {
    final source = _selectedType == StockType.material
        ? materialProducts
        : finishedProducts;

    if (_search.trim().isEmpty) {
      return source;
    }

    final query = _search.trim().toLowerCase();

    return source.where((product) {
      return product.name.toLowerCase().contains(query);
    }).toList();
  }

  // ============================================================
  // SUMMARY HELPERS
  // ============================================================

  int get materialCount => materialProducts.length;

  int get finishedProductCount => finishedProducts.length;

  double get materialStockValue {
    double total = 0;

    for (final product in materialProducts) {
      total += product.stockValue;
    }

    return total;
  }

  double get finishedProductStockValue {
    double total = 0;

    for (final product in finishedProducts) {
      total += product.stockValue;
    }

    return total;
  }

  int get selectedTotalProducts => selectedProducts.length;

  int get selectedInStock =>
      selectedProducts.where((e) => e.stock > 10).length;

  int get selectedLowStock =>
      selectedProducts
          .where(
            (e) => e.stock > 0 && e.stock <= 10,
          )
          .length;

  int get selectedOutStock =>
      selectedProducts.where((e) => e.stock <= 0).length;

  double get selectedStockValue {
    double total = 0;

    for (final product in selectedProducts) {
      total += product.stockValue;
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

  // ============================================================
  // STOCK STATUS
  // ============================================================

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

  // ============================================================
  // SELECT STOCK TYPE
  // ============================================================

  void _selectType(StockType type) {
    setState(() {
      _selectedType = type;
      _search = "";
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

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
                      // MATERIAL / PRODUCT SELECTOR
                      // ==================================================
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          6,
                        ),
                        child: LayoutBuilder(
                          builder: (context, selectorConstraints) {
                            final isPhone =
                                selectorConstraints.maxWidth < 600;

                            if (isPhone) {
                              return Column(
                                children: [
                                  _stockTypeCard(
                                    title: "Material Stock",
                                    subtitle:
                                        "Raw materials & components",
                                    count: materialCount,
                                    value: materialStockValue,
                                    icon: Icons.construction,
                                    color: Colors.orange,
                                    selected:
                                        _selectedType ==
                                            StockType.material,
                                    onTap: () {
                                      _selectType(
                                        StockType.material,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _stockTypeCard(
                                    title: "Product Stock",
                                    subtitle:
                                        "Finished products",
                                    count:
                                        finishedProductCount,
                                    value:
                                        finishedProductStockValue,
                                    icon: Icons.inventory_2,
                                    color: Colors.blue,
                                    selected:
                                        _selectedType ==
                                            StockType.product,
                                    onTap: () {
                                      _selectType(
                                        StockType.product,
                                      );
                                    },
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: _stockTypeCard(
                                    title: "Material Stock",
                                    subtitle:
                                        "Raw materials & components",
                                    count: materialCount,
                                    value: materialStockValue,
                                    icon: Icons.construction,
                                    color: Colors.orange,
                                    selected:
                                        _selectedType ==
                                            StockType.material,
                                    onTap: () {
                                      _selectType(
                                        StockType.material,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _stockTypeCard(
                                    title: "Product Stock",
                                    subtitle:
                                        "Finished products",
                                    count:
                                        finishedProductCount,
                                    value:
                                        finishedProductStockValue,
                                    icon: Icons.inventory_2,
                                    color: Colors.blue,
                                    selected:
                                        _selectedType ==
                                            StockType.product,
                                    onTap: () {
                                      _selectType(
                                        StockType.product,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // ==================================================
                      // SEARCH
                      // ==================================================
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          2,
                          horizontalPadding,
                          6,
                        ),
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: _selectedType ==
                                      StockType.material
                                  ? "Search material..."
                                  : "Search product...",
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
                      // COMPACT SUMMARY CARDS
                      // ==================================================
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: LayoutBuilder(
                          builder: (context, cardConstraints) {
                            final isPhone =
                                cardConstraints.maxWidth < 600;

                            if (isPhone) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _summaryCard(
                                          "Items",
                                          selectedTotalProducts
                                              .toString(),
                                          _selectedType ==
                                                  StockType.material
                                              ? Colors.orange
                                              : Colors.blue,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _summaryCard(
                                          "In Stock",
                                          selectedInStock
                                              .toString(),
                                          Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _summaryCard(
                                          "Low Stock",
                                          selectedLowStock
                                              .toString(),
                                          Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _summaryCard(
                                          "Out Stock",
                                          selectedOutStock
                                              .toString(),
                                          Colors.red,
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
                                  child: _summaryCard(
                                    "Items",
                                    selectedTotalProducts
                                        .toString(),
                                    _selectedType ==
                                            StockType.material
                                        ? Colors.orange
                                        : Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _summaryCard(
                                    "In Stock",
                                    selectedInStock.toString(),
                                    Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _summaryCard(
                                    "Low Stock",
                                    selectedLowStock.toString(),
                                    Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _summaryCard(
                                    "Out Stock",
                                    selectedOutStock.toString(),
                                    Colors.red,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 6),

                      // ==================================================
                      // TOTAL STOCK VALUE
                      // ==================================================
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: SizedBox(
                          height: 52,
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
                                    radius: 16,
                                    backgroundColor:
                                        (_selectedType ==
                                                    StockType.material
                                                ? Colors.orange
                                                : Colors.blue)
                                            .withOpacity(.10),
                                    child: Icon(
                                      Icons
                                          .account_balance_wallet,
                                      size: 17,
                                      color: _selectedType ==
                                              StockType.material
                                          ? Colors.orange
                                          : Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      _selectedType ==
                                              StockType.material
                                          ? "Material Stock Value"
                                          : "Product Stock Value",
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "৳${selectedStockValue.toStringAsFixed(2)}",
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
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

                      const SizedBox(height: 6),

                      // ==================================================
                      // LIST TITLE
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
                            Icon(
                              _selectedType ==
                                      StockType.material
                                  ? Icons.construction
                                  : Icons.inventory_2,
                              size: 20,
                              color: _selectedType ==
                                      StockType.material
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedType ==
                                        StockType.material
                                    ? "Material Stock"
                                    : "Product Stock",
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                            if (selectedProducts.isNotEmpty)
                              Text(
                                "${selectedProducts.length}",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // ==================================================
                      // STOCK LIST
                      // ==================================================
                      Expanded(
                        child: selectedProducts.isEmpty
                            ? Center(
                                child: Text(
                                  _search.trim().isNotEmpty
                                      ? "No matching item found"
                                      : _selectedType ==
                                              StockType.material
                                          ? "No Material Found"
                                          : "No Product Found",
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
                                    selectedProducts.length,
                                itemBuilder:
                                    (context, index) {
                                  final product =
                                      selectedProducts[index];

                                  return _productCard(
                                    product,
                                    isMaterial:
                                        _selectedType ==
                                            StockType.material,
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
  // STOCK TYPE CARD
  // ============================================================

  Widget _stockTypeCard({
    required String title,
    required String subtitle,
    required int count,
    required double value,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: selected ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? color.withOpacity(.55)
              : Colors.transparent,
          width: selected ? 1.2 : 0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor:
                    color.withOpacity(.12),
                child: Icon(
                  icon,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    "$count Items",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "৳${value.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 5),
              Icon(
                selected
                    ? Icons.keyboard_arrow_down
                    : Icons.chevron_right,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT / MATERIAL CARD
  // ============================================================

  Widget _productCard(
    Product product, {
    required bool isMaterial,
  }) {
    final color = stockColor(product.stock);
    final avgCost = averageCost(product);

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
                isMaterial
                    ? Icons.construction
                    : Icons.inventory_2,
                color: color,
                size: 20,
              ),
            ),

            const SizedBox(width: 10),

            // ==================================================
            // DETAILS
            // ==================================================
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
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

                  // ==================================================
                  // SELLING PRICE ONLY FOR PRODUCT
                  // ==================================================
                  if (!isMaterial)
                    Text(
                      "Sell : ৳${product.sellingPrice.toStringAsFixed(2)}",
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),

                  Text(
                    "Value : ৳${product.stockValue.toStringAsFixed(2)}",
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
                  "${product.stock}",
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
                    stockText(product.stock),
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

  // ============================================================
  // COMPACT SUMMARY CARD
  // ============================================================

  Widget _summaryCard(
    String title,
    String value,
    Color color,
  ) {
    return SizedBox(
      height: 60,
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 6,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor:
                    color.withOpacity(.12),
                child: Icon(
                  Icons.inventory_2,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment:
                          Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.bold,
                          color: color,
                        ),
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

// ============================================================
// STOCK TYPE
// ============================================================

enum StockType {
  material,
  product,
}