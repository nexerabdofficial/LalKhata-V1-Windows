import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/production_bom.dart';
import '../../models/production_bom_item.dart';
import '../../repositories/production_bom_repository.dart';
import '../../services/product_repository.dart';

class ProductionBomScreen extends StatefulWidget {
  final int? bomId;

  const ProductionBomScreen({super.key, this.bomId});

  @override
  State<ProductionBomScreen> createState() => _ProductionBomScreenState();
}

class _ProductionBomScreenState extends State<ProductionBomScreen> {
  final ProductionBomRepository _bomRepository = ProductionBomRepository();

  final ProductRepository _productRepository = ProductRepository();

  final TextEditingController _bomNameController = TextEditingController();

  final TextEditingController _noteController = TextEditingController();

  List<Product> _products = [];

  Product? _finishedProduct;

  final List<_BomMaterialRow> _materials = [];

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _bomNameController.dispose();
    _noteController.dispose();

    for (final material in _materials) {
      material.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadData() async {
    try {
      final products = await _productRepository.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
      });

      if (widget.bomId != null) {
        await _loadExistingBom(widget.bomId!);
      }
    } catch (e) {
      if (!mounted) return;

      _showError('Failed to load BOM data.\n$e');
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadExistingBom(int bomId) async {
    final data = await _bomRepository.getBomWithItems(bomId);

    if (data == null) {
      throw Exception('BOM not found.');
    }

    final bom = data['bom'] as ProductionBom;

    final items = data['items'] as List<ProductionBomItem>;

    Product? finishedProduct;

    for (final product in _products) {
      if (product.id == bom.productId) {
        finishedProduct = product;
        break;
      }
    }

    _bomNameController.text = bom.name;
    _noteController.text = bom.note ?? '';

    _finishedProduct = finishedProduct;

    for (final item in items) {
      Product? materialProduct;

      for (final product in _products) {
        if (product.id == item.materialProductId) {
          materialProduct = product;
          break;
        }
      }

      if (materialProduct != null) {
        _materials.add(
          _BomMaterialRow(
            product: materialProduct,
            quantity: item.quantity.toString(),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // ADD MATERIAL
  // ============================================================

  Future<void> _addMaterial() async {
    if (_finishedProduct == null) {
      _showError('Select a finished product first.');
      return;
    }

    try {
      final latestProducts = await _productRepository.getProducts();

      if (!mounted) return;

      Product? updatedFinishedProduct;

      if (_finishedProduct?.id != null) {
        for (final product in latestProducts) {
          if (product.id == _finishedProduct!.id) {
            updatedFinishedProduct = product;
            break;
          }
        }
      }

      setState(() {
        _products = latestProducts;
        _finishedProduct = updatedFinishedProduct;
      });

      if (_finishedProduct == null) {
        _showError('Finished product is no longer available.');
        return;
      }

      final availableProducts = latestProducts.where((product) {
        // ============================================================
        // MATERIAL PRODUCT TYPE FILTER
        //
        // RAW_MATERIAL = allowed
        // BOTH         = allowed
        // FINISHED_PRODUCT = not allowed
        // ============================================================

        final isMaterial =
            product.productType == 'RAW_MATERIAL' ||
            product.productType == 'BOTH';

        if (!isMaterial) {
          return false;
        }

        // Finished product cannot be its own material.
        if (product.id == _finishedProduct!.id) {
          return false;
        }

        // Prevent duplicate materials.
        return !_materials.any(
          (material) => material.product?.id == product.id,
        );
      }).toList();

      if (availableProducts.isEmpty) {
        _showError('No other products are available as material.');
        return;
      }

      final result = await showModalBottomSheet<Product>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _MaterialPickerSheet(products: availableProducts);
        },
      );

      if (result == null || !mounted) {
        return;
      }

      setState(() {
        _materials.add(_BomMaterialRow(product: result, quantity: '1'));
      });
    } catch (e) {
      _showError('Failed to load products.\n$e');
    }
  }

  // ============================================================
  // REMOVE MATERIAL
  // ============================================================

  void _removeMaterial(int index) {
    final material = _materials.removeAt(index);
    material.dispose();

    setState(() {});
  }

  // ============================================================
  // MATERIAL COST
  // ============================================================

  double get _estimatedMaterialCost {
    double total = 0;

    for (final material in _materials) {
      final quantity =
          double.tryParse(material.quantityController.text.trim()) ?? 0;

      if (quantity <= 0 || material.product == null) {
        continue;
      }

      total += quantity * material.product!.purchasePrice;
    }

    return total;
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveBom() async {
    FocusScope.of(context).unfocus();

    if (_finishedProduct == null) {
      _showError('Please select the finished product.');
      return;
    }

    final bomName = _bomNameController.text.trim();

    if (bomName.isEmpty) {
      _showError('Please enter a BOM name.');
      return;
    }

    if (_materials.isEmpty) {
      _showError('Add at least one material.');
      return;
    }

    final List<ProductionBomItem> items = [];

    for (final material in _materials) {
      final product = material.product;

      if (product == null) {
        _showError('Please select a material.');
        return;
      }

      final quantity =
          double.tryParse(material.quantityController.text.trim()) ?? 0;

      if (quantity <= 0) {
        _showError('Material quantity must be greater than 0.');
        return;
      }

      items.add(
        ProductionBomItem(
          bomId: widget.bomId ?? 0,
          materialProductId: product.id!,
          quantity: quantity,
        ),
      );
    }

    setState(() {
      _saving = true;
    });

    try {
      final now = DateTime.now().toIso8601String();

      if (widget.bomId == null) {
        final bom = ProductionBom(
          productId: _finishedProduct!.id!,
          name: bomName,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        await _bomRepository.createBom(bom, items);
      } else {
        final existing = await _bomRepository.getBomById(widget.bomId!);

        if (existing == null) {
          throw Exception('BOM no longer exists.');
        }

        final bom = ProductionBom(
          id: existing.id,
          productId: _finishedProduct!.id!,
          name: bomName,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          isActive: existing.isActive,
          createdAt: existing.createdAt,
          updatedAt: now,
        );

        await _bomRepository.updateBom(bom, items);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.bomId == null
                ? 'BOM created successfully.'
                : 'BOM updated successfully.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showError('Failed to save BOM.\n$e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bomId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Production BOM' : 'New Production BOM'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildBasicInfo(),
                        const SizedBox(height: 24),
                        _buildMaterials(),
                        const SizedBox(height: 24),
                        _buildCostSummary(),
                        const SizedBox(height: 24),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: Icon(
            Icons.precision_manufacturing_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Production Recipe',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                'Define the materials required to make one unit.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfo() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BOM Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<Product>(
              value: _finishedProduct,
              decoration: const InputDecoration(
                labelText: 'Finished Product',
                hintText: 'Select the product you manufacture',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),

              items: _products
                  .where(
                    (product) =>
                        product.productType == 'FINISHED_PRODUCT' ||
                        product.productType == 'BOTH',
                  )
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
              onChanged: (product) {
                if (product == null) return;

                setState(() {
                  _finishedProduct = product;

                  _materials.removeWhere((material) {
                    final remove = material.product?.id == product.id;

                    if (remove) {
                      material.dispose();
                    }

                    return remove;
                  });
                });
              },
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _bomNameController,
              decoration: const InputDecoration(
                labelText: 'BOM Name',
                hintText: 'e.g. Standard 12W Assembly',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Optional production note',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterials() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Materials',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'What goes into one finished unit?',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addMaterial,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Material'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_materials.isEmpty)
              _buildEmptyMaterials()
            else
              ...List.generate(
                _materials.length,
                (index) => _buildMaterialRow(index, _materials[index]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMaterials() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.layers_clear_outlined,
            size: 38,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            'No materials added yet',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Add the components needed to manufacture this product.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialRow(int index, _BomMaterialRow material) {
    final product = material.product;

    final unit = product?.unit ?? 'PCS';

    final cost = product == null
        ? 0
        : (double.tryParse(material.quantityController.text.trim()) ?? 0) *
              product.purchasePrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.name ?? 'Unknown product',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  'Current avg. cost: ৳${(product?.purchasePrice ?? 0).toStringAsFixed(2)} / $unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            width: 110,
            child: TextField(
              controller: material.quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: 'Qty',
                suffixText: unit,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),

          const SizedBox(width: 14),

          SizedBox(
            width: 100,
            child: Text(
              '৳${cost.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),

          IconButton(
            tooltip: 'Remove material',
            onPressed: () => _removeMaterial(index),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildCostSummary() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('Estimated Material Cost')),
                Text(
                  '৳${_estimatedMaterialCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This is based on the product cost currently stored in inventory. Actual production costing will use the current average cost at production time.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _saving ? null : _saveBom,
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check_circle_outline),
        label: Text(
          _saving
              ? 'Saving...'
              : widget.bomId == null
              ? 'Save BOM'
              : 'Update BOM',
        ),
      ),
    );
  }
}

// ============================================================
// BOM MATERIAL ROW
// ============================================================

class _BomMaterialRow {
  Product? product;

  final TextEditingController quantityController;

  _BomMaterialRow({this.product, String quantity = '1'})
    : quantityController = TextEditingController(text: quantity);

  void dispose() {
    quantityController.dispose();
  }
}

// ============================================================
// MATERIAL PICKER
// ============================================================

class _MaterialPickerSheet extends StatefulWidget {
  final List<Product> products;

  const _MaterialPickerSheet({required this.products});

  @override
  State<_MaterialPickerSheet> createState() => _MaterialPickerSheetState();
}

class _MaterialPickerSheetState extends State<_MaterialPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((product) {
      return product.name.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),

            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search material...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No material found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = filtered[index];

                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.inventory_2_outlined),
                            ),
                            title: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Avg. cost ৳${product.purchasePrice.toStringAsFixed(2)} • ${product.unit}',
                            ),
                            trailing: const Icon(Icons.add_circle_outline),
                            onTap: () {
                              Navigator.pop(context, product);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
