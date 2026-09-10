import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/purchase_item.dart';
import '../models/purchase/purchase_item_history.dart';

class PurchaseItemRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> insertPurchaseItem(PurchaseItem item) async {
    final Database db = await _databaseHelper.database;

    return await db.insert(
      'purchase_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PurchaseItem>> getItemsByPurchase(int purchaseId) async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );

    return maps.map((e) => PurchaseItem.fromMap(e)).toList();
  }
  Future<List<PurchaseItemHistory>> getItemHistoryByPurchase(
  int purchaseId,
) async {
  final Database db = await _databaseHelper.database;

  final result = await db.rawQuery('''
    SELECT
      purchase_items.*,
      products.name AS product_name
    FROM purchase_items
    INNER JOIN products
      ON purchase_items.product_id = products.id
    WHERE purchase_items.purchase_id = ?
    ORDER BY purchase_items.id ASC
  ''', [purchaseId]);

  return result.map((row) {
    return PurchaseItemHistory(
      item: PurchaseItem.fromMap(row),
      productName: row['product_name'] as String,
    );
  }).toList();
}
}