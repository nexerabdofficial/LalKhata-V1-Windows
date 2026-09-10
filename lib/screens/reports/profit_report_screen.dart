import 'package:flutter/material.dart';
import '../../gab/gab_branding.dart';

import '../../services/profit_repository.dart';
import '../../services/product_repository.dart';
import '../../services/account_repository.dart';
import '../../services/customer_repository.dart';
import '../../services/supplier_repository.dart';

class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  State<ProfitReportScreen> createState() =>
      _ProfitReportScreenState();
}

class _ProfitReportScreenState
    extends State<ProfitReportScreen> {
  final ProfitRepository _profitRepository =
      ProfitRepository();

  final ProductRepository _productRepository =
      ProductRepository();

  final AccountRepository _accountRepository =
      AccountRepository();

  final CustomerRepository _customerRepository =
      CustomerRepository();

  final SupplierRepository _supplierRepository =
      SupplierRepository();

  DateTime _fromDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _toDate = DateTime.now();

  double totalSales = 0;
  double totalExpense = 0;
  double totalIncome = 0;
  double totalStockValue = 0;
  double cashBalance = 0;
  double customerDue = 0;
  double supplierDue = 0;
  double totalCogs = 0;
  double grossProfit = 0;
  double netProfit = 0;

  bool loading = true;

  // ============================================================
  // PROFIT MARGIN
  // ============================================================

  double get profitMargin {
    if (totalSales <= 0) return 0;

    return (grossProfit / totalSales) * 100;
  }

  double get netProfitMargin {
    if (totalSales <= 0) return 0;

    return (netProfit / totalSales) * 100;
  }

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ============================================================
  // DATE PICKERS
  // ============================================================

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    if (picked.isAfter(_toDate)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('From date cannot be later than To date.'),
        ),
      );

      return;
    }

    setState(() {
      _fromDate = picked;
      loading = true;
    });

    await _loadReport();
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    if (picked.isBefore(_fromDate)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('To date cannot be earlier than From date.'),
        ),
      );

      return;
    }

    setState(() {
      _toDate = picked;
      loading = true;
    });

    await _loadReport();
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<void> _loadReport() async {
    try {
      final from = _fromDate;

      final to = DateTime(
        _toDate.year,
        _toDate.month,
        _toDate.day,
        23,
        59,
        59,
        999,
      );

      final results = await Future.wait<double>([
        _profitRepository.getTotalSales(
          from: from,
          to: to,
        ),
        _profitRepository.getCostOfGoodsSold(
          from: from,
          to: to,
        ),
        _profitRepository.getGrossProfit(
          from: from,
          to: to,
        ),
        _profitRepository.getTotalIncome(
          from: from,
          to: to,
        ),
        _profitRepository.getTotalExpense(
          from: from,
          to: to,
        ),
        _profitRepository.getNetProfit(
          from: from,
          to: to,
        ),
        _productRepository.getTotalStockValue(),
        _customerRepository.getTotalDue(),
        _supplierRepository.getTotalDue(),
        _accountRepository.getTotalBalance(),
      ]);

      if (!mounted) return;

      setState(() {
        totalSales = results[0];
        totalCogs = results[1];
        grossProfit = results[2];
        totalIncome = results[3];
        totalExpense = results[4];
        netProfit = results[5];
        totalStockValue = results[6];
        customerDue = results[7];
        supplierDue = results[8];
        cashBalance = results[9];

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to load profit report: $e'),
        ),
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _money(double value) {
    return '৳ ${value.toStringAsFixed(2)}';
  }

  // ============================================================
  // DATE BUTTON
  // ============================================================

  Widget _dateButton({
    required String label,
    required DateTime date,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(
          Icons.calendar_month_rounded,
          size: 19,
        ),
        label: Text(
          '$label\n${_formatDate(date)}',
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          minimumSize:
              const Size(0, 58),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard(
    String title,
    double value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 1.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(
                color:
                    color.withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _money(value),
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
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
    );
  }

  // ============================================================
  // PROFIT MARGIN CARD
  // ============================================================

  Widget _profitMarginCard() {
    final positive = netProfit >= 0;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Profit Analysis',
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _marginItem(
                    'Gross Margin',
                    profitMargin,
                    Colors.blue,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _marginItem(
                    'Net Margin',
                    netProfitMargin,
                    positive
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              'Gross Margin = Gross Profit ÷ Sales × 100',
              style: TextStyle(
                fontSize: 11,
                color:
                    Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Net Margin = Net Profit ÷ Sales × 100',
              style: TextStyle(
                fontSize: 11,
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _marginItem(
    String title,
    double value,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.06),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            '${value.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 23,
              fontWeight:
                  FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFIT RESULT
  // ============================================================

  Widget _profitResultCard() {
    final isProfit = netProfit >= 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isProfit
                        ? 'NET PROFIT'
                        : 'NET LOSS',
                    style:
                        const TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                Icon(
                  isProfit
                      ? Icons
                          .trending_up_rounded
                      : Icons
                          .trending_down_rounded,
                  color: isProfit
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  size: 30,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                _money(netProfit),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
                  color: isProfit
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                ),
              ),
            ),

            const SizedBox(height: 6),

            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                'Net Margin: '
                '${netProfitMargin.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // P&L STATEMENT
  // ============================================================

  Widget _statementRow(
    String title,
    double amount, {
    bool bold = false,
    Color? amountColor,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 9,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize:
                    bold ? 17 : 15,
                fontWeight: bold
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Text(
            _money(amount),
            textAlign:
                TextAlign.right,
            style: TextStyle(
              fontSize:
                  bold ? 18 : 15,
              fontWeight:
                  FontWeight.bold,
              color: amountColor ??
                  Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statementCard() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          18,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Profit & Loss Statement',
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              'For the period '
              '${_formatDate(_fromDate)}'
              ' – '
              '${_formatDate(_toDate)}',
              style:
                  const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'INCOME',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 5),

            _statementRow(
              'Sales',
              totalSales,
              amountColor:
                  Colors.green.shade600,
            ),

            _statementRow(
              'Other Income',
              totalIncome,
              amountColor:
                  Colors.teal.shade600,
            ),

            const Divider(height: 22),

            _statementRow(
              'Total Income',
              totalSales +
                  totalIncome,
              bold: true,
              amountColor:
                  Colors.green.shade700,
            ),

            const SizedBox(height: 15),

            const Text(
              'COST OF SALES',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 5),

            _statementRow(
              'Cost of Goods Sold',
              totalCogs,
              amountColor:
                  Colors.orange.shade700,
            ),

            const Divider(height: 22),

            _statementRow(
              'Gross Profit',
              grossProfit,
              bold: true,
              amountColor:
                  Colors.blue.shade600,
            ),

            const SizedBox(height: 15),

            const Text(
              'OPERATING EXPENSES',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 5),

            _statementRow(
              'Operating Expenses',
              totalExpense,
              amountColor:
                  Colors.red.shade600,
            ),

            const Divider(height: 22),

            _statementRow(
              'Profit After Expenses',
              netProfit,
              bold: true,
              amountColor:
                  netProfit >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
            ),

            const SizedBox(height: 18),

            _profitResultCard(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REPORT HEADER
  // ============================================================

  Widget _reportHeader() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profit & Loss',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        'Business Financial Statement',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
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
                      fontSize: 21,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: 2,
                      color:
                          Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                _dateButton(
                  label: 'From',
                  date: _fromDate,
                  onPressed:
                      _pickFromDate,
                ),

                const SizedBox(width: 10),

                _dateButton(
                  label: 'To',
                  date: _toDate,
                  onPressed:
                      _pickToDate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUSINESS SNAPSHOT
  // ============================================================

  Widget _businessSnapshot() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(
            left: 2,
            top: 22,
            bottom: 10,
          ),
          child: const Text(
            'Business Snapshot',
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        Center(
          child: Text(
            'Current business position',
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ),

        const SizedBox(height: 12),

        GridView.count(
          shrinkWrap: true,
          primary: false,
          physics:
              const NeverScrollableScrollPhysics(),
          crossAxisCount:
              MediaQuery.of(context)
                          .size
                          .width >
                      700
                  ? 4
                  : 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.05,
          children: [
            _summaryCard(
              'Cash Balance',
              cashBalance,
              Icons
                  .account_balance_wallet_rounded,
              Colors.green,
            ),

            _summaryCard(
              'Stock Value',
              totalStockValue,
              Icons
                  .inventory_2_rounded,
              Colors.deepPurple,
            ),

            _summaryCard(
              'Customer Due',
              customerDue,
              Icons.people_alt_rounded,
              Colors.orange,
            ),

            _summaryCard(
              'Supplier Due',
              supplierDue,
              Icons.local_shipping_rounded,
              Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // NO DATA
  // ============================================================

  Widget _noDataView() {
    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        _reportHeader(),

        const SizedBox(height: 30),

        Center(
          child: Column(
            children: [
              Icon(
                Icons
                    .receipt_long_outlined,
                size: 64,
                color:
                    Colors.grey.shade400,
              ),

              const SizedBox(height: 14),

              const Text(
                'No data available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'There is no financial activity '
                'for the selected period.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final hasData =
        totalSales != 0 ||
        totalCogs != 0 ||
        totalIncome != 0 ||
        totalExpense != 0;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Profit Statement',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: hasData
                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.fromLTRB(
                        12,
                        8,
                        12,
                        28,
                      ),
                      children: [
                        _reportHeader(),

                        Padding(
                          padding:
                              const EdgeInsets.only(
                            left: 2,
                            top: 22,
                            bottom: 10,
                          ),
                          child: const Text(
                            'Income Statement',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),

                        _statementCard(),

                        const SizedBox(height: 12),

                        _profitMarginCard(),

                        _businessSnapshot(),
                      ],
                    )
                  : _noDataView(),
            ),
    );
  }
}