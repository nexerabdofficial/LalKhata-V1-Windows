import 'package:flutter/material.dart';

import '../../services/purchase_repository.dart';

class PurchaseReportScreen extends StatefulWidget {
  const PurchaseReportScreen({super.key});

  @override
  State<PurchaseReportScreen> createState() =>
      _PurchaseReportScreenState();
}

class _PurchaseReportScreenState
    extends State<PurchaseReportScreen> {

  final PurchaseRepository _repository =
      PurchaseRepository();

  List<dynamic> _purchases = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final purchases =
        await _repository.getPurchases();

    if (!mounted) return;

    setState(() {
      _purchases = purchases;
      _loading = false;
    });
  }

  double get totalPurchase {
  double total = 0;

  for (final purchase in _purchases) {
    total += purchase.purchase.grandTotal;
  }

  return total;
}

  double get totalPaid {
  double total = 0;

  for (final purchase in _purchases) {
    total += purchase.purchase.paid;
  }

  return total;
}

  double get totalDue {
  double total = 0;

  for (final purchase in _purchases) {
    total += purchase.purchase.due;
  }

  return total;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Purchase Summary"),
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
                    title: const Text("Total Purchase"),
                    trailing: Text(
                      "৳${totalPurchase.toStringAsFixed(2)}",
                    ),
                  ),
                ),

                Card(
                  child: ListTile(
                    title: const Text("Total Paid"),
                    trailing: Text(
                      "৳${totalPaid.toStringAsFixed(2)}",
                    ),
                  ),
                ),

                Card(
                  child: ListTile(
                    title: const Text("Total Due"),
                    trailing: Text(
                      "৳${totalDue.toStringAsFixed(2)}",
                    ),
                  ),
                ),

                Card(
                  child: ListTile(
                    title: const Text("Total Purchases"),
                    trailing: Text(
                      _purchases.length.toString(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}