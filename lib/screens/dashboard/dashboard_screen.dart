import 'dart:async';

import 'package:flutter/material.dart';

import '../../main.dart';

import '../../gab/gab_branding.dart';

import '../../services/customer_repository.dart';
import '../../services/product_repository.dart';
import '../../services/supplier_repository.dart';
import '../../services/account_repository.dart';
import '../../services/refresh_service.dart';

import '../../widgets/dashboard_card.dart';
import '../../widgets/quick_action_sheet.dart';

import '../records/records_screen.dart';
import '../reports/reports_screen.dart';
import '../sales/add_sale_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {
  final ProductRepository _repository =
      ProductRepository();

  final SupplierRepository _supplierRepository =
      SupplierRepository();

  final CustomerRepository _customerRepository =
      CustomerRepository();

  final AccountRepository _accountRepository =
      AccountRepository();

  late final StreamSubscription _refreshSubscription;

  int _productCount = 0;
  int _supplierCount = 0;
  int _customerCount = 0;

  double _stockValue = 0;

  double _cashBalance = 0;
  double _bankBalance = 0;
  double _mobileBalance = 0;
  double _totalBalance = 0;

  double _customerDue = 0;
  double _supplierDue = 0;

  // ============================================================
  // BUSINESS / CUSTOMER NAME
  // ============================================================

  String _businessName = '';

  @override
  void initState() {
    super.initState();

    _loadBusinessName();
    _loadDashboard();

    // ==========================================================
    // REALTIME REFRESH
    // ==========================================================

    _refreshSubscription =
        RefreshService.stream.listen((_) {
      if (mounted) {
        _loadDashboard();
        _loadBusinessName();
      }
    });
  }

  @override
  void dispose() {
    _refreshSubscription.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD BUSINESS NAME
  // ============================================================

  Future<void> _loadBusinessName() async {
    try {
      final businessName =
          await GABBranding.getBusinessName();

      if (!mounted) return;

      setState(() {
        _businessName =
            businessName.trim().isEmpty
                ? 'LalKhata'
                : businessName.trim();
      });
    } catch (e) {
      debugPrint(
        'Business name loading error: $e',
      );
    }
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> _loadDashboard() async {
    try {
      final productCount =
          await _repository.getProductCount();

      final supplierCount =
          await _supplierRepository
              .getSupplierCount();

      final customers =
          await _customerRepository
              .getCustomers();

      final customerCount =
          customers.length;

      final stockValue =
          await _repository
              .getTotalStockValue();

      final cashBalance =
          await _accountRepository
              .getBalanceByType("CASH");

      final bankBalance =
          await _accountRepository
              .getBalanceByType("BANK");

      final mobileBalance =
          await _accountRepository
              .getBalanceByType(
        "MOBILE_BANKING",
      );

      final totalBalance =
          await _accountRepository
              .getTotalBalance();

      // --------------------------------------------------------
      // CUSTOMER DUE
      // --------------------------------------------------------

      double customerDue = 0;

      for (final customer in customers) {
        customerDue += customer.balance;
      }

      // --------------------------------------------------------
      // SUPPLIER DUE
      // --------------------------------------------------------

      final suppliers =
          await _supplierRepository
              .getSuppliers();

      double supplierDue = 0;

      for (final supplier in suppliers) {
        supplierDue += supplier.balance;
      }

      if (!mounted) return;

      setState(() {
        _productCount = productCount;
        _supplierCount = supplierCount;
        _customerCount = customerCount;

        _stockValue = stockValue;

        _cashBalance = cashBalance;
        _bankBalance = bankBalance;
        _mobileBalance = mobileBalance;
        _totalBalance = totalBalance;

        _customerDue = customerDue;
        _supplierDue = supplierDue;
      });
    } catch (e) {
      debugPrint(
        'Dashboard loading error: $e',
      );
    }
  }

  // ============================================================
  // GREETING
  // ============================================================

  String get greeting {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Good Morning 👋";
    }

    if (hour < 17) {
      return "Good Afternoon ☀️";
    }

    return "Good Evening 🌙";
  }

  // ============================================================
  // MONEY FORMAT
  // ============================================================

  String formatMoney(double amount) {
    return amount.toStringAsFixed(2);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        centerTitle: true,
      ),

      // ========================================================
      // QUICK ACTION
      // ========================================================

      floatingActionButton:
          FloatingActionButton(
        onPressed: () async {
          await QuickActionSheet.show(
            context,
          );

          if (mounted) {
            await _loadDashboard();
          }
        },
        child: const Icon(
          Icons.add,
        ),
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,

      // ========================================================
      // BODY
      // ========================================================

      body: RefreshIndicator(
        onRefresh: () async {
          await _loadBusinessName();
          await _loadDashboard();
        },

        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.all(16),

          children: [

            // ==================================================
            // LALKHATA BRANDING
            // ==================================================

            Center(
              child: Column(
                children: [

                  // ------------------------------------------------
                  // APP NAME
                  // ------------------------------------------------

                  Text(
                    "LalKhata",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      foreground: Paint()
                        ..shader =
                            const LinearGradient(
                          colors: [
                            Color(0xFFE53935),
                            Color(0xFFB71C1C),
                          ],
                        ).createShader(
                          const Rect.fromLTWH(
                            0,
                            0,
                            180,
                            45,
                          ),
                        ),
                    ),
                  ),

                  const SizedBox(
                    height: 2,
                  ),

                  // ------------------------------------------------
                  // CUSTOMER / BUSINESS NAME
                  // ------------------------------------------------

                  Text(
                    _businessName.isEmpty
                        ? 'LalKhata'
                        : _businessName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            // ==================================================
            // GREETING
            // ==================================================

            Text(
              greeting,
              style: const TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // BALANCE SUMMARY
            // ==================================================

            Card(
              elevation: 0,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
                side: BorderSide(
                  color:
                      Colors.grey.shade300,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  children: [

                    // ----------------------------------------
                    // HEADER
                    // ----------------------------------------

                    Row(
                      children: [

                        Container(
                          padding:
                              const EdgeInsets.all(
                            10,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.blue.shade50,
                            borderRadius:
                                BorderRadius.circular(
                              10,
                            ),
                          ),
                          child: Icon(
                            Icons
                                .account_balance_wallet,
                            color:
                                Colors.blue.shade700,
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        const Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [

                            Text(
                              "Balance Summary",
                              style:
                                  TextStyle(
                                fontSize: 17,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            Text(
                              "Cash • Bank • Mobile Banking",
                              style:
                                  TextStyle(
                                fontSize: 12,
                                color:
                                    Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ----------------------------------------
                    // CASH / BANK
                    // ----------------------------------------

                    Row(
                      children: [

                        Expanded(
                          child:
                              _balanceTile(
                            "Cash",
                            _cashBalance,
                            Colors.green,
                          ),
                        ),

                        Expanded(
                          child:
                              _balanceTile(
                            "Bank",
                            _bankBalance,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ----------------------------------------
                    // MOBILE / TOTAL
                    // ----------------------------------------

                    Row(
                      children: [

                        Expanded(
                          child:
                              _balanceTile(
                            "Mobile",
                            _mobileBalance,
                            Colors.orange,
                          ),
                        ),

                        Expanded(
                          child:
                              _balanceTile(
                            "Total",
                            _totalBalance,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================================
            // CUSTOMER / SUPPLIER DUE
            // ==================================================

            Card(
              elevation: 2,
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Row(
                  children: [

                    // ------------------------------------------
                    // CUSTOMER DUE
                    // ------------------------------------------

                    Expanded(
                      child: Column(
                        children: [

                          const Text(
                            "Customer Due",
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            "৳ ${formatMoney(_customerDue)}",
                            style:
                                const TextStyle(
                              color:
                                  Colors.red,
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ------------------------------------------
                    // SUPPLIER DUE
                    // ------------------------------------------

                    Expanded(
                      child: Column(
                        children: [

                          const Text(
                            "Supplier Due",
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            "৳ ${formatMoney(_supplierDue)}",
                            style:
                                const TextStyle(
                              color:
                                  Colors.orange,
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================================
            // DASHBOARD ACTION GRID
            // ==================================================

GridView.count(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),

  crossAxisCount:
      MediaQuery.of(context).size.width >= 900
          ? 4
          : 2,

  crossAxisSpacing:
      MediaQuery.of(context).size.width >= 900
          ? 12
          : 15,

  mainAxisSpacing:
      MediaQuery.of(context).size.width >= 900
          ? 12
          : 15,

  childAspectRatio:
      MediaQuery.of(context).size.width >= 900
          ? 2.4
          : 1.35,

  children: [
    DashboardCard(
      icon: Icons.shopping_cart,
      title: "New Sale",
      value: null,
      color: Colors.orange,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddSaleScreen(),
          ),
        );

        await _loadDashboard();
      },
    ),

    DashboardCard(
      icon: Icons.folder_copy,
      title: "Records",
      value: "",
      color: Colors.indigo,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RecordsScreen(),
          ),
        );

        await _loadDashboard();
      },
    ),

    DashboardCard(
      icon: Icons.analytics,
      title: "Reports",
      value: "",
      color: Colors.deepPurple,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ReportsScreen(),
          ),
        );

        await _loadDashboard();
      },
    ),

    
    DashboardCard(
      icon: Icons.settings,
      title: "Settings",
      value: "",
      color: Colors.grey,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SettingsScreen(),
          ),
        );

        await _loadDashboard();
        await _loadBusinessName();
      },
    ),
  ],
),

            const SizedBox(
              height: 80,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BALANCE TILE
  // ============================================================

  Widget _balanceTile(
    String title,
    double amount,
    Color color,
  ) {
    return Column(
      children: [

        Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        Text(
          "৳ ${formatMoney(amount)}",
          style:
              TextStyle(
            color: color,
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
    );
  }
}