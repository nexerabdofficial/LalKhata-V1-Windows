import 'package:flutter/material.dart';

import '../../gab/gab_branding.dart';
import '../../services/account_repository.dart';
import '../../services/customer_repository.dart';
import '../../services/product_repository.dart';
import '../../services/supplier_repository.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() =>
      _BalanceSheetScreenState();
}

class _BalanceSheetScreenState
    extends State<BalanceSheetScreen> {
  final ProductRepository _productRepository =
      ProductRepository();

  final AccountRepository _accountRepository =
      AccountRepository();

  final CustomerRepository _customerRepository =
      CustomerRepository();

  final SupplierRepository _supplierRepository =
      SupplierRepository();

  bool _loading = true;

  double _cash = 0;
  double _stock = 0;
  double _customerDue = 0;
  double _supplierDue = 0;

  @override
  void initState() {
    super.initState();
    _loadBalanceSheet();
  }

  Future<void> _loadBalanceSheet() async {
    try {
      final results = await Future.wait<double>([
        _accountRepository.getTotalBalance(),
        _productRepository.getTotalStockValue(),
        _customerRepository.getTotalDue(),
        _supplierRepository.getTotalDue(),
      ]);

      if (!mounted) return;

      setState(() {
        _cash = results[0];
        _stock = results[1];
        _customerDue = results[2];
        _supplierDue = results[3];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load balance sheet: $e',
          ),
        ),
      );
    }
  }

  String _money(double value) {
    return '৳ ${value.toStringAsFixed(2)}';
  }

  Widget _amountRow(
    String title,
    double amount, {
    IconData? icon,
    Color? color,
    bool bold = false,
  }) {
    final rowColor = color ?? Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 11,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: rowColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: rowColor,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: bold ? 17 : 15,
                fontWeight: bold
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ),
          Text(
            _money(amount),
            style: TextStyle(
              fontSize: bold ? 17 : 15,
              fontWeight: FontWeight.bold,
              color: rowColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
    required Color color,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          18,
          18,
          18,
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color:
                        color.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    title == 'ASSETS'
                        ? Icons.account_balance_wallet_rounded
                        : Icons.account_balance_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),

            ...children,
          ],
        ),
      ),
    );
  }

  Widget _totalCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 27,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _money(amount),
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: color,
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

  Widget _header() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Balance Sheet',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Current financial position',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            Opacity(
              opacity: 0.12,
              child: Text(
                GABBranding.businessName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAssets =
        _cash + _stock + _customerDue;

    final totalLiabilities = _supplierDue;

    final netPosition =
        totalAssets - totalLiabilities;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Balance Sheet',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading
                ? null
                : _loadBalanceSheet,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadBalanceSheet,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  30,
                ),
                children: [
                  _header(),

                  const SizedBox(height: 15),

                  // ==========================
                  // ASSETS
                  // ==========================

                  _sectionCard(
                    title: 'ASSETS',
                    subtitle:
                        'What the business owns',
                    color: Colors.green.shade700,
                    children: [
                      _amountRow(
                        'Cash & Bank',
                        _cash,
                        icon:
                            Icons.account_balance_wallet_rounded,
                        color:
                            Colors.green.shade700,
                      ),
                      _amountRow(
                        'Inventory / Stock',
                        _stock,
                        icon:
                            Icons.inventory_2_rounded,
                        color:
                            Colors.deepPurple.shade600,
                      ),
                      _amountRow(
                        'Customer Receivables',
                        _customerDue,
                        icon:
                            Icons.people_alt_rounded,
                        color:
                            Colors.orange.shade700,
                      ),

                      const Divider(),

                      _amountRow(
                        'Total Assets',
                        totalAssets,
                        bold: true,
                        color:
                            Colors.green.shade800,
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // ==========================
                  // LIABILITIES
                  // ==========================

                  _sectionCard(
                    title: 'LIABILITIES',
                    subtitle:
                        'What the business owes',
                    color: Colors.red.shade700,
                    children: [
                      _amountRow(
                        'Supplier Payables',
                        _supplierDue,
                        icon:
                            Icons.local_shipping_rounded,
                        color:
                            Colors.red.shade700,
                      ),

                      const Divider(),

                      _amountRow(
                        'Total Liabilities',
                        totalLiabilities,
                        bold: true,
                        color:
                            Colors.red.shade800,
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // ==========================
                  // NET POSITION
                  // ==========================

                  _totalCard(
                    title:
                        'NET BUSINESS POSITION',
                    amount: netPosition,
                    color: netPosition >= 0
                        ? Colors.blue.shade700
                        : Colors.red.shade700,
                    icon:
                        netPosition >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                  ),

                  const SizedBox(height: 15),

                  // ==========================
                  // ACCOUNTING EQUATION
                  // ==========================

                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Accounting Position',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Assets − Liabilities = Net Business Position',
                            style: TextStyle(
                              color:
                                  Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(height: 15),

                          _amountRow(
                            'Total Assets',
                            totalAssets,
                          ),

                          _amountRow(
                            'Less: Liabilities',
                            totalLiabilities,
                            color:
                                Colors.red.shade700,
                          ),

                          const Divider(),

                          _amountRow(
                            'Net Position',
                            netPosition,
                            bold: true,
                            color: netPosition >= 0
                                ? Colors.blue.shade700
                                : Colors.red.shade700,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}