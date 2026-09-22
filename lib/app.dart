import 'dart:async';

import 'package:flutter/material.dart';

import 'main.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'services/license_service.dart';

class NexeraInventoryApp extends StatelessWidget {
  const NexeraInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'LalKhata',

      navigatorObservers: [routeObserver],

      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),

      // Desktop keyboard + mouse scrolling support.
      // Arrow keys, Page Up/Down, Home/End work with focused scroll views.
      // Text fields keep their normal editing/backspace behavior.
      scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars: true),

      home: const LicenseGate(),
    );
  }
}

// ============================================================
// LICENSE GATE
// ============================================================

class LicenseGate extends StatefulWidget {
  const LicenseGate({super.key});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> with WidgetsBindingObserver {
  LicenseResult? _result;

  bool _loading = true;
  bool _processing = false;

  Timer? _licenseCheckTimer;

  final TextEditingController _customerCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _checkLicense();

    // ==========================================================
    // PERIODIC LICENSE CHECK
    // ==========================================================
    //
    // This makes sure that if the license expires while the app
    // is already open, the app will be locked automatically.
    //
    // validate() normally uses local expiry information, so this
    // does NOT contact Supabase every minute unless verification
    // is actually required.
    //
    _licenseCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _revalidateLicense();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _licenseCheckTimer?.cancel();
    _licenseCheckTimer = null;

    _customerCodeController.dispose();

    super.dispose();
  }

  // ==========================================================
  // APP LIFECYCLE
  // ==========================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Whenever the user returns to LalKhata,
    // immediately check the license again.
    if (state == AppLifecycleState.resumed) {
      _revalidateLicense();
    }
  }

  // ==========================================================
  // INITIAL LICENSE CHECK
  // ==========================================================

  Future<void> _checkLicense() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final result = await LicenseService.instance.validate();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _result = const LicenseResult(
          success: false,
          code: 'LICENSE_VERIFICATION_FAILED',
          message: 'Unable to verify the license. Please try again.',
        );
      });
    }
  }

  // ==========================================================
  // PERIODIC / RESUME LICENSE CHECK
  // ==========================================================
  //
  // IMPORTANT:
  // Do NOT show the splash screen during this check.
  //
  // Otherwise every minute the Dashboard would disappear
  // briefly and show "Checking license...".
  //
  Future<void> _revalidateLicense() async {
    if (!mounted) return;

    if (_processing) return;

    try {
      final result = await LicenseService.instance.validate();

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _result = result;
          _loading = false;
        });

        return;
      }

      if (_result?.success != true ||
          _result?.expiresAt != result.expiresAt ||
          _result?.code != result.code) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (e) {
      // Silent failure.
      //
      // We intentionally do not block the app here because
      // the existing license state remains valid unless
      // validate() explicitly reports an invalid license.
    }
  }

  // ==========================================================
  // ACTIVATE
  // ==========================================================

  Future<void> _activate() async {
    if (_processing) return;

    final customerCode = _customerCodeController.text.trim();

    if (customerCode.isEmpty) {
      setState(() {
        _result = const LicenseResult(
          success: false,
          code: 'INVALID_CUSTOMER_CODE',
          message: 'Please enter your customer code.',
        );
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _processing = true;
    });

    try {
      final result = await LicenseService.instance.activate(
        customerCode: customerCode,
      );

      if (!mounted) return;

      setState(() {
        _processing = false;
        _result = result;
      });

      if (result.success) {
        _showSuccessMessage('License activated successfully.');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _processing = false;

        _result = const LicenseResult(
          success: false,
          code: 'LICENSE_ACTIVATION_FAILED',
          message: 'Unable to activate the license. Please try again.',
        );
      });
    }
  }

  // ==========================================================
  // SUCCESS MESSAGE
  // ==========================================================

  void _showSuccessMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    // ========================================================
    // BRANDED SPLASH / INITIAL LICENSE CHECK
    // ========================================================

    if (_loading) {
      return const LalKhataSplashScreen();
    }

    // ========================================================
    // LICENSE VALID
    // ========================================================

    if (_result?.success == true) {
      return const DashboardScreen();
    }

    // ========================================================
    // LICENSE INVALID
    // ========================================================

    return _LicenseScreen(
      result: _result!,
      customerCodeController: _customerCodeController,
      processing: _processing,
      onActivate: _activate,
      onRetry: _checkLicense,
    );
  }
}

// ============================================================
// LALKHATA SPLASH SCREEN
// ============================================================

class LalKhataSplashScreen extends StatelessWidget {
  const LalKhataSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/branding/lalkhata_logo.png',
                width: 180,
                height: 130,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 12),

              const Text(
                'LalKhata',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Simple. Smart. Business.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 32),

              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),

              const SizedBox(height: 16),

              Text(
                'Checking license...',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 60),

              Text(
                'Powered by NexEra IT BD',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LICENSE SCREEN
// ============================================================

class _LicenseScreen extends StatelessWidget {
  final LicenseResult result;

  final TextEditingController customerCodeController;

  final bool processing;

  final VoidCallback onActivate;
  final VoidCallback onRetry;

  const _LicenseScreen({
    required this.result,
    required this.customerCodeController,
    required this.processing,
    required this.onActivate,
    required this.onRetry,
  });

  bool get isMismatch => result.code == 'DEVICE_MISMATCH';

  bool get isExpired => result.code == 'LICENSE_EXPIRED';

  bool get isDeviceLimit => result.code == 'DEVICE_LIMIT_REACHED';

  bool get isNotActivated =>
      result.code == 'NOT_ACTIVATED' ||
      result.code == 'LICENSE_NOT_ACTIVATED' ||
      result.code == 'LICENSE_NOT_FOUND' ||
      result.code == 'CUSTOMER_NOT_FOUND';

  String get title {
    if (isMismatch) {
      return 'Device Not Authorized';
    }

    if (isExpired) {
      return 'License Expired';
    }

    if (isDeviceLimit) {
      return 'Device Limit Reached';
    }

    if (isNotActivated) {
      return 'License Activation';
    }

    return 'License Verification Failed';
  }

  IconData get icon {
    if (isMismatch) {
      return Icons.phonelink_erase;
    }

    if (isExpired) {
      return Icons.event_busy;
    }

    if (isDeviceLimit) {
      return Icons.devices_other;
    }

    if (isNotActivated) {
      return Icons.verified_user_outlined;
    }

    return Icons.lock_outline;
  }

  @override
  Widget build(BuildContext context) {
    final showActivationForm = isNotActivated || isExpired;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LalKhata',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/branding/lalkhata_logo.png',
                      width: 150,
                      height: 90,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'LalKhata',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Simple. Smart. Business.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Icon(icon, size: 52),

                    const SizedBox(height: 16),

                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      result.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),

                    if (result.businessName != null) ...[
                      const SizedBox(height: 14),

                      Text(
                        result.businessName!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    if (result.expiresAt != null) ...[
                      const SizedBox(height: 8),

                      Text(
                        'Expiry: '
                        '${_formatDate(result.expiresAt!)}',
                        textAlign: TextAlign.center,
                      ),
                    ],

                    // ==================================================
                    // CUSTOMER CODE
                    // ==================================================
                    if (showActivationForm) ...[
                      const SizedBox(height: 28),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Customer Code',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: customerCodeController,
                        enabled: !processing,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          hintText: 'Enter your customer code',
                          prefixIcon: Icon(Icons.key),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => onActivate(),
                      ),

                      const SizedBox(height: 8),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Enter the customer code '
                          'provided by NexEra IT BD.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: processing ? null : onActivate,
                          icon: processing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified),
                          label: Text(
                            processing ? 'Activating...' : 'Activate License',
                          ),
                        ),
                      ),
                    ],

                    // ==================================================
                    // DEVICE MISMATCH
                    // ==================================================
                    if (isMismatch) ...[
                      const SizedBox(height: 24),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This license is already '
                                'bound to another device. '
                                'Please contact NexEra IT BD '
                                'if you need to change devices.',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: processing ? null : onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check Again'),
                        ),
                      ),
                    ],

                    // ==================================================
                    // OTHER ERRORS
                    // ==================================================
                    if (!showActivationForm && !isMismatch) ...[
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: processing ? null : onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    const Divider(),

                    const SizedBox(height: 12),

                    const Text(
                      'LalKhata',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'by NexEra IT BD',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // DATE FORMAT
  // ==========================================================

  static String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final year = local.year.toString();

    return '$day-$month-$year';
  }
}
