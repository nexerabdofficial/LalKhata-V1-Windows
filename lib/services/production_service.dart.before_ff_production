import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/production.dart';
import '../models/production_bom_item.dart';
import '../models/production_cost.dart';
import '../repositories/production_bom_repository.dart';

class ProductionService {
  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  final ProductionBomRepository _bomRepository =
      ProductionBomRepository();

  // ============================================================
  // CREATE PRODUCTION
  //
  // COSTING FLOW
  //
  // Raw Material Purchase
  //        ↓
  // Current Inventory Unit Cost
  //        ↓
  // BOM
  //        ↓
  // Production
  //        ↓
  // Raw Material Stock -
  // Raw Material Value -
  //        ↓
  // Finished Product Stock +
  // Finished Product Value +
  //
  // EVERYTHING happens inside ONE transaction.
  // ============================================================

  Future<Production> createProduction({
    required int productId,
    required int bomId,
    required double quantity,
    required String productionDate,
    List<ProductionCost> factoryCosts = const [],
    String? productionNo,
    String? note,
  }) async {
    // ----------------------------------------------------------
    // BASIC VALIDATION
    // ----------------------------------------------------------

    if (quantity <= 0) {
      throw Exception(
        'Production quantity must be greater than 0.',
      );
    }

    if (!_isWholeNumber(quantity)) {
      throw Exception(
        'Production quantity must be a whole number.',
      );
    }

    // ----------------------------------------------------------
    // LOAD BOM
    // ----------------------------------------------------------

    final bomData =
        await _bomRepository.getBomWithItems(
      bomId,
    );

    if (bomData == null) {
      throw Exception(
        'Production BOM not found.',
      );
    }

    final bom =
        bomData['bom'];

    final bomItems =
        bomData['items']
            as List<ProductionBomItem>;

    // ----------------------------------------------------------
    // MAKE SURE BOM BELONGS TO PRODUCT
    // ----------------------------------------------------------

    if (bom.productId != productId) {
      throw Exception(
        'Selected BOM does not belong to this product.',
      );
    }

    if (!bom.isActive) {
      throw Exception(
        'Selected BOM is inactive.',
      );
    }

    if (bomItems.isEmpty) {
      throw Exception(
        'Production BOM has no materials.',
      );
    }

    // ----------------------------------------------------------
    // VALIDATE FACTORY COSTS
    // ----------------------------------------------------------

    for (final cost in factoryCosts) {
      if (cost.costPerUnit < 0) {
        throw Exception(
          'Factory cost cannot be negative.',
        );
      }
    }

    final db =
        await _databaseHelper.database;

    return await db.transaction<Production>(
      (txn) async {
        // ======================================================
        // 1. LOAD FINISHED PRODUCT
        // ======================================================

        final finishedProductResult =
            await txn.query(
          'products',
          columns: [
            'id',
            'name',
            'stock',
            'stock_value',
          ],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );

        if (finishedProductResult.isEmpty) {
          throw Exception(
            'Finished product not found.',
          );
        }

        final finishedProduct =
            finishedProductResult.first;

        final finishedProductName =
            finishedProduct['name']
                    ?.toString() ??
                '';

        final existingFinishedStock =
            ((finishedProduct['stock'] ?? 0) as num)
                .toInt();

        final existingFinishedStockValue =
            ((finishedProduct['stock_value'] ?? 0)
                    as num)
                .toDouble();

        // ======================================================
        // 2. CALCULATE MATERIAL REQUIREMENTS
        // ======================================================

        double totalMaterialCost = 0;

        final materialSnapshots =
            <_MaterialCostSnapshot>[];

        final usedMaterialIds =
            <int>{};

        for (final bomItem in bomItems) {
          final materialProductId =
              bomItem.materialProductId;

          // ----------------------------------------------------
          // PREVENT DUPLICATE MATERIAL ROWS
          // ----------------------------------------------------

          if (usedMaterialIds.contains(
            materialProductId,
          )) {
            throw Exception(
              'Duplicate material found in BOM.',
            );
          }

          usedMaterialIds.add(
            materialProductId,
          );

          // ----------------------------------------------------
          // PREVENT FINISHED PRODUCT FROM BEING ITS OWN MATERIAL
          // ----------------------------------------------------

          if (materialProductId ==
              productId) {
            throw Exception(
              'Finished product cannot be used as its own material.',
            );
          }

          final bomQuantity =
              bomItem.quantity;

          if (bomQuantity <= 0) {
            throw Exception(
              'BOM material quantity must be greater than 0.',
            );
          }

          final requiredQuantity =
              bomQuantity * quantity;

          if (!_isWholeNumber(
            requiredQuantity,
          )) {
            throw Exception(
              'Material "$materialProductId" requires a fractional '
              'stock quantity. Current inventory stock supports '
              'whole numbers only.',
            );
          }

          // ----------------------------------------------------
          // LOAD MATERIAL
          // ----------------------------------------------------

          final materialResult =
              await txn.query(
            'products',
            columns: [
              'id',
              'name',
              'stock',
              'stock_value',
            ],
            where: 'id = ?',
            whereArgs: [
              materialProductId,
            ],
            limit: 1,
          );

          if (materialResult.isEmpty) {
            throw Exception(
              'Material product not found: '
              '$materialProductId',
            );
          }

          final material =
              materialResult.first;

          final materialName =
              material['name']
                      ?.toString() ??
                  '';

          final currentStock =
              ((material['stock'] ?? 0) as num)
                  .toInt();

          final currentStockValue =
              ((material['stock_value'] ?? 0)
                      as num)
                  .toDouble();

          final requiredStock =
              requiredQuantity.toInt();

          // ----------------------------------------------------
          // STOCK CHECK
          // ----------------------------------------------------

          if (currentStock <
              requiredStock) {
            throw Exception(
              'Insufficient stock for "$materialName". '
              'Required: $requiredStock, '
              'Available: $currentStock.',
            );
          }

          // ----------------------------------------------------
          // CURRENT INVENTORY UNIT COST
          //
          // Current Stock Value
          // -------------------
          // Current Stock
          //
          // This uses the same current inventory value boundary
          // that SaleRepository uses.
          // ----------------------------------------------------

          if (currentStock <= 0) {
            throw Exception(
              'No stock available for "$materialName".',
            );
          }

          if (currentStockValue < 0) {
            throw Exception(
              'Invalid stock value for "$materialName".',
            );
          }

          final currentUnitCost =
              currentStockValue /
                  currentStock;

          // ----------------------------------------------------
          // MATERIAL TOTAL COST
          // ----------------------------------------------------

          final materialTotalCost =
              requiredQuantity *
                  currentUnitCost;

          totalMaterialCost +=
              materialTotalCost;

          // ----------------------------------------------------
          // SAVE HISTORICAL SNAPSHOT
          // ----------------------------------------------------

          materialSnapshots.add(
            _MaterialCostSnapshot(
              productId:
                  materialProductId,
              productName:
                  materialName,
              quantity:
                  requiredQuantity,
              unitCost:
                  currentUnitCost,
              totalCost:
                  materialTotalCost,
            ),
          );
        }

        // ======================================================
        // 3. FACTORY / OTHER COST
        // ======================================================

        double totalFactoryCost = 0;

        final factoryCostSnapshots =
            <ProductionCost>[];

        for (final cost in factoryCosts) {
          if (cost.costPerUnit <= 0) {
            continue;
          }

          final totalCost =
              cost.costPerUnit *
                  quantity;

          totalFactoryCost +=
              totalCost;

          factoryCostSnapshots.add(
            ProductionCost(
              productionId: 0,
              costType:
                  cost.costType,
              costPerUnit:
                  cost.costPerUnit,
              totalCost:
                  totalCost,
              note:
                  cost.note,
            ),
          );
        }

        // ======================================================
        // 4. TOTAL PRODUCTION COST
        // ======================================================

        final totalProductionCost =
            totalMaterialCost +
                totalFactoryCost;

        final unitCost =
            totalProductionCost /
                quantity;

        // ======================================================
        // 5. INSERT PRODUCTION
        // ======================================================

        final createdAt =
            DateTime.now()
                .toIso8601String();

        final productionId =
            await txn.insert(
          'productions',
          {
            'product_id':
                productId,
            'bom_id':
                bomId,
            'production_no':
                productionNo,
            'production_date':
                productionDate,
            'quantity':
                quantity,
            'total_material_cost':
                totalMaterialCost,
            'other_cost':
                totalFactoryCost,
            'total_production_cost':
                totalProductionCost,
            'unit_cost':
                unitCost,
            'note':
                note,
            'created_at':
                createdAt,
          },
        );

        // ======================================================
        // 6. INSERT MATERIAL COST SNAPSHOTS
        // ======================================================

        for (final snapshot
            in materialSnapshots) {
          await txn.insert(
            'production_items',
            {
              'production_id':
                  productionId,
              'material_product_id':
                  snapshot.productId,
              'material_name':
                  snapshot.productName,
              'quantity':
                  snapshot.quantity,
              'unit_cost':
                  snapshot.unitCost,
              'total_cost':
                  snapshot.totalCost,
            },
          );
        }

        // ======================================================
        // 7. INSERT FACTORY COST SNAPSHOTS
        // ======================================================

        for (final cost
            in factoryCostSnapshots) {
          await txn.insert(
            'production_costs',
            {
              'production_id':
                  productionId,
              'cost_type':
                  cost.costType,
              'cost_per_unit':
                  cost.costPerUnit,
              'total_cost':
                  cost.totalCost,
              'note':
                  cost.note,
            },
          );
        }

        // ======================================================
        // 8. DEDUCT RAW MATERIAL STOCK + VALUE
        //
        // IMPORTANT:
        //
        // Raw material value is reduced using the EXACT unit
        // cost snapshot captured for this production.
        //
        // Average cost itself is NOT changed.
        // ======================================================

        for (final snapshot
            in materialSnapshots) {
          final materialQty =
              snapshot.quantity.toInt();

          final materialCost =
              snapshot.totalCost;

          await txn.rawUpdate(
            '''
            UPDATE products
            SET
              stock = stock - ?,
              stock_value =
                CASE
                  WHEN stock_value - ? < 0
                  THEN 0
                  ELSE stock_value - ?
                END
            WHERE id = ?
            ''',
            [
              materialQty,
              materialCost,
              materialCost,
              snapshot.productId,
            ],
          );
        }

        // ======================================================
        // 9. INCREASE FINISHED PRODUCT STOCK + VALUE
        //
        // Existing inventory value
        //            +
        // New production cost
        //
        // This creates the correct weighted current inventory
        // cost for the finished product.
        // ======================================================

        final newFinishedStock =
            existingFinishedStock +
                quantity.toInt();

        final newFinishedStockValue =
            existingFinishedStockValue +
                totalProductionCost;

        await txn.rawUpdate(
          '''
          UPDATE products
          SET
            stock = ?,
            stock_value = ?
          WHERE id = ?
          ''',
          [
            newFinishedStock,
            newFinishedStockValue,
            productId,
          ],
        );

        // ======================================================
        // 10. RETURN PRODUCTION
        // ======================================================

        return Production(
          id: productionId,
          productId:
              productId,
          bomId:
              bomId,
          productionNo:
              productionNo,
          productionDate:
              productionDate,
          quantity:
              quantity,
          totalMaterialCost:
              totalMaterialCost,
          otherCost:
              totalFactoryCost,
          totalProductionCost:
              totalProductionCost,
          unitCost:
              unitCost,
          note:
              note,
          createdAt:
              createdAt,
        );
      },
    );
  }

  // ============================================================
  // GET PRODUCTION BY ID
  // ============================================================

  Future<Production?> getProductionById(
    int productionId,
  ) async {
    final db =
        await _databaseHelper.database;

    final result =
        await db.query(
      'productions',
      where: 'id = ?',
      whereArgs: [
        productionId,
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Production.fromMap(
      result.first,
    );
  }

  // ============================================================
  // GET PRODUCTION ITEMS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getProductionItems(
    int productionId,
  ) async {
    final db =
        await _databaseHelper.database;

    return await db.query(
      'production_items',
      where: 'production_id = ?',
      whereArgs: [
        productionId,
      ],
      orderBy: 'id ASC',
    );
  }

  // ============================================================
  // GET FACTORY COSTS
  // ============================================================

  Future<List<ProductionCost>>
      getProductionCosts(
    int productionId,
  ) async {
    final db =
        await _databaseHelper.database;

    final result =
        await db.query(
      'production_costs',
      where: 'production_id = ?',
      whereArgs: [
        productionId,
      ],
      orderBy: 'id ASC',
    );

    return result
        .map(
          (map) =>
              ProductionCost.fromMap(
            map,
          ),
        )
        .toList();
  }

  // ============================================================
  // GET ALL PRODUCTIONS
  // ============================================================

  Future<List<Production>>
      getProductions() async {
    final db =
        await _databaseHelper.database;

    final result =
        await db.query(
      'productions',
      orderBy:
          'production_date DESC, id DESC',
    );

    return result
        .map(
          (map) =>
              Production.fromMap(map),
        )
        .toList();
  }

  // ============================================================
  // GET PRODUCT PRODUCTION HISTORY
  // ============================================================

  Future<List<Production>>
      getProductionsForProduct(
    int productId,
  ) async {
    final db =
        await _databaseHelper.database;

    final result =
        await db.query(
      'productions',
      where: 'product_id = ?',
      whereArgs: [
        productId,
      ],
      orderBy:
          'production_date DESC, id DESC',
    );

    return result
        .map(
          (map) =>
              Production.fromMap(map),
        )
        .toList();
  }

  // ============================================================
  // PRODUCTION AVERAGE COST
  //
  // Historical production average:
  //
  // SUM(production quantity × unit cost)
  // ------------------------------------
  // SUM(production quantity)
  //
  // Purchase Average Cost is NOT involved here.
  //
  // This method is for production history/reporting.
  // It is NOT used for current inventory costing.
  // ============================================================

  Future<double> getProductionAverageCost(
    int productId,
  ) async {
    final db =
        await _databaseHelper.database;

    final result =
        await db.rawQuery(
      '''
      SELECT
        COALESCE(
          SUM(
            quantity * unit_cost
          ),
          0
        ) AS total_cost,

        COALESCE(
          SUM(quantity),
          0
        ) AS total_quantity

      FROM productions

      WHERE product_id = ?
      ''',
      [productId],
    );

final totalCost =
    ((result.first['total_cost'] ?? 0) as num)
        .toDouble();

final totalQuantity =
    ((result.first['total_quantity'] ?? 0) as num)
        .toDouble();

    if (totalQuantity <= 0) {
      return 0;
    }

    return totalCost /
        totalQuantity;
  }

  // ============================================================
  // WHOLE NUMBER CHECK
  // ============================================================

  bool _isWholeNumber(
    double value,
  ) {
    return value ==
        value.roundToDouble();
  }
}

// ============================================================
// INTERNAL MATERIAL COST SNAPSHOT
// ============================================================

class _MaterialCostSnapshot {
  final int productId;
  final String productName;
  final double quantity;
  final double unitCost;
  final double totalCost;

  _MaterialCostSnapshot({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
  });
}