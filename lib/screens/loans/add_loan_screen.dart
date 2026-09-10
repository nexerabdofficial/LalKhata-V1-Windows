import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/loan.dart';
import '../../services/loan_service.dart';

class AddLoanScreen extends StatefulWidget {
  const AddLoanScreen({super.key});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final LoanService _loanService = LoanService.instance;
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _personController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  final TextEditingController _amountController =
      TextEditingController();

  final TextEditingController _interestController =
      TextEditingController(text: '0');

  final TextEditingController _noteController =
      TextEditingController();

  String _loanType = 'GIVEN';
  String _interestType = 'ANNUAL';
  String _paymentMethod = 'Cash';

  DateTime _loanDate = DateTime.now();
  DateTime? _dueDate;

  bool _saving = false;
  bool _loadingAccounts = false;

  int? _accountId;
  String? _accountName;

  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _personController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _interestController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD ACCOUNTS
  // ============================================================

  Future<void> _loadAccounts() async {
    setState(() {
      _loadingAccounts = true;
    });

    try {
      final db = await _databaseHelper.database;

      final accounts = await db.query(
        'accounts',
        orderBy: 'id ASC',
      );

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _loadingAccounts = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingAccounts = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load accounts: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SELECT ACCOUNT
  // ============================================================

  Future<void> _selectAccount() async {
    if (_accounts.isEmpty) {
      await _loadAccounts();
    }

    if (!mounted) return;

    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No account found. Please create an account first.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  12,
                ),
                child: Text(
                  'Select Account',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              ..._accounts.map(
                (account) {
                  final id =
                      (account['id'] as num).toInt();

                  final name =
                      account['name']?.toString() ??
                          account['account_name']
                              ?.toString() ??
                          'Account #$id';

                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.account_balance_wallet,
                      ),
                    ),
                    title: Text(name),
                    selected: _accountId == id,
                    trailing: _accountId == id
                        ? const Icon(
                            Icons.check,
                            color: Colors.green,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _accountId = id;
                        _accountName = name;
                      });

                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // SELECT LOAN DATE
  // ============================================================

  Future<void> _selectLoanDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _loanDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) return;

    setState(() {
      _loanDate = selected;

      // If due date is before new loan date,
      // clear it.
      if (_dueDate != null &&
          _dueDate!.isBefore(_loanDate)) {
        _dueDate = null;
      }
    });
  }

  // ============================================================
  // SELECT DUE DATE
  // ============================================================

  Future<void> _selectDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _loanDate,
      firstDate: _loanDate,
      lastDate: DateTime(2100),
    );

    if (selected == null) return;

    setState(() {
      _dueDate = selected;
    });
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // SAVE LOAN
  // ============================================================

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ----------------------------------------------------------
    // ACCOUNT REQUIRED
    // ----------------------------------------------------------

    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a payment account.',
          ),
        ),
      );
      return;
    }

    final amount = double.tryParse(
      _amountController.text.trim(),
    );

    final interestRate = double.tryParse(
          _interestController.text.trim(),
        ) ??
        0;

    if (amount == null || amount <= 0) {
      return;
    }

    if (interestRate < 0) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final loan = Loan(
        loanType: _loanType,

        personName:
            _personController.text.trim(),

        phone:
            _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),

        principalAmount: amount,

        interestRate: interestRate,

        interestType: _interestType,

        loanDate: _formatDate(_loanDate),

        dueDate:
            _dueDate == null
                ? null
                : _formatDate(_dueDate!),

        // IMPORTANT:
        // Selected account ID
        accountId: _accountId,

        paymentMethod: _paymentMethod,

        paidAmount: 0,

        interestAmount: 0,
        
        accruedInterest: 0,

        status: 'ACTIVE',

        note:
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),

        createdAt:
            DateTime.now().toIso8601String(),
      );

      await _loanService.createLoan(
        loan: loan,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Loan added successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add loan: $e',
          ),
          backgroundColor: Colors.red,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Loan'),
      ),

      body: Form(
        key: _formKey,

        child: ListView(
          padding: const EdgeInsets.all(16),

          children: [
            // ==================================================
            // LOAN TYPE
            // ==================================================

            DropdownButtonFormField<String>(
              initialValue: _loanType,

              decoration: const InputDecoration(
                labelText: 'Loan Type',
                border: OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value: 'GIVEN',
                  child: Text('Loan Given'),
                ),
                DropdownMenuItem(
                  value: 'TAKEN',
                  child: Text('Loan Taken'),
                ),
              ],

              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _loanType = value;
                      });
                    },
            ),

            const SizedBox(height: 14),

            // ==================================================
            // PERSON
            // ==================================================

            TextFormField(
              controller: _personController,

              textInputAction:
                  TextInputAction.next,

              decoration: const InputDecoration(
                labelText:
                    'Person / Organization Name',
                border: OutlineInputBorder(),
              ),

              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Enter person name';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            // ==================================================
            // PHONE
            // ==================================================

            TextFormField(
              controller: _phoneController,

              keyboardType:
                  TextInputType.phone,

              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            // ==================================================
            // PRINCIPAL
            // ==================================================

            TextFormField(
              controller: _amountController,

              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),

              decoration: const InputDecoration(
                labelText: 'Principal Amount',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),

              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Enter loan amount';
                }

                final amount =
                    double.tryParse(
                  value.trim(),
                );

                if (amount == null ||
                    amount <= 0) {
                  return 'Enter a valid amount';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            // ==================================================
            // INTEREST RATE
            // ==================================================

            TextFormField(
              controller:
                  _interestController,

              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),

              decoration: const InputDecoration(
                labelText:
                    'Annual Interest Rate',
                suffixText: '%',
                border:
                    OutlineInputBorder(),
              ),

              validator: (value) {
                final rate =
                    double.tryParse(
                  value?.trim() ?? '',
                );

                if (rate == null ||
                    rate < 0) {
                  return 'Enter a valid interest rate';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            // ==================================================
            // INTEREST TYPE
            // ==================================================

            DropdownButtonFormField<String>(
              initialValue: _interestType,

              decoration: const InputDecoration(
                labelText: 'Interest Type',
                border:
                    OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value: 'ANNUAL',
                  child: Text('Annual'),
                ),
              ],

              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _interestType =
                            value;
                      });
                    },
            ),

            const SizedBox(height: 14),

            // ==================================================
            // PAYMENT METHOD
            // ==================================================

            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,

              decoration: const InputDecoration(
                labelText:
                    'Payment Method',
                border:
                    OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value: 'Cash',
                  child: Text('Cash'),
                ),
                DropdownMenuItem(
                  value: 'Bank',
                  child: Text('Bank'),
                ),
                DropdownMenuItem(
                  value: 'Mobile Banking',
                  child:
                      Text('Mobile Banking'),
                ),
                DropdownMenuItem(
                  value: 'Other',
                  child: Text('Other'),
                ),
              ],

              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _paymentMethod =
                            value;
                      });
                    },
            ),

            const SizedBox(height: 14),

            // ==================================================
            // ACCOUNT
            // ==================================================

            InkWell(
              onTap: _saving
                  ? null
                  : _selectAccount,

              borderRadius:
                  BorderRadius.circular(4),

              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText:
                      'Payment Account',
                  border:
                      OutlineInputBorder(),
                  suffixIcon:
                      Icon(
                    Icons
                        .arrow_drop_down,
                  ),
                ),

                child: _loadingAccounts
                    ? const SizedBox(
                        height: 20,
                        child:
                            Align(
                          alignment:
                              Alignment
                                  .centerLeft,
                          child:
                              SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        _accountName ??
                            'Select payment account',
                        style: TextStyle(
                          color:
                              _accountName ==
                                      null
                                  ? Colors
                                      .grey
                                      .shade600
                                  : null,
                          fontWeight:
                              _accountName ==
                                      null
                                  ? FontWeight
                                      .normal
                                  : FontWeight
                                      .w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 14),

            // ==================================================
            // LOAN DATE
            // ==================================================

            InkWell(
              onTap: _saving
                  ? null
                  : _selectLoanDate,

              borderRadius:
                  BorderRadius.circular(4),

              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText: 'Loan Date',
                  border:
                      OutlineInputBorder(),
                  suffixIcon:
                      Icon(
                    Icons
                        .calendar_today,
                  ),
                ),

                child: Text(
                  _formatDate(
                    _loanDate,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ==================================================
            // DUE DATE
            // ==================================================

            InkWell(
              onTap: _saving
                  ? null
                  : _selectDueDate,

              borderRadius:
                  BorderRadius.circular(4),

              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText: 'Due Date',
                  border:
                      OutlineInputBorder(),
                  suffixIcon:
                      Icon(
                    Icons.event,
                  ),
                ),

                child: Text(
                  _dueDate == null
                      ? 'Select due date'
                      : _formatDate(
                          _dueDate!,
                        ),
                  style: TextStyle(
                    color: _dueDate == null
                        ? Colors.grey
                        : null,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ==================================================
            // NOTE
            // ==================================================

            TextFormField(
              controller:
                  _noteController,

              maxLines: 3,

              decoration:
                  const InputDecoration(
                labelText: 'Note',
                hintText: 'Optional',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // SAVE
            // ==================================================

            SizedBox(
              height: 52,

              child: FilledButton.icon(
                onPressed:
                    _saving
                        ? null
                        : _saveLoan,

                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.save,
                      ),

                label: Text(
                  _saving
                      ? 'Saving...'
                      : 'Save Loan',
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}