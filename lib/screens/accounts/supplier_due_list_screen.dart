import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../../services/refresh_service.dart';
import '../../services/supplier_repository.dart';
import 'pay_supplier_screen.dart';

class SupplierDueListScreen extends StatefulWidget {
  const SupplierDueListScreen({super.key});

  @override
  State<SupplierDueListScreen> createState() => _SupplierDueListScreenState();
}

class _SupplierDueListScreenState extends State<SupplierDueListScreen> {
  final SupplierRepository _repository = SupplierRepository();

  List<Supplier> _suppliers = [];

  bool _loading = true;

  late final StreamSubscription _refreshSubscription;

  @override
  void initState() {
    super.initState();

    _loadSuppliers();

    _refreshSubscription = RefreshService.stream.listen((_) {
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

  Future<void> _loadSuppliers() async {
    try {
      final suppliers = await _repository.getSuppliers();

      final dueSuppliers = suppliers
          .where((supplier) => supplier.balance > 0.000001)
          .toList();

      dueSuppliers.sort((a, b) => b.balance.compareTo(a.balance));

      if (!mounted) return;

      setState(() {
        _suppliers = dueSuppliers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load supplier due: $e')),
      );
    }
  }

  double get _totalDue {
    double total = 0;

    for (final supplier in _suppliers) {
      total += supplier.balance;
    }

    return total;
  }

  String _formatMoney(double amount) {
    return amount.toStringAsFixed(2);
  }

  Future<void> _openPayment(Supplier supplier) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaySupplierScreen(supplier: supplier)),
    );

    await _loadSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Due'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadSuppliers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSuppliers,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryCard(),
                  const SizedBox(height: 16),
                  if (_suppliers.isEmpty)
                    _emptyState()
                  else
                    ..._suppliers.map(_supplierCard),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFE65100)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Supplier Due',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '৳ ${_formatMoney(_totalDue)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_suppliers.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplierCard(Supplier supplier) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPayment(supplier),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: Colors.orange.shade50,
                child: Icon(
                  Icons.local_shipping,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((supplier.phone ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        supplier.phone!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Due',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '৳ ${_formatMoney(supplier.balance)}',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'No Supplier Due',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'All supplier balances are clear.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
