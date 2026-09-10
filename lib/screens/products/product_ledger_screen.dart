import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/product_ledger.dart';
import '../../services/product_repository.dart';

class ProductLedgerScreen extends StatefulWidget {
  final int productId;
  final String productName;

  const ProductLedgerScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<ProductLedgerScreen> createState() =>
      _ProductLedgerScreenState();
}

class _ProductLedgerScreenState
    extends State<ProductLedgerScreen> {
  final ProductRepository _repository =
      ProductRepository();

  List<ProductLedger> _ledger = [];

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
          await _repository.getProductLedger(
        widget.productId,
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
            'Failed to load product ledger: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // FILTERED LEDGER
  // ============================================================

  List<ProductLedger> get _filteredLedger {
    return _ledger.where((item) {
      final date = DateTime.tryParse(item.date);

      if (date == null) {
        return false;
      }

      // FROM DATE
      if (_fromDate != null) {
        final start = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
        );

        if (date.isBefore(start)) {
          return false;
        }
      }

      // TO DATE
      if (_toDate != null) {
        final end = DateTime(
          _toDate!.year,
          _toDate!.month,
          _toDate!.day,
          23,
          59,
          59,
          999,
        );

        if (date.isAfter(end)) {
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
  // PREVIOUS STOCK
  //
  // Stock before selected From Date.
  // ============================================================

  int _getPreviousStock() {
    if (_fromDate == null) {
      return 0;
    }

    final start = DateTime(
      _fromDate!.year,
      _fromDate!.month,
      _fromDate!.day,
    );

    int stock = 0;

    for (final item in _ledger) {
      final date =
          DateTime.tryParse(item.date);

      if (date == null) continue;

      if (date.isBefore(start)) {
        stock += item.stockIn;
        stock -= item.stockOut;
      }
    }

    return stock;
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return '-';
    }

    return DateFormat(
      'dd MMM yy',
    ).format(date);
  }

  // ============================================================
  // VOUCHER
  // ============================================================

  String _voucher(ProductLedger item) {
    final reference =
        item.reference.trim();

    if (reference.isNotEmpty) {
      return reference;
    }

    final particular =
        item.particular.trim();

    if (particular.isNotEmpty) {
      return particular;
    }

    return '-';
  }

  // ============================================================
  // STOCK CHANGE
  //
  // IN  -> +quantity
  // OUT -> -quantity
  // ============================================================

  int _stockChange(ProductLedger item) {
    return item.stockIn - item.stockOut;
  }

  String _stockChangeText(
    ProductLedger item,
  ) {
    final change = _stockChange(item);

    if (change > 0) {
      return '+$change';
    }

    if (change < 0) {
      return '$change';
    }

    return '0';
  }

  Color _stockChangeColor(
    ProductLedger item,
  ) {
    final change = _stockChange(item);

    if (change > 0) {
      return Colors.green;
    }

    if (change < 0) {
      return Colors.red;
    }

    return Colors.grey;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filteredLedger =
        _filteredLedger;

    // ==========================================================
    // TOTALS
    // ==========================================================

    int totalIn = 0;
    int totalOut = 0;

    for (final item in filteredLedger) {
      totalIn += item.stockIn;
      totalOut += item.stockOut;
    }

    // ==========================================================
    // PREVIOUS STOCK
    // ==========================================================

    final previousStock =
        _fromDate != null
            ? _getPreviousStock()
            : 0;

    // ==========================================================
    // CURRENT STOCK
    //
    // Calculate separately.
    // Do NOT mutate this value while building table rows.
    // ==========================================================

    int currentStock = previousStock;

    for (final item in filteredLedger) {
      currentStock += item.stockIn;
      currentStock -= item.stockOut;
    }

    // ==========================================================
    // TABLE RUNNING STOCK
    // ==========================================================

    int tableRunningStock = previousStock;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.productName} Ledger',
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

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
                  // PREVIOUS STOCK
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
                            BorderRadius
                                .circular(
                          8,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            'Previous Stock',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          Text(
                            '$previousStock',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              color:
                                  Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(
                    height: 8,
                  ),

                  // ==================================================
                  // LEDGER
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
                    )
                  else
                    SingleChildScrollView(
                      padding:
                          const EdgeInsets.all(
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
                                32,
                            horizontalMargin:
                                16,

                            headingRowColor:
                                WidgetStateProperty
                                    .all(
                              Colors
                                  .blue
                                  .shade100,
                            ),

                            // ==================================================
                            // 4 COLUMNS
                            // ==================================================

                            columns: const [
                              DataColumn(
                                label: Text(
                                  'Date',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),

                              DataColumn(
                                label: Text(
                                  'Voucher',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),

                              DataColumn(
                                numeric: true,
                                label: Text(
                                  'In / Out',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),

                              DataColumn(
                                numeric: true,
                                label: Text(
                                  'Stock',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),
                            ],

                            // ==================================================
                            // ROWS
                            // ==================================================

                            rows:
                                filteredLedger.map(
                              (item) {
                                // Apply transaction
                                // exactly once.
                                tableRunningStock +=
                                    item.stockIn;

                                tableRunningStock -=
                                    item.stockOut;

                                return DataRow(
                                  cells: [
                                    // ==============================
                                    // DATE
                                    // ==============================

                                    DataCell(
                                      Text(
                                        _formatDate(
                                          item.date,
                                        ),
                                      ),
                                    ),

                                    // ==============================
                                    // VOUCHER
                                    // ==============================

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
                                              BorderRadius
                                                  .circular(
                                            6,
                                          ),
                                        ),
                                        child:
                                            Text(
                                          _voucher(
                                            item,
                                          ),
                                          maxLines:
                                              1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                            color: Colors
                                                .blue,
                                            fontSize:
                                                12,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // ==============================
                                    // IN / OUT
                                    // ==============================

                                    DataCell(
                                      Text(
                                        _stockChangeText(
                                          item,
                                        ),
                                        style:
                                            TextStyle(
                                          color:
                                              _stockChangeColor(
                                            item,
                                          ),
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                    ),

                                    // ==============================
                                    // RUNNING STOCK
                                    // ==============================

                                    DataCell(
                                      Text(
                                        '$tableRunningStock',
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                          color: Colors
                                              .blue,
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

                  // ==================================================
                  // SUMMARY
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
                          children: [
                            // TOTAL IN

                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                const Text(
                                  'Total Stock In',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                Text(
                                  '+$totalIn',
                                  style:
                                      const TextStyle(
                                    color: Colors
                                        .green,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            // TOTAL OUT

                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                const Text(
                                  'Total Stock Out',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                Text(
                                  '-$totalOut',
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.red,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ],
                            ),

                            const Divider(
                              height: 20,
                            ),

                            // CURRENT STOCK

                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                const Text(
                                  'Current Stock',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        17,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                Text(
                                  '$currentStock',
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        19,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color:
                                        Colors
                                            .blue,
                                  ),
                                ),
                              ],
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