import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_repository.dart';

class LowStockScreen extends StatefulWidget {
  const LowStockScreen({super.key});

  @override
  State<LowStockScreen> createState() =>
      _LowStockScreenState();
}

class _LowStockScreenState
    extends State<LowStockScreen> {

  final ProductRepository _repository =
      ProductRepository();

  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _repository.getProducts();

    if (!mounted) return;

    setState(() {
      _products = products
          .where((e) => e.stock <= 5)
          .toList();

      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Low Stock"),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _products.isEmpty
              ? const Center(
                  child: Text(
                    "No Low Stock Products",
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.warning,
                          color: Colors.red,
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                          "Current Stock: ${p.stock}",
                        ),
                        trailing: Text(
                          "৳${p.sellingPrice}",
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}