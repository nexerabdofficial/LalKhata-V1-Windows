import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppKeyboardShortcut {
  final String id;
  final String title;
  final String defaultKeys;

  const AppKeyboardShortcut({
    required this.id,
    required this.title,
    required this.defaultKeys,
  });
}

class KeyboardShortcutService {
  KeyboardShortcutService._();

  static const String _prefix = 'keyboard_shortcut_';

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void _notifyChanged() {
    revision.value++;
  }

  static const List<AppKeyboardShortcut> shortcuts = [
    AppKeyboardShortcut(id: 'new_sale', title: 'New Sale', defaultKeys: 'SS'),
    AppKeyboardShortcut(
      id: 'new_purchase',
      title: 'New Purchase',
      defaultKeys: 'PP',
    ),
    AppKeyboardShortcut(id: 'ledger', title: 'Ledger', defaultKeys: 'LL'),
    AppKeyboardShortcut(id: 'journal', title: 'Journal', defaultKeys: 'JJ'),
    AppKeyboardShortcut(
      id: 'customer_receive',
      title: 'Receive from Customer',
      defaultKeys: 'RR',
    ),
    AppKeyboardShortcut(
      id: 'supplier_payment',
      title: 'Payment to Supplier',
      defaultKeys: 'EE',
    ),
    AppKeyboardShortcut(
      id: 'fund_transfer',
      title: 'Fund Transfer',
      defaultKeys: 'TT',
    ),
    AppKeyboardShortcut(
      id: 'quick_entry',
      title: 'Quick Entry',
      defaultKeys: 'QQ',
    ),
    AppKeyboardShortcut(id: 'cash_flow', title: 'Cash Flow', defaultKeys: 'CC'),
    AppKeyboardShortcut(id: 'dashboard', title: 'Dashboard', defaultKeys: 'DD'),
    AppKeyboardShortcut(
      id: 'stock_report',
      title: 'Stock Report',
      defaultKeys: 'AA',
    ),
  ];

  static Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      for (final item in shortcuts)
        item.id: (prefs.getString('$_prefix${item.id}') ?? item.defaultKeys)
            .trim()
            .toUpperCase(),
    };
  }

  static Future<String> getShortcut(String id) async {
    final prefs = await SharedPreferences.getInstance();

    final item = shortcuts.firstWhere((e) => e.id == id);

    return (prefs.getString('$_prefix$id') ?? item.defaultKeys)
        .trim()
        .toUpperCase();
  }

  static Future<String?> saveShortcut({
    required String id,
    required String keys,
  }) async {
    final normalized = keys.trim().toUpperCase();

    if (!RegExp(r'^[A-Z0-9]{2}$').hasMatch(normalized)) {
      return 'Shortcut must contain exactly 2 letters or numbers.';
    }

    final values = await load();

    for (final entry in values.entries) {
      if (entry.key != id && entry.value == normalized) {
        final conflict = shortcuts.firstWhere((e) => e.id == entry.key);

        return '$normalized is already used by ${conflict.title}.';
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$id', normalized);

    _notifyChanged();

    return null;
  }

  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();

    for (final item in shortcuts) {
      await prefs.remove('$_prefix${item.id}');
    }

    _notifyChanged();
  }
}
