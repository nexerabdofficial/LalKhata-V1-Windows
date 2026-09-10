import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/cart_item.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';

import '../../services/account_repository.dart';
import '../../services/customer_repository.dart';
import '../../services/product_repository.dart';
import '../../services/sale_repository.dart';
import '../../services/refresh_service.dart';

import '../../pdf/sale_invoice_pdf.dart';

import '../customers/add_customer_screen.dart';
import '../products/add_product_screen.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final CustomerRepository _customerRepository =
      CustomerRepository();

  final ProductRepository _productRepository =
      ProductRepository();

  final SaleRepository _saleRepository =
      SaleRepository();

  final AccountRepository _accountRepository =
      AccountRepository();

  List<Customer> _customers = [];
  List<Product> _products = [];
  List<Account> _accounts = [];

  Customer? _selectedCustomer;
  Product? _selectedProduct;
  Account? _selectedAccount;

  final List<CartItem> _cart = [];

  // ============================================================
  // CUSTOMER SEARCH
  // ============================================================

  final TextEditingController _customerController =
      TextEditingController();

  bool _showCustomerSuggestions = false;

  // ============================================================
  // PRODUCT SEARCH
  // ============================================================

  final TextEditingController _productController =
      TextEditingController();

  bool _showProductSuggestions = false;

  // ============================================================
  // OTHER CONTROLLERS
  // ============================================================

  final TextEditingController _qtyController =
      TextEditingController();

  final TextEditingController _paidController =
      TextEditingController();

  final TextEditingController _additionalChargeController =
      TextEditingController(text: "0");

  final TextEditingController _discountController =
      TextEditingController(text: "0");

  final TextEditingController _noteController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;

  // ============================================================
  // CUSTOMER PREVIOUS BALANCE / BF
  // ============================================================

  double _balanceForward = 0;

  // ============================================================
  // BILL CALCULATION
  // ============================================================

  double _additionalCharge = 0;
  double _invoiceDiscount = 0;
  double _grandTotal = 0;

  double get _subtotal {
    double total = 0;

    for (final item in _cart) {
      total += item.subtotal;
    }

    return total;
  }

  double get _invoiceTotal {
    return _grandTotal;
  }

  double get _totalOutstanding {
    return _balanceForward + _invoiceTotal;
  }

  double get _balanceDue {
    final paid =
        double.tryParse(
              _paidController.text.trim(),
            ) ??
            0;

    final balance =
        _totalOutstanding - paid;

    return balance < 0 ? 0 : balance;
  }

  // ============================================================
  // FILTERED CUSTOMERS
  // ============================================================

  List<Customer> get _filteredCustomers {
    final query =
        _customerController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return [];
    }

    return _customers.where((customer) {
      final name =
          customer.name.toLowerCase();

      final id =
          customer.id?.toString().toLowerCase() ?? "";

      final phone =
          customer.phone?.toLowerCase() ?? "";

      return name.contains(query) ||
          id.contains(query) ||
          phone.contains(query);
    }).take(10).toList();
  }

  // ============================================================
  // FILTERED PRODUCTS
  // ============================================================

  List<Product> get _filteredProducts {
    final query =
        _productController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return [];
    }

    return _products.where((product) {
      final name =
          product.name.toLowerCase();

      final id =
          product.id?.toString().toLowerCase() ?? "";

      return name.contains(query) ||
          id.contains(query);
    }).take(10).toList();
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _qtyController.text = "1";
    _paidController.text = "0";

    _paidController.addListener(
      _calculateTotal,
    );

    _additionalChargeController.addListener(
      _calculateTotal,
    );

    _discountController.addListener(
      _calculateTotal,
    );

    _customerController.addListener(() {
      if (!mounted) return;

      setState(() {
        _showCustomerSuggestions =
            _customerController.text.trim().isNotEmpty;
      });
    });

    _productController.addListener(() {
      if (!mounted) return;

      setState(() {
        _showProductSuggestions =
            _productController.text.trim().isNotEmpty;
      });
    });

    _loadData();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadData() async {
    try {
      final customers =
          await _customerRepository.getCustomers();

      final products =
          await _productRepository.getProducts();

      final accounts =
          await _accountRepository.getAccounts();

      if (!mounted) return;

      setState(() {
        _customers = customers;
        _products = products;
        _accounts = accounts;

        if (_accounts.isNotEmpty) {
          try {
            _selectedAccount =
                _accounts.firstWhere(
              (e) =>
                  e.type.toUpperCase() ==
                  "CASH",
            );
          } catch (_) {
            _selectedAccount =
                _accounts.first;
          }
        }

        _loading = false;
      });

      _calculateTotal();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to load data: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // REFRESH CUSTOMERS
  // ============================================================

  Future<void> _openAddCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AddCustomerScreen(),
      ),
    );

    if (result == true) {
      final customers =
          await _customerRepository.getCustomers();

      if (!mounted) return;

      setState(() {
        _customers = customers;
        _customerController.clear();
        _showCustomerSuggestions = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Customer list updated.",
          ),
        ),
      );
    }
  }

  // ============================================================
  // REFRESH PRODUCTS
  // ============================================================

  Future<void> _openAddProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AddProductScreen(),
      ),
    );

    if (result == true) {
      final products =
          await _productRepository.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _productController.clear();
        _selectedProduct = null;
        _showProductSuggestions = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Product list updated.",
          ),
        ),
      );
    }
  }

  // ============================================================
  // CUSTOMER
  // ============================================================

  void _selectCustomer(
    Customer customer,
  ) {
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedCustomer = customer;

      _customerController.text =
          customer.name;

      _balanceForward =
          customer.balance;

      _showCustomerSuggestions = false;
    });

    _calculateTotal();
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;

      _customerController.clear();

      _balanceForward = 0;

      _showCustomerSuggestions = false;
    });

    _calculateTotal();
  }

  // ============================================================
  // PRODUCT
  // ============================================================

  void _selectProduct(
    Product product,
  ) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This product is out of stock.",
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _selectedProduct = product;

      _productController.text =
          product.name;

      _qtyController.text = "1";

      _showProductSuggestions = false;
    });
  }

  void _clearProduct() {
    setState(() {
      _selectedProduct = null;

      _productController.clear();

      _qtyController.text = "1";

      _showProductSuggestions = false;
    });
  }

  // ============================================================
  // CALCULATE BILL
  // ============================================================

  void _calculateTotal() {
    double subtotal = 0;

    for (final item in _cart) {
      subtotal += item.subtotal;
    }

    double additionalCharge =
        double.tryParse(
              _additionalChargeController.text.trim(),
            ) ??
            0;

    double discount =
        double.tryParse(
              _discountController.text.trim(),
            ) ??
            0;

    if (additionalCharge < 0) {
      additionalCharge = 0;
    }

    if (discount < 0) {
      discount = 0;
    }

    final maximumDiscount =
        subtotal + additionalCharge;

    if (discount > maximumDiscount) {
      discount = maximumDiscount;
    }

    final grandTotal =
        subtotal +
        additionalCharge -
        discount;

    if (!mounted) return;

    setState(() {
      _additionalCharge =
          additionalCharge;

      _invoiceDiscount =
          discount;

      _grandTotal =
          grandTotal < 0
              ? 0
              : grandTotal;
    });
  }

  // ============================================================
  // CHANGE CART RATE
  // ============================================================

  void _editCartRate(int index) {
    final item = _cart[index];

    final controller =
        TextEditingController(
      text: item.saleRate.toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Edit Selling Rate",
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration:
                const InputDecoration(
              labelText: "Rate",
              prefixText: "৳ ",
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final newRate =
                    double.tryParse(
                  controller.text.trim(),
                );

                if (newRate == null ||
                    newRate < 0) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Please enter a valid rate.",
                      ),
                    ),
                  );
                  return;
                }

                setState(() {
                  item.saleRate =
                      newRate;
                });

                Navigator.pop(
                  dialogContext,
                );

                _calculateTotal();
              },
              child:
                  const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ADD PRODUCT TO CART
  // ============================================================

  void _addProduct() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Select a product.",
          ),
        ),
      );
      return;
    }

    final qty =
        int.tryParse(
              _qtyController.text.trim(),
            ) ??
            0;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Invalid quantity.",
          ),
        ),
      );
      return;
    }

    if (qty >
        _selectedProduct!.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Available Stock : "
            "${_selectedProduct!.stock}",
          ),
        ),
      );
      return;
    }

    setState(() {
      final index =
          _cart.indexWhere(
        (e) =>
            e.product.id ==
            _selectedProduct!.id,
      );

      if (index == -1) {
        _cart.add(
          CartItem(
            product:
                _selectedProduct!,
            quantity:
                qty,
            saleRate:
                _selectedProduct!
                    .sellingPrice,
          ),
        );
      } else {
        final newQty =
            _cart[index].quantity +
                qty;

        if (newQty >
            _selectedProduct!.stock) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(
              content: Text(
                "Available Stock : "
                "${_selectedProduct!.stock}",
              ),
            ),
          );
          return;
        }

        _cart[index].quantity =
            newQty;
      }

      _selectedProduct = null;

      _productController.clear();

      _qtyController.text = "1";

      _showProductSuggestions =
          false;
    });

    FocusScope.of(context).unfocus();

    _calculateTotal();
  }

  // ============================================================
  // REMOVE CART ITEM
  // ============================================================

  void _removeCartItem(int index) {
    setState(() {
      _cart.removeAt(index);
    });

    _calculateTotal();
  }

  // ============================================================
  // SAVE SALE
  // ============================================================

  Future<void> _saveSale() async {
    if (_saving) return;

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select customer.",
          ),
        ),
      );
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select account.",
          ),
        ),
      );
      return;
    }

    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Cart is empty.",
          ),
        ),
      );
      return;
    }

    final paid =
        double.tryParse(
              _paidController.text.trim(),
            ) ??
            0;

    if (paid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Paid amount cannot be negative.",
          ),
        ),
      );
      return;
    }

    final totalOutstanding =
        _totalOutstanding;

    if (paid > totalOutstanding) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Paid amount cannot exceed Total Outstanding "
            "(৳${totalOutstanding.toStringAsFixed(2)}).",
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // ==========================================================
      // CURRENT INVOICE DUE
      // ==========================================================

      final invoiceDue =
          _grandTotal - paid;

      final now =
          DateTime.now().toIso8601String();

      final sale = Sale(
        customerId:
            _selectedCustomer!.id!,
        invoiceNo: "",
        saleDate:
            now,
        grandTotal:
            _grandTotal,
        additionalCharge:
            _additionalCharge,
        invoiceDiscount:
            _invoiceDiscount,
        paid:
            paid,
        due:
            invoiceDue < 0
                ? 0
                : invoiceDue,
        note:
            _noteController.text.trim(),
        paymentMethod:
            _selectedAccount!.name,
        createdAt:
            now,
      );

      final List<SaleItem> items = [];

      for (final cart in _cart) {
        if (cart.quantity >
            cart.product.stock) {
          throw Exception(
            "${cart.product.name} stock unavailable.",
          );
        }

        items.add(
          SaleItem(
            saleId: 0,
            productId:
                cart.product.id!,
            productName:
                cart.product.name,
            qty:
                cart.quantity,
            purchasePrice:
                cart.product.purchasePrice,
            sellingPrice:
                cart.saleRate,
            subtotal:
                cart.subtotal,
          ),
        );
      }

      // ==========================================================
      // SAVE SALE
      // ==========================================================

      final saleId =
          await _saleRepository.saveSale(
        sale: sale,
        items: items,
      );

      // ==========================================================
      // CUSTOMER PAYMENT / CP#
      // ==========================================================

      if (paid > 0) {
        final voucherNo =
            await _customerRepository
                .getNextCustomerPaymentVoucherNo();

        await _customerRepository
            .saveCustomerPayment(
          customerId:
              sale.customerId,
          amount:
              paid,
          accountId:
              _selectedAccount!.id!,
          paymentMethod:
              _selectedAccount!.name,
          voucherNo:
              voucherNo,
        );
      }

      // ==========================================================
      // ACCOUNT BALANCE
      // ==========================================================

      if (paid > 0) {
        await _accountRepository.addBalance(
          _selectedAccount!.id!,
          paid,
        );
      }

      // ==========================================================
      // REFRESH APP
      // ==========================================================

      RefreshService.notify();

      // ==========================================================
      // GET SAVED SALE
      // ==========================================================

      final savedSale =
          await _saleRepository.getSale(
        saleId,
      );

      final savedItems =
          await _saleRepository.getSaleItems(
        saleId,
      );

      if (savedSale == null) {
        throw Exception(
          "Saved sale could not be loaded.",
        );
      }

      // ==========================================================
      // GENERATE PDF
      // ==========================================================

      await _generateInvoicePdf(
        savedSale,
        savedItems,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Sale saved successfully.",
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // PDF
  // ============================================================

  Future<void> _generateInvoicePdf(
    Sale sale,
    List<SaleItem> items,
  ) async {
    try {
      final saleInfo =
          await _saleRepository.getSaleById(
        sale.id!,
      );

      if (saleInfo == null) {
        throw Exception(
          "Sale not found.",
        );
      }

      await SaleInvoicePdf.savePdf(
        sale: sale,
        saleInfo: saleInfo,
        items: items,
      );

      await SaleInvoicePdf.preview(
        sale: sale,
        saleInfo: saleInfo,
        items: items,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "PDF Error: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _customerController.dispose();
    _productController.dispose();
    _qtyController.dispose();
    _paidController.dispose();
    _additionalChargeController.dispose();
    _discountController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "New Sale",
        ),
      ),

      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : SafeArea(
              child:
                  SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  children: [
                    // ==================================================
                    // CUSTOMER SEARCH + ADD CUSTOMER
                    // ==================================================

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              TextFormField(
                                controller:
                                    _customerController,
                                decoration:
                                    InputDecoration(
                                  labelText:
                                      "Search Customer",
                                  hintText:
                                      "Name, ID or phone...",
                                  border:
                                      const OutlineInputBorder(),
                                  prefixIcon:
                                      const Icon(
                                    Icons
                                        .person_search,
                                  ),
                                  suffixIcon:
                                      _selectedCustomer !=
                                              null
                                          ? IconButton(
                                              icon:
                                                  const Icon(
                                                Icons
                                                    .clear,
                                              ),
                                              onPressed:
                                                  _clearCustomer,
                                            )
                                          : null,
                                ),
                                onTap: () {
                                  if (_customerController
                                      .text
                                      .trim()
                                      .isNotEmpty) {
                                    setState(() {
                                      _showCustomerSuggestions =
                                          true;
                                    });
                                  }
                                },
                              ),

                              if (_showCustomerSuggestions &&
                                  _filteredCustomers
                                      .isNotEmpty)
                                Container(
                                  margin:
                                      const EdgeInsets
                                          .only(
                                    top: 4,
                                  ),
                                  constraints:
                                      const BoxConstraints(
                                    maxHeight:
                                        280,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        Colors.white,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      8,
                                    ),
                                    border:
                                        Border.all(
                                      color: Colors
                                          .grey
                                          .shade300,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors
                                            .black
                                            .withOpacity(
                                          0.12,
                                        ),
                                        blurRadius:
                                            8,
                                        offset:
                                            const Offset(
                                          0,
                                          3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  child:
                                      ListView.builder(
                                    shrinkWrap:
                                        true,
                                    padding:
                                        EdgeInsets
                                            .zero,
                                    itemCount:
                                        _filteredCustomers
                                            .length,
                                    itemBuilder:
                                        (
                                      context,
                                      index,
                                    ) {
                                      final customer =
                                          _filteredCustomers[
                                              index];

                                      return InkWell(
                                        onTap: () {
                                          _selectCustomer(
                                            customer,
                                          );
                                        },
                                        child:
                                            Padding(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                            horizontal:
                                                12,
                                            vertical:
                                                10,
                                          ),
                                          child:
                                              Row(
                                            children: [
                                              CircleAvatar(
                                                radius:
                                                    20,
                                                backgroundColor:
                                                    Colors
                                                        .green
                                                        .shade100,
                                                child:
                                                    Text(
                                                  customer
                                                          .name
                                                          .isNotEmpty
                                                      ? customer
                                                          .name[
                                                              0]
                                                          .toUpperCase()
                                                      : "?",
                                                  style:
                                                      TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color:
                                                        Colors.green.shade800,
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(
                                                width:
                                                    12,
                                              ),

                                              Expanded(
                                                child:
                                                    Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      customer.name,
                                                      maxLines:
                                                          1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            15,
                                                      ),
                                                    ),

                                                    const SizedBox(
                                                      height:
                                                          3,
                                                    ),

                                                    Text(
                                                      "ID: ${customer.id}   "
                                                      "Balance: ৳${customer.balance.toStringAsFixed(2)}",
                                                      maxLines:
                                                          1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          TextStyle(
                                                        fontSize:
                                                            12,
                                                        color:
                                                            Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        SizedBox(
                          height: 56,
                          child:
                              ElevatedButton(
                            onPressed:
                                _openAddCustomer,
                            style:
                                ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    12,
                              ),
                            ),
                            child:
                                const Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                Icon(
                                  Icons
                                      .person_add,
                                  size:
                                      20,
                                ),
                                Text(
                                  "Add",
                                  style:
                                      TextStyle(
                                    fontSize:
                                        11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==================================================
                    // PRODUCT SEARCH + ADD PRODUCT
                    // ==================================================

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              TextFormField(
                                controller:
                                    _productController,
                                decoration:
                                    InputDecoration(
                                  labelText:
                                      "Search Product",
                                  hintText:
                                      "Product name or ID...",
                                  border:
                                      const OutlineInputBorder(),
                                  prefixIcon:
                                      const Icon(
                                    Icons
                                        .inventory_2,
                                  ),
                                  suffixIcon:
                                      _selectedProduct !=
                                              null
                                          ? IconButton(
                                              icon:
                                                  const Icon(
                                                Icons
                                                    .clear,
                                              ),
                                              onPressed:
                                                  _clearProduct,
                                            )
                                          : null,
                                ),
                                onTap: () {
                                  if (_productController
                                      .text
                                      .trim()
                                      .isNotEmpty) {
                                    setState(() {
                                      _showProductSuggestions =
                                          true;
                                    });
                                  }
                                },
                              ),

                              if (_showProductSuggestions &&
                                  _filteredProducts
                                      .isNotEmpty)
                                Container(
                                  margin:
                                      const EdgeInsets
                                          .only(
                                    top: 4,
                                  ),
                                  constraints:
                                      const BoxConstraints(
                                    maxHeight:
                                        300,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        Colors.white,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      8,
                                    ),
                                    border:
                                        Border.all(
                                      color: Colors
                                          .grey
                                          .shade300,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors
                                            .black
                                            .withOpacity(
                                          0.12,
                                        ),
                                        blurRadius:
                                            8,
                                        offset:
                                            const Offset(
                                          0,
                                          3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  child:
                                      ListView.builder(
                                    shrinkWrap:
                                        true,
                                    padding:
                                        EdgeInsets
                                            .zero,
                                    itemCount:
                                        _filteredProducts
                                            .length,
                                    itemBuilder:
                                        (
                                      context,
                                      index,
                                    ) {
                                      final product =
                                          _filteredProducts[
                                              index];

                                      final bool
                                          outOfStock =
                                          product.stock <=
                                              0;

                                      final bool
                                          lowStock =
                                          product.stock >
                                                  0 &&
                                              product.stock <=
                                                  10;

                                      return InkWell(
                                        onTap:
                                            outOfStock
                                                ? null
                                                : () {
                                                    _selectProduct(
                                                      product,
                                                    );
                                                  },
                                        child:
                                            Padding(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                            horizontal:
                                                12,
                                            vertical:
                                                10,
                                          ),
                                          child:
                                              Row(
                                            children: [
                                              Container(
                                                width:
                                                    40,
                                                height:
                                                    40,
                                                decoration:
                                                    BoxDecoration(
                                                  color:
                                                      outOfStock
                                                          ? Colors.red.shade50
                                                          : Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    8,
                                                  ),
                                                ),
                                                child:
                                                    Icon(
                                                  Icons
                                                      .inventory_2,
                                                  color:
                                                      outOfStock
                                                          ? Colors.red
                                                          : Colors.blue,
                                                ),
                                              ),

                                              const SizedBox(
                                                width:
                                                    12,
                                              ),

                                              Expanded(
                                                child:
                                                    Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      product.name,
                                                      maxLines:
                                                          1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            15,
                                                      ),
                                                    ),

                                                    const SizedBox(
                                                      height:
                                                          3,
                                                    ),

                                                    Text(
                                                      "ID: ${product.id}   "
                                                      "৳${product.sellingPrice.toStringAsFixed(2)}",
                                                      style:
                                                          TextStyle(
                                                        fontSize:
                                                            12,
                                                        color:
                                                            Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                  horizontal:
                                                      8,
                                                  vertical:
                                                      5,
                                                ),
                                                decoration:
                                                    BoxDecoration(
                                                  color:
                                                      outOfStock
                                                          ? Colors.red.shade100
                                                          : lowStock
                                                              ? Colors.orange.shade100
                                                              : Colors.green.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    6,
                                                  ),
                                                ),
                                                child:
                                                    Text(
                                                  outOfStock
                                                      ? "Out"
                                                      : "${product.stock} ${product.unit}",
                                                  style:
                                                      TextStyle(
                                                    fontSize:
                                                        11,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color:
                                                        outOfStock
                                                            ? Colors.red
                                                            : lowStock
                                                                ? Colors.orange.shade800
                                                                : Colors.green.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        SizedBox(
                          height: 56,
                          child:
                              ElevatedButton(
                            onPressed:
                                _openAddProduct,
                            style:
                                ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    12,
                              ),
                            ),
                            child:
                                const Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                Icon(
                                  Icons
                                      .add_box,
                                  size:
                                      20,
                                ),
                                Text(
                                  "Add",
                                  style:
                                      TextStyle(
                                    fontSize:
                                        11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==================================================
                    // SELECTED PRODUCT / QTY
                    // ==================================================

                    Row(
                      children: [
                        Expanded(
                          child:
                              TextFormField(
                            controller:
                                _qtyController,
                            keyboardType:
                                TextInputType
                                    .number,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  "Qty",
                              border:
                                  OutlineInputBorder(),
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child:
                              SizedBox(
                            height: 56,
                            child:
                                ElevatedButton.icon(
                              icon:
                                  const Icon(
                                Icons
                                    .add_shopping_cart,
                              ),
                              label:
                                  const Text(
                                "Add",
                              ),
                              onPressed:
                                  _addProduct,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_selectedProduct !=
                        null)
                      Container(
                        width:
                            double.infinity,
                        margin:
                            const EdgeInsets
                                .only(
                          top: 8,
                        ),
                        padding:
                            const EdgeInsets
                                .all(
                          10,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.green.shade50,
                          borderRadius:
                              BorderRadius.circular(
                            8,
                          ),
                        ),
                        child:
                            Row(
                          children: [
                            Icon(
                              Icons
                                  .check_circle,
                              color:
                                  Colors.green
                                      .shade700,
                            ),
                            const SizedBox(
                              width:
                                  8,
                            ),
                            Expanded(
                              child:
                                  Text(
                                "${_selectedProduct!.name}  •  "
                                "Stock: ${_selectedProduct!.stock} ${_selectedProduct!.unit}",
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==================================================
                    // CART
                    // ==================================================

                    SizedBox(
                      height: 270,
                      child:
                          Card(
                        elevation:
                            2,
                        child:
                            _cart.isEmpty
                                ? const Center(
                                    child:
                                        Text(
                                      "No Product Added",
                                    ),
                                  )
                                : SingleChildScrollView(
                                    scrollDirection:
                                        Axis.vertical,
                                    child:
                                        SingleChildScrollView(
                                      scrollDirection:
                                          Axis.horizontal,
                                      child:
                                          DataTable(
                                        columnSpacing:
                                            18,
                                        headingRowColor:
                                            MaterialStateProperty.all(
                                          Colors
                                              .green
                                              .shade100,
                                        ),
                                        columns:
                                            const [
                                          DataColumn(
                                            label:
                                                Text(
                                              "Product",
                                            ),
                                          ),
                                          DataColumn(
                                            numeric:
                                                true,
                                            label:
                                                Text(
                                              "Qty",
                                            ),
                                          ),
                                          DataColumn(
                                            numeric:
                                                true,
                                            label:
                                                Text(
                                              "Rate",
                                            ),
                                          ),
                                          DataColumn(
                                            numeric:
                                                true,
                                            label:
                                                Text(
                                              "Total",
                                            ),
                                          ),
                                          DataColumn(
                                            label:
                                                Text(
                                              "",
                                            ),
                                          ),
                                        ],
                                        rows:
                                            List.generate(
                                          _cart.length,
                                          (
                                            index,
                                          ) {
                                            final item =
                                                _cart[index];

                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  SizedBox(
                                                    width:
                                                        150,
                                                    child:
                                                        Text(
                                                      item.product.name,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),

                                                DataCell(
                                                  Text(
                                                    item.quantity.toString(),
                                                  ),
                                                ),

                                                DataCell(
                                                  InkWell(
                                                    onTap:
                                                        () {
                                                      _editCartRate(
                                                        index,
                                                      );
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      6,
                                                    ),
                                                    child:
                                                        Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                        horizontal:
                                                            8,
                                                        vertical:
                                                            6,
                                                      ),
                                                      decoration:
                                                          BoxDecoration(
                                                        color:
                                                            Colors.blue.shade50,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                          6,
                                                        ),
                                                        border:
                                                            Border.all(
                                                          color:
                                                              Colors.blue.shade200,
                                                        ),
                                                      ),
                                                      child:
                                                          Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            item.saleRate.toStringAsFixed(
                                                              2,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width:
                                                                4,
                                                          ),
                                                          Icon(
                                                            Icons.edit,
                                                            size:
                                                                14,
                                                            color:
                                                                Colors.blue.shade700,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                DataCell(
                                                  Text(
                                                    item.subtotal.toStringAsFixed(
                                                      2,
                                                    ),
                                                  ),
                                                ),

                                                DataCell(
                                                  IconButton(
                                                    icon:
                                                        const Icon(
                                                      Icons.delete,
                                                      color:
                                                          Colors.red,
                                                    ),
                                                    onPressed:
                                                        () {
                                                      _removeCartItem(
                                                        index,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==================================================
                    // BILL SUMMARY
                    // ==================================================

                    Card(
                      elevation:
                          3,
                      child:
                          Padding(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        child:
                            Column(
                          children: [
                            _summaryRow(
                              "Subtotal",
                              _subtotal,
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            TextFormField(
                              controller:
                                  _additionalChargeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal:
                                    true,
                              ),
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    "Additional Charge",
                                prefixIcon:
                                    Icon(
                                  Icons
                                      .add_circle_outline,
                                ),
                                border:
                                    OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            TextFormField(
                              controller:
                                  _discountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal:
                                    true,
                              ),
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    "Invoice Discount",
                                prefixIcon:
                                    Icon(
                                  Icons.discount,
                                ),
                                border:
                                    OutlineInputBorder(),
                              ),
                            ),

                            const Divider(
                              height:
                                  28,
                            ),

                            _summaryRow(
                              "Invoice Total",
                              _invoiceTotal,
                              bold:
                                  true,
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            _summaryRow(
                              "Previous Due (BF)",
                              _balanceForward,
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            Container(
                              width:
                                  double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical:
                                    12,
                                horizontal:
                                    4,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.blue.shade50,
                                borderRadius:
                                    BorderRadius.circular(
                                  8,
                                ),
                              ),
                              child:
                                  _summaryRow(
                                "Total Outstanding",
                                _totalOutstanding,
                                bold:
                                    true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==================================================
                    // PAYMENT METHOD
                    // ==================================================

                    DropdownButtonFormField<Account>(
                      value:
                          _selectedAccount,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Receive To Account",
                        prefixIcon:
                            Icon(
                          Icons
                              .account_balance_wallet,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                      items:
                          _accounts.map(
                        (
                          account,
                        ) {
                          return DropdownMenuItem<
                              Account>(
                            value:
                                account,
                            child:
                                Text(
                              account.name,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged:
                          (value) {
                        if (value ==
                            null) {
                          return;
                        }

                        setState(() {
                          _selectedAccount =
                              value;
                        });
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==================================================
                    // PAYMENT
                    // ==================================================

                    TextFormField(
                      controller:
                          _paidController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal:
                            true,
                      ),
                      textInputAction:
                          TextInputAction.done,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Paid Amount",
                        prefixIcon:
                            Icon(
                          Icons.payments,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==================================================
                    // BALANCE DUE
                    // ==================================================

                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.red.shade50,
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                        border:
                            Border.all(
                          color:
                              Colors.red.shade100,
                        ),
                      ),
                      child:
                          Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            "Balance Due",
                            style:
                                TextStyle(
                              fontSize:
                                  18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            "৳${_balanceDue.toStringAsFixed(2)}",
                            style:
                                const TextStyle(
                              fontSize:
                                  22,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==================================================
                    // NOTE
                    // ==================================================

                    TextFormField(
                      controller:
                          _noteController,
                      maxLines:
                          2,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Note",
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==================================================
                    // SAVE
                    // ==================================================

                    SizedBox(
                      width:
                          double.infinity,
                      height:
                          55,
                      child:
                          ElevatedButton.icon(
                        icon:
                            _saving
                                ? const SizedBox(
                                    width:
                                        22,
                                    height:
                                        22,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.save,
                                  ),
                        label:
                            Text(
                          _saving
                              ? "Saving..."
                              : "Save Sale",
                          style:
                              const TextStyle(
                            fontSize:
                                18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        onPressed:
                            _saving
                                ? null
                                : _saveSale,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _summaryRow(
    String title,
    double amount, {
    bool bold = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child:
          Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [
          Text(
            title,
            style:
                TextStyle(
              fontSize:
                  bold ? 18 : 15,
              fontWeight:
                  bold
                      ? FontWeight.bold
                      : FontWeight.w500,
            ),
          ),
          Text(
            "৳${amount.toStringAsFixed(2)}",
            style:
                TextStyle(
              fontSize:
                  bold ? 20 : 16,
              fontWeight:
                  bold
                      ? FontWeight.bold
                      : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}