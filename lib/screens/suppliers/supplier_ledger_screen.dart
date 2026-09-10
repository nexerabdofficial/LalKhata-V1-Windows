import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../pdf/supplier_ledger_pdf.dart';
import '../../models/supplier_ledger.dart';
import '../../services/supplier_repository.dart';

class SupplierLedgerScreen extends StatefulWidget {
  final int supplierId;
  final String supplierName;

  const SupplierLedgerScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<SupplierLedgerScreen> createState() =>
      _SupplierLedgerScreenState();
}

class _SupplierLedgerScreenState
    extends State<SupplierLedgerScreen> {
  final SupplierRepository _repository =
      SupplierRepository();

  List<SupplierLedger> _ledger = [];

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
    setState(() {
      _loading = true;
    });

    try {
      final result =
          await _repository.getSupplierLedger(
        widget.supplierId,
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
            "Failed to load supplier ledger: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // FILTER LEDGER
  // ============================================================

  List<SupplierLedger> get _filteredLedger {
    return _ledger.where((item) {
      final date = DateTime.tryParse(item.date);

      if (date == null) {
        return false;
      }

      // FROM DATE
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

      // TO DATE
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
  // PREVIOUS BALANCE
  //
  // If From Date is selected:
  // calculate all transactions BEFORE From Date.
  //
  // Supplier logic:
  // Purchase  = Debit  (+)
  // Payment   = Credit (-)
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
      final date = DateTime.tryParse(item.date);

      if (date == null) continue;

      if (date.isBefore(startDate)) {
        balance += item.debit;
        balance -= item.credit;
      }
    }

    return balance;
  }

  // ============================================================
  // SELECT FROM DATE
  // ============================================================

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _fromDate = picked;
    });
  }

  // ============================================================
  // SELECT TO DATE
  // ============================================================

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _toDate = picked;
    });
  }

  // ============================================================
  // CLEAR FILTER
  // ============================================================

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filteredLedger = _filteredLedger;

    // ----------------------------------------------------------
    // TOTALS
    // ----------------------------------------------------------

    double totalPurchases = 0;
    double totalPaid = 0;

    for (final item in filteredLedger) {
      totalPurchases += item.debit;
      totalPaid += item.credit;
    }

    // ----------------------------------------------------------
    // RUNNING BALANCE
    //
    // IMPORTANT:
    // Start from Previous Balance only when From Date exists.
    //
    // Otherwise start from 0.
    //
    // Every filtered transaction is applied exactly once.
    // ----------------------------------------------------------

    double runningBalance =
        _fromDate != null
            ? _getPreviousBalance()
            : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.supplierName} Ledger",
        ),
        actions: [
          IconButton(
            tooltip: "Export PDF",
            icon: const Icon(
              Icons.picture_as_pdf,
            ),
            onPressed: filteredLedger.isEmpty
                ? null
                : () async {
                    await SupplierLedgerPdf.generate(
  supplierName: widget.supplierName,
  ledger: filteredLedger,
  fromDate: _fromDate,
  toDate: _toDate,
  openingBalance: _fromDate != null
      ? _getPreviousBalance()
      : 0,
);
                  },
          ),
        ],
      ),

      // ============================================================
      // BODY
      // ============================================================

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                // ==================================================
                // DATE FILTER
                // ==================================================

                Padding(
                  padding:
                      const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            OutlinedButton.icon(
                          icon:
                              const Icon(
                            Icons.calendar_today,
                            size: 18,
                          ),
                          label: Text(
                            _fromDate == null
                                ? "From"
                                : DateFormat(
                                    "dd MMM yyyy",
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
                            Icons.calendar_today,
                            size: 18,
                          ),
                          label: Text(
                            _toDate == null
                                ? "To"
                                : DateFormat(
                                    "dd MMM yyyy",
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
                            "Clear Filter",
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

                if (_fromDate != null)
                  Container(
                    width:
                        double.infinity,
                    margin:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.blue.shade50,
                      borderRadius:
                          BorderRadius.circular(
                        8,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                      children: [
                        const Text(
                          "Previous Balance",
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        Text(
                          "৳${_getPreviousBalance().toStringAsFixed(0)}",
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            color:
                                _getPreviousBalance() >
                                        0
                                    ? Colors.red
                                    : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ==================================================
                // LEDGER TABLE
                // ==================================================

                Expanded(
                  child:
                      filteredLedger.isEmpty
                          ? const Center(
                              child: Text(
                                "No Ledger Found",
                                style:
                                    TextStyle(
                                  color:
                                      Colors.grey,
                                  fontSize:
                                      16,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              padding:
                                  const EdgeInsets
                                      .all(
                                12,
                              ),
                              child: Card(
                                elevation: 3,
                                child:
                                    SingleChildScrollView(
                                  scrollDirection:
                                      Axis.horizontal,
                                  child:
                                      DataTable(
                                    columnSpacing:
                                        30,
                                    horizontalMargin:
                                        16,
                                    headingRowColor:
                                        WidgetStateProperty
                                            .all(
                                      Colors.blue
                                          .shade100,
                                    ),
                                    columns:
                                        const [
                                      DataColumn(
                                        label:
                                            Text(
                                          "Date",
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label:
                                            Text(
                                          "Voucher",
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        numeric:
                                            true,
                                        label:
                                            Text(
                                          "Amount",
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        numeric:
                                            true,
                                        label:
                                            Text(
                                          "Balance",
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ),
                                    ],

                                    rows:
                                        filteredLedger
                                            .map(
                                      (item) {
                                        final date =
                                            DateTime
                                                .tryParse(
                                          item.date,
                                        );

                                        // =================================
                                        // APPLY TRANSACTION ONCE
                                        // =================================

                                        runningBalance +=
                                            item.debit;

                                        runningBalance -=
                                            item.credit;

                                        return DataRow(
                                          cells: [
                                            // =============================
                                            // DATE
                                            // =============================

                                            DataCell(
                                              Text(
                                                date ==
                                                        null
                                                    ? "-"
                                                    : DateFormat(
                                                        "dd MMM yy",
                                                      ).format(
                                                        date,
                                                      ),
                                              ),
                                            ),

                                            // =============================
                                            // VOUCHER
                                            // =============================

                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                  horizontal:
                                                      8,
                                                  vertical:
                                                      4,
                                                ),
                                                decoration:
                                                    BoxDecoration(
                                                  color: Colors
                                                      .blue
                                                      .shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    6,
                                                  ),
                                                ),
                                                child:
                                                    Text(
                                                  item.reference
                                                          .isEmpty
                                                      ? item.particular
                                                      : item.reference,
                                                  maxLines:
                                                      1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color:
                                                        Colors.blue,
                                                    fontSize:
                                                        12,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // =============================
                                            // AMOUNT
                                            // =============================

                                            DataCell(
                                              Text(
                                                item.debit >
                                                        0
                                                    ? "+৳${item.debit.toStringAsFixed(0)}"
                                                    : item.credit >
                                                            0
                                                        ? "-৳${item.credit.toStringAsFixed(0)}"
                                                        : "৳0",
                                                style:
                                                    TextStyle(
                                                  color:
                                                      item.debit >
                                                              0
                                                          ? Colors.green
                                                          : item.credit >
                                                                  0
                                                              ? Colors.red
                                                              : Colors.grey,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                            ),

                                            // =============================
                                            // BALANCE
                                            // =============================

                                            DataCell(
                                              Text(
                                                "৳${runningBalance.toStringAsFixed(0)}",
                                                style:
                                                    TextStyle(
                                                  color:
                                                      runningBalance >
                                                              0
                                                          ? Colors.blue
                                                          : runningBalance <
                                                                  0
                                                              ? Colors.red
                                                              : Colors.grey,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ).toList(),
                                  ),
                                ),
                              ),
                            ),
                ),
              ],
            ),

      // ============================================================
      // SUMMARY
      // ============================================================

      bottomNavigationBar:
          !_loading &&
                  filteredLedger.isNotEmpty
              ? Container(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  color:
                      Colors.blue.shade50,
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      // ==================================================
                      // TOTAL PURCHASES
                      // ==================================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            "Total Purchases",
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            "৳${totalPurchases.toStringAsFixed(0)}",
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      // ==================================================
                      // TOTAL PAID
                      // ==================================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            "Total Paid",
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            "৳${totalPaid.toStringAsFixed(0)}",
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const Divider(
                        height: 20,
                      ),

                      // ==================================================
                      // CURRENT DUE
                      // ==================================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            "Current Due",
                            style:
                                TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            "৳${runningBalance.toStringAsFixed(0)}",
                            style:
                                TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  runningBalance >
                                          0
                                      ? Colors.red
                                      : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : null,
    );
  }
}