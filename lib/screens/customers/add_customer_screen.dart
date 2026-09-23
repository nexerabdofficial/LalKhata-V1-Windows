import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/customer_repository.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? customer;

  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final CustomerRepository _repository = CustomerRepository();

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _openingBalanceController = TextEditingController();

  bool _isSaving = false;

  DateTime _openingDate = DateTime.now();

  String _openingType = 'RECEIVABLE';

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();

    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _phoneController.text = widget.customer!.phone ?? "";
      _addressController.text = widget.customer!.address ?? "";

      final opening = widget.customer!.openingBalance;

      _openingType = opening < 0 ? 'PAYABLE' : 'RECEIVABLE';

      _openingBalanceController.text = opening.abs().toStringAsFixed(2);

      if (widget.customer!.openingDate != null) {
        _openingDate = widget.customer!.openingDate!;
      }
    } else {
      _openingBalanceController.text = "0";
      _openingDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _openingBalanceController.dispose();

    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  Future<void> _selectOpeningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _openingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _openingDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();

    final exists = await _repository.customerExists(
      name,
      ignoreId: widget.customer?.id,
    );

    if (exists) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Customer already exists.")));

      return;
    }

    final openingAmount =
        double.tryParse(_openingBalanceController.text.trim()) ?? 0;

    final openingBalance = _openingType == 'PAYABLE'
        ? -openingAmount.abs()
        : openingAmount.abs();

    setState(() {
      _isSaving = true;
    });

    try {
      // ========================================================
      // EDIT CUSTOMER
      // ========================================================

      if (_isEdit) {
        final customer = Customer(
          id: widget.customer!.id,
          name: name,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          openingBalance: openingBalance,
          openingDate: _openingDate,
          balance: widget.customer!.balance,
        );

        await _repository.updateCustomer(customer);

        if (!mounted) return;

        Navigator.pop(context, true);
        return;
      }

      // ========================================================
      // NEW CUSTOMER
      //
      // IMPORTANT:
      // This is ONLY a sales/customer record.
      // NO LICENSE IS CREATED HERE.
      // ========================================================

      final customer = Customer(
        name: name,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        openingBalance: openingBalance,
        openingDate: _openingDate,
        balance: 0,
      );

      await _repository.insertCustomer(customer);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer added successfully.')),
      );

      // NEW customer: stay here and prepare for the next customer.
      _formKey.currentState?.reset();

      setState(() {
        _nameController.clear();
        _phoneController.clear();
        _addressController.clear();
        _openingBalanceController.clear();
        _openingType = 'RECEIVABLE';
        _openingDate = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save customer: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? "Edit Customer" : "Add Customer")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                "Customer Information",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter customer name';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _openingBalanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Opening Balance',
                  hintText: '0.00',
                  prefixText: '৳ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter opening balance';
                  }

                  final amount = double.tryParse(value.trim());

                  if (amount == null) {
                    return 'Please enter a valid amount';
                  }

                  if (amount < 0) {
                    return 'Opening balance cannot be negative';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _openingType,
                decoration: const InputDecoration(
                  labelText: 'Opening Balance Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'RECEIVABLE',
                    child: Text('Receivable — Customer owes us'),
                  ),
                  DropdownMenuItem(
                    value: 'PAYABLE',
                    child: Text('Payable — We owe customer'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _openingType = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: _selectOpeningDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Opening Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _formatDate(_openingDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCustomer,
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isEdit ? 'Update Customer' : 'Save Customer',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
