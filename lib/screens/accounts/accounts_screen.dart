import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../../services/account_service.dart';
import '../../services/ff/ff_account_hierarchy_service.dart';
import '../../services/ff/ff_universal_ledger_service.dart';
import '../../models/ff_account_group.dart';
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

  final FFAccountHierarchyService _hierarchyService =
      FFAccountHierarchyService.instance;

  final FFUniversalLedgerService _ledgerService =
      FFUniversalLedgerService.instance;

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;

  List<Account> _allAccounts = [];
  List<FFAccountGroup> _groups = [];

  final Map<int, int> _accountGroupIds = {};
  final Map<int, double> _ledgerBalances = {};

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
      final results = await Future.wait([
        _repository.getAccounts(),
        _hierarchyService.getGroups(activeOnly: true),
      ]);

      final accounts = results[0] as List<Account>;
      final groups = results[1] as List<FFAccountGroup>;

      final groupPairs = await Future.wait(
        accounts.where((a) => a.id != null).map((account) async {
          final group = await _hierarchyService.getPrimaryGroupForAccount(
            account.id!,
          );

          return MapEntry(account.id!, group?.id);
        }),
      );

      final balancePairs = await Future.wait(
        accounts.where((a) => a.id != null).map((account) async {
          final summary = await _ledgerService.getSummary(
            accountId: account.id!,
          );

          return MapEntry(account.id!, summary.closingBalance);
        }),
      );

      if (!mounted) return;

      setState(() {
        _allAccounts = accounts;
        _groups = groups;

        _accountGroupIds..clear();

        for (final pair in groupPairs) {
          if (pair.value != null) {
            _accountGroupIds[pair.key] = pair.value!;
          }
        }

        _ledgerBalances
          ..clear()
          ..addEntries(balancePairs);

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
      return account.name.toLowerCase().contains(keyword);
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

  List<FFAccountGroup> _childGroups(int? parentId) {
    final items = _groups.where((group) {
      return group.parentId == parentId;
    }).toList();

    items.sort((a, b) => a.name.compareTo(b.name));

    return items;
  }

  List<Account> _accountsForGroup(int groupId) {
    final visible = _filteredAccounts();

    final items = visible.where((account) {
      final id = account.id;

      if (id == null) return false;

      return _accountGroupIds[id] == groupId;
    }).toList();

    items.sort((a, b) => a.name.compareTo(b.name));

    return items;
  }

  bool _groupHasVisibleContent(int groupId) {
    if (_accountsForGroup(groupId).isNotEmpty) {
      return true;
    }

    for (final child in _childGroups(groupId)) {
      if (_groupHasVisibleContent(child.id!)) {
        return true;
      }
    }

    return false;
  }

  double _accountClosingBalance(Account account) {
    final id = account.id;

    if (id == null) return 0;

    return _ledgerBalances[id] ?? 0;
  }

  Widget _buildLedgerTile(Account account, int depth) {
    final systemControlled = _isSystemControlled(account);

    return Padding(
      padding: EdgeInsets.only(
        left: 18.0 + (depth * 18.0),
        right: 12,
        top: 3,
        bottom: 3,
      ),
      child: Card(
        elevation: 0,
        child: ListTile(
          leading: CircleAvatar(
            radius: 18,
            child: Icon(getIcon(account.type), size: 19),
          ),
          title: Text(
            account.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(_typeLabels[account.type] ?? account.type),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "৳${formatMoney(_accountClosingBalance(account))}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'ledger') {
                    _openLedger(account);
                  } else if (value == 'edit') {
                    _editAccount(account);
                  } else if (value == 'delete') {
                    _deleteAccount(account);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'ledger', child: Text('Ledger')),
                  if (!systemControlled)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (!systemControlled)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          onTap: () => _openLedger(account),
        ),
      ),
    );
  }

  Widget _buildGroupNode(FFAccountGroup group, int depth) {
    final children = _childGroups(group.id);
    final accounts = _accountsForGroup(group.id!);

    final visibleChildren = children
        .where((child) => _groupHasVisibleContent(child.id!))
        .toList();

    final totalLedgers =
        accounts.length +
        visibleChildren.fold<int>(
          0,
          (total, child) => total + _countGroupLedgers(child.id!),
        );

    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0, right: 8, top: 2, bottom: 2),
      child: Card(
        elevation: depth == 0 ? 1 : 0,
        child: ExpansionTile(
          key: ValueKey(
            'account-group-${group.id}-${_search.trim().isNotEmpty ? 'search' : 'normal'}',
          ),
          initiallyExpanded: depth == 0 || _search.trim().isNotEmpty,
          leading: Icon(
            depth == 0 ? Icons.account_tree_outlined : Icons.folder_outlined,
          ),
          title: Text(
            group.name,
            style: TextStyle(
              fontWeight: depth <= 1 ? FontWeight.bold : FontWeight.w600,
            ),
          ),
          subtitle: Text('$totalLedgers ledger${totalLedgers == 1 ? '' : 's'}'),
          children: [
            ...visibleChildren.map(
              (child) => _buildGroupNode(child, depth + 1),
            ),
            ...accounts.map((account) => _buildLedgerTile(account, depth + 1)),
          ],
        ),
      ),
    );
  }

  int _countGroupLedgers(int groupId) {
    var count = _accountsForGroup(groupId).length;

    for (final child in _childGroups(groupId)) {
      count += _countGroupLedgers(child.id!);
    }

    return count;
  }

  Widget _buildHierarchy() {
    final roots = _childGroups(
      null,
    ).where((group) => _groupHasVisibleContent(group.id!)).toList();

    if (roots.isEmpty) {
      return Center(
        child: Text(
          _search.trim().isEmpty ? "No Accounts Yet" : "No matching accounts",
          style: const TextStyle(fontSize: 18),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 90),
      children: roots.map((group) => _buildGroupNode(group, 0)).toList(),
    );
  }

  // ============================================================
  // MOBILE-ONLY ACCOUNT ACTIONS
  // Desktop AppBar actions remain unchanged.
  // ============================================================

  Future<void> _handleMobileAction(String value) async {
    switch (value) {
      case 'cash_flow':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CashFlowScreen()),
        );
        await _loadAccounts();
        break;

      case 'contra':
        final refresh = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FundTransferScreen()),
        );

        if (refresh == true) {
          await _loadAccounts();
        }
        break;

      case 'reconciliation':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReconciliationScreen()),
        );
        await _loadAccounts();
        break;

      case 'journal':
        final refresh = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JournalScreen()),
        );

        if (refresh == true) {
          await _loadAccounts();
        }
        break;
    }
  }

  Widget _mobileActionsMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Account Actions',
      icon: const Icon(Icons.more_vert),
      onSelected: _handleMobileAction,
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'cash_flow',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_balance_wallet_outlined),
            title: Text('Cash Flow'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'contra',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.swap_horiz),
            title: Text('Contra'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'reconciliation',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.fact_check_outlined),
            title: Text('Reconciliation'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'journal',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.menu_book_outlined),
            title: Text('Journal'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Accounts"),
            actions: isMobile
                ? [_mobileActionsMenu(), const SizedBox(width: 6)]
                : [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CashFlowScreen(),
                            ),
                          );

                          await _loadAccounts();
                        },
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                        ),
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
                            MaterialPageRoute(
                              builder: (_) => const FundTransferScreen(),
                            ),
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
                          MaterialPageRoute(
                            builder: (_) => const JournalScreen(),
                          ),
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

                      Expanded(child: _buildHierarchy()),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
