import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/account_transaction.dart';
import '../../services/account_transaction_repository.dart';
import '../../services/account_repository.dart';

class AccountMoneyFlowScreen extends StatefulWidget {
  final bool received;

  const AccountMoneyFlowScreen({super.key, required this.received});

  @override
  State<AccountMoneyFlowScreen> createState() => _AccountMoneyFlowScreenState();
}

class _AccountMoneyFlowScreenState extends State<AccountMoneyFlowScreen> {
  final AccountTransactionRepository _transactionRepository =
      AccountTransactionRepository();

  final AccountRepository _accountRepository = AccountRepository();

  bool _loading = true;

  List<AccountTransaction> _transactions = [];
  Map<int, Account> _accounts = {};

  double _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      final transactions = await _transactionRepository.getAllTransactions();

      final accounts = await _accountRepository.getAccounts();

      final accountMap = <int, Account>{
        for (final account in accounts)
          if (account.id != null) account.id!: account,
      };

      final now = DateTime.now();

      final start = DateTime(now.year, now.month, now.day);

      final end = start.add(const Duration(days: 1));

      final filtered = transactions.where((transaction) {
        if (widget.received) {
          if (transaction.credit <= 0) return false;
          if (transaction.transactionType == 'FUND_TRANSFER_IN') {
            return false;
          }
        } else {
          if (transaction.debit <= 0) return false;
          if (transaction.transactionType == 'FUND_TRANSFER_OUT') {
            return false;
          }
        }

        final date = DateTime.tryParse(transaction.transactionDate);

        if (date == null) return false;

        return !date.isBefore(start) && date.isBefore(end);
      }).toList();

      filtered.sort((a, b) {
        final ad = DateTime.tryParse(a.transactionDate);
        final bd = DateTime.tryParse(b.transactionDate);

        if (ad == null || bd == null) return 0;

        return bd.compareTo(ad);
      });

      double total = 0;

      for (final transaction in filtered) {
        total += widget.received ? transaction.credit : transaction.debit;
      }

      if (!mounted) return;

      setState(() {
        _transactions = filtered;
        _accounts = accountMap;
        _total = total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load transactions: $e')),
      );
    }
  }

  String _money(double value) {
    return '৳${value.toStringAsFixed(2)}';
  }

  String _date(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) return value;

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}-${two(date.month)}-${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final received = widget.received;

    final title = received ? 'Money Received' : 'Money Given';

    final color = received ? const Color(0xff16a34a) : const Color(0xffdc2626);

    final icon = received ? Icons.south_west_rounded : Icons.north_east_rounded;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _transactions.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Icon(icon, size: 48, color: color.withOpacity(.35)),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            'No $title transactions today',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(14),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: color.withOpacity(.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withOpacity(.12)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Today's $title",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _money(_total),
                                      style: TextStyle(
                                        fontSize: 21,
                                        color: color,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${_transactions.length} entries',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._transactions.map((transaction) {
                          final account = _accounts[transaction.accountId];

                          final amount = received
                              ? transaction.credit
                              : transaction.debit;

                          final particular =
                              transaction.referenceType?.trim().isNotEmpty ==
                                  true
                              ? transaction.referenceType!
                              : transaction.transactionType;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(.09),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, size: 18, color: color),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account?.name ??
                                            'Account #${transaction.accountId}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        particular,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (transaction.voucherNo
                                              ?.trim()
                                              .isNotEmpty ==
                                          true)
                                        Text(
                                          'Voucher: ${transaction.voucherNo}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      if (transaction.note?.trim().isNotEmpty ==
                                          true)
                                        Text(
                                          transaction.note!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _date(transaction.transactionDate),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _money(amount),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
            ),
    );
  }
}
