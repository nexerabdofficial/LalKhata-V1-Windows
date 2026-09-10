import 'package:flutter/material.dart';

import '../../models/loan.dart';
import '../../services/loan_service.dart';

class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen>
    with SingleTickerProviderStateMixin {
  final LoanService _loanService = LoanService.instance;

  late TabController _tabController;

  List<Loan> _loans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
    );

    _loadLoans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  List<Loan> get _givenLoans {
    return _loans
        .where(
          (loan) =>
              loan.loanType.toUpperCase() == 'LOAN_GIVEN' ||
              loan.loanType.toUpperCase() == 'GIVEN',
        )
        .toList();
  }

  List<Loan> get _takenLoans {
    return _loans
        .where(
          (loan) =>
              loan.loanType.toUpperCase() == 'LOAN_TAKEN' ||
              loan.loanType.toUpperCase() == 'TAKEN',
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Management'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Given'),
            Tab(text: 'Taken'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadLoans,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddLoanOptions();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Loan'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLoanList(_loans),
                _buildLoanList(_givenLoans),
                _buildLoanList(_takenLoans),
              ],
            ),
    );
  }

  Widget _buildLoanList(List<Loan> loans) {
    if (loans.isEmpty) {
      return const Center(
        child: Text(
          'No loans found',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLoans,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: loans.length,
        itemBuilder: (context, index) {
          final loan = loans[index];

          final bool isGiven =
              loan.loanType.toUpperCase() == 'LOAN_GIVEN' ||
              loan.loanType.toUpperCase() == 'GIVEN';

          final remaining =
              loan.principalAmount - loan.paidAmount;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: CircleAvatar(
                child: Icon(
                  isGiven
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                ),
              ),
              title: Text(
                loan.personName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGiven
                          ? 'Loan Given'
                          : 'Loan Taken',
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Principal: ৳${loan.principalAmount.toStringAsFixed(2)}',
                    ),
                    Text(
                      'Paid: ৳${loan.paidAmount.toStringAsFixed(2)}',
                    ),
                    Text(
                      'Remaining: ৳${remaining.clamp(0, double.infinity).toStringAsFixed(2)}',
                    ),
                    if (loan.interestRate > 0)
                      Text(
                        'Interest: ${loan.interestRate.toStringAsFixed(2)}% / year',
                      ),
                  ],
                ),
              ),
              trailing: _statusBadge(loan.status),
              onTap: () {
                _showLoanDetails(loan);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: status.toUpperCase() == 'COMPLETED' ||
                status.toUpperCase() == 'PAID'
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: status.toUpperCase() == 'COMPLETED' ||
                  status.toUpperCase() == 'PAID'
              ? Colors.green
              : Colors.orange,
        ),
      ),
    );
  }

  void _showAddLoanOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.arrow_upward,
                ),
                title: const Text('Loan Given'),
                subtitle: const Text(
                  'Money given to someone',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showComingSoon('Loan Given');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.arrow_downward,
                ),
                title: const Text('Loan Taken'),
                subtitle: const Text(
                  'Money taken from someone',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showComingSoon('Loan Taken');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showComingSoon(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type entry screen — next step'),
      ),
    );
  }

  void _showLoanDetails(Loan loan) {
    final remaining =
        loan.principalAmount - loan.paidAmount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  loan.personName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loan.loanType.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 24),
                _detailRow(
                  'Principal',
                  '৳${loan.principalAmount.toStringAsFixed(2)}',
                ),
                _detailRow(
                  'Paid',
                  '৳${loan.paidAmount.toStringAsFixed(2)}',
                ),
                _detailRow(
                  'Remaining',
                  '৳${remaining.clamp(0, double.infinity).toStringAsFixed(2)}',
                ),
                _detailRow(
                  'Interest Rate',
                  '${loan.interestRate.toStringAsFixed(2)}%',
                ),
                _detailRow(
                  'Status',
                  loan.status,
                ),
                if (loan.phone != null &&
                    loan.phone!.trim().isNotEmpty)
                  _detailRow(
                    'Phone',
                    loan.phone!,
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showComingSoon(
                        'Loan Payment',
                      );
                    },
                    icon: const Icon(
                      Icons.payments,
                    ),
                    label: const Text(
                      'Add Payment',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}