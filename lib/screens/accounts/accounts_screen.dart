import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../../services/account_service.dart';
import 'add_account_screen.dart';
import 'account_ledger_screen.dart';
import 'fund_transfer_screen.dart';
import 'journal_screen.dart';
import '../reports/cash_flow_screen.dart';
import 'reconciliation_screen.dart';

class AccountsScreen extends StatefulWidget {
  final String? initialType;

  const AccountsScreen({super.key, this.initialType});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> with RouteAware {
  final AccountRepository _repository = AccountRepository();
  final AccountService _accountService = AccountService();

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;

  List<Account> _allAccounts = [];

  String _search = "";

  final Map<String, String> _typeLabels = {
    "CASH": "Cash",
    "BANK": "Bank",
    "MOBILE_BANKING": "MFS / Mobile Banking",
    "MFS": "MFS / Mobile Banking",
    "OTHER_CURRENT_ASSET": "Other Current Asset",
    "FIXED_ASSET": "Fixed Asset",
    "OTHER_LIABILITY": "Other Liability",
    "OWNER_CAPITAL": "Owner Capital",
    "OTHER_INCOME": "Income",
    "OPERATING_EXPENSE": "Expense",

    // System-controlled FF ledgers
    "CUSTOMER_RECEIVABLE": "Customer Receivable",
    "SUPPLIER_PAYABLE": "Supplier Payable",
    "INVENTORY": "Inventory",
    "SALES_INCOME": "Sales Income",
    "OWNER_WITHDRAWAL": "Owner Withdrawal",
    "RETAINED_EARNINGS": "Retained Earnings",
    "LOAN_RECEIVABLE": "Loan Receivable",
    "LOAN_PAYABLE": "Loan Payable",
  };

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);

    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _loadAccounts();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final data = await _repository.getAccounts();

      if (!mounted) return;

      setState(() {
        _allAccounts = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load accounts: $e")));
    }
  }

  List<Account> _filteredAccounts() {
    var accounts = _allAccounts;

    if (widget.initialType != null) {
      accounts = accounts
          .where(
            (account) =>
                account.type.toUpperCase() == widget.initialType!.toUpperCase(),
          )
          .toList();
    }

    if (_search.trim().isEmpty) {
      return accounts;
    }

    final keyword = _search.trim().toLowerCase();

    return accounts.where((account) {
      return account.name.toLowerCase().contains(keyword) ||
          account.type.toLowerCase().contains(keyword);
    }).toList();
  }

  String formatMoney(double amount) {
    if (amount == amount.roundToDouble()) {
      return NumberFormat('#,##0').format(amount);
    }

    return NumberFormat('#,##0.##').format(amount);
  }

  bool _isSystemControlled(Account account) {
    const systemTypes = <String>{
      'CUSTOMER_RECEIVABLE',
      'SUPPLIER_PAYABLE',
      'INVENTORY',
      'SALES_INCOME',
      'OWNER_WITHDRAWAL',
      'RETAINED_EARNINGS',
      'LOAN_RECEIVABLE',
      'LOAN_PAYABLE',
    };

    return systemTypes.contains(account.type.toUpperCase());
  }

  IconData getIcon(String type) {
    switch (type.toUpperCase()) {
      case "BANK":
        return Icons.account_balance;

      case "MOBILE_BANKING":
      case "MFS":
        return Icons.phone_android;

      case "OTHER_CURRENT_ASSET":
        return Icons.wallet_outlined;

      case "FIXED_ASSET":
        return Icons.apartment_outlined;

      case "OTHER_LIABILITY":
        return Icons.request_quote_outlined;

      case "OWNER_CAPITAL":
        return Icons.savings_outlined;

      case "OTHER_INCOME":
      case "SALES_INCOME":
        return Icons.trending_up;

      case "OPERATING_EXPENSE":
        return Icons.trending_down;

      case "CUSTOMER_RECEIVABLE":
        return Icons.people_outline;

      case "SUPPLIER_PAYABLE":
        return Icons.local_shipping_outlined;

      case "INVENTORY":
        return Icons.inventory_2_outlined;

      case "LOAN_RECEIVABLE":
      case "LOAN_PAYABLE":
        return Icons.handshake_outlined;

      case "OWNER_WITHDRAWAL":
        return Icons.money_off_csred_outlined;

      case "RETAINED_EARNINGS":
        return Icons.account_balance_wallet_outlined;

      case "CARD":
        return Icons.credit_card;

      case "CASH":
      default:
        return Icons.payments;
    }
  }

  Future<void> _editAccount(Account account) async {
    if (_isSystemControlled(account)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This is a system-controlled account and cannot be edited manually.",
          ),
        ),
      );
      return;
    }

    final refresh = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddAccountScreen(account: account)),
    );

    if (refresh == true) {
      await _loadAccounts();
    }
  }

  Future<void> _openLedger(Account account) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AccountLedgerScreen(account: account)),
    );
  }

  Future<void> _deleteAccount(Account account) async {
    if (_isSystemControlled(account)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This is a system-controlled account and cannot be deleted manually.",
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete Account"),
          content: Text("Delete '${account.name}'?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _accountService.deleteAccount(account.id!);

      await _loadAccounts();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Account deleted.")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete account: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Accounts"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CashFlowScreen()),
                );

                await _loadAccounts();
              },
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              label: const Text('Cash Flow'),
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: OutlinedButton.icon(
              onPressed: () async {
                final refresh = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FundTransferScreen()),
                );

                if (refresh == true) {
                  await _loadAccounts();
                }
              },
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Contra'),
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReconciliationScreen(),
                  ),
                );

                await _loadAccounts();
              },
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Reconciliation'),
            ),
          ),
          const SizedBox(width: 8),

          OutlinedButton.icon(
            onPressed: () async {
              final refresh = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JournalScreen()),
              );

              if (refresh == true) {
                await _loadAccounts();
              }
            },
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Journal'),
          ),
          const SizedBox(width: 8),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAccountScreen()),
          );

          await _loadAccounts();
        },
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAccounts,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search account...",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();

                                  setState(() {
                                    _search = "";
                                  });
                                },
                              ),
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
                    child: _filteredAccounts().isEmpty
                        ? Center(
                            child: Text(
                              _search.trim().isEmpty
                                  ? "No Accounts Yet"
                                  : "No matching accounts",
                              style: const TextStyle(fontSize: 18),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: _filteredAccounts().length,
                            itemBuilder: (context, index) {
                              final account = _filteredAccounts()[index];

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            child: Icon(getIcon(account.type)),
                                          ),

                                          const SizedBox(width: 12),

                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  account.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),

                                                const SizedBox(height: 4),

                                                Text(
                                                  _typeLabels[account.type] ??
                                                      account.type,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const Text(
                                                "Balance",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),

                                              Text(
                                                "৳${formatMoney(account.balance)}",
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      const Divider(height: 1),

                                      const SizedBox(height: 10),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _editAccount(account),
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                "Edit",
                                                maxLines: 1,
                                                softWrap: false,
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _openLedger(account),
                                              icon: const Icon(
                                                Icons.receipt_long,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                "Ledger",
                                                maxLines: 1,
                                                softWrap: false,
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _deleteAccount(account),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                "Delete",
                                                maxLines: 1,
                                                softWrap: false,
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
