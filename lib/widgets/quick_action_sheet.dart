import 'package:flutter/material.dart';

import '../screens/incomes/add_income_screen.dart';
import '../screens/accounts/add_account_screen.dart';
import '../screens/customers/add_customer_screen.dart';
import '../screens/products/add_product_screen.dart';
import '../screens/purchases/purchase_screen.dart';
import '../screens/sales/add_sale_screen.dart';
import '../screens/suppliers/add_supplier_screen.dart';
import '../screens/expenses/add_expense_screen.dart';
import '../screens/production/actual_production_screen.dart';
import '../screens/production/production_bom_screen.dart';

class QuickActionSheet {
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Wrap(
              runSpacing: 12,
              children: [
                const Center(
                  child: Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                _item(
                  context,
                  Icons.account_balance_wallet,
                  "Add Account",
                  () => _open(
                    context,
                    const AddAccountScreen(),
                  ),
                ),

                _item(
                  context,
                  Icons.inventory_2,
                  "Add Product",
                  () => _open(
                    context,
                    const AddProductScreen(),
                  ),
                ),

                _item(
                  context,
                  Icons.local_shipping,
                  "Add Supplier",
                  () => _open(
                    context,
                    const AddSupplierScreen(),
                  ),
                ),

                _item(
                  context,
                  Icons.shopping_bag,
                  "New Purchase",
                  () => _open(
                    context,
                    const PurchaseScreen(),
                  ),
                ),

                _item(
                  context,
                  Icons.people,
                  "Add Customer",
                  () => _open(
                    context,
                    const AddCustomerScreen(),
                  ),
                ),

                _item(
                  context,
                  Icons.shopping_cart,
                  "New Sale",
                  () => _open(
                    context,
                    const AddSaleScreen(),
                  ),
                ),

                _item(
                  context,
                  Icons.payments,
                  "Add Income",
                  () => _open(
                    context,
                    const AddIncomeScreen(),
                  ),
                ),

                _item(
                  context,
                  Icons.money_off,
                  "Add Expense",
                  () => _open(
                    context,
                    const AddExpenseScreen(),
                  ),
                ),

                // ==================================================
                // PRODUCTION
                // ==================================================

                _item(
                  context,
                  Icons.factory,
                  "Production",
                  () => _open(
                    context,
                    const ActualProductionScreen(),
                  ),
                ),

                _item(
                  context,
                  Icons.account_tree,
                  "BOM Management",
                  () => _open(
                    context,
                    const ProductionBomScreen(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(icon),
      ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  static Future<void> _open(
    BuildContext context,
    Widget page,
  ) async {
    Navigator.pop(context);

    await Future.delayed(
      const Duration(milliseconds: 150),
    );

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }
}