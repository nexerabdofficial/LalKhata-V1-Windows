import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../pdf/customer_ledger_pdf.dart';
import '../../models/customer_ledger.dart';
import '../../services/customer_repository.dart';

class CustomerLedgerScreen extends StatefulWidget {
  final int customerId;
  final String customerName;

  const CustomerLedgerScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState
    extends State<CustomerLedgerScreen> {
  final CustomerRepository _repository =
      CustomerRepository();

  final DateFormat _dateFormat =
      DateFormat('dd/MM/yyyy');

  List<CustomerLedger> _ledger = [];

  bool _loading = true;

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  // ============================================================
  // LOAD LEDGER
  // ============================================================

  Future<void> _loadLedger() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final result =
          await _repository.getCustomerLedger(
        widget.customerId,
      );

      if (!mounted) return;

      setState(() {
        _ledger = result;
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
            'Failed to load customer ledger: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // FILTERED LEDGER
  // ============================================================

  List<CustomerLedger> get _filteredLedger {
    return _ledger.where((item) {
      final date = DateTime.tryParse(
        item.date,
      );

      if (date == null) {
        return false;
      }

      if (_fromDate != null) {
        final startDate = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
        );

        if (date.isBefore(startDate)) {
          return false;
        }
      }

      if (_toDate != null) {
        final endDate = DateTime(
          _toDate!.year,
          _toDate!.month,
          _toDate!.day,
          23,
          59,
          59,
          999,
        );

        if (date.isAfter(endDate)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ============================================================
  // DATE PICKERS
  // ============================================================

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _fromDate = picked;
    });
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _toDate = picked;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  // ============================================================
  // PREVIOUS BALANCE
  // ============================================================

  double _getPreviousBalance() {
    if (_fromDate == null) {
      return 0;
    }

    final startDate = DateTime(
      _fromDate!.year,
      _fromDate!.month,
      _fromDate!.day,
    );

    double balance = 0;

    for (final item in _ledger) {
      final date =
          DateTime.tryParse(item.date);

      if (date == null) continue;

      if (date.isBefore(startDate)) {
        balance += item.debit;
        balance -= item.credit;
      }
    }

    return balance;
  }

  // ============================================================
  // MONEY
  // ============================================================

  String _formatMoney(double value) {
    return NumberFormat(
      '#,##0.##',
    ).format(value);
  }

  // ============================================================
  // VOUCHER
  // ============================================================

  String _voucher(CustomerLedger item) {
    final reference =
        item.reference.trim();

    if (reference.isNotEmpty) {
      return reference;
    }

    final particular =
        item.particular.trim();

    if (particular
        .toLowerCase()
        .contains('opening')) {
      return 'OB';
    }

    if (particular.isNotEmpty) {
      return particular;
    }

    return '-';
  }

  // ============================================================
  // AMOUNT
  // ============================================================

  String _amountText(
    CustomerLedger item,
  ) {
    if (item.debit > 0) {
      return '+৳${_formatMoney(item.debit)}';
    }

    if (item.credit > 0) {
      return '-৳${_formatMoney(item.credit)}';
    }

    return '৳0';
  }

  Color _amountColor(
    CustomerLedger item,
  ) {
    if (item.debit > 0) {
      return Colors.green;
    }

    if (item.credit > 0) {
      return Colors.red;
    }

    return Colors.grey;
  }

  // ============================================================
  // TRANSACTION BALANCE
  // ============================================================

  double _balanceAfterTransaction(
    double balance,
    CustomerLedger item,
  ) {
    balance += item.debit;
    balance -= item.credit;

    return balance;
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              'Date',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              'Voucher',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Amount',
              textAlign:
                  TextAlign.right,
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 105,
            child: Text(
              'Balance',
              textAlign:
                  TextAlign.right,
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TRANSACTION ROW
  // ============================================================

  Widget _buildTransactionRow(
    CustomerLedger item,
    double balance,
  ) {
    final date =
        DateTime.tryParse(item.date);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(
                date == null
                    ? '-'
                    : DateFormat(
                        'dd/MM/yy',
                      ).format(date),
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(width: 2),

            SizedBox(
              width: 72,
              child: Text(
                _voucher(item),
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),

            Expanded(
              child: Text(
                _amountText(item),
                textAlign:
                    TextAlign.right,
                style: TextStyle(
                  color:
                      _amountColor(item),
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 8),

            SizedBox(
              width: 105,
              child: Text(
                '৳${_formatMoney(balance)}',
                textAlign:
                    TextAlign.right,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PREVIOUS BALANCE
  // ============================================================

  Widget _buildPreviousBalance(
    double balance,
  ) {
    if (_fromDate == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Previous Balance',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          Text(
            '৳${_formatMoney(balance)}',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
              color: balance > 0
                  ? Colors.red
                  : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary({
    required double totalSales,
    required double totalReceived,
    required double currentDue,
  }) {
    return Card(
      margin: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        6,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          children: [
            _summaryRow(
              'Total Sales',
              totalSales,
            ),

            const SizedBox(height: 6),

            _summaryRow(
              'Total Received',
              totalReceived,
            ),

            const Divider(height: 20),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Text(
                  'Current Due',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                Text(
                  '৳${_formatMoney(currentDue)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                    color: currentDue > 0
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String title,
    double value,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        Text(
          '৳${_formatMoney(value)}',
          style: const TextStyle(
            fontWeight:
                FontWeight.w600,
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
    final filteredLedger =
        _filteredLedger;

    double totalSales = 0;
    double totalReceived = 0;

    for (final item in filteredLedger) {
      // Opening entry isn't part of period totals.
      final particular =
          item.particular
              .trim()
              .toLowerCase();

      final reference =
          item.reference
              .trim()
              .toLowerCase();

      final isOpening =
          particular.contains('opening') ||
              reference == 'opening' ||
              reference == 'ob';

      if (isOpening) continue;

      totalSales += item.debit;
      totalReceived += item.credit;
    }

    // ==========================================================
    // TABLE BALANCE
    // ==========================================================

    double tableRunningBalance =
        _fromDate != null
            ? _getPreviousBalance()
            : 0;

    // ==========================================================
    // CURRENT DUE
    // ==========================================================

    double currentDue =
        tableRunningBalance;

    for (final item in filteredLedger) {
      final particular =
          item.particular
              .trim()
              .toLowerCase();

      final reference =
          item.reference
              .trim()
              .toLowerCase();

      final isOpening =
          particular.contains('opening') ||
              reference == 'opening' ||
              reference == 'ob';

      if (isOpening) continue;

      currentDue =
          _balanceAfterTransaction(
        currentDue,
        item,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.customerName} Ledger',
        ),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(
              Icons.picture_as_pdf,
            ),
            onPressed:
                _loading ||
                        filteredLedger.isEmpty
                    ? null
                    : () async {
                        await CustomerLedgerPdf
                            .generate(
                          customerName:
                              widget.customerName,
                          ledger:
                              filteredLedger,
                          fromDate:
                              _fromDate,
                          toDate:
                              _toDate,

                          // IMPORTANT:
                          // Correct parameter name.
                          previousBalance:
                              _fromDate != null
                                  ? _getPreviousBalance()
                                  : 0,
                        );
                      },
          ),
        ],
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadLedger,
              child: ListView(
                padding:
                    const EdgeInsets.only(
                  bottom: 24,
                ),
                children: [
                  // ==================================================
                  // DATE FILTER
                  // ==================================================

                  Padding(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child:
                              OutlinedButton.icon(
                            icon:
                                const Icon(
                              Icons
                                  .calendar_today,
                              size: 18,
                            ),
                            label: Text(
                              _fromDate ==
                                      null
                                  ? 'From'
                                  : DateFormat(
                                      'dd MMM yyyy',
                                    ).format(
                                      _fromDate!,
                                    ),
                            ),
                            onPressed:
                                _selectFromDate,
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Expanded(
                          child:
                              OutlinedButton.icon(
                            icon:
                                const Icon(
                              Icons
                                  .calendar_today,
                              size: 18,
                            ),
                            label: Text(
                              _toDate ==
                                      null
                                  ? 'To'
                                  : DateFormat(
                                      'dd MMM yyyy',
                                    ).format(
                                      _toDate!,
                                    ),
                            ),
                            onPressed:
                                _selectToDate,
                          ),
                        ),

                        IconButton(
                          tooltip:
                              'Clear Filter',
                          icon:
                              const Icon(
                            Icons.refresh,
                          ),
                          onPressed:
                              _clearDateFilter,
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // PREVIOUS BALANCE
                  // ==================================================

                  _buildPreviousBalance(
                    _fromDate != null
                        ? _getPreviousBalance()
                        : 0,
                  ),

                  // ==================================================
                  // SUMMARY
                  // ==================================================

                  _buildSummary(
                    totalSales:
                        totalSales,
                    totalReceived:
                        totalReceived,
                    currentDue:
                        currentDue,
                  ),

                  // ==================================================
                  // HEADER
                  // ==================================================

                  _buildHeader(),

                  // ==================================================
                  // NO DATA
                  // ==================================================

                  if (filteredLedger.isEmpty)
                    const Padding(
                      padding:
                          EdgeInsets.all(30),
                      child: Center(
                        child: Text(
                          'No Ledger Found',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                  // ==================================================
                  // TRANSACTION ROWS
                  // ==================================================

                  ...List.generate(
                    filteredLedger.length,
                    (index) {
                      final item =
                          filteredLedger[
                              index];

                      final particular =
                          item.particular
                              .trim()
                              .toLowerCase();

                      final reference =
                          item.reference
                              .trim()
                              .toLowerCase();

                      final isOpening =
                          particular.contains(
                                'opening',
                              ) ||
                              reference ==
                                  'opening' ||
                              reference ==
                                  'ob';

                      if (!isOpening) {
                        tableRunningBalance =
                            _balanceAfterTransaction(
                          tableRunningBalance,
                          item,
                        );
                      }

                      return _buildTransactionRow(
                        item,
                        tableRunningBalance,
                      );
                    },
                  ),

                  // ==================================================
                  // TOTAL CARD
                  // ==================================================

                  if (filteredLedger.isNotEmpty)
                    Card(
                      margin:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 12,
                      ),
                      child: Padding(
                        padding:
                            const EdgeInsets
                                .all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .end,
                          children: [
                            Text(
                              'Debit: ৳${_formatMoney(totalSales)}',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.red,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              'Credit: ৳${_formatMoney(totalReceived)}',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.green,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
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