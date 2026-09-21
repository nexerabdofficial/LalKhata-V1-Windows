import '../../database/database_helper.dart';

class FFAccountGroupOption {
  final int id;
  final String name;
  final int? parentId;
  final String? groupCode;
  final String groupKind;
  final String accountNature;
  final bool isSystem;

  const FFAccountGroupOption({
    required this.id,
    required this.name,
    required this.parentId,
    required this.groupCode,
    required this.groupKind,
    required this.accountNature,
    required this.isSystem,
  });

  factory FFAccountGroupOption.fromMap(Map<String, Object?> map) {
    return FFAccountGroupOption(
      id: (map['id'] as num).toInt(),
      name: map['name']?.toString() ?? '',
      parentId: map['parent_id'] == null
          ? null
          : (map['parent_id'] as num).toInt(),
      groupCode: map['group_code']?.toString(),
      groupKind: map['group_kind']?.toString() ?? '',
      accountNature: map['account_nature']?.toString() ?? '',
      isSystem: (map['is_system'] as num? ?? 0).toInt() == 1,
    );
  }
}

class FFCustomGroupService {
  FFCustomGroupService._();

  static final FFCustomGroupService instance = FFCustomGroupService._();

  Future<List<FFAccountGroupOption>> getSelectableGroups() async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.query(
      'ff_account_groups',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'group_kind ASC, name COLLATE NOCASE ASC',
    );

    return rows
        .map(FFAccountGroupOption.fromMap)
        .where((group) => group.parentId != null || !group.isSystem)
        .toList();
  }

  Future<List<FFAccountGroupOption>> getPossibleParents() async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.query(
      'ff_account_groups',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'group_kind ASC, name COLLATE NOCASE ASC',
    );

    return rows.map(FFAccountGroupOption.fromMap).toList();
  }

  Future<int> createCustomGroup({
    required String name,
    required int parentId,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('Group name is required.');
    }

    final db = await DatabaseHelper.instance.database;

    return db.transaction((txn) async {
      final parents = await txn.query(
        'ff_account_groups',
        where: 'id = ? AND is_active = ?',
        whereArgs: [parentId, 1],
        limit: 1,
      );

      if (parents.isEmpty) {
        throw StateError('Parent group not found.');
      }

      final parent = parents.first;

      final duplicate = await txn.rawQuery(
        '''
        SELECT id
        FROM ff_account_groups
        WHERE parent_id = ?
          AND LOWER(TRIM(name)) = LOWER(TRIM(?))
          AND is_active = 1
        LIMIT 1
        ''',
        [parentId, cleanName],
      );

      if (duplicate.isNotEmpty) {
        throw StateError(
          'A group with this name already exists under the selected parent.',
        );
      }

      return txn.insert('ff_account_groups', {
        'name': cleanName,
        'parent_id': parentId,
        'group_code': null,
        'group_kind': parent['group_kind']?.toString(),
        'account_nature': parent['account_nature']?.toString(),
        'is_system': 0,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }
}
