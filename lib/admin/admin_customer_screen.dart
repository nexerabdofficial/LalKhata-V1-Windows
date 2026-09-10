import 'package:flutter/material.dart';

import '../services/license_admin_service.dart';

class AdminCustomerScreen extends StatefulWidget {
  const AdminCustomerScreen({
    super.key,
  });

  @override
  State<AdminCustomerScreen> createState() =>
      _AdminCustomerScreenState();
}

class _AdminCustomerScreenState
    extends State<AdminCustomerScreen> {
  final _formKey =
      GlobalKey<FormState>();

  final _customerCodeController =
      TextEditingController();

  final _businessNameController =
      TextEditingController();

  final _phoneController =
      TextEditingController();

  final _addressController =
      TextEditingController();

  final _maxDevicesController =
      TextEditingController(
    text: '1',
  );

  String _duration = '1_year';

  bool _loading = false;

  @override
  void dispose() {
    _customerCodeController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _maxDevicesController.dispose();

    super.dispose();
  }

  // ==========================================================
  // CREATE CUSTOMER
  // ==========================================================

  Future<void> _createCustomer() async {
    if (_loading) return;

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final maxDevices =
        int.tryParse(
      _maxDevicesController.text
          .trim(),
    );

    if (maxDevices == null ||
        maxDevices < 1) {
      _showMessage(
        'Maximum devices must be at least 1.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    final result =
    await LicenseAdminService
        .instance
        .createCustomer(
  customerCode:
      _customerCodeController.text.trim(),
  businessName:
      _businessNameController.text.trim(),
  phone:
      _phoneController.text.trim(),
  address:
      _addressController.text.trim(),
  duration:
      _duration,
  maxDevices:
      maxDevices,
);


    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (result['success'] == true) {
  _showSuccess(
    result['message']?.toString() ??
        'Customer created successfully.',
  );

  _clearForm();

  return;
}

_showMessage(
  '${result['code'] ?? 'ERROR'}: '
  '${result['message'] ?? 'Unable to create customer.'}',
);
  }

  void _clearForm() {
    _customerCodeController.clear();
    _businessNameController.clear();
    _phoneController.clear();
    _addressController.clear();

    _maxDevicesController.text =
        '1';

    setState(() {
      _duration = '1_year';
    });
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _showSuccess(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        backgroundColor:
            Colors.green,
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
      appBar: AppBar(
        title: const Text(
          'Create Software Customer',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 600,
            ),
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Software Customer',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      const Text(
                        'This customer is a NexEra software customer, not an in-app customer.',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      TextFormField(
                        controller:
                            _customerCodeController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Customer Code',
                          hintText:
                              'Example: RHMS-001',
                          prefixIcon:
                              Icon(Icons.key),
                          border:
                              OutlineInputBorder(),
                        ),
                        textCapitalization:
                            TextCapitalization
                                .characters,
                        enabled: !_loading,
                        validator: (value) {
                          if (value == null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'Customer code is required';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      TextFormField(
                        controller:
                            _businessNameController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Business Name',
                          hintText:
                              'Example: Rahim Store',
                          prefixIcon:
                              Icon(
                            Icons.store,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        enabled: !_loading,
                        validator: (value) {
                          if (value == null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'Business name is required';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      TextFormField(
                        controller:
                            _phoneController,
                        keyboardType:
                            TextInputType.phone,
                        decoration:
                            const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon:
                              Icon(
                            Icons.phone,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        enabled: !_loading,
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      TextFormField(
                        controller:
                            _addressController,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(
                          labelText: 'Address',
                          prefixIcon:
                              Icon(
                            Icons.location_on,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        enabled: !_loading,
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      DropdownButtonFormField<
                          String>(
                        value: _duration,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'License Duration',
                          prefixIcon:
                              Icon(
                            Icons.calendar_month,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value:
                                '7_days',
                            child:
                                Text('7 Days'),
                          ),
                          DropdownMenuItem(
                            value:
                                '30_days',
                            child:
                                Text('30 Days'),
                          ),
                          DropdownMenuItem(
                            value:
                                '1_year',
                            child:
                                Text('1 Year'),
                          ),
                          DropdownMenuItem(
                            value:
                                'lifetime',
                            child:
                                Text('Lifetime'),
                          ),
                        ],
                        onChanged:
                            _loading
                                ? null
                                : (value) {
                                    if (value !=
                                        null) {
                                      setState(() {
                                        _duration =
                                            value;
                                      });
                                    }
                                  },
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      TextFormField(
                        controller:
                            _maxDevicesController,
                        keyboardType:
                            TextInputType.number,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Maximum Devices',
                          hintText: 'Example: 2',
                          prefixIcon:
                              Icon(
                            Icons.devices,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        enabled: !_loading,
                        validator: (value) {
                          final number =
                              int.tryParse(
                            value?.trim() ??
                                '',
                          );

                          if (number == null ||
                              number < 1) {
                            return 'Enter a valid device limit';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      SizedBox(
                        width:
                            double.infinity,
                        height: 52,
                        child:
                            FilledButton.icon(
                          onPressed:
                              _loading
                                  ? null
                                  : _createCustomer,
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
                                  Icons
                                      .person_add,
                                ),
                          label: Text(
                            _loading
                                ? 'Creating...'
                                : 'Create Customer',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}