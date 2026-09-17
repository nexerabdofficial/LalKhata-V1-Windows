class ProductionBomItem {
  final int? id;
  final int bomId;
  final int materialProductId;
  final double quantity;
  final String? note;

  ProductionBomItem({
    this.id,
    required this.bomId,
    required this.materialProductId,
    required this.quantity,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bom_id': bomId,
      'material_product_id': materialProductId,
      'quantity': quantity,
      'note': note,
    };
  }

  factory ProductionBomItem.fromMap(Map<String, dynamic> map) {
    return ProductionBomItem(
      id: map['id'] as int?,
      bomId: map['bom_id'] as int,
      materialProductId: map['material_product_id'] as int,
      quantity: (map['quantity'] as num).toDouble(),
      note: map['note'] as String?,
    );
  }
}
