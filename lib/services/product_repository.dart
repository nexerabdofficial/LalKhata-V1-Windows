import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/product.dart';
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
  // IMPORTANT:
  //
  // Average Cost =
  // Total Purchase Amount
  // ---------------------
  // Total Purchase Qty
  //
  // Sale does NOT change Average Cost.
  //
  // Stock Value =
  // Current Stock × Average Cost
  // ============================================================

  Future<List<Product>> getProducts() async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.rawQuery(
      '''
      SELECT
        p.*,

        CASE
          WHEN COALESCE(
            (
              SELECT SUM(pi.qty)
              FROM purchase_items pi
              WHERE pi.product_id = p.id
            ),
            0
          ) > 0

          THEN
            (
              COALESCE(
                (
                  SELECT SUM(
                    pi.qty * pi.purchase_price
                  )
                  FROM purchase_items pi
                  WHERE pi.product_id = p.id
                ),
                0
              )
              /
              (
                SELECT SUM(pi.qty)
                FROM purchase_items pi
                WHERE pi.product_id = p.id
              )
            )

          ELSE 0
        END AS calculated_average_cost

      FROM products p
      ORDER BY p.id DESC
      ''',
    );

    final List<Product> products = [];

    for (final map in maps) {
      final mutableMap =
          Map<String, dynamic>.from(map);

      final stock =
          ((mutableMap['stock'] ?? 0) as num)
              .toInt();

      final averageCost =
          ((mutableMap['calculated_average_cost'] ?? 0) as num)
              .toDouble();

      // --------------------------------------------------------
      // CALCULATE CURRENT STOCK VALUE
      //
      // Current Stock × Average Cost
      // --------------------------------------------------------

      final stockValue =
          stock > 0
              ? stock * averageCost
              : 0.0;

      // --------------------------------------------------------
      // Replace stored stock_value with calculated value.
      //
      // This prevents sales from changing Average Cost.
      // --------------------------------------------------------

      mutableMap['stock_value'] =
          stockValue;

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
  // IMPORTANT:
  //
  // Uses:
  // Current Stock × Average Cost
  //
  // Sale does not change Average Cost.
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
  // GET AVERAGE COST
  //
  // Total Purchase Amount
  // ---------------------
  // Total Purchase Qty
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
  // ============================================================

  Future<double> getCurrentStockValue(
    int productId,
  ) async {
    final product =
        await getProductById(
      productId,
    );

    if (product == null ||
        product.stock <= 0) {
      return 0;
    }

    final averageCost =
        await getAverageCost(
      productId,
    );

    return product.stock *
        averageCost;
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
              ((row['purchase_price'] ?? 0) as num).toDouble(),
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
}