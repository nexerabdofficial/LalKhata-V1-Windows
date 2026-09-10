import 'package:flutter/material.dart';

import '../accounts/accounts_screen.dart';
import '../customers/customer_screen.dart';
import '../products/product_screen.dart';
import '../purchases/purchase_history_screen.dart';
import '../sales/sales_screen.dart';
import '../suppliers/supplier_screen.dart';
import '../loan_screen.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Records"),
        centerTitle: true,
      ),

      body: GridView.count(
        padding: const EdgeInsets.all(16),

        crossAxisCount: 2,

        crossAxisSpacing: 14,

        mainAxisSpacing: 14,

        childAspectRatio: 0.82,

        children: [

          // =====================================================
          // CUSTOMERS
          // =====================================================

          _card(
            context,
            Icons.people,
            "Customers",
            "Manage customers",
            Colors.blue,
            const CustomerScreen(),
          ),

          // =====================================================
          // SUPPLIERS
          // =====================================================

          _card(
            context,
            Icons.local_shipping,
            "Suppliers",
            "Manage suppliers",
            Colors.orange,
            const SupplierScreen(),
          ),

          // =====================================================
          // ACCOUNTS
          // =====================================================

          _card(
            context,
            Icons.account_balance_wallet,
            "Accounts",
            "Receivable & payment",
            Colors.purple,
            const AccountsScreen(),
          ),

          // =====================================================
          // PRODUCTS
          // =====================================================

          _card(
            context,
            Icons.inventory_2,
            "Products",
            "Stock & inventory",
            Colors.green,
            const ProductScreen(),
          ),

          // =====================================================
          // SALES
          // =====================================================

          _card(
            context,
            Icons.shopping_cart,
            "Sales",
            "Sales records",
            Colors.deepOrange,
            const SalesScreen(),
          ),

          // =====================================================
          // PURCHASES
          // =====================================================

          _card(
            context,
            Icons.shopping_bag,
            "Purchases",
            "Purchase history",
            Colors.teal,
            const PurchaseHistoryScreen(),
          ),

          // =====================================================
          // LOANS
          // =====================================================

          _card(
            context,
            Icons.account_balance,
            "Loans",
            "Loan given & taken",
            Colors.red,
            const LoanScreen(),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // RECORD CARD
  // ===========================================================

  Widget _card(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    Widget page,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),

      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => page,
          ),
        );
      },

      child: Card(
        elevation: 3,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),

        child: Padding(
          padding: const EdgeInsets.all(18),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              // -------------------------------------------------
              // ICON
              // -------------------------------------------------

              CircleAvatar(
                radius: 28,

                backgroundColor:
                    color.withOpacity(.12),

                child: Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              // -------------------------------------------------
              // TITLE
              // -------------------------------------------------

              Text(
                title,

                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),

                textAlign: TextAlign.center,
              ),

              const SizedBox(
                height: 6,
              ),

              // -------------------------------------------------
              // SUBTITLE
              // -------------------------------------------------

              Text(
                subtitle,

                textAlign: TextAlign.center,

                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}