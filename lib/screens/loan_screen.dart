import 'package:flutter/material.dart';

import '../models/loan.dart';
import '../services/loan_service.dart';
import 'loans/add_loan_screen.dart';
import 'loans/loan_details_screen.dart';
class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  final LoanService _loanService = LoanService.instance;

  List<Loan> _loans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    setState(() {
      _loading = true;
    });

    try {
      final loans = await _loanService.getLoans();

      if (!mounted) return;

      setState(() {
        _loans = loans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load loans: $e'),
        ),
      );
    }
  }

  double get _totalGiven {
    return _loans
        .where(
          (loan) =>
              loan.loanType.toUpperCase() == 'GIVEN' ||
              loan.loanType.toUpperCase() == 'LOAN_GIVEN',
        )
        .fold(
          0.0,
          (sum, loan) => sum + loan.principalAmount,
        );
  }

  double get _totalTaken {
    return _loans
        .where(
          (loan) =>
              loan.loanType.toUpperCase() == 'TAKEN' ||
              loan.loanType.toUpperCase() == 'LOAN_TAKEN',
        )
        .fold(
          0.0,
          (sum, loan) => sum + loan.principalAmount,
        );
  }

  double get _outstandingGiven {
    return _loans
        .where(
          (loan) =>
              (loan.loanType.toUpperCase() == 'GIVEN' ||
                  loan.loanType.toUpperCase() ==
                      'LOAN_GIVEN') &&
              loan.status.toUpperCase() != 'PAID' &&
              loan.status.toUpperCase() != 'COMPLETED',
        )
        .fold(
          0.0,
          (sum, loan) =>
              sum + loan.remainingPrincipal,
        );
  }

  double get _outstandingTaken {
    return _loans
        .where(
          (loan) =>
              (loan.loanType.toUpperCase() == 'TAKEN' ||
                  loan.loanType.toUpperCase() ==
                      'LOAN_TAKEN') &&
              loan.status.toUpperCase() != 'PAID' &&
              loan.status.toUpperCase() != 'COMPLETED',
        )
        .fold(
          0.0,
          (sum, loan) =>
              sum + loan.remainingPrincipal,
        );
  }

  bool _isGiven(Loan loan) {
    final type = loan.loanType.toUpperCase();

    return type == 'GIVEN' || type == 'LOAN_GIVEN';
  }

  String _statusText(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return 'Active';
      case 'PARTIAL':
        return 'Partial';
      case 'PAID':
        return 'Paid';
      case 'COMPLETED':
        return 'Completed';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
      case 'COMPLETED':
        return Colors.green;

      case 'PARTIAL':
        return Colors.orange;

      default:
        return Colors.blue;
    }
  }

  String _formatAmount(double amount) {
    return '৳${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Management'),
        actions: [
          IconButton(
            onPressed: _loadLoans,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
onPressed: () async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const AddLoanScreen(),
    ),
  );

  if (result == true) {
    _loadLoans();
  }
},
        icon: const Icon(Icons.add),
        label: const Text('Add Loan'),
      ),

      body: RefreshIndicator(
        onRefresh: _loadLoans,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _loans.isEmpty
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummary(),

                      const SizedBox(height: 20),

                      const Text(
                        'Loan Records',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      ..._loans.map(
                        (loan) => _buildLoanCard(loan),
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSummary() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'Given',
                amount: _totalGiven,
                icon: Icons.arrow_upward,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                title: 'Taken',
                amount: _totalTaken,
                icon: Icons.arrow_downward,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'Receivable',
                amount: _outstandingGiven,
                icon: Icons.call_received,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                title: 'Payable',
                amount: _outstandingTaken,
                icon: Icons.call_made,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              _formatAmount(amount),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanCard(Loan loan) {
    final given = _isGiven(loan);
    final statusColor =
        _statusColor(loan.status);

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LoanDetailsScreen(
        loan: loan,
      ),
    ),
  );

  if (result == true) {
    _loadLoans();
  }
},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      given
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.personName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          given
                              ? 'Loan Given'
                              : 'Loan Taken',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor
                          .withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText(loan.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _loanInfo(
                      'Principal',
                      _formatAmount(
                        loan.principalAmount,
                      ),
                    ),
                  ),

                  Expanded(
                    child: _loanInfo(
                      'Paid',
                      _formatAmount(
                        loan.paidAmount,
                      ),
                    ),
                  ),

                  Expanded(
                    child: _loanInfo(
                      'Remaining',
                      _formatAmount(
                        loan.remainingPrincipal,
                      ),
                    ),
                  ),
                ],
              ),

              if (loan.interestRate > 0) ...[
                const SizedBox(height: 10),

                Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Interest: ${loan.interestRate.toStringAsFixed(2)}% ${loan.interestType}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],

              if (loan.dueDate != null &&
                  loan.dueDate!.trim().isNotEmpty) ...[
                const SizedBox(height: 5),

                Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Due: ${loan.dueDate}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _loanInfo(
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height:
              MediaQuery.of(context).size.height *
                  0.65,
          child: Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 70,
                  color: Colors.grey[400],
                ),

                const SizedBox(height: 16),

                const Text(
                  'No loans found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Add your first loan to get started.',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}