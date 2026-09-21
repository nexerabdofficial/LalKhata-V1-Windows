import 'package:flutter/material.dart';

import '../screens/accounts/add_account_screen.dart';
import '../screens/accounts/ff_receive_payment_screen.dart';
import '../screens/accounts/fund_transfer_screen.dart';
import '../screens/accounts/journal_screen.dart';
import '../screens/accounts/manage_account_groups_screen.dart';
import '../screens/production/actual_production_screen.dart';
import '../screens/production/production_bom_screen.dart';
import '../screens/products/add_product_screen.dart';
import '../screens/purchases/purchase_screen.dart';
import '../screens/sales/add_sale_screen.dart';

class QuickActionSheet {
  // Legacy compatibility.
  static Future<void> show(BuildContext context) {
    return showQuickAdd(context);
  }

  static Future<void> showQuickAdd(BuildContext context) async {
    await _showSheet(
      context,
      title: 'Quick Add',
      subtitle: 'Create master records',
      icon: Icons.add_circle_outline_rounded,
      items: [
        _QuickSheetItem(
          icon: Icons.account_balance_outlined,
          title: 'Add Account',
          subtitle: 'Customer, Supplier, Cash, Bank, MFS, Asset, Liability...',
          page: const AddAccountScreen(),
        ),
        _QuickSheetItem(
          icon: Icons.account_tree_outlined,
          title: 'Account Groups',
          subtitle: 'Create or manage custom account groups',
          page: const ManageAccountGroupsScreen(),
        ),
        _QuickSheetItem(
          icon: Icons.inventory_2_outlined,
          title: 'Add Product',
          subtitle: 'Create raw material or finished product',
          page: const AddProductScreen(),
        ),
      ],
    );
  }

  static Future<void> showQuickEntry(BuildContext context) async {
    await _showSheet(
      context,
      title: 'Quick Entry',
      subtitle: 'Record business transactions',
      icon: Icons.bolt_rounded,
      items: [
        _QuickSheetItem(
          icon: Icons.shopping_cart_outlined,
          title: 'New Sale',
          subtitle: 'Cash, credit or split-payment sale',
          page: const AddSaleScreen(),
        ),
        _QuickSheetItem(
          icon: Icons.shopping_bag_outlined,
          title: 'New Purchase',
          subtitle: 'Cash, credit or split-payment purchase',
          page: const PurchaseScreen(),
        ),
        _QuickSheetItem(
          icon: Icons.south_west_rounded,
          title: 'Receive',
          subtitle: 'Receive from customer, income or other ledger',
          page: const FFReceivePaymentEntryScreen(
            mode: FFMoneyEntryMode.receive,
          ),
        ),
        _QuickSheetItem(
          icon: Icons.north_east_rounded,
          title: 'Payment',
          subtitle: 'Pay supplier, expense or other ledger',
          page: const FFReceivePaymentEntryScreen(
            mode: FFMoneyEntryMode.payment,
          ),
        ),
        _QuickSheetItem(
          icon: Icons.swap_horiz_rounded,
          title: 'Contra',
          subtitle: 'Transfer money between accounts',
          page: const FundTransferScreen(),
        ),
        _QuickSheetItem(
          icon: Icons.menu_book_outlined,
          title: 'Journal',
          subtitle: 'Create a balanced double-entry journal',
          page: const JournalScreen(),
        ),
        _QuickSheetItem(
          icon: Icons.factory_outlined,
          title: 'Production',
          subtitle: 'Consume materials and produce finished goods',
          page: const ActualProductionScreen(),
        ),
        _QuickSheetItem(
          icon: Icons.account_tree_outlined,
          title: 'BOM Management',
          subtitle: 'Create or manage production recipes',
          page: const ProductionBomScreen(),
        ),
      ],
    );
  }

  static Future<void> _showSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<_QuickSheetItem> items,
  }) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * .88,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    icon,
                    size: 30,
                    color: Theme.of(sheetContext).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...items.map(
                    (item) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(child: Icon(item.icon)),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(item.subtitle),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _open(sheetContext, item.page),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _open(BuildContext context, Widget page) async {
    Navigator.pop(context);

    await Future.delayed(const Duration(milliseconds: 120));

    if (!context.mounted) return;

    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _QuickSheetItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  const _QuickSheetItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });
}
