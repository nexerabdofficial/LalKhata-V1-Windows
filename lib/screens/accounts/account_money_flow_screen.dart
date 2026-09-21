import 'package:flutter/material.dart';

import '../../services/ff/ff_money_flow_service.dart';

class AccountMoneyFlowScreen extends StatefulWidget {
  final bool received;

  const AccountMoneyFlowScreen({super.key, required this.received});

  @override
  State<AccountMoneyFlowScreen> createState() => _AccountMoneyFlowScreenState();
}

class _AccountMoneyFlowScreenState extends State<AccountMoneyFlowScreen> {
  final FFMoneyFlowService _service = FFMoneyFlowService.instance;

  bool _loading = true;

  FFMoneyFlowReport? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final report = await _service.getTodayReport(received: widget.received);

      if (!mounted) return;

      setState(() {
        _report = report;
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

    if (date == null) {
      return value;
    }

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}-'
        '${two(date.month)}-'
        '${date.year} '
        '${two(date.hour)}:'
        '${two(date.minute)}';
  }

  String _particular(FFMoneyFlowRow row) {
    final reference = row.referenceType?.trim();

    if (reference != null && reference.isNotEmpty) {
      return reference;
    }

    final description = row.description?.trim();

    if (description != null && description.isNotEmpty) {
      return description;
    }

    return row.transactionType;
  }

  @override
  Widget build(BuildContext context) {
    final received = widget.received;

    final title = received ? 'Money Received' : 'Money Given';

    final color = received ? const Color(0xff16a34a) : const Color(0xffdc2626);

    final icon = received ? Icons.south_west_rounded : Icons.north_east_rounded;

    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: report == null || report.rows.isEmpty
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
                                      _money(report.total),
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
                                '${report.entryCount} entries',
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
                        ...report.rows.map((row) {
                          final particular = _particular(row);

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
                                        row.accountName,
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
                                      if (row.voucherNo?.trim().isNotEmpty ==
                                          true)
                                        Text(
                                          'Voucher: ${row.voucherNo}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      if (row.note?.trim().isNotEmpty == true)
                                        Text(
                                          row.note!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _date(row.transactionDate),
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
                                  _money(row.amount),
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
