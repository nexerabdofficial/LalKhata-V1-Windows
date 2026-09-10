import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_repository.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;

  const AddProductScreen({
    super.key,
    this.product,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _sellingController = TextEditingController();
  final _stockController = TextEditingController();

  final ProductRepository _repository = ProductRepository();

  String _selectedUnit = 'PCS';

  final List<String> _units = [
    'PCS',
    'Dozen',
    'Kg',
    'Gram',
    'Liter',
    'ML',
    'Meter',
    'Feet',
    'Yard',
    'Roll',
    'Pack',
    'Box',
    'Bag',
    'Bottle',
    'Carton',
    'Set',
    'Pair',
  ];

  bool _isSaving = false;

  bool get _isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();

    _selectedUnit = widget.product?.unit ?? 'PCS';

    if (_isEditMode) {
      _nameController.text = widget.product!.name;
      _sellingController.text =
          widget.product!.sellingPrice.toString();
      _stockController.text =
          widget.product!.stock.toString();
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final product = Product(
  id: widget.product?.id,

  name: _nameController.text.trim(),

  purchasePrice:
      widget.product?.purchasePrice ?? 0,

  sellingPrice:
      double.parse(_sellingController.text.trim()),

  stock:
      int.parse(_stockController.text.trim()),

  stockValue:
      widget.product?.stockValue ?? 0,

  unit: _selectedUnit,
);

    if (_isEditMode) {
      await _repository.updateProduct(product);
    } else {
      await _repository.insertProduct(product);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditMode
              ? '✅ Product Updated Successfully'
              : '✅ Product Saved Successfully',
        ),
      ),
    );

    Navigator.pop(context, true);
  }

  InputDecoration decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sellingController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Product' : 'Add Product',
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Form(
          key: _formKey,

          child: Column(
            children: [
              // =====================================================
              // PRODUCT NAME
              // =====================================================

              TextFormField(
                controller: _nameController,
                decoration:
                    decoration('Product Name'),

                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter product name';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =====================================================
              // SELLING PRICE
              // =====================================================

              TextFormField(
                controller: _sellingController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),

                decoration:
                    decoration('Selling Price'),

                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter selling price';
                  }

                  final price =
                      double.tryParse(value.trim());

                  if (price == null ||
                      price < 0) {
                    return 'Enter a valid selling price';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =====================================================
              // OPENING STOCK
              // =====================================================

              TextFormField(
                controller: _stockController,
                keyboardType:
                    TextInputType.number,

                decoration:
                    decoration('Opening Stock'),

                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter opening stock';
                  }

                  final stock =
                      int.tryParse(value.trim());

                  if (stock == null ||
                      stock < 0) {
                    return 'Enter a valid stock quantity';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =====================================================
              // UNIT
              // =====================================================

              DropdownButtonFormField<String>(
                initialValue: _selectedUnit,

                decoration:
                    decoration('Unit'),

                items: _units
                    .map(
                      (unit) => DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      ),
                    )
                    .toList(),

                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedUnit = value;
                  });
                },
              ),

              const SizedBox(height: 30),

              // =====================================================
              // SAVE BUTTON
              // =====================================================

              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  onPressed:
                      _isSaving ? null : _saveProduct,

                  child: Text(
                    _isSaving
                        ? (_isEditMode
                            ? 'Updating...'
                            : 'Saving...')
                        : (_isEditMode
                            ? 'Update Product'
                            : 'Save Product'),

                    style: const TextStyle(
                      fontSize: 18,
                    ),
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