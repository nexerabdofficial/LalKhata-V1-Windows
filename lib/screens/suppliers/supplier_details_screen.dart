import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../accounts/pay_supplier_screen.dart';

class SupplierDetailsScreen extends StatelessWidget {
  final Supplier supplier;

  const SupplierDetailsScreen({
    super.key,
    required this.supplier,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Supplier Details"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.local_shipping),
                ),
                title: Text(supplier.name),
                subtitle: Text(supplier.phone ?? ""),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: ListTile(
                title: const Text("Current Due"),
                trailing: Text(
                  "৳${supplier.balance.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payments),
                label: const Text("Pay Supplier"),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaySupplierScreen(
                        supplier: supplier,
                      ),
                    ),
                  );

                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}