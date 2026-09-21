import 'package:flutter/material.dart';
import '../../models/sale_item.dart';
import '../../services/sale_repository.dart';
import '../invoices/sale_invoice_preview_screen.dart';

class SaleDetailsScreen extends StatefulWidget {
  final int saleId;

  const SaleDetailsScreen({super.key, required this.saleId});

  @override
  State<SaleDetailsScreen> createState() => _SaleDetailsScreenState();
}

class _SaleDetailsScreenState extends State<SaleDetailsScreen> {
  final SaleRepository _repository = SaleRepository();

  Map<String, dynamic>? _sale;
  List<SaleItem> _items = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSaleDetails();
  }

  Future<void> _loadSaleDetails() async {
    final sale = await _repository.getSaleDetails(widget.saleId);

    final items = await _repository.getSaleItems(widget.saleId);

    if (!mounted) return;

    setState(() {
      _sale = sale;
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_sale == null) {
      return const Scaffold(body: Center(child: Text("Sale Not Found")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Invoice #${widget.saleId}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Sales Invoice',
            onPressed: () async {
              final repository = SaleRepository();

              try {
                final sale = await repository.getSale(widget.saleId);
                final saleInfo = await repository.getSaleById(widget.saleId);
                final items = await repository.getSaleItems(widget.saleId);

                if (saleInfo == null || !mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SaleInvoicePreviewScreen(
                      sale: sale,
                      saleInfo: saleInfo,
                      items: items,
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not open invoice: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer", style: TextStyle(color: Colors.grey.shade600)),

            Text(
              _sale!['customer_name'] ?? "",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text("Invoice: ${_sale!['invoice_no'] ?? "-"}"),
                ),

                Expanded(child: Text("Date: ${_sale!['sale_date']}")),
              ],
            ),

            const SizedBox(height: 8),

            if ((_sale!['note'] ?? "").toString().isNotEmpty)
              Text("Note: ${_sale!['note']}"),

            const SizedBox(height: 15),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Grand Total"),
                        Text("৳${_sale!['grand_total']}"),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Paid"),
                        Text("৳${_sale!['paid']}"),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Due"),
                        Text(
                          "৳${_sale!['due']}",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text("Items"), Text("${_items.length}")],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            const Divider(),

            const Text(
              "Products",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        item.productName.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Qty : ${item.qty}"),
                          Text(
                            "Price : ৳${item.sellingPrice.toStringAsFixed(2)}",
                          ),
                        ],
                      ),
                      trailing: Text(
                        "৳${item.subtotal.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
