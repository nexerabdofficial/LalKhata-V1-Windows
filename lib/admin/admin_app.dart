import 'package:flutter/material.dart';

import 'admin_login_screen.dart';

class NexeraAdminApp extends StatelessWidget {
  const NexeraAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NexEra License Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: const AdminLoginScreen(),
    );
  }
}