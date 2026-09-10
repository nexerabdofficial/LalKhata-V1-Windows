import 'package:flutter/material.dart';

import '../../models/loan.dart';
import '../../models/loan_payment.dart';
import '../../services/loan_service.dart';

class AddLoanPaymentScreen extends StatefulWidget {
  final Loan loan;

  const AddLoanPaymentScreen({
    super.key,
    required this.loan,
  });

  @override
  State<AddLoanPaymentScreen> createState() =>
      _AddLoanPaymentScreenState();
}

class _AddLoanPaymentScreenState
    extends State<AddLoanPaymentScreen> {
  final LoanService _loanService =
      LoanService.instance;

  final _formKey =
      GlobalKey<FormState>();

  final TextEditingController
      _amountController =
      TextEditingController();

  final TextEditingController
      _noteController =
      TextEditingController();

  String _paymentMethod = 'Cash';

  int? _accountId;

  DateTime _paymentDate =
      DateTime.now();

  bool _saving = false;
  bool _loadingInterest = true;

  double _accruedInterest = 0;

  List<LoanPayment>
      _previousPayments = [];

  // ============================================================
  // LOAN TYPE
  // ============================================================

  bool get _isLoanGiven {
    final type =
        widget.loan.loanType
            .toUpperCase();

    return type == 'GIVEN' ||
        type == 'LOAN_GIVEN';
  }

  // ============================================================
  // CURRENT REMAINING PRINCIPAL
  // ============================================================

  double get _remainingPrincipal {
    double remaining =
        widget.loan.principalAmount -
            widget.loan.paidAmount;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  // ============================================================
  // CURRENT PAYMENT AMOUNT
  // ============================================================

  double get _paymentAmount {
    return double.tryParse(
          _amountController.text.trim(),
        ) ??
        0;
  }

  // ============================================================
  // PRINCIPAL ADJUSTMENT
  //
  // Payment first clears accrued interest.
  // Remaining amount goes to principal.
  // ============================================================

  double get _principalAdjustment {
    final value =
        _paymentAmount -
            _accruedInterest;

    if (value <= 0) {
      return 0;
    }

    if (value > _remainingPrincipal) {
      return _remainingPrincipal;
    }

    return value;
  }

  // ============================================================
  // REMAINING PRINCIPAL AFTER PAYMENT
  // ============================================================

  double get _remainingPrincipalAfterPayment {
    final remaining =
        _remainingPrincipal -
            _principalAdjustment;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  // ============================================================
  // REMAINING INTEREST AFTER PAYMENT
  // ============================================================

  double get _remainingInterestAfterPayment {
    final remaining =
        _accruedInterest -
            _paymentAmount;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

  DateTime _parseDate(
    String value,
  ) {
    final parts =
        value.split('-');

    if (parts.length != 3) {
      throw FormatException(
        'Invalid date: $value',
      );
    }

    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    final year =
        date.year
            .toString()
            .padLeft(4, '0');

    final month =
        date.month
            .toString()
            .padLeft(2, '0');

    final day =
        date.day
            .toString()
            .padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ============================================================
  // CALCULATE ACCRUED INTEREST
  //
  // Interest is calculated:
  //
  // outstanding principal
  // × annual rate
  // ÷ 365
  // × days
  //
  // IMPORTANT:
  //
  // Interest is NOT added to principal.
  // ============================================================

  Future<void>
      _calculateAccruedInterest() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loadingInterest = true;
    });

    try {
      if (widget.loan.interestRate <=
          0) {
        if (!mounted) {
          return;
        }

        setState(() {
          _accruedInterest = 0;
          _loadingInterest = false;
        });

        return;
      }

      final payments =
          await _loanService
              .getLoanPayments(
        widget.loan.id!,
      );

      final loanDate =
          _parseDate(
        widget.loan.loanDate,
      );

      final selectedDate =
          DateTime(
        _paymentDate.year,
        _paymentDate.month,
        _paymentDate.day,
      );

      final normalizedLoanDate =
          DateTime(
        loanDate.year,
        loanDate.month,
        loanDate.day,
      );

      // --------------------------------------------------------
      // Payment date cannot be before loan date.
      // --------------------------------------------------------

      if (selectedDate.isBefore(
        normalizedLoanDate,
      )) {
        if (!mounted) {
          return;
        }

        setState(() {
          _previousPayments =
              payments;

          _accruedInterest = 0;

          _loadingInterest = false;
        });

        return;
      }

      // --------------------------------------------------------
      // Sort payments chronologically.
      // --------------------------------------------------------

      payments.sort(
        (a, b) =>
            a.paymentDate.compareTo(
          b.paymentDate,
        ),
      );

      double outstandingPrincipal =
          widget.loan.principalAmount;

      double accruedInterest = 0;

      DateTime currentDate =
          normalizedLoanDate;

      // --------------------------------------------------------
      // PROCESS PAYMENT HISTORY
      // --------------------------------------------------------

      for (final payment
          in payments) {
        final paymentDate =
            _parseDate(
          payment.paymentDate,
        );

        final normalizedPaymentDate =
            DateTime(
          paymentDate.year,
          paymentDate.month,
          paymentDate.day,
        );

        // Ignore future payments.
        if (normalizedPaymentDate
            .isAfter(selectedDate)) {
          break;
        }

        // Ignore invalid payments.
        if (normalizedPaymentDate
            .isBefore(
          normalizedLoanDate,
        )) {
          continue;
        }

        // ------------------------------------------------------
        // ACCRUE INTEREST BEFORE THIS PAYMENT
        //
        // Example:
        //
        // Loan date: Sept 2
        // Payment date: Sept 3
        //
        // Difference = 1 day
        //
        // 50,000 × 12% ÷ 365
        // = 16.44
        // ------------------------------------------------------

        final days =
            normalizedPaymentDate
                .difference(
                  currentDate,
                )
                .inDays;

        if (days > 0 &&
            outstandingPrincipal >
                0.000001) {
          final dailyInterest =
              outstandingPrincipal *
                  (widget.loan
                          .interestRate /
                      100) /
                  365;

          accruedInterest +=
              dailyInterest * days;
        }

        // ------------------------------------------------------
        // Existing payment's interest
        // reduces accrued interest.
        // ------------------------------------------------------

        accruedInterest -=
            payment.interestAmount;

        if (accruedInterest <
            0.000001) {
          accruedInterest = 0;
        }

        // ------------------------------------------------------
        // Existing principal payment
        // reduces principal.
        // ------------------------------------------------------

        outstandingPrincipal -=
            payment.principalAmount;

        if (outstandingPrincipal <
            0.000001) {
          outstandingPrincipal = 0;
        }

        // ------------------------------------------------------
        // Next interest period starts
        // from this payment date.
        // ------------------------------------------------------

        currentDate =
            normalizedPaymentDate;

        if (outstandingPrincipal <=
            0.000001) {
          break;
        }
      }

      // --------------------------------------------------------
      // ACCRUE FROM LAST TRANSACTION
      // UNTIL SELECTED PAYMENT DATE
      // --------------------------------------------------------

      if (outstandingPrincipal >
              0.000001 &&
          currentDate.isBefore(
            selectedDate,
          )) {
        final days =
            selectedDate
                .difference(
                  currentDate,
                )
                .inDays;

        if (days > 0) {
          final dailyInterest =
              outstandingPrincipal *
                  (widget.loan
                          .interestRate /
                      100) /
                  365;

          accruedInterest +=
              dailyInterest * days;
        }
      }

      // --------------------------------------------------------
      // SAFETY
      // --------------------------------------------------------

      if (accruedInterest <
          0.000001) {
        accruedInterest = 0;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _previousPayments =
            payments;

        _accruedInterest =
            accruedInterest;

        _loadingInterest = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _accruedInterest = 0;
        _loadingInterest = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to calculate interest: $e',
          ),
          backgroundColor:
              Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // User enters total payment manually.
    _amountController.clear();

    _calculateAccruedInterest();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  // ============================================================
  // DATE SELECTION
  // ============================================================

  Future<void>
      _selectPaymentDate() async {
    final selected =
        await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate:
          DateTime(2000),
      lastDate:
          DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _paymentDate = selected;
    });

    await _calculateAccruedInterest();
  }

  // ============================================================
  // ACCOUNT SELECTION
  // ============================================================

  Future<void>
      _selectAccount() async {
    try {
      final accounts =
          await _loanService
              .getAccounts();

      if (!mounted) {
        return;
      }

      if (accounts.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'No accounts found. Please create an account first.',
            ),
          ),
        );

        return;
      }

      await showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding:
                      EdgeInsets.all(16),
                  child: Text(
                    'Select Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                ...accounts.map(
                  (account) {
                    final id =
                        (account['id']
                                as num)
                            .toInt();

                    final name =
                        account['name']
                                ?.toString() ??
                            account[
                                    'account_name']
                                ?.toString() ??
                            'Account';

                    return ListTile(
                      leading:
                          const Icon(
                        Icons
                            .account_balance_wallet,
                      ),
                      title:
                          Text(name),
                      selected:
                          _accountId ==
                              id,
                      onTap: () {
                        setState(() {
                          _accountId =
                              id;
                        });

                        Navigator.pop(
                          context,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load accounts: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SAVE PAYMENT
  // ============================================================

  Future<void> _savePayment() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_accountId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an account.',
          ),
        ),
      );

      return;
    }

    if (widget.loan.id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid loan ID.',
          ),
        ),
      );

      return;
    }

    final totalPayment =
        _paymentAmount;

    final interest =
        _accruedInterest;

    // ----------------------------------------------------------
    // PAYMENT ALLOCATION
    //
    // Interest is paid FIRST.
    // Remaining amount goes to principal.
    // ----------------------------------------------------------

    final principalAdjustment =
        totalPayment > interest
            ? totalPayment - interest
            : 0.0;

    // ----------------------------------------------------------
    // SAFETY
    // ----------------------------------------------------------

    if (totalPayment <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid payment amount.',
          ),
        ),
      );

      return;
    }

    final totalOutstanding =
        _remainingPrincipal +
            interest;

    if (totalPayment >
        totalOutstanding + 0.000001) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment exceeds total outstanding amount.',
          ),
        ),
      );

      return;
    }

    if (principalAdjustment >
        _remainingPrincipal +
            0.000001) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Principal adjustment exceeds remaining principal.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final voucherNo =
          await _loanService
              .generatePaymentVoucher();

      final payment =
          LoanPayment(
        loanId:
            widget.loan.id!,

        // IMPORTANT:
        // This is TOTAL payment.
        amount:
            totalPayment,

        voucherNo:
            voucherNo,

        // Repository will also validate/recalculate
        // these values.
        principalAmount:
            principalAdjustment,

        interestAmount:
            interest,

        paymentDate:
            _formatDate(
          _paymentDate,
        ),

        accountId:
            _accountId!,

        paymentMethod:
            _paymentMethod,

        note:
            _noteController.text
                .trim(),

        createdAt:
            DateTime.now()
                .toIso8601String(),
      );

      await _loanService
          .addLoanPayment(
        payment: payment,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Loan payment added successfully.',
          ),
          backgroundColor:
              Colors.green,
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add payment: $e',
          ),
          backgroundColor:
              Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final paymentAmount =
        _paymentAmount;

    final principalAdjustment =
        _principalAdjustment;

    final remainingPrincipal =
        _remainingPrincipalAfterPayment;

    final remainingInterest =
        _remainingInterestAfterPayment;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Loan Payment',
        ),
        centerTitle: true,
      ),

      body: Form(
        key: _formKey,

        child: ListView(
          padding:
              const EdgeInsets.all(16),

          children: [
            // ==================================================
            // LOAN SUMMARY
            // ==================================================

            Card(
              elevation: 2,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),

              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,

                          backgroundColor:
                              _isLoanGiven
                                  ? Colors
                                      .blue
                                      .shade50
                                  : Colors
                                      .orange
                                      .shade50,

                          child: Icon(
                            _isLoanGiven
                                ? Icons
                                    .arrow_upward
                                : Icons
                                    .arrow_downward,

                            color:
                                _isLoanGiven
                                    ? Colors
                                        .blue
                                    : Colors
                                        .orange,
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [
                              Text(
                                widget.loan
                                    .personName,

                                style:
                                    const TextStyle(
                                  fontSize:
                                      18,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const SizedBox(
                                height: 3,
                              ),

                              Text(
                                _isLoanGiven
                                    ? 'Loan Given'
                                    : 'Loan Taken',

                                style:
                                    TextStyle(
                                  color: Colors
                                      .grey
                                      .shade600,
                                  fontSize:
                                      13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                            widget.loan
                                .principalAmount,
                          ),
                        ),

                        Expanded(
                          child:
                              _summaryItem(
                            'Paid',
                            widget.loan
                                .paidAmount,
                          ),
                        ),

                        Expanded(
                          child:
                              _summaryItem(
                            'Remaining',
                            _remainingPrincipal,
                            highlight:
                                true,
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
            // TOTAL PAYMENT AMOUNT
            // ==================================================

            TextFormField(
              controller:
                  _amountController,

              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),

              onChanged: (_) {
                setState(() {});
              },

              decoration:
                  const InputDecoration(
                labelText:
                    'Payment Amount',
                hintText:
                    'Enter total payment amount',
                prefixText:
                    '৳ ',
                border:
                    OutlineInputBorder(),
              ),

              validator: (value) {
                if (value == null ||
                    value
                        .trim()
                        .isEmpty) {
                  return 'Enter payment amount';
                }

                final amount =
                    double.tryParse(
                  value.trim(),
                );

                if (amount == null ||
                    amount <= 0) {
                  return 'Enter a valid amount';
                }

                final totalOutstanding =
                    _remainingPrincipal +
                        _accruedInterest;

                if (amount >
                    totalOutstanding +
                        0.000001) {
                  return 'Payment exceeds total outstanding';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // ACCRUED INTEREST
            // ==================================================

            Card(
              elevation: 0,
              color:
                  Colors.orange.shade50,

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                side: BorderSide(
                  color:
                      Colors.orange.shade100,
                ),
              ),

              child: Padding(
                padding:
                    const EdgeInsets.all(
                  14,
                ),

                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .percent_rounded,
                      color:
                          Colors.orange,
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    const Expanded(
                      child: Text(
                        'Accrued Interest',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),

                    if (_loadingInterest)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Text(
                        '৳ ${_accruedInterest.toStringAsFixed(2)}',

                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            // ==================================================
            // INTEREST INFO
            // ==================================================

            Container(
              padding:
                  const EdgeInsets.all(
                12,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.blueGrey.shade50,

                borderRadius:
                    BorderRadius.circular(
                  10,
                ),

                border:
                    Border.all(
                  color:
                      Colors.blueGrey.shade100,
                ),
              ),

              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  Icon(
                    Icons.info_outline,
                    size: 19,
                    color: Colors
                        .blueGrey
                        .shade700,
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child: Text(
                      'Interest is calculated daily on outstanding principal. '
                      'Interest is paid first and is never added to principal.',

                      style:
                          TextStyle(
                        fontSize: 12,
                        color: Colors
                            .blueGrey
                            .shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            // ==================================================
            // PAYMENT BREAKDOWN
            // ==================================================

            Card(
              elevation: 0,

              color:
                  Colors.grey.shade100,

              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),

                child: Column(
                  children: [
                    _breakdownRow(
                      'Payment Amount',
                      paymentAmount,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _breakdownRow(
                      'Accrued Interest',
                      _accruedInterest,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _breakdownRow(
                      'Principal Adjustment',
                      principalAdjustment,
                    ),

                    const Divider(
                      height: 28,
                    ),

                    _breakdownRow(
                      'Remaining Principal',
                      remainingPrincipal,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _breakdownRow(
                      'Remaining Interest',
                      remainingInterest,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            // ==================================================
            // PAYMENT METHOD
            // ==================================================

            DropdownButtonFormField<
                String>(
              initialValue:
                  _paymentMethod,

              decoration:
                  const InputDecoration(
                labelText:
                    'Payment Method',
                border:
                    OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value: 'Cash',
                  child:
                      Text('Cash'),
                ),

                DropdownMenuItem(
                  value: 'Bank',
                  child:
                      Text('Bank'),
                ),

                DropdownMenuItem(
                  value:
                      'Mobile Banking',
                  child:
                      Text(
                    'Mobile Banking',
                  ),
                ),
              ],

              onChanged:
                  _saving
                      ? null
                      : (value) {
                          if (value ==
                              null) {
                            return;
                          }

                          setState(() {
                            _paymentMethod =
                                value;
                          });
                        },
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // ACCOUNT
            // ==================================================

            InkWell(
              onTap:
                  _saving
                      ? null
                      : _selectAccount,

              borderRadius:
                  BorderRadius.circular(
                4,
              ),

              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText:
                      'Account',

                  border:
                      OutlineInputBorder(),

                  suffixIcon:
                      Icon(
                    Icons
                        .arrow_drop_down,
                  ),
                ),

                child: Text(
                  _accountId == null
                      ? 'Select account'
                      : 'Account #$_accountId',

                  style:
                      TextStyle(
                    color:
                        _accountId ==
                                null
                            ? Colors
                                .grey
                                .shade600
                            : Colors.black,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // PAYMENT DATE
            // ==================================================

            InkWell(
              onTap:
                  _saving
                      ? null
                      : _selectPaymentDate,

              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText:
                      'Payment Date',

                  border:
                      OutlineInputBorder(),

                  suffixIcon:
                      Icon(
                    Icons
                        .calendar_month,
                  ),
                ),

                child: Text(
                  _formatDate(
                    _paymentDate,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // NOTE
            // ==================================================

            TextFormField(
              controller:
                  _noteController,

              maxLines: 3,

              decoration:
                  const InputDecoration(
                labelText:
                    'Note',

                hintText:
                    'Optional note',

                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            // ==================================================
            // SAVE BUTTON
            // ==================================================

            SizedBox(
              height: 52,

              child:
                  ElevatedButton.icon(
                onPressed:
                    _saving ||
                            _loadingInterest
                        ? null
                        : _savePayment,

                icon:
                    _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            Icons.check,
                          ),

                label:
                    Text(
                  _saving
                      ? 'Saving...'
                      : 'Save Payment',

                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 30,
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
    double amount, {
    bool highlight = false,
  }) {
    return Column(
      children: [
        Text(
          title,

          style:
              TextStyle(
            fontSize: 12,
            color:
                Colors.grey.shade600,
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        Text(
          '৳ ${amount.toStringAsFixed(2)}',

          style:
              TextStyle(
            fontSize: 15,
            fontWeight:
                FontWeight.bold,
            color:
                highlight
                    ? Colors.red
                    : Colors.black,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BREAKDOWN ROW
  // ============================================================

  Widget _breakdownRow(
    String title,
    double amount,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,

            style:
                TextStyle(
              fontSize: 14,
              color:
                  Colors.grey.shade700,
            ),
          ),
        ),

        Text(
          '৳ ${amount.toStringAsFixed(2)}',

          style:
              const TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}