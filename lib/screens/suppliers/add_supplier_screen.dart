import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../../services/supplier_repository.dart';

class AddSupplierScreen extends StatefulWidget {
  final Supplier? supplier;

  const AddSupplierScreen({super.key, this.supplier});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _openingBalanceController = TextEditingController();

  final SupplierRepository _repository = SupplierRepository();

  bool _isSaving = false;

  DateTime _openingDate = DateTime.now();

  String _openingType = 'PAYABLE';

  @override
  void initState() {
    super.initState();

    if (widget.supplier != null) {
      _nameController.text = widget.supplier!.name;

      _phoneController.text = widget.supplier!.phone ?? "";

      _addressController.text = widget.supplier!.address ?? "";

      final opening = widget.supplier!.openingBalance;

      _openingType = opening < 0 ? 'RECEIVABLE' : 'PAYABLE';

      _openingBalanceController.text = opening.abs().toStringAsFixed(2);

      if (widget.supplier!.openingDate != null) {
        _openingDate = widget.supplier!.openingDate!;
      }
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

  Future<void> _pickOpeningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _openingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _openingDate = picked;
      });
    }
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final openingAmount =
          double.tryParse(_openingBalanceController.text.trim()) ?? 0.0;

      final openingBalance = _openingType == 'RECEIVABLE'
          ? -openingAmount.abs()
          : openingAmount.abs();

      final supplier = Supplier(
        id: widget.supplier?.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        openingBalance: openingBalance,
        openingDate: _openingDate,
        balance: widget.supplier?.balance ?? 0.0,
      );

      if (widget.supplier == null) {
        await _repository.insertSupplier(supplier);
      } else {
        await _repository.updateSupplier(supplier);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.supplier == null
                ? "✅ Supplier Saved Successfully"
                : "✅ Supplier Updated Successfully",
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save supplier: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  InputDecoration decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier == null ? "Add Supplier" : "Edit Supplier"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: decoration("Supplier Name"),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Enter supplier name";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: decoration("Phone Number"),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: decoration("Address"),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _openingBalanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: decoration("Opening Balance").copyWith(
                  prefixText: "৳ ",
                  helperText: "Previous payable amount",
                ),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _openingType,
                decoration: decoration("Opening Balance Type"),
                items: const [
                  DropdownMenuItem(
                    value: 'PAYABLE',
                    child: Text('Payable — We owe supplier'),
                  ),
                  DropdownMenuItem(
                    value: 'RECEIVABLE',
                    child: Text('Receivable — Supplier owes us'),
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
                onTap: _pickOpeningDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: decoration("Opening Date"),
                  child: Text(
                    "${_openingDate.day.toString().padLeft(2, '0')}/"
                    "${_openingDate.month.toString().padLeft(2, '0')}/"
                    "${_openingDate.year}",
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSupplier,
                  child: Text(
                    _isSaving
                        ? "Saving..."
                        : widget.supplier == null
                        ? "Save Supplier"
                        : "Update Supplier",
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
