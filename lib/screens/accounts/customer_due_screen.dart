import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../services/customer_repository.dart';
import 'receive_payment_screen.dart';

class CustomerDueScreen extends StatefulWidget {
  const CustomerDueScreen({super.key});

  @override
  State<CustomerDueScreen> createState() => _CustomerDueScreenState();
}

class _CustomerDueScreenState extends State<CustomerDueScreen> {
  final CustomerRepository _repository = CustomerRepository();

  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await _repository.getDueCustomers();

    if (!mounted) return;

    setState(() {
      _customers = customers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Due"),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _customers.isEmpty
              ? const Center(
                  child: Text(
                    "No Due Customers",
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final customer = _customers[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(customer.name),
                        subtitle: Text(
                          customer.phone ?? "",
                        ),
                        trailing: Text(
                          "৳${customer.balance.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () async {
  final refresh = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ReceivePaymentScreen(
        customer: customer,
      ),
    ),
  );

  if (refresh == true) {
    _loadCustomers();
  }
},
                      ),
                    );
                  },
                ),
    );
  }
}