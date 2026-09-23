import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/account.dart';
import 'account_ledger_preview_screen.dart';
import '../../services/ff/ff_universal_ledger_service.dart';

class AccountLedgerScreen extends StatefulWidget {
  final Account account;

  const AccountLedgerScreen({super.key, required this.account});

  @override
  State<AccountLedgerScreen> createState() => _AccountLedgerScreenState();
}

class _AccountLedgerScreenState extends State<AccountLedgerScreen> {
  final FFUniversalLedgerService _ledgerService =
      FFUniversalLedgerService.instance;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  List<Map<String, dynamic>> _transactions = [];

  FFUniversalLedgerSummary? _summary;

  String _dateFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;

  static const List<String> _dateFilters = [
    'All',
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
    'Custom',
  ];

  // ============================================================
  // DATE RANGE
  // ============================================================

  String? get _fromIso {
    final date = _fromDate;
    if (date == null) return null;

    return DateTime(date.year, date.month, date.day).toIso8601String();
  }

  String? get _toIso {
    final date = _toDate;
    if (date == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).toIso8601String();
  }

  void _setPreset(String value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? from;
    DateTime? to;

    switch (value) {
      case 'Today':
        from = today;
        to = today;
        break;

      case 'Yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        from = yesterday;
        to = yesterday;
        break;

      case 'This Week':
        from = today.subtract(Duration(days: today.weekday - 1));
        to = today;
        break;

      case 'This Month':
        from = DateTime(today.year, today.month, 1);
        to = today;
        break;

      case 'All':
        from = null;
        to = null;
        break;
    }

    setState(() {
      _dateFilter = value;
      _fromDate = from;
      _toDate = to;
    });
  }

  Future<void> _selectDateFilter(String value) async {
    if (value != 'Custom') {
      _setPreset(value);
      await _loadLedger();
      return;
    }

    final now = DateTime.now();

    final initialStart = _fromDate ?? DateTime(now.year, now.month, 1);

    final initialEnd = _toDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Select Ledger Date Range',
    );

    if (picked == null) return;

    setState(() {
      _dateFilter = 'Custom';
      _fromDate = picked.start;
      _toDate = picked.end;
    });

    await _loadLedger();
  }

  String get _rangeLabel {
    if (_fromDate == null || _toDate == null) {
      return 'All Transactions';
    }

    return '${DateFormat('dd MMM yyyy').format(_fromDate!)}'
        ' - '
        '${DateFormat('dd MMM yyyy').format(_toDate!)}';
  }

  // ============================================================
  // LOAD UNIVERSAL LEDGER
  // ============================================================

  Future<void> _loadLedger() async {
    if (widget.account.id == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final results = await Future.wait([
        _ledgerService.getLedger(
          accountId: widget.account.id!,
          fromDate: _fromIso,
          toDate: _toIso,
        ),
        _ledgerService.getSummary(
          accountId: widget.account.id!,
          fromDate: _fromIso,
          toDate: _toIso,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _transactions = results[0] as List<Map<String, dynamic>>;
        _summary = results[1] as FFUniversalLedgerSummary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load ledger: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  // ============================================================
  // VALUES
  // ============================================================

  double get _openingBalance {
    return _summary?.openingBalance ?? 0;
  }

  double get _currentBalance {
    return _summary?.closingBalance ?? 0;
  }

  double get _totalDebit {
    return _summary?.totalDebit ?? 0;
  }

  double get _totalCredit {
    return _summary?.totalCredit ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // FORMAT
  // ============================================================

  String _formatMoney(double value) {
    return NumberFormat('#,##0.##').format(value);
  }

  String _formatDate(String value) {
    try {
      return _dateFormat.format(DateTime.parse(value));
    } catch (_) {
      return value.length >= 10 ? value.substring(0, 10) : value;
    }
  }

  String _voucher(Map<String, dynamic> row) {
    final voucher = row['voucher_no']?.toString().trim() ?? '';

    if (voucher.isNotEmpty) {
      return voucher;
    }

    return '-';
  }

  String _description(Map<String, dynamic> row) {
    final counterparty = row['counterparty']?.toString().trim() ?? '';
    final debit = _toDouble(row['debit']);
    final credit = _toDouble(row['credit']);

    if (counterparty.isNotEmpty) {
      if (debit > 0) {
        return 'Received from $counterparty';
      }

      if (credit > 0) {
        return 'Paid to $counterparty';
      }

      return counterparty;
    }

    final note = row['note']?.toString().trim() ?? '';

    if (note.isNotEmpty) {
      return note;
    }

    final description = row['description']?.toString().trim() ?? '';

    if (description.isNotEmpty) {
      return description;
    }

    return row['transaction_type']?.toString().trim() ?? '';
  }

  String _secondaryDescription(Map<String, dynamic> row) {
    final counterparty = row['counterparty']?.toString().trim() ?? '';

    if (counterparty.isEmpty) {
      return '';
    }

    final note = row['note']?.toString().trim() ?? '';

    if (note.isNotEmpty) {
      return note;
    }

    final description = row['description']?.toString().trim() ?? '';

    if (description.isNotEmpty) {
      return description;
    }

    return row['transaction_type']?.toString().trim() ?? '';
  }

  String _transactionDate(Map<String, dynamic> row) {
    return row['transaction_date']?.toString().trim() ?? '';
  }

  // ============================================================
  // AMOUNT PRESENTATION
  //
  // IMPORTANT:
  // Debit/Credit are accounting movements.
  // We do NOT use legacy "+credit -debit" logic here.
  // Running balance comes directly from FF Universal Ledger.
  // ============================================================

  Color _amountColor(Map<String, dynamic> row) {
    final debit = _toDouble(row['debit']);
    final credit = _toDouble(row['credit']);

    if (debit > 0) {
      return Colors.red;
    }

    if (credit > 0) {
      return Colors.green;
    }

    return Colors.grey;
  }

  String _amountText(Map<String, dynamic> row) {
    final debit = _toDouble(row['debit']);
    final credit = _toDouble(row['credit']);

    if (debit > 0) {
      return 'Dr ৳${_formatMoney(debit)}';
    }

    if (credit > 0) {
      return 'Cr ৳${_formatMoney(credit)}';
    }

    return '৳0';
  }

  // ============================================================
  // PDF
  // ============================================================

  Future<void> _exportPdf() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountLedgerPreviewScreen(
          account: widget.account,
          fromDate: _fromIso,
          toDate: _toIso,
        ),
      ),
    );
  }

  // ============================================================
  // DATE FILTER
  // ============================================================

  Widget _buildDateFilter() {
    return Center(
      child: SizedBox(
        width: _ledgerWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._dateFilters.map(
                (filter) => ChoiceChip(
                  label: Text(filter),
                  selected: _dateFilter == filter,
                  onSelected: (_) => _selectDateFilter(filter),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _rangeLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Opening Balance',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '৳${_formatMoney(_openingBalance)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Closing Balance',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '৳${_formatMoney(_currentBalance)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LEDGER TABLE
  // ============================================================

  static const double _ledgerWidth = 980;
  static const double _dateWidth = 105;
  static const double _voucherWidth = 125;
  static const double _particularWidth = 330;
  static const double _amountWidth = 125;
  static const double _balanceWidth = 145;

  Widget _ledgerCell(
    String text, {
    required double width,
    TextAlign align = TextAlign.left,
    FontWeight weight = FontWeight.normal,
    bool header = false,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Text(
          text,
          textAlign: align,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: header ? 13 : 12.5, fontWeight: weight),
        ),
      ),
    );
  }

  Widget _buildLedgerHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          _ledgerCell(
            'Date',
            width: _dateWidth,
            weight: FontWeight.bold,
            header: true,
          ),
          _ledgerCell(
            'Voucher',
            width: _voucherWidth,
            weight: FontWeight.bold,
            header: true,
          ),
          _ledgerCell(
            'Particulars',
            width: _particularWidth,
            weight: FontWeight.bold,
            header: true,
          ),
          _ledgerCell(
            'Debit',
            width: _amountWidth,
            align: TextAlign.right,
            weight: FontWeight.bold,
            header: true,
          ),
          _ledgerCell(
            'Credit',
            width: _amountWidth,
            align: TextAlign.right,
            weight: FontWeight.bold,
            header: true,
          ),
          _ledgerCell(
            'Balance',
            width: _balanceWidth,
            align: TextAlign.right,
            weight: FontWeight.bold,
            header: true,
          ),
        ],
      ),
    );
  }

  Widget _ledgerDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
    );
  }

  Widget _buildOpeningLedgerRow() {
    return Row(
      children: [
        _ledgerCell(
          _fromDate != null ? 'B/F' : _formatDate(widget.account.openingDate),
          width: _dateWidth,
          weight: FontWeight.w600,
        ),
        _ledgerCell(
          _fromDate != null ? 'B/F' : 'OB',
          width: _voucherWidth,
          weight: FontWeight.w600,
        ),
        _ledgerCell(
          _fromDate != null ? 'Balance Brought Forward' : 'Opening Balance',
          width: _particularWidth,
          weight: FontWeight.w500,
        ),
        _ledgerCell('', width: _amountWidth, align: TextAlign.right),
        _ledgerCell('', width: _amountWidth, align: TextAlign.right),
        _ledgerCell(
          '৳${_formatMoney(_openingBalance)}',
          width: _balanceWidth,
          align: TextAlign.right,
          weight: FontWeight.bold,
        ),
      ],
    );
  }

  Widget _buildTransactionLedgerRow(Map<String, dynamic> transaction) {
    final debit = _toDouble(transaction['debit']);
    final credit = _toDouble(transaction['credit']);
    final balance = _toDouble(transaction['running_balance']);

    return Row(
      children: [
        _ledgerCell(
          _formatDate(_transactionDate(transaction)),
          width: _dateWidth,
        ),
        Tooltip(
          message: _voucher(transaction),
          child: _ledgerCell(
            _voucher(transaction),
            width: _voucherWidth,
            weight: FontWeight.w600,
          ),
        ),
        Tooltip(
          message: [
            _description(transaction),
            _secondaryDescription(transaction),
          ].where((e) => e.isNotEmpty).join(' • '),
          child: SizedBox(
            width: _particularWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _description(transaction),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_secondaryDescription(transaction).isNotEmpty)
                    Text(
                      _secondaryDescription(transaction),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        _ledgerCell(
          debit > 0 ? '৳${_formatMoney(debit)}' : '',
          width: _amountWidth,
          align: TextAlign.right,
          weight: debit > 0 ? FontWeight.w600 : FontWeight.normal,
        ),
        _ledgerCell(
          credit > 0 ? '৳${_formatMoney(credit)}' : '',
          width: _amountWidth,
          align: TextAlign.right,
          weight: credit > 0 ? FontWeight.w600 : FontWeight.normal,
        ),
        _ledgerCell(
          '৳${_formatMoney(balance)}',
          width: _balanceWidth,
          align: TextAlign.right,
          weight: FontWeight.bold,
        ),
      ],
    );
  }

  Widget _buildLedgerTable() {
    final rows = <Widget>[];

    if (_openingBalance != 0) {
      rows.add(_buildOpeningLedgerRow());
      rows.add(_ledgerDivider());
    }

    for (var i = 0; i < _transactions.length; i++) {
      rows.add(_buildTransactionLedgerRow(_transactions[i]));

      if (i != _transactions.length - 1) {
        rows.add(_ledgerDivider());
      }
    }

    if (_openingBalance == 0 && _transactions.isEmpty) {
      rows.add(
        const Padding(
          padding: EdgeInsets.all(28),
          child: Center(
            child: Text(
              'No transactions yet.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _ledgerWidth,
          child: Card(
            margin: const EdgeInsets.only(top: 6),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [_buildLedgerHeader(), ...rows]),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOTALS
  // ============================================================

  Widget _summaryLine(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '৳${_formatMoney(value)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    const double summaryWidth = 330;

    return Center(
      child: SizedBox(
        width: _ledgerWidth,
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: summaryWidth,
            child: Card(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    _compactSummaryLine('Total Debit', _totalDebit),
                    const Divider(height: 1),
                    _compactSummaryLine('Total Credit', _totalCredit),
                    const Divider(height: 1),
                    _compactSummaryLine('Balance', _currentBalance, bold: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactSummaryLine(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '৳${_formatMoney(value)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE-ONLY LEDGER
  // Desktop ledger table/totals are intentionally untouched.
  // ============================================================

  Widget _mobileOpeningCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _fromDate != null
                        ? 'Balance Brought Forward'
                        : 'Opening Balance',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '৳${_formatMoney(_openingBalance)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _fromDate != null
                  ? 'B/F'
                  : '${_formatDate(widget.account.openingDate)}  •  OB',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileTransactionCard(Map<String, dynamic> transaction) {
    final debit = _toDouble(transaction['debit']);
    final credit = _toDouble(transaction['credit']);
    final balance = _toDouble(transaction['running_balance']);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _formatDate(_transactionDate(transaction)),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _voucher(transaction),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              _description(transaction),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),

            if (_secondaryDescription(transaction).isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                _secondaryDescription(transaction),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const Divider(height: 20),

            Row(
              children: [
                Expanded(
                  child: Text(
                    _amountText(transaction),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _amountColor(transaction),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '৳${_formatMoney(balance)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (debit > 0 || credit > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      debit > 0 ? 'Debit: ৳${_formatMoney(debit)}' : 'Debit: -',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ),
                  Text(
                    credit > 0
                        ? 'Credit: ৳${_formatMoney(credit)}'
                        : 'Credit: -',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mobileLedgerEntries() {
    if (_openingBalance == 0 && _transactions.isEmpty) {
      return const Card(
        margin: EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(
            child: Text(
              'No transactions yet.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_openingBalance != 0) _mobileOpeningCard(),
        ..._transactions.map(_mobileTransactionCard),
      ],
    );
  }

  Widget _mobileTotals() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            _compactSummaryLine('Total Debit', _totalDebit),
            const Divider(height: 1),
            _compactSummaryLine('Total Credit', _totalCredit),
            const Divider(height: 1),
            _compactSummaryLine('Balance', _currentBalance, bold: true),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _loading ? null : _exportPdf,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLedger,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _buildDateFilter(),
                  _buildSummary(),
                  if (MediaQuery.sizeOf(context).width < 700)
                    _mobileLedgerEntries()
                  else
                    _buildLedgerTable(),
                  if (MediaQuery.sizeOf(context).width < 700)
                    _mobileTotals()
                  else
                    _buildTotals(),
                ],
              ),
            ),
    );
  }
}
