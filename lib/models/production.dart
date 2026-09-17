class Production {
  final int? id;
  final int productId;
  final int? bomId;
  final String? productionNo;
  final String productionDate;
  final double quantity;
  final double totalMaterialCost;
  final double otherCost;
  final double totalProductionCost;
  final double unitCost;
  final String? note;
  final String createdAt;

  Production({
    this.id,
    required this.productId,
    this.bomId,
    this.productionNo,
    required this.productionDate,
    required this.quantity,
    this.totalMaterialCost = 0,
    this.otherCost = 0,
    this.totalProductionCost = 0,
    this.unitCost = 0,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'bom_id': bomId,
      'production_no': productionNo,
      'production_date': productionDate,
      'quantity': quantity,
      'total_material_cost': totalMaterialCost,
      'other_cost': otherCost,
      'total_production_cost': totalProductionCost,
      'unit_cost': unitCost,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory Production.fromMap(Map<String, dynamic> map) {
    return Production(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      bomId: map['bom_id'] as int?,
      productionNo: map['production_no'] as String?,
      productionDate: map['production_date'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      totalMaterialCost: ((map['total_material_cost'] ?? 0) as num).toDouble(),
      otherCost: ((map['other_cost'] ?? 0) as num).toDouble(),
      totalProductionCost: ((map['total_production_cost'] ?? 0) as num)
          .toDouble(),
      unitCost: ((map['unit_cost'] ?? 0) as num).toDouble(),
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
