class ProductionCost {
  final int? id;
  final int productionId;
  final String costType;
  final double costPerUnit;
  final double totalCost;
  final String? note;

  ProductionCost({
    this.id,
    required this.productionId,
    required this.costType,
    required this.costPerUnit,
    required this.totalCost,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'production_id': productionId,
      'cost_type': costType,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'note': note,
    };
  }

  factory ProductionCost.fromMap(Map<String, dynamic> map) {
    return ProductionCost(
      id: map['id'] as int?,
      productionId: map['production_id'] as int,
      costType: map['cost_type'] as String,
      costPerUnit: (map['cost_per_unit'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      note: map['note'] as String?,
    );
  }
}
