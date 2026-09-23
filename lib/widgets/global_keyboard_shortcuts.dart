import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../screens/accounts/accounts_screen.dart';
import '../screens/accounts/ff_receive_payment_screen.dart';
import '../screens/accounts/fund_transfer_screen.dart';
import '../screens/accounts/journal_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/purchases/purchase_screen.dart';
import '../screens/reports/cash_flow_screen.dart';
import '../screens/reports/stock_report_screen.dart';
import '../screens/sales/add_sale_screen.dart';
import '../services/keyboard_shortcut_service.dart';
import 'quick_action_sheet.dart';

class GlobalKeyboardShortcuts extends StatefulWidget {
  final Widget child;

  const GlobalKeyboardShortcuts({super.key, required this.child});

  @override
  State<GlobalKeyboardShortcuts> createState() =>
      _GlobalKeyboardShortcutsState();
}

class _GlobalKeyboardShortcutsState extends State<GlobalKeyboardShortcuts> {
  Map<String, String> _shortcuts = {};

  String _buffer = '';
  Timer? _bufferTimer;

  bool _opening = false;

  bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();

    KeyboardShortcutService.revision.addListener(_onShortcutsChanged);

    _loadShortcuts();
  }

  void _onShortcutsChanged() {
    _clearBuffer();
    _loadShortcuts();
  }

  @override
  void dispose() {
    KeyboardShortcutService.revision.removeListener(_onShortcutsChanged);
    _bufferTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadShortcuts() async {
    final values = await KeyboardShortcutService.load();

    if (!mounted) return;

    setState(() {
      _shortcuts = values;
    });
  }

  bool _isTextEntryFocused() {
    final focus = FocusManager.instance.primaryFocus;

    if (focus == null) return false;

    final context = focus.context;

    if (context == null) return false;

    if (context.widget is EditableText) {
      return true;
    }

    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!_desktop) return KeyEventResult.ignored;

    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_opening || _isTextEntryFocused()) {
      _clearBuffer();
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      return KeyEventResult.ignored;
    }

    final label = key.keyLabel.trim().toUpperCase();

    if (!RegExp(r'^[A-Z0-9]$').hasMatch(label)) {
      _clearBuffer();
      return KeyEventResult.ignored;
    }

    _bufferTimer?.cancel();

    _buffer += label;

    if (_buffer.length > 2) {
      _buffer = _buffer.substring(_buffer.length - 2);
    }

    if (_buffer.length == 2) {
      final sequence = _buffer;
      _clearBuffer();

      final action = _actionFor(sequence);

      if (action != null) {
        _execute(action);
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    _bufferTimer = Timer(const Duration(milliseconds: 900), _clearBuffer);

    return KeyEventResult.ignored;
  }

  String? _actionFor(String sequence) {
    for (final entry in _shortcuts.entries) {
      if (entry.value.toUpperCase() == sequence) {
        return entry.key;
      }
    }

    return null;
  }

  void _clearBuffer() {
    _bufferTimer?.cancel();
    _bufferTimer = null;
    _buffer = '';
  }

  Future<void> _execute(String action) async {
    if (!mounted || _opening) return;

    _opening = true;

    try {
      // Reload here so Settings edits work immediately without app restart.
      _shortcuts = await KeyboardShortcutService.load();

      if (!mounted) return;

      switch (action) {
        case 'new_sale':
          await _open(const AddSaleScreen());
          break;

        case 'new_purchase':
          await _open(const PurchaseScreen());
          break;

        case 'ledger':
          // Account Ledger needs a selected Account.
          await _open(const AccountsScreen());
          break;

        case 'journal':
          await _open(const JournalScreen());
          break;

        case 'customer_receive':
          await _open(
            const FFReceivePaymentEntryScreen(mode: FFMoneyEntryMode.receive),
          );
          break;

        case 'supplier_payment':
          await _open(
            const FFReceivePaymentEntryScreen(mode: FFMoneyEntryMode.payment),
          );
          break;

        case 'fund_transfer':
          await _open(const FundTransferScreen());
          break;

        case 'quick_entry':
          await QuickActionSheet.showQuickEntry(context);
          break;

        case 'cash_flow':
          await _open(const CashFlowScreen());
          break;

        case 'dashboard':
          await appNavigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
          );
          break;

        case 'stock_report':
          await _open(const StockReportScreen());
          break;
      }
    } finally {
      _opening = false;

      // A shortcut may have been edited while another screen was open.
      await _loadShortcuts();
    }
  }

  Future<void> _open(Widget page) async {
    await appNavigatorKey.currentState!.push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      canRequestFocus: true,
      onKeyEvent: _handleKey,
      child: widget.child,
    );
  }
}
