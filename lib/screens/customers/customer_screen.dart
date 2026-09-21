import 'dart:async';
import 'package:flutter/material.dart';
import '../accounts/account_ledger_screen.dart';
import '../../services/account_repository.dart';
import '../../services/ff/ff_party_account_service.dart';
import '../../models/customer.dart';
import '../../services/customer_repository.dart';
import 'add_customer_screen.dart';
import 'customer_details_screen.dart';
import '../../services/refresh_service.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final CustomerRepository _repository = CustomerRepository();

  List<Customer> _customers = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  late final StreamSubscription _refreshSubscription;
  String _search = "";
  @override
  void dispose() {
    _refreshSubscription.cancel();
    super.dispose();
  }

  List<Customer> get _filteredCustomers {
    if (_search.trim().isEmpty) {
      return _customers;
    }

    final keyword = _search.toLowerCase();

    return _customers.where((customer) {
      return customer.name.toLowerCase().contains(keyword) ||
          (customer.phone ?? "").toLowerCase().contains(keyword);
    }).toList();
  }

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

  Future<void> _loadCustomers() async {
    try {
      final customers = await _repository.getCustomers();

      if (!mounted) return;

      setState(() {
        _customers = customers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _editCustomer(Customer customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddCustomerScreen(customer: customer)),
    );

    _loadCustomers();
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Customer"),
          content: Text('Are you sure you want to delete "${customer.name}"?'),
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
        );
      },
    );

    if (confirm != true) return;

    await _repository.deleteCustomer(customer.id!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Customer deleted successfully.")),
    );

    _loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Customers")),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
          );

          if (result == true) {
            await _loadCustomers();

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Customer added successfully.")),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCustomers,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search customer...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _search = value;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: _filteredCustomers.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 180),
                              Center(
                                child: Text(
                                  "No customers found",
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: _filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = _filteredCustomers[index];

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: () async {
                                          final refresh = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  CustomerDetailsScreen(
                                                    customer: customer,
                                                  ),
                                            ),
                                          );

                                          if (refresh == true) {
                                            _loadCustomers();
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            const CircleAvatar(
                                              child: Icon(Icons.person),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                customer.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      Text("Phone : ${customer.phone ?? "-"}"),
                                      Text(
                                        "Address : ${customer.address?.isNotEmpty == true ? customer.address! : "-"}",
                                      ),
                                      Text(
                                        "Due : ৳${customer.balance.toStringAsFixed(2)}",
                                      ),

                                      const SizedBox(height: 15),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _editCustomer(customer),
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                "Edit",
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          Expanded(
                                            child: OutlinedButton.icon(
                                              icon: const Icon(
                                                Icons.menu_book,
                                                size: 18,
                                              ),
                                              label: const FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text("Ledger"),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                              ),
                                              onPressed: () async {
                                                final customerId = customer.id;
                                                if (customerId == null) return;

                                                try {
                                                  final accountId =
                                                      await FFPartyAccountService
                                                          .instance
                                                          .ensureCustomerAccount(
                                                            customerId,
                                                          );

                                                  final account =
                                                      await AccountRepository()
                                                          .getAccountById(
                                                            accountId,
                                                          );

                                                  if (!context.mounted) return;

                                                  if (account == null) {
                                                    throw StateError(
                                                      'Customer account not found.',
                                                    );
                                                  }

                                                  await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          AccountLedgerScreen(
                                                            account: account,
                                                          ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  if (!context.mounted) return;

                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Could not open customer ledger: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () async {
                                                await _deleteCustomer(customer);
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                              ),
                                              label: const FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  "Delete",
                                                  maxLines: 1,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                minimumSize: const Size(0, 42),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                    ),
                                              ),
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
              ),
            ),
    );
  }
}
