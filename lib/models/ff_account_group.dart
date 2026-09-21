class FFAccountGroup {
  final int? id;
  final String name;
  final int? parentId;
  final String? groupCode;
  final String? groupKind;
  final String? accountNature;
  final bool isSystem;
  final bool isActive;
  final String createdAt;

  const FFAccountGroup({
    this.id,
    required this.name,
    this.parentId,
    this.groupCode,
    this.groupKind,
    this.accountNature,
    required this.isSystem,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'group_code': groupCode,
      'group_kind': groupKind,
      'account_nature': accountNature,
      'is_system': isSystem ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory FFAccountGroup.fromMap(Map<String, dynamic> map) {
    return FFAccountGroup(
      id: map['id'] as int?,
      name: map['name'] as String,
      parentId: map['parent_id'] as int?,
      groupCode: map['group_code']?.toString(),
      groupKind: map['group_kind']?.toString(),
      accountNature: map['account_nature']?.toString(),
      isSystem: (map['is_system'] as num? ?? 0) != 0,
      isActive: (map['is_active'] as num? ?? 1) != 0,
      createdAt: map['created_at']?.toString() ?? '',
    );
  }
}
