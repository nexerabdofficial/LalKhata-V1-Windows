import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/opening_stock_entry.dart';
import '../models/product_ledger.dart';

class ProductRepository {
  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  // ============================================================
  // INSERT PRODUCT
  // ============================================================

  Future<int> insertProduct(Product product) async {
    final Database db =
        await _databaseHelper.database;

    return await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm:
          ConflictAlgorithm.replace,
    );
  }

  // ============================================================
  // GET PRODUCTS
  //
  // IMPORTANT COSTING RULE
  //
  // products.stock_value is the CURRENT INVENTORY VALUE.
  //
  // Purchase:
  //   stock_value += purchase amount
  //
  // Sale:
  //   stock_value -= current inventory cost
  //
  // Production:
  //   raw material stock_value decreases
  //   finished product stock_value increases
  //
  // Therefore we MUST NOT recalculate stock_value here from
  // purchase history.
  //
  // Purchase Average Cost is still available separately through
  // getAverageCost().
  // ============================================================

  Future<List<Product>> getProducts() async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'products',
      orderBy: 'id DESC',
    );

    final List<Product> products = [];

    for (final map in maps) {
      final mutableMap =
          Map<String, dynamic>.from(map);

      // --------------------------------------------------------
      // CURRENT STOCK VALUE
      //
      // Use the stored inventory value directly.
      //
      // This is important for Production because a finished
      // product may have production value even when it has never
      // been purchased.
      // --------------------------------------------------------

      mutableMap['stock_value'] =
          ((mutableMap['stock_value'] ?? 0) as num)
              .toDouble();

      products.add(
        Product.fromMap(
          mutableMap,
        ),
      );
    }

    return products;
  }

  // ============================================================
  // GET SINGLE PRODUCT
  // ============================================================

  Future<Product?> getProductById(
    int productId,
  ) async {
    final products =
        await getProducts();

    try {
      return products.firstWhere(
        (product) =>
            product.id == productId,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // UPDATE PRODUCT
  // ============================================================

  Future<int> updateProduct(
    Product product,
  ) async {
    final Database db =
        await _databaseHelper.database;

    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  // ============================================================
  // DELETE PRODUCT
  // ============================================================

  Future<int> deleteProduct(
    int id,
  ) async {
    final Database db =
        await _databaseHelper.database;

    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // PRODUCT COUNT
  // ============================================================

  Future<int> getProductCount() async {
    final Database db =
        await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM products
      ''',
    );

    return Sqflite.firstIntValue(
          result,
        ) ??
        0;
  }

  // ============================================================
  // TOTAL STOCK VALUE
  //
  // Uses the CURRENT stored inventory value.
  //
  // Purchase / Sale / Production all maintain this value.
  // ============================================================

  Future<double> getTotalStockValue() async {
    final products =
        await getProducts();

    double total = 0;

    for (final product in products) {
      total += product.stockValue;
    }

    return total;
  }

  // ============================================================
  // GET PURCHASE AVERAGE COST
  //
  // IMPORTANT:
  //
  // This method remains PURCHASE-ONLY.
  //
  // Total Purchase Amount
  // ---------------------
  // Total Purchase Qty
  //
  // Production does NOT modify this calculation.
  // ============================================================

  Future<double> getAverageCost(
    int productId,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(
          SUM(
            qty * purchase_price
          ),
          0
        ) AS total_purchase_amount,

        COALESCE(
          SUM(qty),
          0
        ) AS total_purchase_qty

      FROM purchase_items

      WHERE product_id = ?
      ''',
      [productId],
    );

    final totalPurchaseAmount =
        ((result.first['total_purchase_amount'] ?? 0) as num)
            .toDouble();

    final totalPurchaseQty =
        ((result.first['total_purchase_qty'] ?? 0) as num)
            .toDouble();

    if (totalPurchaseQty <= 0) {
      return 0;
    }

    return totalPurchaseAmount /
        totalPurchaseQty;
  }

  // ============================================================
  // GET CURRENT STOCK VALUE
  //
  // IMPORTANT:
  //
  // This is the CURRENT INVENTORY VALUE, not historical
  // purchase-average value.
  //
  // Production can create stock that has no purchase history,
  // therefore this MUST use products.stock_value.
  // ============================================================

  Future<double> getCurrentStockValue(
    int productId,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final result = await db.query(
      'products',
      columns: [
        'stock',
        'stock_value',
      ],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (result.isEmpty) {
      return 0;
    }

    final stock =
        ((result.first['stock'] ?? 0) as num)
            .toInt();

    if (stock <= 0) {
      return 0;
    }

    return ((result.first['stock_value'] ?? 0) as num)
        .toDouble();
  }

  // ============================================================
  // GET CURRENT INVENTORY UNIT COST
  //
  // Current Stock Value
  // -------------------
  // Current Stock
  //
  // This is the costing boundary used by Production for raw
  // material consumption.
  // ============================================================

  Future<double> getCurrentInventoryUnitCost(
    int productId,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final result = await db.query(
      'products',
      columns: [
        'stock',
        'stock_value',
      ],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (result.isEmpty) {
      return 0;
    }

    final stock =
        ((result.first['stock'] ?? 0) as num)
            .toDouble();

    final stockValue =
        ((result.first['stock_value'] ?? 0) as num)
            .toDouble();

    if (stock <= 0) {
      return 0;
    }

    return stockValue / stock;
  }

  // ============================================================
  // PRODUCT LEDGER
  //
  // Purchase = IN
  // Sale     = OUT
  //
  // Balance = Running Stock
  // ============================================================

  Future<List<ProductLedger>>
      getProductLedger(
    int productId,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final List<ProductLedger> ledger =
        [];

    // ==========================================================
    // OPENING STOCK = STOCK IN
    // ==========================================================

    final openingStocks = await db.rawQuery(
      '''
      SELECT
        opening_date AS date,
        'Opening Stock' AS reference,
        'Opening Stock' AS particular,
        quantity AS stock_in,
        0 AS stock_out,
        unit_cost AS purchase_price

      FROM opening_stock_entries

      WHERE product_id = ?
      ''',
      [productId],
    );

    for (final row in openingStocks) {
      ledger.add(
        ProductLedger(
          date: row['date']?.toString() ?? '',
          reference: row['reference']?.toString() ?? '',
          particular: 'Opening Stock',
          stockIn: ((row['stock_in'] ?? 0) as num).toInt(),
          stockOut: 0,
          balance: 0,
          purchasePrice:
              ((row['purchase_price'] ?? 0) as num).toDouble(),
        ),
      );
    }

    // ==========================================================
    // PURCHASES = STOCK IN
    // ==========================================================

    final purchases =
        await db.rawQuery(
      '''
      SELECT
        p.purchase_date AS date,
        p.invoice_no AS reference,
        'Purchase' AS particular,
        pi.qty AS stock_in,
        0 AS stock_out,
        pi.purchase_price AS purchase_price

      FROM purchase_items pi

      INNER JOIN purchases p
        ON p.id = pi.purchase_id

      WHERE pi.product_id = ?
      ''',
      [productId],
    );

    for (final row in purchases) {
      ledger.add(
        ProductLedger(
          date:
              row['date']?.toString() ??
                  '',
          reference:
              row['reference']
                      ?.toString() ??
                  '',
          particular: 'Purchase',
          stockIn:
              ((row['stock_in'] ??
                          0) as num)
                  .toInt(),
          stockOut: 0,
          balance: 0,
                    purchasePrice:
              ((row['purchase_price'] ?? 0) as num)
                  .toDouble(),
        ),
      );
    }

    // ==========================================================
    // SALES = STOCK OUT
    // ==========================================================

    final sales =
        await db.rawQuery(
      '''
      SELECT
        s.sale_date AS date,
        s.invoice_no AS reference,
        'Sale' AS particular,
        0 AS stock_in,
        si.qty AS stock_out,
        si.purchase_price AS purchase_price,
        si.selling_price AS selling_price

      FROM sale_items si

      INNER JOIN sales s
        ON s.id = si.sale_id

      WHERE si.product_id = ?
      ''',
      [productId],
    );

    for (final row in sales) {
      ledger.add(
        ProductLedger(
          date:
              row['date']?.toString() ??
                  '',
          reference:
              row['reference']
                      ?.toString() ??
                  '',
          particular: 'Sale',
          stockIn: 0,
          stockOut:
              ((row['stock_out'] ??
                          0) as num)
                  .toInt(),
          balance: 0,
                    purchasePrice:
              ((row['purchase_price'] ?? 0) as num)
                  .toDouble(),
          sellingPrice:
              ((row['selling_price'] ?? 0) as num)
                  .toDouble(),
        ),
      );
    }

    // ==========================================================
    // SORT BY DATE
    // ==========================================================

    ledger.sort(
      (a, b) {
        final dateA =
            DateTime.tryParse(a.date);

        final dateB =
            DateTime.tryParse(b.date);

        if (dateA == null &&
            dateB == null) {
          return 0;
        }

        if (dateA == null) {
          return 1;
        }

        if (dateB == null) {
          return -1;
        }

        return dateA.compareTo(dateB);
      },
    );

    // ==========================================================
    // RUNNING STOCK BALANCE
    // ==========================================================

    int runningBalance = 0;

    final result =
        <ProductLedger>[];

    for (final item in ledger) {
      runningBalance +=
          item.stockIn;

      runningBalance -=
          item.stockOut;

      result.add(
        ProductLedger(
          date: item.date,
          reference:
              item.reference,
          particular:
              item.particular,
          stockIn:
              item.stockIn,
          stockOut:
              item.stockOut,
          balance:
              runningBalance,
          purchasePrice:
              item.purchasePrice,
          sellingPrice:
              item.sellingPrice,
        ),
      );
    }

    return result;
  }

  // ============================================================
  // OPENING STOCK
  // ============================================================

  Future<void> addOpeningStock({
    required int productId,
    required int quantity,
    required double unitCost,
    required String openingDate,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Opening stock quantity must be greater than zero.');
    }

    if (unitCost < 0) {
      throw ArgumentError('Opening stock rate cannot be negative.');
    }

    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      final products = await txn.query(
        'products',
        columns: ['stock', 'stock_value'],
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );

      if (products.isEmpty) {
        throw StateError('Product not found.');
      }

      final product = products.first;

      final currentStock = (product['stock'] as num).toInt();
      final currentStockValue =
          (product['stock_value'] as num?)?.toDouble() ?? 0.0;

      final totalValue = quantity * unitCost;

      final now = DateTime.now().toIso8601String();

      await txn.insert(
        'opening_stock_entries',
        OpeningStockEntry(
          productId: productId,
          quantity: quantity,
          unitCost: unitCost,
          totalValue: totalValue,
          openingDate: openingDate,
          createdAt: now,
        ).toMap(),
      );

      await txn.update(
        'products',
        {
          'stock': currentStock + quantity,
          'stock_value': currentStockValue + totalValue,
        },
        where: 'id = ?',
        whereArgs: [productId],
      );
    });
  }

  Future<List<OpeningStockEntry>> getOpeningStockEntries(
    int productId,
  ) async {
    final db = await _databaseHelper.database;

    final rows = await db.query(
      'opening_stock_entries',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'opening_date ASC, id ASC',
    );

    return rows.map(OpeningStockEntry.fromMap).toList();
  }

}
