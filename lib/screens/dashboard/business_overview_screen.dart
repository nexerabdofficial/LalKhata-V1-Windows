import 'dart:async';

import 'package:flutter/material.dart';

import '../../gab/gab_branding.dart';

import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../accounts/account_ledger_screen.dart';
import '../accounts/account_money_flow_screen.dart';
import '../accounts/money_flow_hub_screen.dart';
import '../accounts/accounts_screen.dart';
import '../accounts/fund_transfer_screen.dart';
import '../accounts/journal_screen.dart';
import '../reports/cash_flow_screen.dart';
import '../../services/customer_repository.dart';
import '../../services/product_repository.dart';
import '../../services/supplier_repository.dart';
import '../../services/ar_data_service.dart';
import '../../services/ff/ff_cash_flow_service.dart';
import '../../services/refresh_service.dart';

import '../accounts/customer_due_list_screen.dart';
import '../customers/customer_screen.dart';
import '../products/product_screen.dart';
import '../suppliers/supplier_screen.dart';
import '../accounts/supplier_due_list_screen.dart';
import '../sales/add_sale_screen.dart';
import '../sales/sales_screen.dart';
import '../purchases/purchase_history_screen.dart';
import '../records/records_screen.dart';
import '../expenses/expense_screen.dart';
import '../incomes/income_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

import '../../widgets/quick_action_sheet.dart';
import '../../database/database_helper.dart';

class _DelayedDueCustomer {
  final int customerId;
  final String name;
  final double due;
  final DateTime? lastTransactionDate;
  final int? daysSinceTransaction;

  const _DelayedDueCustomer({
    required this.customerId,
    required this.name,
    required this.due,
    required this.lastTransactionDate,
    required this.daysSinceTransaction,
  });
}

class BusinessOverviewScreen extends StatefulWidget {
  const BusinessOverviewScreen({super.key});

  @override
  State<BusinessOverviewScreen> createState() => _BusinessOverviewScreenState();
}

class _BusinessOverviewScreenState extends State<BusinessOverviewScreen> {
  final ProductRepository _repository = ProductRepository();
  final SupplierRepository _supplierRepository = SupplierRepository();
  final CustomerRepository _customerRepository = CustomerRepository();
  final AccountRepository _accountRepository = AccountRepository();
  final ARDataService _arDataService = ARDataService();
  final FFCashFlowService _cashFlowService = FFCashFlowService.instance;
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  StreamSubscription? _refreshSubscription;
  Timer? _clockTimer;

  DateTime _currentTime = DateTime.now();

  bool _loading = true;

  int _productCount = 0;
  int _supplierCount = 0;
  int _customerCount = 0;

  double _stockValue = 0;

  double _cashBalance = 0;
  double _bankBalance = 0;
  double _mobileBalance = 0;
  double _totalBalance = 0;

  Account? _cashAccount;

  double _customerDue = 0;
  double _supplierDue = 0;

  double _todaySales = 0;
  double _todayPurchase = 0;
  double _todayExpense = 0;
  double _todayIncome = 0;

  double _moneyReceived = 0;
  double _moneyGiven = 0;
  double _cashClosing = 0;

  double _cashInFlow = 0;
  double _cashOutFlow = 0;
  double _netCashFlow = 0;

  List<dynamic> _bestSellingProducts = [];

  List<_DelayedDueCustomer> _delayedDueCustomers = [];

  String _businessName = 'My Business';

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        _currentTime = DateTime.now();
      });
    });

    _refreshSubscription = RefreshService.stream.listen((_) {
      _loadDashboard();
      _loadBusinessName();
    });

    _loadDashboard();
    _loadBusinessName();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _refreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBusinessName() async {
    try {
      final name = GABBranding.businessName;

      if (!mounted) return;

      setState(() {
        if (name.trim().isNotEmpty) {
          _businessName = name.trim();
        }
      });
    } catch (_) {
      // Keep fallback business name.
    }
  }

  Future<List<_DelayedDueCustomer>> _loadDelayedDueCustomers(
    List customers,
  ) async {
    try {
      final db = await _databaseHelper.database;

      /*
       * Last customer transaction comes from:
       *
       * 1. sales.sale_date
       * 2. customer_payments.created_at
       *
       * We intentionally do NOT calculate due from these tables here.
       * CustomerRepository already maintains customer.balance.
       *
       * This query is only for finding the customer's latest activity.
       */
      final rows = await db.rawQuery('''
        SELECT
          c.id AS customer_id,
          c.name AS customer_name,
          MAX(t.tx_date) AS last_transaction_date
        FROM customers c
        LEFT JOIN (
          SELECT
            customer_id,
            sale_date AS tx_date
          FROM sales

          UNION ALL

          SELECT
            customer_id,
            created_at AS tx_date
          FROM customer_payments
        ) t
          ON t.customer_id = c.id
        GROUP BY
          c.id,
          c.name
      ''');

      final transactionMap = <int, DateTime?>{};

      for (final row in rows) {
        final rawId = row['customer_id'];

        final id = rawId is num
            ? rawId.toInt()
            : int.tryParse(rawId?.toString() ?? '') ?? 0;

        if (id <= 0) continue;

        final rawDate = row['last_transaction_date'];

        DateTime? date;

        if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
          date = DateTime.tryParse(rawDate.toString());
        }

        transactionMap[id] = date;
      }

      final result = <_DelayedDueCustomer>[];

      for (final customer in customers) {
        double due = 0;

        try {
          due = (customer.balance as num).toDouble();
        } catch (_) {
          continue;
        }

        if (due <= 0) continue;

        int customerId = 0;

        try {
          customerId = (customer.id as num).toInt();
        } catch (_) {}

        if (customerId <= 0) continue;

        String name = 'Customer';

        try {
          name = customer.name.toString().trim();

          if (name.isEmpty) {
            name = 'Customer';
          }
        } catch (_) {}

        final lastTransactionDate = transactionMap[customerId];

        int? daysSinceTransaction;

        if (lastTransactionDate != null) {
          final now = DateTime.now();

          final difference = now.difference(lastTransactionDate.toLocal());

          daysSinceTransaction = difference.inDays;

          if (daysSinceTransaction < 0) {
            daysSinceTransaction = 0;
          }
        }

        result.add(
          _DelayedDueCustomer(
            customerId: customerId,
            name: name,
            due: due,
            lastTransactionDate: lastTransactionDate,
            daysSinceTransaction: daysSinceTransaction,
          ),
        );
      }

      /*
       * Delayed customers:
       *
       * 1. Customers with no transaction ever first.
       * 2. Then customers with the longest transaction gap.
       * 3. Due amount is used as secondary ordering.
       */
      result.sort((a, b) {
        final aDays = a.daysSinceTransaction;
        final bDays = b.daysSinceTransaction;

        if (aDays == null && bDays != null) {
          return -1;
        }

        if (aDays != null && bDays == null) {
          return 1;
        }

        if (aDays != null && bDays != null) {
          final daysCompare = bDays.compareTo(aDays);

          if (daysCompare != 0) {
            return daysCompare;
          }
        }

        return b.due.compareTo(a.due);
      });

      return result.take(2).toList();
    } catch (e) {
      debugPrint('Delayed customer loading error: $e');

      /*
       * Safe fallback:
       * If the transaction query fails, keep
       * the dashboard functional using customer
       * balances only.
       */
      final fallback = <_DelayedDueCustomer>[];

      for (final customer in customers) {
        double due = 0;

        try {
          due = (customer.balance as num).toDouble();
        } catch (_) {
          continue;
        }

        if (due <= 0) continue;

        int customerId = 0;

        try {
          customerId = (customer.id as num).toInt();
        } catch (_) {}

        String name = 'Customer';

        try {
          name = customer.name.toString().trim();

          if (name.isEmpty) {
            name = 'Customer';
          }
        } catch (_) {}

        fallback.add(
          _DelayedDueCustomer(
            customerId: customerId,
            name: name,
            due: due,
            lastTransactionDate: null,
            daysSinceTransaction: null,
          ),
        );
      }

      fallback.sort((a, b) => b.due.compareTo(a.due));

      return fallback.take(2).toList();
    }
  }

  Future<void> _loadDashboard() async {
    try {
      if (mounted) {
        setState(() {
          _loading = true;
        });
      }

      final now = DateTime.now();
      final todayCashFlow = await _cashFlowService.getReport(
        from: now,
        to: now,
      );

      final results = await Future.wait<dynamic>([
        _arDataService.getTodaySales(),
        _arDataService.getTodayPurchase(),
        _arDataService.getTodayExpense(),
        _arDataService.getTodayIncome(),
        _arDataService.getTodayMoneyReceived(),
        _arDataService.getTodayMoneyGiven(),
        _arDataService.getCashClosing(),
        _arDataService.getBestSellingProducts(limit: 5),
        _repository.getProducts(),
        _supplierRepository.getSuppliers(),
        _customerRepository.getCustomers(),
        _repository.getTotalStockValue(),
        _accountRepository.getAccounts(),
      ]);

      final products = results[8] as List;
      final suppliers = results[9] as List;
      final customers = results[10] as List;
      final stockValue = (results[11] as num).toDouble();
      final accounts = results[12] as List;

      double customerDue = 0;

      for (final customer in customers) {
        customerDue += (customer.balance as num).toDouble();
      }

      double supplierDue = 0;

      for (final supplier in suppliers) {
        supplierDue += (supplier.balance as num).toDouble();
      }

      double cashBalance = 0;
      double bankBalance = 0;
      double mobileBalance = 0;
      double totalBalance = 0;

      Account? cashAccount;

      for (final account in accounts) {
        final balance = (account.balance as num).toDouble();

        final type = account.type.toString().trim().toUpperCase();

        totalBalance += balance;

        if (type == 'CASH') {
          cashBalance += balance;
          cashAccount ??= account as Account;
        } else if (type == 'BANK') {
          bankBalance += balance;
        } else if (type == 'MOBILE_BANKING') {
          mobileBalance += balance;
        }
      }

      final delayedCustomers = await _loadDelayedDueCustomers(customers);

      if (!mounted) return;

      setState(() {
        _todaySales = (results[0] as num).toDouble();

        _todayPurchase = (results[1] as num).toDouble();

        _todayExpense = (results[2] as num).toDouble();

        _todayIncome = (results[3] as num).toDouble();

        _moneyReceived = (results[4] as num).toDouble();

        _moneyGiven = (results[5] as num).toDouble();

        _bestSellingProducts = results[7] as List;

        _productCount = products.length;

        _supplierCount = suppliers.length;

        _customerCount = customers.length;

        _stockValue = stockValue;

        _customerDue = customerDue;

        _supplierDue = supplierDue;

        _cashBalance = cashBalance;

        _bankBalance = bankBalance;

        _mobileBalance = mobileBalance;

        _totalBalance = totalBalance;

        _cashAccount = cashAccount;

        _cashClosing = (results[6] as num).toDouble();

        _cashInFlow = todayCashFlow.cashIn;
        _cashOutFlow = todayCashFlow.cashOut;
        _netCashFlow = todayCashFlow.netCashFlow;

        _delayedDueCustomers = delayedCustomers;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      debugPrint('Dashboard loading error: $e');
    }
  }

  String _greeting() {
    final hour = _currentTime.hour;

    if (hour < 12) {
      return 'Good Morning';
    }

    if (hour < 17) {
      return 'Good Afternoon';
    }

    if (hour < 21) {
      return 'Good Evening';
    }

    return 'Good Night';
  }

  String _money(double value) {
    return '৳${value.toStringAsFixed(2)}';
  }

  String _formatClock() {
    final hour = _currentTime.hour % 12 == 0 ? 12 : _currentTime.hour % 12;

    final minute = _currentTime.minute.toString().padLeft(2, '0');

    final second = _currentTime.second.toString().padLeft(2, '0');

    final period = _currentTime.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute:$second $period';
  }

  String _formatDate() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[_currentTime.month - 1]} '
        '${_currentTime.day}, '
        '${_currentTime.year}';
  }

  String _formatWeekday() {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return weekdays[_currentTime.weekday - 1];
  }

  void _openCustomerDue() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerDueListScreen()),
    );
  }

  void _openSupplierDue() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupplierDueListScreen()),
    );
  }

  Future<void> _openSalesHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SalesScreen(initialFilter: SalesDateFilter.today),
      ),
    );

    if (!mounted) return;

    _loadDashboard();
  }

  Future<void> _openPurchaseHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PurchaseHistoryScreen(
          initialFilter: PurchaseDateFilter.today,
        ),
      ),
    );

    if (!mounted) return;

    _loadDashboard();
  }

  Future<void> _openIncomeRecords() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IncomeScreen()),
    );

    if (!mounted) return;

    _loadDashboard();
  }

  Future<void> _openExpenseRecords() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExpenseScreen()),
    );

    if (!mounted) return;

    _loadDashboard();
  }

  Future<void> _openNewSale() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddSaleScreen()),
    );

    if (!mounted) return;

    _loadDashboard();
  }

  Future<void> _openRecords() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecordsScreen()),
    );

    if (!mounted) return;

    _loadDashboard();
  }

  Future<void> _openReports() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportsScreen()),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );

    if (!mounted) return;

    _loadDashboard();
    _loadBusinessName();
  }

  void _showQuickAdd() {
    QuickActionSheet.show(context);
  }

  void _openCustomers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerScreen()),
    );
  }

  void _openSuppliers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupplierScreen()),
    );
  }

  void _openProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductScreen()),
    );
  }

  Future<void> _openDelayedCustomer(_DelayedDueCustomer customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerDueListScreen()),
    );

    if (!mounted) return;

    _loadDashboard();
  }

  Future<void> _openDashboardSearch() async {
    final items = <Map<String, dynamic>>[
      {
        'title': 'Cash Flow',
        'subtitle': 'View cash movement',
        'icon': Icons.account_balance_wallet_outlined,
        'page': const CashFlowScreen(),
      },
      {
        'title': 'Contra',
        'subtitle': 'Transfer between accounts',
        'icon': Icons.swap_horiz,
        'page': const FundTransferScreen(),
      },
      {
        'title': 'Accounts',
        'subtitle': 'Manage accounts',
        'icon': Icons.account_balance_outlined,
        'page': const AccountsScreen(),
      },
      {
        'title': 'Journal',
        'subtitle': 'Create double-entry journal',
        'icon': Icons.menu_book_outlined,
        'page': const JournalScreen(),
      },
      {
        'title': 'Customer Due',
        'subtitle': 'View customer dues',
        'icon': Icons.people_outline,
        'page': const CustomerDueListScreen(),
      },
      {
        'title': 'Supplier Due',
        'subtitle': 'View supplier dues',
        'icon': Icons.local_shipping_outlined,
        'page': const SupplierDueListScreen(),
      },
      {
        'title': 'Customers',
        'subtitle': 'Manage customers',
        'icon': Icons.people_alt_outlined,
        'page': const CustomerScreen(),
      },
      {
        'title': 'Products',
        'subtitle': 'Manage products',
        'icon': Icons.inventory_2_outlined,
        'page': const ProductScreen(),
      },
      {
        'title': 'Suppliers',
        'subtitle': 'Manage suppliers',
        'icon': Icons.local_shipping_outlined,
        'page': const SupplierScreen(),
      },
      {
        'title': 'Sales',
        'subtitle': 'View sales',
        'icon': Icons.point_of_sale_outlined,
        'page': const SalesScreen(),
      },
      {
        'title': 'Purchases',
        'subtitle': 'View purchase history',
        'icon': Icons.shopping_cart_outlined,
        'page': const PurchaseHistoryScreen(),
      },
      {
        'title': 'Income',
        'subtitle': 'View income',
        'icon': Icons.trending_up,
        'page': const IncomeScreen(),
      },
      {
        'title': 'Expense',
        'subtitle': 'View expenses',
        'icon': Icons.trending_down,
        'page': const ExpenseScreen(),
      },
      {
        'title': 'Records',
        'subtitle': 'View records',
        'icon': Icons.receipt_long_outlined,
        'page': const RecordsScreen(),
      },
      {
        'title': 'Reports',
        'subtitle': 'View reports',
        'icon': Icons.bar_chart_outlined,
        'page': const ReportsScreen(),
      },
      {
        'title': 'Settings',
        'subtitle': 'App settings',
        'icon': Icons.settings_outlined,
        'page': const SettingsScreen(),
      },
    ];

    await showSearch(
      context: context,
      delegate: _DashboardSearchDelegate(items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),

      /*
       * Search + Quick Add are now inside
       * the premium header.
       *
       * No floating buttons here, so they can
       * never cover the Customer/Due section.
       */
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              final isMobile = width < 700;

              final isTablet = width >= 700 && width < 1100;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 10 : 18,
                  10,
                  isMobile ? 10 : 18,
                  24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1450),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPremiumHeader(isMobile: isMobile),

                        const SizedBox(height: 12),

                        if (_loading)
                          const LinearProgressIndicator(minHeight: 3),

                        const SizedBox(height: 12),

                        if (isMobile)
                          _buildMobileUpperSection()
                        else
                          _buildDesktopUpperSection(isTablet),

                        const SizedBox(height: 16),

                        _buildQuickActions(isMobile: isMobile),

                        const SizedBox(height: 16),

                        _buildBusinessOverview(isMobile: isMobile),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 15 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff7f1d1d), Color(0xff991b1b), Color(0xffb91c1c)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff7f1d1d).withOpacity(.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderGreetingRow(mobile: true),
                const SizedBox(height: 12),
                _buildHeaderClock(compact: true),
                const SizedBox(height: 8),
                _buildHeaderActions(compact: true),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderGreetingRow(mobile: false),
                      const SizedBox(height: 7),
                      Text(
                        _businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Your business overview at a glance',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(.80),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeaderClock(),
                    const SizedBox(height: 8),
                    _buildHeaderActions(),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderGreetingRow({required bool mobile}) {
    return Row(
      mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.wb_sunny_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _greeting(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(.92),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderClock({bool compact = false}) {
    return Container(
      width: compact ? double.infinity : 315,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 9 : 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.105),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.16)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 40 : 48,
            height: compact ? 40 : 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    _formatClock(),
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    '${_formatWeekday()} • ${_formatDate()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.78),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions({bool compact = false}) {
    return SizedBox(
      width: compact ? double.infinity : 315,
      child: Row(
        children: [
          Expanded(
            child: _buildHeaderActionButton(
              icon: Icons.arrow_back_rounded,
              label: 'Back',
              onTap: () => Navigator.maybePop(context),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildHeaderActionButton(
              icon: Icons.search_rounded,
              label: 'Search',
              onTap: _openDashboardSearch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopUpperSection(bool isTablet) {
    final upperHeight = isTablet ? 270.0 : 255.0;

    return SizedBox(
      height: upperHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: _buildTodayPerformanceCard(mobile: false)),
          const SizedBox(width: 14),
          Expanded(flex: 5, child: _buildDueAndCountCard(mobile: false)),
        ],
      ),
    );
  }

  Widget _buildMobileUpperSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDueAndCountCard(mobile: true),
        const SizedBox(height: 14),
        _buildTodayPerformanceCard(mobile: true),
      ],
    );
  }

  Widget _buildDueAndCountCard({required bool mobile}) {
    return Container(
      padding: EdgeInsets.all(mobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff7f1d1d), Color(0xffdc2626)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Due & Business Count',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff202124),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _compactDueTile(
                  title: 'Customer Due',
                  value: _customerDue,
                  icon: Icons.person_outline_rounded,
                  iconColor: const Color(0xff2563eb),
                  background: const Color(0xffeff6ff),
                  onTap: _openCustomerDue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _compactDueTile(
                  title: 'Supplier Due',
                  value: _supplierDue,
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xffd97706),
                  background: const Color(0xfffff7ed),
                  onTap: _openSupplierDue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            'Business Count',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 9),

          /*
           * IMPORTANT:
           *
           * No Expanded here on mobile.
           * The old Expanded inside the
           * SingleChildScrollView was causing
           * the portrait layout to break.
           */
          if (mobile)
            Row(
              children: [
                Expanded(
                  child: _countTile(
                    icon: Icons.people_alt_outlined,
                    label: 'Customers',
                    value: _customerCount,
                    iconColor: const Color(0xff2563eb),
                    onTap: _openCustomers,
                    background: const Color(0xffeff6ff),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _countTile(
                    icon: Icons.local_shipping_outlined,
                    label: 'Suppliers',
                    value: _supplierCount,
                    iconColor: const Color(0xff16a34a),
                    onTap: _openSuppliers,
                    background: const Color(0xfff0fdf4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _countTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Products',
                    value: _productCount,
                    iconColor: const Color(0xff9333ea),
                    onTap: _openProducts,
                    background: const Color(0xfffaf5ff),
                  ),
                ),
              ],
            )
          else
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _countTile(
                      icon: Icons.people_alt_outlined,
                      label: 'Customers',
                      value: _customerCount,
                      iconColor: const Color(0xff2563eb),
                      onTap: _openCustomers,
                      background: const Color(0xffeff6ff),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _countTile(
                      icon: Icons.local_shipping_outlined,
                      label: 'Suppliers',
                      value: _supplierCount,
                      iconColor: const Color(0xff16a34a),
                      onTap: _openSuppliers,
                      background: const Color(0xfff0fdf4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _countTile(
                      icon: Icons.inventory_2_outlined,
                      label: 'Products',
                      value: _productCount,
                      iconColor: const Color(0xff9333ea),
                      onTap: _openProducts,
                      background: const Color(0xfffaf5ff),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _compactDueTile({
    required String title,
    required double value,
    required IconData icon,
    required Color iconColor,
    required Color background,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: iconColor.withOpacity(.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _money(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: iconColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countTile({
    required IconData icon,
    required String label,
    required int value,
    required Color iconColor,
    required Color background,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: iconColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayPerformanceCard({required bool mobile}) {
    final values = [_todaySales, _todayPurchase, _todayIncome, _todayExpense];

    final maxValue = values.fold<double>(
      0,
      (previous, current) => current > previous ? current : previous,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xffbe123c), Color(0xffe11d48)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  "Today's Performance",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff202124),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xfffef2f2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xffb91c1c),
                    letterSpacing: .5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (mobile)
            Column(
              children: [
                SizedBox(
                  height: 62,
                  width: double.infinity,
                  child: _buildMiniPerformanceChart(
                    values: values,
                    maxValue: maxValue,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: _performanceMetric(
                        label: 'Sales',
                        value: _todaySales,
                        color: const Color(0xffdc2626),
                        onTap: _openSalesHistory,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _performanceMetric(
                        label: 'Purchase',
                        value: _todayPurchase,
                        color: const Color(0xff2563eb),
                        onTap: _openPurchaseHistory,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: _performanceMetric(
                        label: 'Income',
                        value: _todayIncome,
                        color: const Color(0xff16a34a),
                        onTap: _openIncomeRecords,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _performanceMetric(
                        label: 'Expense',
                        value: _todayExpense,
                        color: const Color(0xffd97706),
                        onTap: _openExpenseRecords,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: _buildMiniPerformanceChart(
                      values: values,
                      maxValue: maxValue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 9,
                    child: Row(
                      children: [
                        _performanceMetric(
                          label: 'Sales',
                          value: _todaySales,
                          color: const Color(0xffdc2626),
                          onTap: _openSalesHistory,
                        ),
                        _performanceMetric(
                          label: 'Purchase',
                          value: _todayPurchase,
                          color: const Color(0xff2563eb),
                          onTap: _openPurchaseHistory,
                        ),
                        _performanceMetric(
                          label: 'Income',
                          value: _todayIncome,
                          color: const Color(0xff16a34a),
                          onTap: _openIncomeRecords,
                        ),
                        _performanceMetric(
                          label: 'Expense',
                          value: _todayExpense,
                          color: const Color(0xffd97706),
                          onTap: _openExpenseRecords,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _performanceMetric({
    required String label,
    required double value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
              decoration: BoxDecoration(
                color: color.withOpacity(.045),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: color.withOpacity(.07)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 8,
                        color: color.withOpacity(.55),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _money(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniPerformanceChart({
    required List<double> values,
    required double maxValue,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xfffafafa),
        borderRadius: BorderRadius.circular(15),
      ),
      child: CustomPaint(
        painter: _MiniTrendPainter(values: values, maxValue: maxValue),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildQuickActions({required bool isMobile}) {
    final actions = [
      _QuickActionData(
        title: 'Records',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xff2563eb),
        onTap: _openRecords,
      ),
      _QuickActionData(
        title: 'Reports',
        icon: Icons.analytics_rounded,
        color: const Color(0xff16a34a),
        onTap: _openReports,
      ),
      _QuickActionData(
        title: 'Money Flow',
        icon: Icons.swap_vert_rounded,
        color: const Color(0xffd97706),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MoneyFlowHubScreen()),
          );
        },
      ),
      _QuickActionData(
        title: 'Settings',
        icon: Icons.settings_rounded,
        color: const Color(0xff7c3aed),
        onTap: _openSettings,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: isMobile
          ? GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 68,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                return _quickActionButton(actions[index]);
              },
            )
          : Row(
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _quickActionButton(actions[i])),
                ],
              ],
            ),
    );
  }

  Widget _quickActionButton(_QuickActionData action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: action.color.withOpacity(.065),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: action.color.withOpacity(.10)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: action.color.withOpacity(.20),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(action.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.title,
                  style: TextStyle(
                    color: action.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: action.color.withOpacity(.65),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessOverview({required bool isMobile}) {
    if (isMobile) {
      return Column(
        children: [
          _buildCashFlowCard(),
          const SizedBox(height: 14),
          _buildBalanceSummaryCard(),
          const SizedBox(height: 14),
          _buildBestSellingCard(),
        ],
      );
    }

    return SizedBox(
      height: 275,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 4, child: _buildCashFlowCard()),
          const SizedBox(width: 14),
          Expanded(flex: 4, child: _buildBalanceSummaryCard()),
          const SizedBox(width: 14),
          Expanded(flex: 5, child: _buildBestSellingCard()),
        ],
      ),
    );
  }

  Widget _buildCashFlowCard() {
    return _overviewCard(
      title: 'Cash Flow',
      icon: Icons.account_balance_wallet_outlined,
      iconColor: const Color(0xff2563eb),
      child: Column(
        children: [
          _cashFlowRow(
            label: 'In Flow',
            value: _cashInFlow,
            icon: Icons.south_west_rounded,
            color: const Color(0xff16a34a),
          ),
          const SizedBox(height: 9),
          _cashFlowRow(
            label: 'Out Flow',
            value: _cashOutFlow,
            icon: Icons.north_east_rounded,
            color: const Color(0xffdc2626),
          ),
          const SizedBox(height: 9),
          _cashFlowRow(
            label: 'Net Flow',
            value: _netCashFlow,
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xff7c3aed),
          ),
        ],
      ),
    );
  }

  Widget _cashFlowRow({
    required String label,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CashFlowScreen()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(.055),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              _money(value),
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: color.withOpacity(.65),
            ),
          ],
        ),
      ),
    );
  }

  void _openMoneyFlow({required bool received}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountMoneyFlowScreen(received: received),
      ),
    );
  }

  void _openAccountLedger(Account? account) {
    if (account == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AccountLedgerScreen(account: account)),
    );
  }

  void _openBankAccounts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AccountsScreen(initialType: 'BANK'),
      ),
    );
  }

  void _openMobileAccounts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AccountsScreen(initialType: 'MOBILE_BANKING'),
      ),
    );
  }

  void _openAllAccounts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountsScreen()),
    );
  }

  Widget _flowRow({
    required String label,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    final isReceived = label == 'Money Received';

    final isGiven = label == 'Money Given';

    final isClosing = label == 'Cash Closing';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isReceived
          ? () => _openMoneyFlow(received: true)
          : isGiven
          ? () => _openMoneyFlow(received: false)
          : isClosing
          ? () => _openAccountLedger(_cashAccount)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(.055),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              _money(value),
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isReceived || isGiven || isClosing) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: color.withOpacity(.65),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceSummaryCard() {
    return _overviewCard(
      title: 'Balance Summary',
      icon: Icons.account_balance_rounded,
      iconColor: const Color(0xff7c3aed),
      child: Column(
        children: [
          _balanceRow(
            label: 'Cash',
            value: _cashBalance,
            icon: Icons.payments_outlined,
            color: const Color(0xff16a34a),
            onTap: () => _openAccountLedger(_cashAccount),
          ),
          const SizedBox(height: 8),
          _balanceRow(
            label: 'Bank',
            value: _bankBalance,
            icon: Icons.account_balance_outlined,
            color: const Color(0xff2563eb),
            onTap: _openBankAccounts,
          ),
          const SizedBox(height: 8),
          _balanceRow(
            label: 'Mobile',
            value: _mobileBalance,
            icon: Icons.phone_android_rounded,
            color: const Color(0xff9333ea),
            onTap: _openMobileAccounts,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _openAllAccounts,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff7f1d1d), Color(0xffb91c1c)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Total Balance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _money(_totalBalance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceRow({
    required String label,
    required double value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              _money(value),
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: color.withOpacity(.50),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestSellingCard() {
    return _overviewCard(
      title: 'Best Selling',
      icon: Icons.local_fire_department_rounded,
      iconColor: const Color(0xffea580c),
      child: Column(
        children: [
          if (_bestSellingProducts.isEmpty)
            const SizedBox(
              height: 70,
              child: Center(
                child: Text(
                  'No sales data available yet',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _bestSellingProducts.length.clamp(0, 2),
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final item = _bestSellingProducts[index];

                String name = 'Product';

                double quantity = 0;

                try {
                  if (item is Map) {
                    name =
                        item['product_name']?.toString() ??
                        item['name']?.toString() ??
                        'Product';

                    quantity =
                        (item['quantity'] as num?)?.toDouble() ??
                        (item['total_quantity'] as num?)?.toDouble() ??
                        0;
                  } else {
                    name = item.productName?.toString() ?? 'Product';

                    quantity = (item.quantity as num?)?.toDouble() ?? 0;
                  }
                } catch (_) {}

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openProducts,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 3,
                        horizontal: 2,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 27,
                            height: 27,
                            decoration: BoxDecoration(
                              color: const Color(0xffea580c).withOpacity(.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xffea580c),
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${quantity.toStringAsFixed(0)} sold',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xffea580c),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 17,
                            color: Color(0xffea580c),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 9),

          Divider(height: 1, color: Colors.grey.shade200),

          const SizedBox(height: 9),

          Row(
            children: [
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: const Color(0xffdc2626).withOpacity(.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.schedule_outlined,
                  color: Color(0xffdc2626),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Delayed Due Customer',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
              if (_delayedDueCustomers.isNotEmpty)
                Text(
                  'View Due',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 7),

          if (_delayedDueCustomers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 35, top: 2, bottom: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No delayed due customer',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.zero,
              child: _delayedDueCustomerRow(_delayedDueCustomers.first),
            ),
        ],
      ),
    );
  }

  Widget _delayedDueCustomerRow(_DelayedDueCustomer customer) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDelayedCustomer(customer),
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xffdc2626).withOpacity(.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xffdc2626),
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _transactionAgeText(customer),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(customer.due),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xffdc2626),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: Color(0xffdc2626),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _transactionAgeText(_DelayedDueCustomer customer) {
    final days = customer.daysSinceTransaction;

    if (days == null) {
      return 'No transaction yet';
    }

    if (days == 0) {
      return 'Transaction today';
    }

    if (days == 1) {
      return 'No transaction for 1 day';
    }

    return 'No transaction for $days days';
  }

  Widget _overviewCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff202124),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _MiniTrendPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;

  const _MiniTrendPainter({required this.values, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final chartHeight = size.height - 16;

    final stepX = values.length <= 1 ? 0.0 : size.width / (values.length - 1);

    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.grey.withOpacity(.10);

    for (int i = 1; i <= 3; i++) {
      final y = chartHeight * (i / 4.0);

      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final ratio = maxValue <= 0
          ? 0.10
          : (values[i] / maxValue).clamp(0.10, 1.0).toDouble();

      final x = i * stepX;

      final y = chartHeight - (chartHeight * ratio);

      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    final fillPath = Path()
      ..moveTo(points.first.dx, chartHeight)
      ..lineTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }

    fillPath
      ..lineTo(points.last.dx, chartHeight)
      ..close();

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xffb91c1c).withOpacity(.055);

    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xffb91c1c).withOpacity(.68);

    canvas.drawPath(linePath, linePaint);

    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xffb91c1c).withOpacity(.82);

    for (final point in points) {
      canvas.drawCircle(point, 3.2, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniTrendPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.maxValue != maxValue;
  }
}

class _QuickActionData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _DashboardSearchDelegate extends SearchDelegate<void> {
  final List<Map<String, dynamic>> items;

  _DashboardSearchDelegate({required this.items});

  @override
  String get searchFieldLabel => 'Search anything...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) {
      return null;
    }

    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildResults(context);
  }

  Widget _buildResults(BuildContext context) {
    final keyword = query.trim().toLowerCase();

    final results = items.where((item) {
      if (keyword.isEmpty) {
        return true;
      }

      final title = (item['title'] as String).toLowerCase();

      final subtitle = (item['subtitle'] as String).toLowerCase();

      return title.contains(keyword) || subtitle.contains(keyword);
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('No matching option found', style: TextStyle(fontSize: 16)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
      itemBuilder: (context, index) {
        final item = results[index];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 4,
          ),
          leading: CircleAvatar(child: Icon(item['icon'] as IconData)),
          title: Text(
            item['title'] as String,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(item['subtitle'] as String),
          trailing: const Icon(Icons.arrow_forward_ios, size: 15),
          onTap: () {
            final page = item['page'] as Widget;

            close(context, null);

            Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          },
        );
      },
    );
  }
}
