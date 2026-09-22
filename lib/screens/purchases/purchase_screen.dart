import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../../database/database_helper.dart';
import '../../services/supplier_repository.dart';
import '../../models/purchase/purchase_form_state.dart';
import '../../models/product.dart';
import '../../services/product_repository.dart';
import '../../services/purchase_service.dart';
import '../../models/purchase_item_draft.dart';
import '../../models/purchase.dart';
import '../../models/purchase_item.dart';
import '../../services/purchase_repository.dart';
import '../../services/purchase_item_repository.dart';
import '../../services/refresh_service.dart';
import '../../models/account.dart';
import '../../models/payment_allocation.dart';
import '../../services/account_repository.dart';
import '../../services/ff/ff_payment_allocation_service.dart';
import '../suppliers/add_supplier_screen.dart';
import '../products/add_product_screen.dart';

class PurchaseScreen extends StatefulWidget {
  final int? purchaseId;

  const PurchaseScreen({super.key, this.purchaseId});

  bool get isEdit => purchaseId != null;

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  final PurchaseService _purchaseService = PurchaseService();
  final PurchaseRepository _purchaseRepository = PurchaseRepository();
  final PurchaseItemRepository _purchaseItemRepository =
      PurchaseItemRepository();
  final SupplierRepository _supplierRepository = SupplierRepository();
  final AccountRepository _accountRepository = AccountRepository();
  final ProductRepository _productRepository = ProductRepository();

  final FFPaymentAllocationService _paymentAllocationService =
      FFPaymentAllocationService.instance;

  List<Account> _accounts = [];
  Account? _selectedAccount;

  final List<_PurchasePaymentRow> _paymentRows = [];

  List<Supplier> _suppliers = [];
  List<Product> _products = [];

  final PurchaseFormState _formState = PurchaseFormState();
  final List<PurchaseItemDraft> _purchaseItems = [];

  bool _isSaving = false;
  bool _isLoading = true;

  final TextEditingController _quantityController = TextEditingController();

  final TextEditingController _priceController = TextEditingController();

  final TextEditingController _paidController = TextEditingController();

  final TextEditingController _additionalChargeController =
      TextEditingController(text: '0');

  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([_loadSuppliers(), _loadAccounts(), _loadProducts()]);

      await _loadPurchaseForEdit();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadProducts() async {
    final products = await _productRepository.getProducts();

    if (!mounted) return;

    setState(() {
      _products = products;
    });
  }

  Future<void> _openAddProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );

    if (result == true) {
      final products = await _productRepository.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _formState.productId = null;
      });

      _showMessage('Product list updated.');
    }
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await _supplierRepository.getSuppliers();

    if (!mounted) return;

    setState(() {
      _suppliers = suppliers;
    });
  }

  Future<void> _openAddSupplier() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddSupplierScreen()),
    );

    if (result == true) {
      final suppliers = await _supplierRepository.getSuppliers();

      if (!mounted) return;

      setState(() {
        _suppliers = suppliers;
        _formState.supplierId = null;
      });

      _showMessage('Supplier list updated.');
    }
  }

  Future<void> _loadAccounts() async {
    final accounts = await _accountRepository.getAccounts();
    final db = await _databaseHelper.database;

    final rows = await db.rawQuery('''
      SELECT DISTINCT a.id
      FROM accounts a
      LEFT JOIN ff_account_links l
        ON l.account_id = a.id
       AND l.is_primary = 1
      LEFT JOIN ff_account_groups g
        ON g.id = l.group_id
      WHERE UPPER(a.type) IN (
        'CASH',
        'BANK',
        'MFS',
        'MOBILE_BANKING'
      )
      OR UPPER(COALESCE(g.group_code, '')) IN (
        'CASH',
        'BANK',
        'MFS'
      )
    ''');

    final moneyIds = <int>{};

    for (final row in rows) {
      final id = row['id'];
      if (id is num) {
        moneyIds.add(id.toInt());
      }
    }

    final moneyAccounts = accounts
        .where((account) => account.id != null && moneyIds.contains(account.id))
        .toList();

    if (!mounted) return;

    setState(() {
      _accounts = moneyAccounts;

      if (_accounts.isEmpty) {
        _selectedAccount = null;
        return;
      }

      if (_selectedAccount == null ||
          !_accounts.any((account) => account.id == _selectedAccount?.id)) {
        try {
          _selectedAccount = _accounts.firstWhere(
            (account) => account.type.toUpperCase() == 'CASH',
          );
        } catch (_) {
          _selectedAccount = _accounts.first;
        }
      }

      if (!widget.isEdit && _paymentRows.isEmpty && _selectedAccount != null) {
        final controller = TextEditingController(text: '0');

        _attachPaymentListener(controller);

        _paymentRows.add(
          _PurchasePaymentRow(
            account: _selectedAccount!,
            controller: controller,
          ),
        );
      }
    });
  }

  Future<void> _pickSupplier() async {
    if (_suppliers.isEmpty) {
      _showMessage('No supplier found. Please add a supplier first.');
      return;
    }

    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        var query = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = _suppliers.where((supplier) {
              return supplier.name.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text('Select Supplier'),
              content: SizedBox(
                width: 520,
                height: 460,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search supplier...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          query = value.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No supplier found.'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final supplier = filtered[index];

                                return ListTile(
                                  leading: const Icon(Icons.business),
                                  title: Text(supplier.name),
                                  selected:
                                      supplier.id == _formState.supplierId,
                                  onTap: () =>
                                      Navigator.pop(dialogContext, supplier.id),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _formState.supplierId = selected;
    });
  }

  Future<void> _pickProduct() async {
    if (_products.isEmpty) {
      _showMessage('No product found. Please add a product first.');
      return;
    }

    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        var query = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = _products.where((product) {
              return product.name.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text('Select Product'),
              content: SizedBox(
                width: 520,
                height: 460,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search product...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          query = value.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No product found.'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final product = filtered[index];

                                return ListTile(
                                  leading: const Icon(Icons.inventory_2),
                                  title: Text(product.name),
                                  selected: product.id == _formState.productId,
                                  onTap: () =>
                                      Navigator.pop(dialogContext, product.id),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _formState.productId = selected;
    });
  }

  String _selectedSupplierName() {
    final id = _formState.supplierId;
    if (id == null) return 'Select Supplier';

    for (final supplier in _suppliers) {
      if (supplier.id == id) {
        return supplier.name;
      }
    }

    return 'Select Supplier';
  }

  String _selectedProductName() {
    final id = _formState.productId;
    if (id == null) return 'Select Product';

    for (final product in _products) {
      if (product.id == id) {
        return product.name;
      }
    }

    return 'Select Product';
  }

  String _formatDateTime(DateTime date) {
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

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;

    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day $month $year, '
        '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Future<void> _selectPurchaseDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _formState.purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_formState.purchaseDate),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _formState.purchaseDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _addItem() {
    if (_formState.supplierId == null) {
      _showMessage('Please select a supplier.');
      return;
    }

    if (_formState.productId == null) {
      _showMessage('Please select a product.');
      return;
    }

    if (_quantityController.text.trim().isEmpty) {
      _showMessage('Please enter quantity.');
      return;
    }

    if (_priceController.text.trim().isEmpty) {
      _showMessage('Please enter purchase price.');
      return;
    }

    final qty = int.tryParse(_quantityController.text.trim());

    final purchasePrice = double.tryParse(_priceController.text.trim());

    if (qty == null || qty <= 0) {
      _showMessage('Quantity must be greater than zero.');
      return;
    }

    if (purchasePrice == null || purchasePrice <= 0) {
      _showMessage('Purchase price must be greater than zero.');
      return;
    }

    final selectedProduct = _products.firstWhere(
      (product) => product.id == _formState.productId,
    );

    final subtotal = qty * purchasePrice;

    setState(() {
      _purchaseItems.add(
        PurchaseItemDraft(
          productId: selectedProduct.id!,
          productName: selectedProduct.name,
          qty: qty,
          purchasePrice: purchasePrice,
          subtotal: subtotal,
        ),
      );

      _formState.productId = null;
      _quantityController.clear();
      _priceController.clear();
    });

    _showMessage('Item added successfully.');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double _itemsSubtotal() {
    return _purchaseItems.fold(0, (total, item) => total + item.subtotal);
  }

  double _additionalCharge() {
    return double.tryParse(_additionalChargeController.text.trim()) ?? 0;
  }

  double _invoiceDiscount() {
    return double.tryParse(_discountController.text.trim()) ?? 0;
  }

  double _grandTotal() {
    final total = _itemsSubtotal() + _additionalCharge() - _invoiceDiscount();

    return total < 0 ? 0 : total;
  }

  double _paidAmount() {
    double total = 0;

    for (final row in _paymentRows) {
      total += double.tryParse(row.controller.text.trim()) ?? 0;
    }

    return total;
  }

  double _dueAmount() {
    final due = _grandTotal() - _paidAmount();

    return due < 0 ? 0 : due;
  }

  void _syncPaidController() {
    _paidController.text = _paidAmount().toStringAsFixed(2);
  }

  void _attachPaymentListener(TextEditingController controller) {
    controller.addListener(() {
      _syncPaidController();

      if (mounted) {
        setState(() {});
      }
    });
  }

  void _addPaymentRow() {
    if (_accounts.isEmpty) {
      _showMessage('Please create a payment account first.');
      return;
    }

    final usedAccountIds = _paymentRows
        .map((row) => row.account.id)
        .whereType<int>()
        .toSet();

    Account? account;

    for (final candidate in _accounts) {
      final candidateId = candidate.id;

      if (candidateId != null && !usedAccountIds.contains(candidateId)) {
        account = candidate;
        break;
      }
    }

    if (account == null) {
      _showMessage('All payment accounts are already added.');
      return;
    }

    final controller = TextEditingController(text: '0');

    _attachPaymentListener(controller);

    setState(() {
      _paymentRows.add(
        _PurchasePaymentRow(account: account!, controller: controller),
      );
    });

    _syncPaidController();
  }

  void _removePaymentRow(int index) {
    if (index < 0 || index >= _paymentRows.length) {
      return;
    }

    final row = _paymentRows.removeAt(index);

    row.controller.dispose();

    _syncPaidController();

    setState(() {});
  }

  Future<void> _loadPurchaseForEdit() async {
    if (!widget.isEdit) return;

    final purchase = await _purchaseRepository.getPurchaseById(
      widget.purchaseId!,
    );

    if (purchase == null || !mounted) return;

    final items = await _purchaseItemRepository.getItemsByPurchase(
      widget.purchaseId!,
    );

    final savedAllocations = await _paymentAllocationService
        .getAllocationsWithExecutor(
          await _databaseHelper.database,
          referenceType: 'PURCHASE',
          referenceId: widget.purchaseId!,
        );

    Account? selectedAccount;

    if (purchase.accountId != null) {
      for (final account in _accounts) {
        if (account.id == purchase.accountId) {
          selectedAccount = account;
          break;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _formState.supplierId = purchase.supplierId;

      _formState.purchaseDate = DateTime.parse(purchase.purchaseDate);

      _additionalChargeController.text = purchase.additionalCharge
          .toStringAsFixed(2);

      _discountController.text = purchase.invoiceDiscount.toStringAsFixed(2);

      _selectedAccount = selectedAccount;

      for (final row in _paymentRows) {
        row.controller.dispose();
      }

      _paymentRows.clear();

      if (savedAllocations.isNotEmpty) {
        for (final allocation in savedAllocations) {
          Account? account;

          for (final candidate in _accounts) {
            if (candidate.id == allocation.accountId) {
              account = candidate;
              break;
            }
          }

          if (account == null) {
            continue;
          }

          final controller = TextEditingController(
            text: allocation.amount.toStringAsFixed(2),
          );

          _attachPaymentListener(controller);

          _paymentRows.add(
            _PurchasePaymentRow(account: account, controller: controller),
          );
        }
      } else if (purchase.paid > 0 && selectedAccount != null) {
        // Legacy purchase fallback.
        final controller = TextEditingController(
          text: purchase.paid.toStringAsFixed(2),
        );

        _attachPaymentListener(controller);

        _paymentRows.add(
          _PurchasePaymentRow(account: selectedAccount, controller: controller),
        );
      } else if (_selectedAccount != null) {
        final controller = TextEditingController(text: '0');

        _attachPaymentListener(controller);

        _paymentRows.add(
          _PurchasePaymentRow(
            account: _selectedAccount!,
            controller: controller,
          ),
        );
      }

      _syncPaidController();

      _purchaseItems.clear();

      for (final item in items) {
        Product? product;

        for (final p in _products) {
          if (p.id == item.productId) {
            product = p;
            break;
          }
        }

        _purchaseItems.add(
          PurchaseItemDraft(
            productId: item.productId,
            productName: product?.name ?? 'Unknown Product',
            qty: item.qty,
            purchasePrice: item.purchasePrice,
            subtotal: item.subtotal,
          ),
        );
      }
    });
  }

  Future<void> _savePurchase() async {
    if (_isSaving) return;

    if (_formState.supplierId == null) {
      _showMessage('Please select a supplier.');
      return;
    }

    if (_purchaseItems.isEmpty) {
      _showMessage('Please add at least one item.');
      return;
    }

    final paidAmount = _paidAmount();
    final grandTotal = _grandTotal();
    final additionalCharge = _additionalCharge();
    final invoiceDiscount = _invoiceDiscount();

    if (additionalCharge < 0) {
      _showMessage('Additional charge cannot be negative.');
      return;
    }

    if (invoiceDiscount < 0) {
      _showMessage('Discount cannot be negative.');
      return;
    }

    if (invoiceDiscount > _itemsSubtotal() + additionalCharge) {
      _showMessage('Discount cannot exceed purchase amount.');
      return;
    }

    if (grandTotal <= 0) {
      _showMessage('Purchase total must be greater than zero.');
      return;
    }

    if (paidAmount < 0) {
      _showMessage('Paid amount cannot be negative.');
      return;
    }

    if (paidAmount > grandTotal) {
      _showMessage('Paid amount cannot exceed total.');
      return;
    }

    for (final row in _paymentRows) {
      final amount = double.tryParse(row.controller.text.trim()) ?? 0;

      if (amount < 0) {
        _showMessage('Payment amount cannot be negative.');
        return;
      }

      if (amount > 0 && row.account.id == null) {
        _showMessage('Please select a valid payment account.');
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final purchase = Purchase(
        supplierId: _formState.supplierId!,
        invoiceNo: null,
        purchaseDate: _formState.purchaseDate.toIso8601String(),
        grandTotal: grandTotal,
        additionalCharge: _additionalCharge(),
        invoiceDiscount: _invoiceDiscount(),
        paid: paidAmount,
        due: grandTotal - paidAmount,
        accountId:
            _paymentRows
                .where(
                  (row) =>
                      (double.tryParse(row.controller.text.trim()) ?? 0) > 0,
                )
                .isNotEmpty
            ? _paymentRows
                  .firstWhere(
                    (row) =>
                        (double.tryParse(row.controller.text.trim()) ?? 0) > 0,
                  )
                  .account
                  .id
            : null,
        paymentMethod:
            _paymentRows
                    .where(
                      (row) =>
                          (double.tryParse(row.controller.text.trim()) ?? 0) >
                          0,
                    )
                    .length >
                1
            ? 'Split Payment'
            : (_paymentRows
                      .where(
                        (row) =>
                            (double.tryParse(row.controller.text.trim()) ?? 0) >
                            0,
                      )
                      .isNotEmpty
                  ? _paymentRows
                        .firstWhere(
                          (row) =>
                              (double.tryParse(row.controller.text.trim()) ??
                                  0) >
                              0,
                        )
                        .account
                        .name
                  : 'Cash'),
        note: null,
        createdAt: DateTime.now().toIso8601String(),
      );

      final items = _purchaseItems.map((item) {
        return PurchaseItem(
          productId: item.productId,
          qty: item.qty,
          purchasePrice: item.purchasePrice,
          subtotal: item.subtotal,
        );
      }).toList();

      final nowForPayments = DateTime.now().toIso8601String();

      final paymentAllocations = _paymentRows
          .where(
            (row) => (double.tryParse(row.controller.text.trim()) ?? 0) > 0,
          )
          .map(
            (row) => PaymentAllocation(
              referenceType: 'PURCHASE',
              referenceId: widget.purchaseId ?? 0,
              accountId: row.account.id!,
              amount: double.tryParse(row.controller.text.trim()) ?? 0,
              paymentMethod: row.account.name,
              createdAt: nowForPayments,
            ),
          )
          .toList();

      if (widget.isEdit) {
        await _purchaseService.updatePurchase(
          widget.purchaseId!,
          purchase,
          items,
          paymentAllocations: paymentAllocations,
        );
      } else {
        await _purchaseService.savePurchase(
          purchase,
          items,
          paymentAllocations: paymentAllocations,
        );

        /*
         * IMPORTANT:
         *
         * PurchaseService handles the actual account balance
         * and account-ledger transaction.
         *
         * Therefore we DO NOT create a second supplier payment
         * or decrease the account balance here.
         *
         * This prevents:
         * - duplicate supplier payment
         * - duplicate account balance deduction
         * - supplier ledger/account ledger mismatch
         */
      }

      RefreshService.notify();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'Purchase updated successfully.'
                : 'Purchase saved successfully.',
          ),
        ),
      );

      if (!widget.isEdit) {
        setState(() {
          _formState.supplierId = null;
          _formState.productId = null;
          _formState.purchaseDate = DateTime.now();

          _purchaseItems.clear();

          _quantityController.clear();
          _priceController.clear();
          _paidController.clear();

          _additionalChargeController.text = '0';
          _discountController.text = '0';

          if (_accounts.isNotEmpty) {
            try {
              _selectedAccount = _accounts.firstWhere(
                (account) => account.type.toUpperCase() == 'CASH',
              );
            } catch (_) {
              _selectedAccount = _accounts.first;
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save purchase: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _paidController.dispose();
    _additionalChargeController.dispose();
    _discountController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isEdit ? 'Edit Purchase' : 'New Purchase'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    if (!isDesktop) {
      return _buildMobilePurchaseScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Purchase' : 'New Purchase'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            // ====================================================
            // SUPPLIER + DATE
            // ====================================================
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickSupplier,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Supplier',
                              prefixIcon: Icon(Icons.person_search),
                              suffixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(
                              _selectedSupplierName(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 58,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _openAddSupplier,
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    readOnly: true,
                    onTap: _selectPurchaseDate,
                    decoration: const InputDecoration(
                      labelText: 'Purchase Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                      isDense: true,
                    ),
                    controller: TextEditingController(
                      text: _formatDateTime(_formState.purchaseDate),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ====================================================
            // PRODUCT + QTY + PRICE + ADD
            // ====================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: InkWell(
                    onTap: _pickProduct,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Product',
                        prefixIcon: Icon(Icons.inventory_2),
                        suffixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        _selectedProductName(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _openAddProduct,
                    child: const Icon(Icons.add_box),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Purchase Price',
                      prefixText: '৳ ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text(
                      'Add Item',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ====================================================
            // ITEMS TABLE
            // ====================================================
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      color: Colors.green.shade700,
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 55,
                            child: Text(
                              'SL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: Text(
                              'Product',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Qty',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Rate',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Total',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              'Action',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _purchaseItems.isEmpty
                          ? const Center(
                              child: Text(
                                'No items added yet.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _purchaseItems.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                              ),
                              itemBuilder: (context, index) {
                                final item = _purchaseItems[index];

                                return Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 46,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 5,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 55,
                                        child: Text('${index + 1}'),
                                      ),
                                      Expanded(
                                        flex: 5,
                                        child: Text(
                                          item.productName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${item.qty}',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item.purchasePrice.toStringAsFixed(2),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item.subtotal.toStringAsFixed(2),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 70,
                                        child: Center(
                                          child: IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            tooltip: 'Delete Item',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _purchaseItems.removeAt(index);
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ====================================================
            // SUMMARY + PAYMENT
            // ====================================================
            Expanded(
              flex: 4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ------------------------------------------------
                  // PURCHASE SUMMARY
                  // ------------------------------------------------
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Purchase Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            _purchaseSummaryRow(
                              'Items Subtotal',
                              _itemsSubtotal(),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _additionalChargeController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Additional Charge',
                                      prefixText: '৳ ',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _discountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Discount',
                                      prefixText: '৳ ',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            _purchaseSummaryRow(
                              'Grand Total',
                              _grandTotal(),
                              bold: true,
                            ),
                            const Divider(),
                            _purchaseSummaryRow('Paid', _paidAmount()),
                            const SizedBox(height: 5),
                            _purchaseSummaryRow(
                              'Due Amount',
                              _dueAmount(),
                              bold: true,
                              due: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ------------------------------------------------
                  // PAYMENT
                  // ------------------------------------------------
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Payment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _addPaymentRow,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Payment'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _paymentRows.length,
                                itemBuilder: (context, index) {
                                  final row = _paymentRows[index];

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child:
                                              DropdownButtonFormField<Account>(
                                                value: row.account,
                                                isExpanded: true,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Payment Account',
                                                      border:
                                                          OutlineInputBorder(),
                                                      isDense: true,
                                                    ),
                                                items: _accounts
                                                    .where(
                                                      (account) =>
                                                          account.id ==
                                                              row.account.id ||
                                                          !_paymentRows.any(
                                                            (otherRow) =>
                                                                !identical(
                                                                  otherRow,
                                                                  row,
                                                                ) &&
                                                                otherRow
                                                                        .account
                                                                        .id ==
                                                                    account.id,
                                                          ),
                                                    )
                                                    .map(
                                                      (account) =>
                                                          DropdownMenuItem<
                                                            Account
                                                          >(
                                                            value: account,
                                                            child: Text(
                                                              account.name,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                    )
                                                    .toList(),
                                                onChanged: (value) {
                                                  if (value == null) return;

                                                  setState(() {
                                                    row.account = value;

                                                    if (index == 0) {
                                                      _selectedAccount = value;
                                                    }
                                                  });
                                                },
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: row.controller,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: const InputDecoration(
                                              labelText: 'Amount',
                                              prefixText: '৳ ',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                        if (_paymentRows.length > 1)
                                          IconButton(
                                            tooltip: 'Remove payment',
                                            onPressed: () =>
                                                _removePaymentRow(index),
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: Colors.green.shade100,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Paid',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '৳${_paidAmount().toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ====================================================
            // SAVE
            // ====================================================
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePurchase,
                icon: const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : widget.isEdit
                      ? 'Update Purchase'
                      : 'Save Purchase',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _purchaseSummaryRow(
    String label,
    double value, {
    bool bold = false,
    bool due = false,
  }) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
      color: due ? Colors.red : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('৳${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  Widget _buildMobilePurchaseScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Purchase' : 'New Purchase'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickSupplier,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Supplier',
                        prefixIcon: Icon(Icons.person_search),
                        suffixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _selectedSupplierName(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _openAddSupplier,
                    child: const Icon(Icons.person_add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: true,
              onTap: _selectPurchaseDate,
              decoration: const InputDecoration(
                labelText: 'Purchase Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              controller: TextEditingController(
                text: _formatDateTime(_formState.purchaseDate),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickProduct,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Product',
                        prefixIcon: Icon(Icons.inventory_2),
                        suffixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _selectedProductName(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _openAddProduct,
                    child: const Icon(Icons.add_box),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Purchase Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add Item'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Added Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_purchaseItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No items added yet.')),
              )
            else
              ...List.generate(_purchaseItems.length, (index) {
                final item = _purchaseItems[index];

                return Card(
                  child: ListTile(
                    title: Text(item.productName),
                    subtitle: Text(
                      'Qty: ${item.qty} × '
                      '${item.purchasePrice.toStringAsFixed(2)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.subtotal.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _purchaseItems.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            _purchaseSummaryRow('Grand Total', _grandTotal(), bold: true),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addPaymentRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Payment'),
                ),
              ],
            ),
            ...List.generate(_paymentRows.length, (index) {
              final row = _paymentRows[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<Account>(
                        value: row.account,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Payment Account',
                          border: OutlineInputBorder(),
                        ),
                        items: _accounts
                            .map(
                              (account) => DropdownMenuItem<Account>(
                                value: account,
                                child: Text(
                                  account.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            row.account = value;
                            if (index == 0) {
                              _selectedAccount = value;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: row.controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '৳ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    if (_paymentRows.length > 1)
                      IconButton(
                        onPressed: () => _removePaymentRow(index),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                  ],
                ),
              );
            }),
            _purchaseSummaryRow('Total Paid', _paidAmount()),
            _purchaseSummaryRow(
              'Due Amount',
              _dueAmount(),
              bold: true,
              due: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePurchase,
                icon: const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : widget.isEdit
                      ? 'Update Purchase'
                      : 'Save Purchase',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchasePaymentRow {
  Account account;
  final TextEditingController controller;

  _PurchasePaymentRow({required this.account, required this.controller});
}
