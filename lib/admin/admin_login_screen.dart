import 'package:flutter/material.dart';

import '../services/license_admin_service.dart';
import 'admin_home_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() =>
      _AdminLoginScreenState();
}

class _AdminLoginScreenState
    extends State<AdminLoginScreen> {
  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  Future<void> _login() async {
    if (_loading) return;

    final email =
        _emailController.text.trim();

    final password =
        _passwordController.text;

    if (email.isEmpty ||
        password.isEmpty) {
      _showMessage(
        'Email and password are required.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    final error =
        await LicenseAdminService.instance.login(
      email: email,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (error == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              const AdminHomeScreen(),
        ),
      );

      return;
    }

    if (error == 'ACCESS_DENIED') {
      _showMessage(
        'Access denied. This account is not a NexEra license administrator.',
      );
      return;
    }

    _showMessage(error);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 430,
          ),
          child: Card(
            margin:
                const EdgeInsets.all(24),
            child: Padding(
              padding:
                  const EdgeInsets.all(32),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    size: 70,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  const Text(
                    'NexEra License Admin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    'Administrator Login',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  TextField(
                    controller:
                        _emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(
                      labelText: 'Email',
                      prefixIcon:
                          Icon(Icons.email),
                      border:
                          OutlineInputBorder(),
                    ),
                    enabled: !_loading,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  TextField(
                    controller:
                        _passwordController,
                    obscureText:
                        _obscurePassword,
                    decoration:
                        InputDecoration(
                      labelText: 'Password',
                      prefixIcon:
                          const Icon(
                        Icons.lock,
                      ),
                      suffixIcon:
                          IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons
                                  .visibility
                              : Icons
                                  .visibility_off,
                        ),
                      ),
                      border:
                          const OutlineInputBorder(),
                    ),
                    enabled: !_loading,
                    onSubmitted: (_) =>
                        _login(),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    height: 50,
                    child:
                        FilledButton.icon(
                      onPressed:
                          _loading
                              ? null
                              : _login,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons.login,
                            ),
                      label: Text(
                        _loading
                            ? 'Signing in...'
                            : 'Login',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}