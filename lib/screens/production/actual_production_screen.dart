import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/production.dart';
import '../../models/production_bom.dart';
import '../../models/production_bom_item.dart';
import '../../models/production_cost.dart';
import '../../models/production_cost_type.dart';
import '../../services/product_repository.dart';
import '../../repositories/production_bom_repository.dart';
import '../../services/production_service.dart';

class ActualProductionScreen extends StatefulWidget {
  const ActualProductionScreen({super.key});

  @override
  State<ActualProductionScreen> createState() => _ActualProductionScreenState();
}

class _ActualProductionScreenState extends State<ActualProductionScreen> {
  final ProductRepository _productRepository = ProductRepository();

  final ProductionBomRepository _bomRepository = ProductionBomRepository();

  final ProductionService _productionService = ProductionService();

  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  final TextEditingController _productionNoController = TextEditingController();

  final TextEditingController _noteController = TextEditingController();

  List<Product> _products = [];
  List<ProductionBom> _boms = [];

  Product? _selectedProduct;
  ProductionBom? _selectedBom;

  List<_MaterialRow> _materials = [];

  final Map<String, TextEditingController> _costControllers = {};

  bool _loading = true;
  bool _saving = false;

  DateTime _productionDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    for (final type in ProductionCostType.defaults) {
      _costControllers[type.key] = TextEditingController(text: '0');

      _costControllers[type.key]!.addListener(_refreshCalculation);
    }

    _quantityController.addListener(_refreshCalculation);

    _loadInitialData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _productionNoController.dispose();
    _noteController.dispose();

    for (final controller in _costControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // INITIAL DATA
  // ============================================================

  Future<void> _loadInitialData() async {
    try {
      final products = await _productRepository.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;

        // BOM must only be loaded after a finished product is selected.
        _boms = [];

        _selectedProduct = null;
        _selectedBom = null;
        _materials = [];

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError('Failed to load production data.\n$e');
    }
  }

  // ============================================================
  // LOAD BOM FOR SELECTED FINISHED PRODUCT
  // ============================================================

  Future<void> _loadBomsForProduct(Product product) async {
    if (product.id == null) {
      if (!mounted) return;

      setState(() {
        _boms = [];
        _selectedBom = null;
        _materials = [];
      });

      return;
    }

    try {
      final boms = await _bomRepository.getBomsForProduct(product.id!);

      if (!mounted) return;

      setState(() {
        _boms = boms;

        // Do NOT auto-select the first BOM.
        // User must select the BOM manually.
        _selectedBom = null;

        _materials = [];
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _boms = [];
        _selectedBom = null;
        _materials = [];
      });

      _showError('Failed to load BOM.\n$e');
    }
  }

  // ============================================================
  // LOAD BOM MATERIALS
  // ============================================================

  Future<void> _loadBomItems(ProductionBom bom) async {
    if (bom.id == null) {
      if (!mounted) return;

      setState(() {
        _materials = [];
      });

      return;
    }

    try {
      final items = await _bomRepository.getBomItems(bom.id!);

      final rows = <_MaterialRow>[];

      for (final item in items) {
        Product? product;

        try {
          product = _products.firstWhere(
            (p) => p.id == item.materialProductId,
          );
        } catch (_) {
          product = null;
        }

        if (product == null) {
          product = await _productRepository.getProductById(
            item.materialProductId,
          );
        }

        if (product != null) {
          rows.add(
            _MaterialRow(
              bomItem: item,
              product: product,
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _materials = rows;
      });
    } catch (e) {
      if (!mounted) return;

      _showError('Failed to load BOM materials.\n$e');
    }
  }

  // ============================================================
  // CALCULATIONS
  // ============================================================

  void _refreshCalculation() {
    if (mounted) {
      setState(() {});
    }
  }

  double get _quantity {
    final value = double.tryParse(
          _quantityController.text.trim(),
        ) ??
        0;

    return value;
  }

  double get _totalMaterialCost {
    double total = 0;

    for (final material in _materials) {
      total += material.totalCost(_quantity);
    }

    return total;
  }

  double get _totalFactoryCost {
    double total = 0;

    for (final type in ProductionCostType.defaults) {
      final controller = _costControllers[type.key];

      final costPerUnit =
          double.tryParse(controller?.text.trim() ?? '0') ?? 0;

      if (costPerUnit > 0) {
        total += costPerUnit * _quantity;
      }
    }

    return total;
  }

  double get _totalProductionCost {
    return _totalMaterialCost + _totalFactoryCost;
  }

  double get _unitProductionCost {
    if (_quantity <= 0) {
      return 0;
    }

    return _totalProductionCost / _quantity;
  }

  String _money(double value) {
    return value.toStringAsFixed(2);
  }

  // ============================================================
  // DATE
  // ============================================================

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _productionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() {
        _productionDate = picked;
      });
    }
  }

  // ============================================================
  // CREATE PRODUCTION
  // ============================================================

  Future<void> _produce() async {
    if (_saving) return;

    if (_selectedProduct == null) {
      _showError('Please select a finished product.');
      return;
    }

    if (_selectedBom == null) {
      _showError('Please select a BOM.');
      return;
    }

    if (_quantity <= 0) {
      _showError('Production quantity must be greater than 0.');
      return;
    }

    if (_quantity != _quantity.roundToDouble()) {
      _showError('Production quantity must be a whole number.');
      return;
    }

    for (final type in ProductionCostType.defaults) {
      final value =
          double.tryParse(_costControllers[type.key]!.text.trim()) ?? 0;

      if (value < 0) {
        _showError('${type.name} cost cannot be negative.');
        return;
      }
    }

    final confirmed = await _showConfirmation();

    if (!confirmed) return;

    setState(() {
      _saving = true;
    });

    try {
      final factoryCosts = <ProductionCost>[];

      for (final type in ProductionCostType.defaults) {
        final costPerUnit =
            double.tryParse(_costControllers[type.key]!.text.trim()) ?? 0;

        if (costPerUnit <= 0) {
          continue;
        }

        factoryCosts.add(
          ProductionCost(
            productionId: 0,
            costType: type.key,
            costPerUnit: costPerUnit,
            totalCost: costPerUnit * _quantity,
          ),
        );
      }

      final production = await _productionService.createProduction(
        productId: _selectedProduct!.id!,
        bomId: _selectedBom!.id!,
        quantity: _quantity,
        productionDate: _productionDate.toIso8601String(),
        productionNo: _productionNoController.text.trim().isEmpty
            ? null
            : _productionNoController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        factoryCosts: factoryCosts,
      );

      if (!mounted) return;

      _showSuccess(
        'Production completed successfully.\n'
        'Unit Cost: ${_money(production.unitCost)}',
      );

      _resetForm();
    } catch (e) {
      if (!mounted) return;

      _showError('Production failed.\n$e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // CONFIRMATION
  // ============================================================

  Future<bool> _showConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Production'),
          content: Text(
            'Produce ${_quantity.toStringAsFixed(0)} '
            '${_selectedProduct?.name ?? ''}?\n\n'
            'Material Cost: ${_money(_totalMaterialCost)}\n'
            'Factory Cost: ${_money(_totalFactoryCost)}\n'
            'Total Cost: ${_money(_totalProductionCost)}\n'
            'Unit Cost: ${_money(_unitProductionCost)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Produce'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // ============================================================
  // RESET
  // ============================================================

  void _resetForm() {
    setState(() {
      _quantityController.text = '1';
      _productionNoController.clear();
      _noteController.clear();

      for (final controller in _costControllers.values) {
        controller.text = '0';
      }

      _productionDate = DateTime.now();

      // Reset product/BOM flow after successful production.
      _selectedProduct = null;
      _selectedBom = null;
      _boms = [];
      _materials = [];
    });
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production & Assembly'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1100,
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(
                        isDesktop ? 28 : 16,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildBasicSection(),
                          const SizedBox(height: 20),
                          _buildMaterialsSection(),
                          const SizedBox(height: 20),
                          _buildFactoryCostSection(),
                          const SizedBox(height: 20),
                          _buildSummarySection(),
                          const SizedBox(height: 24),
                          _buildProduceButton(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context)
                .colorScheme
                .primaryContainer,
          ),
          child: Icon(
            Icons.precision_manufacturing,
            color: Theme.of(context)
                .colorScheme
                .onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Create Production',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Convert raw materials into finished goods',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BASIC SECTION
  // ============================================================

  Widget _buildBasicSection() {
    final finishedProducts = _products.where(
      (product) =>
          product.productType == 'FINISHED_PRODUCT' ||
          product.productType == 'BOTH',
    );

    final hasSelectedProduct = _selectedProduct != null;

    final hasBoms = _boms.isNotEmpty;

    return _sectionCard(
      title: 'Production Details',
      icon: Icons.assignment_outlined,
      child: Column(
        children: [
          // ------------------------------------------------------
          // FINISHED PRODUCT
          // ------------------------------------------------------

          DropdownButtonFormField<Product>(
            value: _selectedProduct,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Finished Product',
              prefixIcon: Icon(
                Icons.inventory_2_outlined,
              ),
              helperText:
                  'Select the finished product to load its BOM.',
            ),
            items: finishedProducts
                .map(
                  (product) => DropdownMenuItem<Product>(
                    value: product,
                    child: Text(
                      product.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (product) async {
                    if (product == null) {
                      return;
                    }

                    setState(() {
                      _selectedProduct = product;

                      // Clear old BOM immediately.
                      _selectedBom = null;
                      _boms = [];
                      _materials = [];
                    });

                    await _loadBomsForProduct(product);
                  },
          ),

          const SizedBox(height: 14),

          // ------------------------------------------------------
          // BOM
          // ------------------------------------------------------

          DropdownButtonFormField<ProductionBom>(
            value: _selectedBom,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'BOM',
              prefixIcon: const Icon(
                Icons.account_tree_outlined,
              ),
              helperText: !hasSelectedProduct
                  ? 'Select a finished product first.'
                  : hasBoms
                      ? 'Select the BOM for this production.'
                      : 'No BOM found for this finished product.',
            ),
            items: _boms
                .where(
                  (bom) =>
                      _selectedProduct != null &&
                      bom.productId == _selectedProduct!.id,
                )
                .map(
                  (bom) => DropdownMenuItem<ProductionBom>(
                    value: bom,
                    child: Text(
                      bom.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving ||
                    !hasSelectedProduct ||
                    !hasBoms
                ? null
                : (bom) async {
                    if (bom == null) {
                      return;
                    }

                    setState(() {
                      _selectedBom = bom;
                      _materials = [];
                    });

                    await _loadBomItems(bom);
                  },
          ),

          const SizedBox(height: 14),

          // ------------------------------------------------------
          // QUANTITY / NO / DATE
          // ------------------------------------------------------

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 650) {
                return Column(
                  children: [
                    _quantityField(),
                    const SizedBox(height: 14),
                    _productionNoField(),
                    const SizedBox(height: 14),
                    _dateField(),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _quantityField(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _productionNoField(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateField(),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUANTITY
  // ============================================================

  Widget _quantityField() {
    return TextField(
      controller: _quantityController,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration: const InputDecoration(
        labelText: 'Production Quantity',
        prefixIcon: Icon(
          Icons.production_quantity_limits,
        ),
        suffixText: 'pcs',
      ),
    );
  }

  // ============================================================
  // PRODUCTION NO
  // ============================================================

  Widget _productionNoField() {
    return TextField(
      controller: _productionNoController,
      decoration: const InputDecoration(
        labelText: 'Production No.',
        prefixIcon: Icon(
          Icons.tag_outlined,
        ),
      ),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  Widget _dateField() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Production Date',
          prefixIcon: Icon(
            Icons.calendar_today_outlined,
          ),
        ),
        child: Text(
          '${_productionDate.day.toString().padLeft(2, '0')}/'
          '${_productionDate.month.toString().padLeft(2, '0')}/'
          '${_productionDate.year}',
        ),
      ),
    );
  }

  // ============================================================
  // MATERIALS
  // ============================================================

  Widget _buildMaterialsSection() {
    return _sectionCard(
      title: 'Raw Materials',
      icon: Icons.inventory_outlined,
      trailing: _materials.isEmpty
          ? null
          : Text(
              '${_materials.length} items',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .primary,
                fontWeight: FontWeight.w600,
              ),
            ),
      child: _materials.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 38,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Select a BOM to load raw materials.',
                  ),
                ],
              ),
            )
          : Column(
              children: [
                ..._materials.map(_buildMaterialRow),
                const Divider(height: 28),
                _summaryLine(
                  'Total Material Cost',
                  _totalMaterialCost,
                  bold: true,
                ),
              ],
            ),
    );
  }

  // ============================================================
  // MATERIAL ROW
  // ============================================================

  Widget _buildMaterialRow(_MaterialRow material) {
    final requiredQty =
        material.requiredQuantity(_quantity);

    final total =
        material.totalCost(_quantity);

    final stock =
        material.product.stock;

    final enoughStock =
        stock >= requiredQty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  material.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '৳${_money(total)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _infoText(
                'Per Unit',
                '${material.bomItem.quantity}',
              ),
              _infoText(
                'Required',
                requiredQty.toStringAsFixed(0),
              ),
              _infoText(
                'Avg Cost',
                '৳${_money(material.averageCost)}',
              ),
              _infoText(
                'Stock',
                stock.toString(),
                warning: !enoughStock,
              ),
            ],
          ),
          if (!enoughStock)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Insufficient stock. '
                      'Need ${requiredQty.toStringAsFixed(0)}, '
                      'available $stock.',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // FACTORY COST
  // ============================================================

  Widget _buildFactoryCostSection() {
    return _sectionCard(
      title: 'Factory Cost Breakdown',
      icon: Icons.factory_outlined,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enter cost per produced unit. '
                    'Total cost will be calculated automatically.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...ProductionCostType.defaults.map(
            _buildCostRow,
          ),
          const Divider(height: 28),
          _summaryLine(
            'Total Factory Cost',
            _totalFactoryCost,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(
    ProductionCostType type,
  ) {
    final controller =
        _costControllers[type.key]!;

    final perUnit =
        double.tryParse(controller.text.trim()) ?? 0;

    final total =
        perUnit * _quantity;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: type.name,
                    prefixIcon: const Icon(
                      Icons.payments_outlined,
                    ),
                    suffixText: '৳/unit',
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: ৳${_money(total)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 7,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        type.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    labelText: 'Cost / Unit',
                    prefixText: '৳ ',
                  ),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 160,
                child: Text(
                  '৳${_money(total)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummarySection() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _summaryLine(
              'Production Quantity',
              _quantity,
              suffix: ' pcs',
            ),
            const SizedBox(height: 10),
            _summaryLine(
              'Material Cost',
              _totalMaterialCost,
              currency: true,
            ),
            const SizedBox(height: 10),
            _summaryLine(
              'Factory Cost',
              _totalFactoryCost,
              currency: true,
            ),
            const Divider(height: 28),
            _summaryLine(
              'Total Production Cost',
              _totalProductionCost,
              currency: true,
              bold: true,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unit Production Cost',
                          style: TextStyle(
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '৳${_money(_unitProductionCost)}',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.calculate_outlined,
                    size: 34,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCE BUTTON
  // ============================================================

  Widget _buildProduceButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _saving ? null : _produce,
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.precision_manufacturing,
              ),
        label: Text(
          _saving
              ? 'Producing...'
              : 'Complete Production',
        ),
      ),
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY LINE
  // ============================================================

  Widget _summaryLine(
    String label,
    double value, {
    bool currency = false,
    bool bold = false,
    String suffix = '',
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
        Text(
          currency
              ? '৳${_money(value)}'
              : '${_money(value)}$suffix',
          style: TextStyle(
            fontWeight: bold
                ? FontWeight.bold
                : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INFO TEXT
  // ============================================================

  Widget _infoText(
    String label,
    String value, {
    bool warning = false,
  }) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: warning
              ? Theme.of(context)
                  .colorScheme
                  .error
              : Theme.of(context)
                  .colorScheme
                  .onSurface,
          fontSize: 12,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

// ============================================================
// MATERIAL ROW MODEL
// ============================================================

class _MaterialRow {
  final ProductionBomItem bomItem;
  final Product product;

  _MaterialRow({
    required this.bomItem,
    required this.product,
  });

  double get averageCost {
    return product.purchasePrice;
  }

  double requiredQuantity(
    double productionQuantity,
  ) {
    return bomItem.quantity * productionQuantity;
  }

  double totalCost(
    double productionQuantity,
  ) {
    return requiredQuantity(productionQuantity) *
        averageCost;
  }
}