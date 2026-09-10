import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/sale_item.dart';

class SaleItemRepository {
  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  Future<int> insertSaleItem(
    SaleItem item,
  ) async {
    final Database db =
        await _databaseHelper.database;

    return await db.insert(
      'sale_items',
      item.toMap(),
      conflictAlgorithm:
          ConflictAlgorithm.replace,
    );
  }

  Future<List<SaleItem>> getItemsBySale(
    int saleId,
  ) async {
    final Database db =
        await _databaseHelper.database;

    final maps = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );

    return maps
        .map((e) => SaleItem.fromMap(e))
        .toList();
  }
}