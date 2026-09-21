import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import '../../models/account.dart';
import '../../models/ff_account_group.dart';

class FFAccountHierarchyService {
  FFAccountHierarchyService._();

  static final FFAccountHierarchyService instance =
      FFAccountHierarchyService._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> createGroup(FFAccountGroup group) async {
    final db = await _databaseHelper.database;

    if (group.name.trim().isEmpty) {
      throw ArgumentError('Account group name is required.');
    }

    if (group.parentId == group.id) {
      throw ArgumentError('An account group cannot be its own parent.');
    }

    if (group.parentId != null) {
      final parent = await db.query(
        'ff_account_groups',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [group.parentId],
        limit: 1,
      );

      if (parent.isEmpty) {
        throw StateError('Parent account group not found: ${group.parentId}');
      }
    }

    if (group.groupCode != null && group.groupCode!.trim().isNotEmpty) {
      final duplicate = await db.query(
        'ff_account_groups',
        columns: ['id'],
        where: 'group_code = ?',
        whereArgs: [group.groupCode!.trim()],
        limit: 1,
      );

      if (duplicate.isNotEmpty) {
        throw StateError(
          'Account group code already exists: ${group.groupCode}',
        );
      }
    }

    return db.insert(
      'ff_account_groups',
      group.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<FFAccountGroup>> getGroups({bool activeOnly = false}) async {
    final db = await _databaseHelper.database;

    final rows = await db.query(
      'ff_account_groups',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name ASC',
    );

    return rows.map(FFAccountGroup.fromMap).toList();
  }

  Future<FFAccountGroup?> getGroupById(int id) async {
    final db = await _databaseHelper.database;

    final rows = await db.query(
      'ff_account_groups',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return FFAccountGroup.fromMap(rows.first);
  }

  Future<FFAccountGroup?> getGroupByCode(String groupCode) async {
    final db = await _databaseHelper.database;

    final rows = await db.query(
      'ff_account_groups',
      where: 'group_code = ?',
      whereArgs: [groupCode],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return FFAccountGroup.fromMap(rows.first);
  }

  Future<int> linkAccount({
    required int accountId,
    required int groupId,
    bool isPrimary = true,
  }) async {
    final db = await _databaseHelper.database;

    return db.transaction((txn) async {
      final account = await txn.query(
        'accounts',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );

      if (account.isEmpty) {
        throw StateError('Account not found: $accountId');
      }

      final group = await txn.query(
        'ff_account_groups',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [groupId],
        limit: 1,
      );

      if (group.isEmpty) {
        throw StateError('Account group not found: $groupId');
      }

      if (isPrimary) {
        await txn.update(
          'ff_account_links',
          {'is_primary': 0},
          where: 'account_id = ?',
          whereArgs: [accountId],
        );
      }

      final existing = await txn.query(
        'ff_account_links',
        columns: ['id'],
        where: 'account_id = ? AND group_id = ?',
        whereArgs: [accountId, groupId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final linkId = (existing.first['id'] as num).toInt();

        await txn.update(
          'ff_account_links',
          {'is_primary': isPrimary ? 1 : 0},
          where: 'id = ?',
          whereArgs: [linkId],
        );

        return linkId;
      }

      return txn.insert('ff_account_links', {
        'account_id': accountId,
        'group_id': groupId,
        'is_primary': isPrimary ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    });
  }

  Future<void> unlinkAccount({
    required int accountId,
    required int groupId,
  }) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'ff_account_links',
      where: 'account_id = ? AND group_id = ?',
      whereArgs: [accountId, groupId],
    );
  }

  Future<List<FFAccountGroup>> getGroupsForAccount(int accountId) async {
    final db = await _databaseHelper.database;

    final rows = await db.rawQuery(
      '''
      SELECT g.*
      FROM ff_account_groups g
      INNER JOIN ff_account_links l
        ON l.group_id = g.id
      WHERE l.account_id = ?
      ORDER BY l.is_primary DESC, g.name ASC
      ''',
      [accountId],
    );

    return rows.map(FFAccountGroup.fromMap).toList();
  }

  Future<FFAccountGroup?> getPrimaryGroupForAccount(int accountId) async {
    final db = await _databaseHelper.database;

    final rows = await db.rawQuery(
      '''
      SELECT g.*
      FROM ff_account_groups g
      INNER JOIN ff_account_links l
        ON l.group_id = g.id
      WHERE l.account_id = ?
        AND l.is_primary = 1
      LIMIT 1
      ''',
      [accountId],
    );

    if (rows.isEmpty) {
      return null;
    }

    return FFAccountGroup.fromMap(rows.first);
  }

  Future<Account?> getPrimaryAccountForGroup(int groupId) async {
    final db = await _databaseHelper.database;

    final rows = await db.rawQuery(
      '''
      SELECT a.*
      FROM accounts a
      INNER JOIN ff_account_links l
        ON l.account_id = a.id
      WHERE l.group_id = ?
        AND l.is_primary = 1
      ORDER BY a.name ASC
      LIMIT 1
      ''',
      [groupId],
    );

    if (rows.isEmpty) {
      return null;
    }

    return Account.fromMap(rows.first);
  }
}
