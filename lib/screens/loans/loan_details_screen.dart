import 'package:flutter/material.dart';

import '../../models/loan.dart';
import '../../models/loan_payment.dart';
import '../../services/loan_service.dart';
import 'add_loan_payment_screen.dart';

class LoanDetailsScreen extends StatefulWidget {
  final Loan loan;

  const LoanDetailsScreen({
    super.key,
    required this.loan,
  });

  @override
  State<LoanDetailsScreen> createState() =>
      _LoanDetailsScreenState();
}

class _LoanDetailsScreenState
    extends State<LoanDetailsScreen> {
  final LoanService _loanService =
      LoanService.instance;

  List<LoanPayment> _payments = [];

  bool _loading = true;

  late Loan _loan;

  @override
  void initState() {
    super.initState();

    _loan = widget.loan;

    _loadDetails();
  }

  // ============================================================
  // LOAD LOAN DETAILS
  // ============================================================

  Future<void> _loadDetails() async {
    try {
      setState(() {
        _loading = true;
      });

      final loanId = _loan.id;

      if (loanId == null) {
        return;
      }

      final latestLoan =
          await _loanService.getLoanById(loanId);

      final payments =
          await _loanService.getLoanPayments(loanId);

      if (!mounted) return;

      setState(() {
        if (latestLoan != null) {
          _loan = latestLoan;
        }

        _payments = payments;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Loan details loading error: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load loan details: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // ADD PAYMENT
  // ============================================================

  Future<void> _addPayment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLoanPaymentScreen(
          loan: _loan,
        ),
      ),
    );

    if (result == true) {
      await _loadDetails();
    }
  }

  // ============================================================
  // DELETE LOAN
  // ============================================================

  Future<void> _deleteLoan() async {
    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Loan?',
          ),
          content: const Text(
            'This will permanently delete this loan '
            'and all related payment records.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      final loanId = _loan.id;

      if (loanId == null) {
        return;
      }

      await _loanService.deleteLoan(
        loanId,
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Loan deleted successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete loan: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // FORMAT MONEY
  // ============================================================

  String _money(double amount) {
    return '৳ ${amount.toStringAsFixed(2)}';
  }

  // ============================================================
  // LOAN TYPE
  // ============================================================

  bool get _isGiven {
    final type =
        _loan.loanType.toUpperCase();

    return type == 'GIVEN' ||
        type == 'LOAN_GIVEN';
  }

  String get _loanTypeText {
    return _isGiven
        ? 'Loan Given'
        : 'Loan Taken';
  }

  // ============================================================
  // STATUS
  // ============================================================

  bool get _isCompleted {
    final status =
        _loan.status.toUpperCase();

    return status == 'PAID' ||
        status == 'COMPLETED';
  }

  Color get _statusColor {
    if (_isCompleted) {
      return Colors.green;
    }

    return Colors.orange;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final remaining =
        _loan.remainingPrincipal;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Loan Details',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Delete Loan',
            icon: const Icon(
              Icons.delete_outline,
            ),
            onPressed: _deleteLoan,
          ),
        ],
      ),

      floatingActionButton:
          _isCompleted
              ? null
              : FloatingActionButton.extended(
                  onPressed: _addPayment,
                  icon: const Icon(
                    Icons.payments,
                  ),
                  label: const Text(
                    'Add Payment',
                  ),
                ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.all(16),
                children: [

                  // ==================================================
                  // PERSON HEADER
                  // ==================================================

                  Card(
                    elevation: 2,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        18,
                      ),
                      child: Column(
                        children: [

                          CircleAvatar(
                            radius: 30,
                            backgroundColor:
                                _isGiven
                                    ? Colors.orange
                                        .withOpacity(
                                        .12,
                                      )
                                    : Colors.blue
                                        .withOpacity(
                                        .12,
                                      ),
                            child: Icon(
                              _isGiven
                                  ? Icons
                                      .arrow_upward
                                  : Icons
                                      .arrow_downward,
                              size: 32,
                              color: _isGiven
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          Text(
                            _loan.personName,
                            style:
                                const TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                            textAlign:
                                TextAlign.center,
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          Text(
                            _loanTypeText,
                            style:
                                TextStyle(
                              color:
                                  _isGiven
                                      ? Colors.orange
                                      : Colors.blue,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          if (_loan.phone != null &&
                              _loan.phone!
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(
                              height: 8,
                            ),
                            Text(
                              _loan.phone!,
                              style:
                                  TextStyle(
                                color: Colors
                                    .grey
                                    .shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // SUMMARY
                  // ==================================================

                  Card(
                    elevation: 1,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        18,
                      ),
                      child: Column(
                        children: [

                          const Align(
                            alignment:
                                Alignment
                                    .centerLeft,
                            child: Text(
                              'Loan Summary',
                              style:
                                  TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          Row(
                            children: [

                              Expanded(
                                child:
                                    _summaryItem(
                                  'Principal',
                                  _money(
                                    _loan
                                        .principalAmount,
                                  ),
                                  Colors.blue,
                                ),
                              ),

                              Expanded(
                                child:
                                    _summaryItem(
                                  'Paid',
                                  _money(
                                    _loan
                                        .paidAmount,
                                  ),
                                  Colors.green,
                                ),
                              ),

                              Expanded(
                                child:
                                    _summaryItem(
                                  'Remaining',
                                  _money(
                                    remaining,
                                  ),
                                  remaining > 0
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          // ------------------------------------------
                          // PROGRESS
                          // ------------------------------------------

                          LinearProgressIndicator(
                            value:
                                _loan
                                            .principalAmount >
                                        0
                                    ? (_loan
                                            .paidAmount /
                                        _loan
                                            .principalAmount)
                                        .clamp(
                                        0.0,
                                        1.0,
                                      )
                                    : 0,
                            minHeight: 8,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              20,
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [

                              Text(
                                'Paid',
                                style:
                                    TextStyle(
                                  fontSize: 12,
                                  color: Colors
                                      .grey
                                      .shade600,
                                ),
                              ),

                              Text(
                                _loan
                                            .principalAmount >
                                        0
                                    ? '${((_loan.paidAmount / _loan.principalAmount) * 100).clamp(0, 100).toStringAsFixed(1)}%'
                                    : '0%',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // LOAN INFORMATION
                  // ==================================================

                  Card(
                    elevation: 1,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        18,
                      ),
                      child: Column(
                        children: [

                          const Align(
                            alignment:
                                Alignment
                                    .centerLeft,
                            child: Text(
                              'Loan Information',
                              style:
                                  TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          _infoRow(
                            'Loan Type',
                            _loanTypeText,
                          ),

                          _infoRow(
                            'Loan Date',
                            _loan.loanDate,
                          ),

                          if (_loan.dueDate != null &&
                              _loan.dueDate!
                                  .trim()
                                  .isNotEmpty)
                            _infoRow(
                              'Due Date',
                              _loan.dueDate!,
                            ),

                          _infoRow(
                            'Interest Rate',
                            '${_loan.interestRate.toStringAsFixed(2)}% / year',
                          ),

                          _infoRow(
                            'Interest Type',
                            _loan.interestType,
                          ),

                          _infoRow(
  'Payment Method',
  _loan.paymentMethod ?? 'Not specified',
),

                          _infoRow(
                            'Status',
                            _loan.status,
                            valueColor:
                                _statusColor,
                          ),

                          if (_loan.note != null &&
                              _loan.note!
                                  .trim()
                                  .isNotEmpty)
                            _infoRow(
                              'Note',
                              _loan.note!,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // PAYMENT HISTORY
                  // ==================================================

                  Card(
                    elevation: 1,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        18,
                      ),
                      child: Column(
                        children: [

                          Row(
                            children: [

                              const Expanded(
                                child: Text(
                                  'Payment History',
                                  style:
                                      TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),

                              Text(
                                '${_payments.length}',
                                style:
                                    TextStyle(
                                  color: Colors
                                      .grey
                                      .shade600,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          if (_payments.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                vertical: 25,
                              ),
                              child: Column(
                                children: [

                                  Icon(
                                    Icons
                                        .receipt_long,
                                    size: 45,
                                    color: Colors
                                        .grey
                                        .shade400,
                                  ),

                                  const SizedBox(
                                    height: 10,
                                  ),

                                  Text(
                                    'No payments yet',
                                    style:
                                        TextStyle(
                                      color: Colors
                                          .grey
                                          .shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._payments
                                .map(
                                  _paymentCard,
                                ),
                        ],
                      ),
                    ),
                  ),

                  // Space for FAB
                  const SizedBox(
                    height: 90,
                  ),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // SUMMARY ITEM
  // ============================================================

  Widget _summaryItem(
    String title,
    String value,
    Color color,
  ) {
    return Column(
      children: [

        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color:
                Colors.grey.shade600,
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        Text(
          value,
          textAlign:
              TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
    String title,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          SizedBox(
            width: 125,
            child: Text(
              title,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),

          const Text(
            ': ',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
                color:
                    valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT CARD
  // ============================================================

  Widget _paymentCard(
    LoanPayment payment,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [

          Container(
            padding:
                const EdgeInsets.all(
              9,
            ),
            decoration:
                BoxDecoration(
              color:
                  Colors.green.shade50,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              Icons.payments,
              color:
                  Colors.green.shade700,
              size: 22,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                Text(
                  payment.paymentDate,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

               Text(
  payment.paymentMethod ?? 'Not specified',
                  style:
                      TextStyle(
                    fontSize: 12,
                    color: Colors
                        .grey
                        .shade600,
                  ),
                ),

                if (payment.note != null &&
                    payment.note!
                        .trim()
                        .isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 3,
                    ),
                    child: Text(
                      payment.note!,
                      style:
                          TextStyle(
                        fontSize: 12,
                        color: Colors
                            .grey
                            .shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [

              Text(
                _money(
                  payment.amount,
                ),
                style:
                    const TextStyle(
                  color:
                      Colors.green,
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 15,
                ),
              ),

              if (payment.interestAmount >
                  0)
                Text(
                  'Interest: ${_money(payment.interestAmount)}',
                  style:
                      TextStyle(
                    fontSize: 11,
                    color: Colors
                        .orange
                        .shade700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}