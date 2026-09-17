import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/production_bom.dart';
import '../models/production_bom_item.dart';

class ProductionBomRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // ============================================================
  // CREATE BOM
  // ============================================================

  Future<int> createBom(
    ProductionBom bom,
    List<ProductionBomItem> items,
  ) async {
    if (items.isEmpty) {
      throw Exception('A BOM must contain at least one material.');
    }

    if (bom.name.trim().isEmpty) {
      throw Exception('BOM name cannot be empty.');
    }

    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('Material quantity must be greater than 0.');
      }

      if (item.materialProductId == bom.productId) {
        throw Exception('Finished product cannot be used as its own material.');
      }
    }

    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final bomId = await txn.insert(
        'production_boms',
        bom.toMap()..remove('id'),
      );

      for (final item in items) {
        await txn.insert(
          'production_bom_items',
          item.toMap()
            ..remove('id')
            ..['bom_id'] = bomId,
        );
      }

      return bomId;
    });
  }

  // ============================================================
  // UPDATE BOM
  // ============================================================

  Future<void> updateBom(
    ProductionBom bom,
    List<ProductionBomItem> items,
  ) async {
    if (bom.id == null) {
      throw Exception('BOM ID is required for update.');
    }

    if (items.isEmpty) {
      throw Exception('A BOM must contain at least one material.');
    }

    if (bom.name.trim().isEmpty) {
      throw Exception('BOM name cannot be empty.');
    }

    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('Material quantity must be greater than 0.');
      }

      if (item.materialProductId == bom.productId) {
        throw Exception('Finished product cannot be used as its own material.');
      }
    }

    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      await txn.update(
        'production_boms',
        {
          'product_id': bom.productId,
          'name': bom.name.trim(),
          'note': bom.note,
          'is_active': bom.isActive ? 1 : 0,
          'updated_at': bom.updatedAt,
        },
        where: 'id = ?',
        whereArgs: [bom.id],
      );

      await txn.delete(
        'production_bom_items',
        where: 'bom_id = ?',
        whereArgs: [bom.id],
      );

      for (final item in items) {
        await txn.insert('production_bom_items', {
          'bom_id': bom.id,
          'material_product_id': item.materialProductId,
          'quantity': item.quantity,
          'note': item.note,
        });
      }
    });
  }

  // ============================================================
  // DELETE BOM
  // ============================================================

  Future<void> deleteBom(int bomId) async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      await txn.delete(
        'production_bom_items',
        where: 'bom_id = ?',
        whereArgs: [bomId],
      );

      await txn.delete('production_boms', where: 'id = ?', whereArgs: [bomId]);
    });
  }

  // ============================================================
  // GET BOM BY ID
  // ============================================================

  Future<ProductionBom?> getBomById(int bomId) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'production_boms',
      where: 'id = ?',
      whereArgs: [bomId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return ProductionBom.fromMap(result.first);
  }

  // ============================================================
  // GET BOM ITEMS
  // ============================================================

  Future<List<ProductionBomItem>> getBomItems(int bomId) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'production_bom_items',
      where: 'bom_id = ?',
      whereArgs: [bomId],
      orderBy: 'id ASC',
    );

    return result.map((map) => ProductionBomItem.fromMap(map)).toList();
  }

  // ============================================================
  // GET BOM + ITEMS
  // ============================================================

  Future<Map<String, dynamic>?> getBomWithItems(int bomId) async {
    final bom = await getBomById(bomId);

    if (bom == null) {
      return null;
    }

    final items = await getBomItems(bomId);

    return {'bom': bom, 'items': items};
  }

  // ============================================================
  // GET ALL BOMs
  // ============================================================

  Future<List<ProductionBom>> getAllBoms({bool activeOnly = false}) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'production_boms',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'id DESC',
    );

    return result.map((map) => ProductionBom.fromMap(map)).toList();
  }

  // ============================================================
  // GET BOMs FOR PRODUCT
  // ============================================================

  Future<List<ProductionBom>> getBomsForProduct(
    int productId, {
    bool activeOnly = false,
  }) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'production_boms',
      where: activeOnly ? 'product_id = ? AND is_active = ?' : 'product_id = ?',
      whereArgs: activeOnly ? [productId, 1] : [productId],
      orderBy: 'id DESC',
    );

    return result.map((map) => ProductionBom.fromMap(map)).toList();
  }

  // ============================================================
  // ACTIVATE / DEACTIVATE BOM
  // ============================================================

  Future<void> setBomActive(int bomId, bool active) async {
    final db = await _databaseHelper.database;

    await db.update(
      'production_boms',
      {
        'is_active': active ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [bomId],
    );
  }
}
