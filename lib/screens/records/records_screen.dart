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
    final bool isDesktop =
        MediaQuery.of(context).size.width >= 900;

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

        // Reports screen-এর মতো card size
        childAspectRatio:
            isDesktop
                ? 2.2
                : 1.05,

        children: [

          _card(
            context,
            Icons.people,
            "Customers",
            "Manage customers",
            Colors.blue,
            const CustomerScreen(),
          ),

          _card(
            context,
            Icons.local_shipping,
            "Suppliers",
            "Manage suppliers",
            Colors.orange,
            const SupplierScreen(),
          ),

          _card(
            context,
            Icons.account_balance_wallet,
            "Accounts",
            "Receivable & payment",
            Colors.purple,
            const AccountsScreen(),
          ),

          _card(
            context,
            Icons.inventory_2,
            "Products",
            "Stock & inventory",
            Colors.green,
            const ProductScreen(),
          ),

          _card(
            context,
            Icons.shopping_cart,
            "Sales",
            "Sales records",
            Colors.deepOrange,
            const SalesScreen(),
          ),

          _card(
            context,
            Icons.shopping_bag,
            "Purchases",
            "Purchase history",
            Colors.teal,
            const PurchaseHistoryScreen(),
          ),

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