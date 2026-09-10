import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/purchase.dart';
import '../models/purchase/purchase_history.dart';

class PurchaseRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> insertPurchase(Purchase purchase) async {
    final Database db = await _databaseHelper.database;

    return await db.insert(
      'purchases',
      purchase.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PurchaseHistory>> getPurchases() async {
  final Database db = await _databaseHelper.database;

  final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT
      purchases.*,
      suppliers.name AS supplier_name
    FROM purchases
    INNER JOIN suppliers
      ON purchases.supplier_id = suppliers.id
    ORDER BY purchases.id DESC
  ''');

  return maps.map((map) {
    return PurchaseHistory(
      purchase: Purchase.fromMap(map),
      supplierName: map['supplier_name'] as String,
    );
  }).toList();
}
Future<Purchase?> getPurchaseById(int id) async {
  final Database db = await _databaseHelper.database;

  final result = await db.query(
    'purchases',
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );

  if (result.isEmpty) {
    return null;
  }

  return Purchase.fromMap(result.first);
}
  Future<int> getPurchaseCount() async {
    final Database db = await _databaseHelper.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM purchases',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }
  Future<double> getTotalPurchases() async {
  final db = await _databaseHelper.database;

  final result = await db.rawQuery('''
    SELECT SUM(grand_total) AS total
    FROM purchases
  ''');

  final value = result.first['total'];

  if (value == null) {
    return 0;
  }

  return (value as num).toDouble();
}
}