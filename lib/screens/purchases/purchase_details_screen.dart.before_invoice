import 'package:flutter/material.dart';

import '../../models/purchase.dart';
import '../../services/purchase_repository.dart';
import '../../models/purchase/purchase_item_history.dart';
import '../../services/purchase_item_repository.dart';
import 'purchase_screen.dart';

class PurchaseDetailsScreen extends StatefulWidget {
  final int purchaseId;

  const PurchaseDetailsScreen({
    super.key,
    required this.purchaseId,
  });

  @override
  State<PurchaseDetailsScreen> createState() =>
      _PurchaseDetailsScreenState();
}

class _PurchaseDetailsScreenState
    extends State<PurchaseDetailsScreen> {

  final PurchaseRepository _purchaseRepository =
      PurchaseRepository();

  Purchase? _purchase;
final PurchaseItemRepository _purchaseItemRepository =
    PurchaseItemRepository();

List<PurchaseItemHistory> _items = [];
  bool _isLoading = true;
Future<void> _loadPurchase() async {
  final purchaseFuture =
      _purchaseRepository.getPurchaseById(
    widget.purchaseId,
  );

  final itemsFuture =
      _purchaseItemRepository.getItemHistoryByPurchase(
    widget.purchaseId,
  );

  final purchase = await purchaseFuture;
  final items = await itemsFuture;

  if (!mounted) return;

  setState(() {
    _purchase = purchase;
    _items = items;
    _isLoading = false;
  });
}
@override
void initState() {
  super.initState();
  _loadPurchase();
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text('Purchase Details'),
  actions: [
    IconButton(
      icon: const Icon(Icons.edit),
      tooltip: 'Edit Purchase',
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PurchaseScreen(
              purchaseId: widget.purchaseId,
            ),
          ),
        );

        if (!mounted) return;

        _loadPurchase();
      },
    ),
  ],
),
      body: _isLoading
    ? const Center(
        child: CircularProgressIndicator(),
      )
    : _purchase == null
        ? const Center(
            child: Text(
              'Purchase not found.',
            ),
          )
        : SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Purchase #${_purchase!.id}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Purchase Date: ${_purchase!.purchaseDate}',
        ),

        const SizedBox(height: 20),

        const Divider(),

        const Text(
          'Purchased Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        ..._items.map(
          (history) => Card(
            child: ListTile(
              title: Text(history.productName),
              subtitle: Text(
                'Qty: ${history.item.qty} × ${history.item.purchasePrice.toStringAsFixed(2)}',
              ),
              trailing: Text(
                history.item.subtotal.toStringAsFixed(2),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Divider(),

        ListTile(
          title: const Text('Grand Total'),
          trailing: Text(
            _purchase!.grandTotal.toStringAsFixed(2),
          ),
        ),

        ListTile(
          title: const Text('Paid'),
          trailing: Text(
            _purchase!.paid.toStringAsFixed(2),
          ),
        ),

        ListTile(
          title: const Text('Due'),
          trailing: Text(
            _purchase!.due.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  ),
    );
  }
}