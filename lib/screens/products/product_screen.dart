import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_repository.dart';
import 'add_product_screen.dart';
import 'product_ledger_screen.dart';
import 'opening_stock_screen.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductRepository _repository = ProductRepository();

  late Future<List<Product>> _products;

  List<Product> _allProducts = [];

  String _search = "";

  @override
  void initState() {
    super.initState();

    _products = _repository.getProducts();

    _loadProducts();
  }

  Future<void> _loadProducts() async {
    _allProducts = await _repository.getProducts();

    _products = Future.value(_allProducts);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _editProduct(Product product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          product: product,
        ),
      ),
    );

    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete Product"),
          content: Text(
            'Delete "${product.name}" ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _repository.deleteProduct(product.id!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Product deleted successfully",
        ),
      ),
    );

    _loadProducts();
  }

  // ============================================================
  // OPENING STOCK
  // ============================================================

  Future<void> _openOpeningStock(Product product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpeningStockScreen(
          product: product,
        ),
      ),
    );

    if (result == true) {
      _loadProducts();
    }
  }

  // ============================================================
  // OPEN PRODUCT LEDGER
  // ============================================================

  void _openProductLedger(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductLedgerScreen(
          productId: product.id!,
          productName: product.name,
        ),
      ),
    );
  }

  List<Product> get _filteredProducts {
    if (_search.trim().isEmpty) {
      return _allProducts;
    }

    return _allProducts.where((product) {
      return product.name
          .toLowerCase()
          .contains(_search.toLowerCase());
    }).toList();
  }

  Color _statusColor(int stock) {
    if (stock <= 0) {
      return Colors.red;
    }

    if (stock <= 10) {
      return Colors.orange;
    }

    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Products"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddProductScreen(),
            ),
          );

          if (result == true) {
            _loadProducts();
          }
        },
        child: const Icon(Icons.add),
      ),

      body: FutureBuilder<List<Product>>(
        future: _products,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Column(
            children: [
              // ==================================================
              // SEARCH
              // ==================================================

              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search product...",
                    prefixIcon:
                        const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _search = value;
                    });
                  },
                ),
              ),

              // ==================================================
              // HEADER
              // ==================================================

              Container(
                color: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 45,
                      child: Text(
                        "ID",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const Expanded(
                      flex: 4,
                      child: Text(
                        "Product",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 70,
                      child: Text(
                        "Buy",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 70,
                      child: Text(
                        "Sell",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 70,
                      child: Text(
                        "Stock",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // ==================================================
              // PRODUCT LIST
              // ==================================================

              Expanded(
                child: _filteredProducts.isEmpty
                    ? const Center(
                        child: Text(
                          "No Products Found",
                        ),
                      )
                    : ListView.separated(
                        itemCount:
                            _filteredProducts.length,
                        separatorBuilder:
                            (_, __) => Divider(
                          height: 1,
                          color:
                              Colors.grey.shade300,
                        ),
                        itemBuilder:
                            (context, index) {
                          final product =
                              _filteredProducts[index];

                          return InkWell(
                            // ====================================
                            // TAP PRODUCT → LEDGER
                            // ====================================

                            onTap: () {
                              _openProductLedger(
                                product,
                              );
                            },

                            child: Container(
                              color: index.isEven
                                  ? Colors.white
                                  : Colors.grey.shade50,
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 45,
                                    child: Text(
                                      product.id
                                          .toString(),
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                  ),

                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      "৳${product.purchasePrice.toStringAsFixed(0)}",
                                      textAlign:
                                          TextAlign.right,
                                    ),
                                  ),

                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      "৳${product.sellingPrice.toStringAsFixed(0)}",
                                      textAlign:
                                          TextAlign.right,
                                    ),
                                  ),

                                  SizedBox(
                                    width: 70,
                                    child: Center(
                                      child: _statusChip(
                                        product.stock,
                                        product.unit,
                                      ),
                                    ),
                                  ),

                                  // =================================
                                  // MENU
                                  // =================================

                                  PopupMenuButton<String>(
                                    onSelected:
                                        (value) {
                                      if (value ==
                                          'ledger') {
                                        _openProductLedger(
                                          product,
                                        );
                                      } else if (value ==
                                          'opening_stock') {
                                        _openOpeningStock(
                                          product,
                                        );
                                      } else if (value ==
                                          'edit') {
                                        _editProduct(
                                          product,
                                        );
                                      } else if (value ==
                                          'delete') {
                                        _deleteProduct(
                                          product,
                                        );
                                      }
                                    },
                                    itemBuilder:
                                        (_) => const [
                                      PopupMenuItem(
                                        value: 'ledger',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons
                                                  .menu_book_outlined,
                                              size: 20,
                                            ),
                                            SizedBox(
                                              width: 10,
                                            ),
                                            Text(
                                              "Product Ledger",
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'opening_stock',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons
                                                  .inventory_2_outlined,
                                              size: 20,
                                            ),
                                            SizedBox(
                                              width: 10,
                                            ),
                                            Text(
                                              "Opening Stock",
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit,
                                              size: 20,
                                            ),
                                            SizedBox(
                                              width: 10,
                                            ),
                                            Text(
                                              "Edit",
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 20,
                                            ),
                                            SizedBox(
                                              width: 10,
                                            ),
                                            Text(
                                              "Delete",
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // STOCK CHIP
  // ============================================================

  Widget _statusChip(
    int stock,
    String unit,
  ) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 75,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color:
            _statusColor(stock).withOpacity(.15),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        stock <= 0
            ? "0 (Out)"
            : "$stock $unit",
        textAlign: TextAlign.center,
        softWrap: false,
        style: TextStyle(
          color: _statusColor(stock),
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}