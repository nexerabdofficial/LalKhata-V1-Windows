import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_repository.dart';

class OpeningStockScreen extends StatefulWidget {
  final Product product;

  const OpeningStockScreen({
    super.key,
    required this.product,
  });

  @override
  State<OpeningStockScreen> createState() =>
      _OpeningStockScreenState();
}

class _OpeningStockScreenState
    extends State<OpeningStockScreen> {
  final ProductRepository _repository =
      ProductRepository();

  final _formKey = GlobalKey<FormState>();

  final _quantityController =
      TextEditingController();

  final _rateController =
      TextEditingController();

  DateTime _openingDate = DateTime.now();

  bool _saving = false;

  double get _totalValue {
    final quantity =
        int.tryParse(_quantityController.text.trim()) ?? 0;

    final rate =
        double.tryParse(_rateController.text.trim()) ?? 0;

    return quantity * rate;
  }

  @override
  void initState() {
    super.initState();

    _quantityController.addListener(_refreshTotal);
    _rateController.addListener(_refreshTotal);
  }

  void _refreshTotal() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _openingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() {
        _openingDate = selected;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity =
        int.parse(_quantityController.text.trim());

    final rate =
        double.parse(_rateController.text.trim());

    setState(() {
      _saving = true;
    });

    try {
      await _repository.addOpeningStock(
        productId: widget.product.id!,
        quantity: quantity,
        unitCost: rate,
        openingDate: _formatDate(_openingDate),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Opening stock added successfully.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add opening stock: $e',
          ),
        ),
      );

      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opening Stock'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 520,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  // PRODUCT
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Product',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.product.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // DATE
                  InkWell(
                    onTap: _selectDate,
                    borderRadius:
                        BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration:
                          const InputDecoration(
                        labelText: 'Opening Date',
                        prefixIcon:
                            Icon(Icons.calendar_today),
                        border:
                            OutlineInputBorder(),
                      ),
                      child: Text(
                        _formatDate(_openingDate),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // QUANTITY
                  TextFormField(
                    controller:
                        _quantityController,
                    keyboardType:
                        TextInputType.number,
                    decoration:
                        InputDecoration(
                      labelText:
                          'Opening Quantity (${widget.product.unit})',
                      prefixIcon:
                          const Icon(Icons.inventory_2_outlined),
                      border:
                          const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final quantity =
                          int.tryParse(
                        value?.trim() ?? '',
                      );

                      if (quantity == null ||
                          quantity <= 0) {
                        return 'Enter a quantity greater than 0';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // RATE
                  TextFormField(
                    controller:
                        _rateController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Opening Cost / Rate',
                      prefixText: '৳ ',
                      prefixIcon:
                          Icon(Icons.price_change_outlined),
                      border:
                          OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final rate =
                          double.tryParse(
                        value?.trim() ?? '',
                      );

                      if (rate == null ||
                          rate < 0) {
                        return 'Enter a valid rate';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // TOTAL
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(18),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Value',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            '৳${_totalValue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed:
                        _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _saving
                          ? 'Saving...'
                          : 'Save Opening Stock',
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
