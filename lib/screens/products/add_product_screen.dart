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

  final ProductRepository _repository = ProductRepository();

  String _selectedUnit = 'PCS';

  // ============================================================
  // PRODUCT TYPE
  // ============================================================

  String _selectedProductType = 'FINISHED_PRODUCT';

  // New products only use these two types.
  //
  // BOTH is kept only when editing an old product that already
  // has BOTH saved in the database.
  final List<String> _newProductTypes = [
    'RAW_MATERIAL',
    'FINISHED_PRODUCT',
  ];

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

  bool get _isRawMaterial =>
      _selectedProductType == 'RAW_MATERIAL';

  bool get _isFinishedProduct =>
      _selectedProductType == 'FINISHED_PRODUCT';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _selectedUnit = widget.product?.unit ?? 'PCS';

    _selectedProductType =
        widget.product?.productType ?? 'FINISHED_PRODUCT';

    if (_isEditMode) {
      _nameController.text = widget.product!.name;

      _sellingController.text =
          widget.product!.sellingPrice.toString();
    }
  }

  // ============================================================
  // PRODUCT TYPE ITEMS
  // ============================================================

  List<String> get _productTypes {
    final types = <String>[
      ..._newProductTypes,
    ];

    // ----------------------------------------------------------
    // Keep legacy BOTH visible when editing an existing BOTH
    // product. It is NOT available for newly created products.
    // ----------------------------------------------------------

    if (_isEditMode &&
        widget.product?.productType == 'BOTH') {
      types.add('BOTH');
    }

    return types;
  }

  // ============================================================
  // SAVE PRODUCT
  // ============================================================

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // --------------------------------------------------------
      // RAW MATERIAL
      //
      // Raw materials are not sold directly through the product
      // sales flow, so selling price is always zero.
      // --------------------------------------------------------

      final sellingPrice = _isRawMaterial
          ? 0.0
          : double.parse(
              _sellingController.text.trim(),
            );

      final product = Product(
        id: widget.product?.id,

        name: _nameController.text.trim(),

        // Existing purchase price is preserved.
        purchasePrice:
            widget.product?.purchasePrice ?? 0,

        sellingPrice: sellingPrice,

        // ------------------------------------------------------
        // No Opening Stock from Add Product.
        //
        // Existing stock is preserved while editing.
        // New products start with zero stock.
        // ------------------------------------------------------

        stock: widget.product?.stock ?? 0,

        // Existing stock value is preserved.
        stockValue:
            widget.product?.stockValue ?? 0,

        unit: _selectedUnit,

        productType: _selectedProductType,
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
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Failed to save product: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  // ============================================================
  // PRODUCT TYPE LABEL
  // ============================================================

  String _productTypeLabel(String type) {
    switch (type) {
      case 'RAW_MATERIAL':
        return 'Raw Material';

      case 'FINISHED_PRODUCT':
        return 'Finished Product';

      case 'BOTH':
        return 'Both';

      default:
        return type;
    }
  }

  // ============================================================
  // SELLING PRICE VALIDATION
  // ============================================================

  String? _validateSellingPrice(String? value) {
    // ----------------------------------------------------------
    // Raw Material does not need selling price.
    // ----------------------------------------------------------

    if (_isRawMaterial) {
      return null;
    }

    if (value == null || value.trim().isEmpty) {
      return 'Enter selling price';
    }

    final price = double.tryParse(
      value.trim(),
    );

    if (price == null || price < 0) {
      return 'Enter a valid selling price';
    }

    return null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _sellingController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode
              ? 'Edit Product'
              : 'Add Product',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ==================================================
              // PRODUCT NAME
              // ==================================================

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

              // ==================================================
              // PRODUCT TYPE
              // ==================================================

              DropdownButtonFormField<String>(
                initialValue: _productTypes.contains(
                  _selectedProductType,
                )
                    ? _selectedProductType
                    : _productTypes.first,
                decoration:
                    decoration('Product Type'),
                items: _productTypes
                    .map(
                      (type) =>
                          DropdownMenuItem<String>(
                        value: type,
                        child: Text(
                          _productTypeLabel(type),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          _selectedProductType =
                              value;

                          // ------------------------------------------------
                          // When switching to Raw Material, force
                          // selling price to zero.
                          // ------------------------------------------------

                          if (value ==
                              'RAW_MATERIAL') {
                            _sellingController
                                .text = '0';
                          }
                        });
                      },
              ),

              const SizedBox(height: 16),

              // ==================================================
              // SELLING PRICE
              // ==================================================

              TextFormField(
                controller: _sellingController,
                enabled:
                    !_isRawMaterial && !_isSaving,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: decoration(
                  _isRawMaterial
                      ? 'Selling Price (Not Applicable)'
                      : 'Selling Price',
                ),
                validator:
                    _validateSellingPrice,
              ),

              const SizedBox(height: 16),

              // ==================================================
              // UNIT
              // ==================================================

              DropdownButtonFormField<String>(
                initialValue: _selectedUnit,
                decoration:
                    decoration('Unit'),
                items: _units
                    .map(
                      (unit) =>
                          DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      ),
                    )
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          _selectedUnit = value;
                        });
                      },
              ),

              const SizedBox(height: 30),

              // ==================================================
              // SAVE BUTTON
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed:
                      _isSaving
                          ? null
                          : _saveProduct,
                  child: Text(
                    _isSaving
                        ? (_isEditMode
                            ? 'Updating...'
                            : 'Saving...')
                        : (_isEditMode
                            ? 'Update Product'
                            : 'Save Product'),
                    style:
                        const TextStyle(
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