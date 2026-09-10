import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

class SaleService {
  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  // ============================================================
  // SAVE SALE
  // ============================================================

  Future<void> saveSale(
    Sale sale,
    List<SaleItem> items,
  ) async {
    final Database db =
        await _databaseHelper.database;

    await db.transaction((txn) async {
      // --------------------------------------------------------
      // 1. INSERT SALE
      // --------------------------------------------------------

      final saleId = await txn.insert(
        'sales',
        sale.toMap(),
      );

      // --------------------------------------------------------
      // 2. INSERT SALE ITEMS
      // --------------------------------------------------------

      for (final item in items) {
        await txn.insert(
          'sale_items',
          {
            'sale_id': saleId,
            'product_id': item.productId,
            'product_name': item.productName,
            'qty': item.qty,
            'purchase_price': item.purchasePrice,
            'selling_price': item.sellingPrice,
            'subtotal': item.subtotal,
          },
        );
      }

      // --------------------------------------------------------
      // 3. REDUCE STOCK + STOCK VALUE
      //
      // Stock value is reduced according to the purchase cost
      // of the sold items.
      // --------------------------------------------------------

      for (final item in items) {
        final stockCost =
            item.purchasePrice * item.qty;

        await txn.rawUpdate(
          '''
          UPDATE products
          SET
            stock = stock - ?,
            stock_value = stock_value - ?
          WHERE id = ?
          ''',
          [
            item.qty,
            stockCost,
            item.productId,
          ],
        );

        final debugProduct = await txn.query(
          'products',
          columns: [
            'id',
            'name',
            'stock',
            'stock_value',
            'purchase_price',
          ],
          where: 'id = ?',
          whereArgs: [item.productId],
        );
      }

      // --------------------------------------------------------
      // 4. INCREASE CUSTOMER DUE
      // --------------------------------------------------------
      //
      // Only the actual due amount increases customer balance.
      //

      if (sale.due != 0) {
        await txn.rawUpdate(
          '''
          UPDATE customers
          SET balance = balance + ?
          WHERE id = ?
          ''',
          [
            sale.due,
            sale.customerId,
          ],
        );
      }
    });
  }
}