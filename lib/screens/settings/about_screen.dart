import 'package:flutter/material.dart';

import '../../gab/gab_branding.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _businessName = '';
  String _phone = '';
  String _address = '';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    final businessName =
        await GABBranding.getBusinessName();

    final phone =
        await GABBranding.getPhone();

    final address =
        await GABBranding.getAddress();

    if (!mounted) return;

    setState(() {
      _businessName = businessName;
      _phone = phone;
      _address = address;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _loading
              ? 'About'
              : 'About $_businessName',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const CircularProgressIndicator()
              : Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ------------------------------------------------
                        // BUSINESS NAME
                        // ------------------------------------------------

                        Text(
                          _businessName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ------------------------------------------------
                        // APP VERSION
                        // ------------------------------------------------

                        Text(
                          GABBranding.appVersion,
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 25),

                        // ------------------------------------------------
                        // PHONE
                        // ------------------------------------------------

                        if (_phone.trim().isNotEmpty) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _phone,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                        ],

                        // ------------------------------------------------
                        // ADDRESS
                        // ------------------------------------------------

                        if (_address.trim().isNotEmpty) ...[
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _address,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                        ],

                        const Divider(),

                        const SizedBox(height: 15),

                        // ------------------------------------------------
                        // DEVELOPED BY
                        // ------------------------------------------------

                        const Text(
                          'Developed by',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Image.asset(
                          'assets/nexera_logo.png',
                          width: 180,
                          height: 100,
                          fit: BoxFit.contain,
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Building Ideas into Software',
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 20),

                        const Divider(),

                        const SizedBox(height: 10),

                        const Text(
                          '© 2026 NexEra BD',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
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