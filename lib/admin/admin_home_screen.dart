import 'package:flutter/material.dart';

import '../services/license_admin_service.dart';
import 'admin_customer_screen.dart';
import 'admin_login_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<void> _logout(
    BuildContext context,
  ) async {
    await LicenseAdminService.instance
        .logout();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const AdminLoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user =
        LicenseAdminService.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NexEra License Admin',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () =>
                _logout(context),
            icon:
                const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, Admin',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              user?.email ??
                  'NexEra Administrator',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(
              height: 32,
            ),

            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(
                    Icons.person_add,
                  ),
                ),
                title: const Text(
                  'Software Customers',
                ),
                subtitle: const Text(
                  'Create and manage NexEra software customers',
                ),
                trailing:
                    const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) {
        return const AdminCustomerScreen();
      },
    ),
  );
},
              ),
            ),
          ],
        ),
      ),
    );
  }
}