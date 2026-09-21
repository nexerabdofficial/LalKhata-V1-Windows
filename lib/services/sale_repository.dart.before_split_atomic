import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

class SaleRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> insertSale(Sale sale) async {
    final db = await _databaseHelper.database;

    return await db.insert(
      'sales',
      sale.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertSaleItem(SaleItem item) async {
    final db = await _databaseHelper.database;

    return await db.insert(
      'sale_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> saveSale({
    required Sale sale,
    required List<SaleItem> items,
  }) async {
    int savedSaleId = 0;

    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      final result = await txn.rawQuery('''
        SELECT COUNT(*) AS total
        FROM sales
        ''');

      final count = result.first['total'] as int;

      final invoiceNo = "INV-${(count + 1).toString().padLeft(6, '0')}";

      savedSaleId = await txn.insert('sales', {
        ...sale.toMap(),
        'invoice_no': invoiceNo,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (final item in items) {
        // ----------------------------------------------------------
        // GET CURRENT INVENTORY VALUE
        // ----------------------------------------------------------

        final product = await txn.query(
          'products',
          columns: ['stock', 'stock_value'],
          where: 'id = ?',
          whereArgs: [item.productId],
        );

        if (product.isEmpty) {
          throw Exception('Product not found: ${item.productId}');
        }

        final currentStock = (product.first['stock'] as num).toInt();

        final currentStockValue = (product.first['stock_value'] as num)
            .toDouble();

        // ----------------------------------------------------------
        // CHECK STOCK
        // ----------------------------------------------------------

        if (item.qty > currentStock) {
          throw Exception('Insufficient stock for ${item.productName}');
        }

        // ----------------------------------------------------------
        // CALCULATE WEIGHTED AVERAGE COST
        // ----------------------------------------------------------

        final averageCost = currentStock > 0
            ? currentStockValue / currentStock
            : 0.0;

        // ----------------------------------------------------------
        // SAVE SALE ITEM
        // ----------------------------------------------------------

        await txn.insert('sale_items', {
          'sale_id': savedSaleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'qty': item.qty,
          'purchase_price': averageCost,
          'selling_price': item.sellingPrice,
          'subtotal': item.subtotal,
        });

        // ----------------------------------------------------------
        // REDUCE STOCK + STOCK VALUE
        // ----------------------------------------------------------

        await txn.rawUpdate(
          '''
    UPDATE products
    SET
      stock = stock - ?,
      stock_value = stock_value - (? * ?)
    WHERE id = ?
    ''',
          [item.qty, item.qty, averageCost, item.productId],
        );
      }

      if (sale.due > 0) {
        await txn.rawUpdate(
          '''
          UPDATE customers
          SET balance = balance + ?
          WHERE id = ?
          ''',
          [sale.due, sale.customerId],
        );
      }
    });

    return savedSaleId;
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await _databaseHelper.database;

    return await db.rawQuery('''
      SELECT
        sales.*,
        customers.name AS customer_name
      FROM sales
      LEFT JOIN customers
        ON customers.id = sales.customer_id
      ORDER BY sales.id DESC
      ''');
  }

  Future<Map<String, dynamic>?> getSaleDetails(int saleId) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        sales.*,
        customers.name AS customer_name
      FROM sales
      LEFT JOIN customers
        ON customers.id = sales.customer_id
      WHERE sales.id = ?
      ''',
      [saleId],
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
    SELECT
      sale_items.*,
      products.name AS product_name
    FROM sale_items
    LEFT JOIN products
      ON products.id = sale_items.product_id
    WHERE sale_items.sale_id = ?
    ORDER BY sale_items.id
    ''',
      [saleId],
    );
    return result.map((e) => SaleItem.fromMap(e)).toList();
  }

  Future<Sale> getSale(int saleId) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );

    return Sale.fromMap(result.first);
  }

  Future<Map<String, dynamic>?> getSaleById(int id) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
    SELECT
      sales.*,
      customers.name AS customer_name,
      customers.phone AS customer_phone,
      customers.address AS customer_address,

      (
        COALESCE(
          (
            SELECT opening_balance
            FROM customers
            WHERE id = sales.customer_id
          ),
          0
        )
        +
        COALESCE(
          (
            SELECT SUM(grand_total)
            FROM sales s
            WHERE s.customer_id = sales.customer_id
              AND (
                s.sale_date < sales.sale_date
                OR (
                  s.sale_date = sales.sale_date
                  AND s.id < sales.id
                )
              )
          ),
          0
        )
        -
        COALESCE(
          (
            SELECT SUM(amount)
            FROM customer_payments cp
            WHERE cp.customer_id = sales.customer_id
              AND cp.created_at < sales.sale_date
          ),
          0
        )
      ) AS previous_due

    FROM sales
    LEFT JOIN customers
      ON customers.id = sales.customer_id

    WHERE sales.id = ?
    LIMIT 1
    ''',
      [id],
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  Future<double> getTotalSales() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT SUM(grand_total) AS total
      FROM sales
      ''');

    final value = result.first['total'];

    if (value == null) {
      return 0;
    }

    return (value as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getSalesByDateRange({
    required String fromDate,
    required String toDate,
  }) async {
    final db = await _databaseHelper.database;

    return await db.rawQuery(
      '''
      SELECT
        sales.*,
        customers.name AS customer_name
      FROM sales
      LEFT JOIN customers
        ON customers.id = sales.customer_id
      WHERE DATE(sales.sale_date)
            BETWEEN DATE(?) AND DATE(?)
      ORDER BY sales.id DESC
      ''',
      [fromDate, toDate],
    );
  }
}
