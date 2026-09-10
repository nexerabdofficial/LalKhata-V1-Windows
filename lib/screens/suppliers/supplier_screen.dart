import 'dart:async';
import '../../services/refresh_service.dart';
import 'package:flutter/material.dart';
import 'supplier_ledger_screen.dart';
import '../../models/supplier.dart';
import '../../services/supplier_repository.dart';
import 'add_supplier_screen.dart';
import 'supplier_details_screen.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final SupplierRepository _repository = SupplierRepository();

  late Future<List<Supplier>> _suppliers;
  late final StreamSubscription _refreshSubscription;
  @override
void initState() {
  super.initState();

  _loadSuppliers();

  _refreshSubscription =
      RefreshService.stream.listen((_) {
    if (mounted) {
      _loadSuppliers();
    }
  });
}
@override
void dispose() {
  _refreshSubscription.cancel();
  super.dispose();
}

  void _loadSuppliers() {
    _suppliers = _repository.getSuppliers();
  }

  Future<void> _editSupplier(Supplier supplier) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSupplierScreen(
          supplier: supplier,
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _loadSuppliers();
      });
    }
  }
  Future<void> _deleteSupplier(Supplier supplier) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Delete Supplier"),
      content: Text(
        'Are you sure you want to delete "${supplier.name}"?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete"),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  await _repository.deleteSupplier(supplier.id!);

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Supplier deleted successfully."),
    ),
  );

  _loadSuppliers();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Suppliers"),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddSupplierScreen(),
            ),
          );

          setState(() {
            _loadSuppliers();
          });
        },
      ),
      body: FutureBuilder<List<Supplier>>(
        future: _suppliers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No Suppliers Yet",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          final suppliers = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];

              return InkWell(
  onTap: () async {
    final refresh = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierDetailsScreen(
          supplier: supplier,
        ),
      ),
    );

    if (refresh == true) {
  setState(() {
    _loadSuppliers();
  });
}
  },
  child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.local_shipping),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              supplier.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text("Phone : ${supplier.phone ?? "-"}"),
                      Text("Address : ${supplier.address ?? "-"}"),
                      Text(
                        "Balance : ৳${supplier.balance.toStringAsFixed(2)}",
                      ),

                      const SizedBox(height: 15),

                      Row(
  children: [
    Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _editSupplier(supplier),
        icon: const Icon(Icons.edit, size: 18),
        label: const Text(
          "Edit",
          maxLines: 1,
        ),
      ),
    ),

    const SizedBox(width: 8),

    Expanded(
      child: OutlinedButton.icon(
        onPressed: () async {
          await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => SupplierLedgerScreen(
      supplierId: supplier.id!,
      supplierName: supplier.name,
    ),
  ),
);

          setState(() {
            _loadSuppliers();
          });
        },
        icon: const Icon(Icons.menu_book, size: 18),
        label: const Text(
          "Ledger",
          maxLines: 1,
        ),
      ),
    ),

    const SizedBox(width: 8),


Expanded(
  child: OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 46),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    onPressed: () async {
      await _deleteSupplier(supplier);
    },
    icon: const Icon(Icons.delete),
    label: const FittedBox(
      child: Text("Delete"),
    ),
  ),
),
  ],
),
                    ],
                  ),
                ),
              )
              );
            },
          );
        },
      ),
    );
  }
}