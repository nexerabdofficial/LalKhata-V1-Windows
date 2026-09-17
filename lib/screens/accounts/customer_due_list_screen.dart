import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/customer_repository.dart';
import '../../services/refresh_service.dart';
import 'receive_payment_screen.dart';

class CustomerDueListScreen extends StatefulWidget {
  const CustomerDueListScreen({super.key});

  @override
  State<CustomerDueListScreen> createState() => _CustomerDueListScreenState();
}

class _CustomerDueListScreenState extends State<CustomerDueListScreen> {
  final CustomerRepository _repository = CustomerRepository();

  List<Customer> _customers = [];

  bool _loading = true;

  late final StreamSubscription _refreshSubscription;

  @override
  void initState() {
    super.initState();

    _loadCustomers();

    _refreshSubscription = RefreshService.stream.listen((_) {
      if (mounted) {
        _loadCustomers();
      }
    });
  }

  @override
  void dispose() {
    _refreshSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await _repository.getCustomers();

      final dueCustomers = customers
          .where((customer) => customer.balance > 0.000001)
          .toList();

      dueCustomers.sort((a, b) => b.balance.compareTo(a.balance));

      if (!mounted) return;

      setState(() {
        _customers = dueCustomers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load customer due: $e')),
      );
    }
  }

  double get _totalDue {
    double total = 0;

    for (final customer in _customers) {
      total += customer.balance;
    }

    return total;
  }

  String _formatMoney(double amount) {
    return amount.toStringAsFixed(2);
  }

  Future<void> _openPayment(Customer customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceivePaymentScreen(customer: customer),
      ),
    );

    await _loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Due'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadCustomers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCustomers,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryCard(),
                  const SizedBox(height: 16),
                  if (_customers.isEmpty)
                    _emptyState()
                  else
                    ..._customers.map(_customerCard),
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
          colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.18),
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
            child: const Icon(Icons.people_alt, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Customer Due',
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
            '${_customers.length}',
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

  Widget _customerCard(Customer customer) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPayment(customer),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: Colors.red.shade50,
                child: Icon(Icons.person, color: Colors.red.shade700),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((customer.phone ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        customer.phone!,
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
                    '৳ ${_formatMoney(customer.balance)}',
                    style: TextStyle(
                      color: Colors.red.shade700,
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
            'No Customer Due',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'All customer balances are clear.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
