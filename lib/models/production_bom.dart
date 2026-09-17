class ProductionBom {
  final int? id;
  final int productId;
  final String name;
  final String? note;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  ProductionBom({
    this.id,
    required this.productId,
    required this.name,
    this.note,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'note': note,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ProductionBom.fromMap(Map<String, dynamic> map) {
    return ProductionBom(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      name: map['name'] as String,
      note: map['note'] as String?,
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }
}
