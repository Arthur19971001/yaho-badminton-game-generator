import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../database/app_database.dart';
import '../domain/grade.dart';

part 'grades_repository.g.dart';

@Riverpod(keepAlive: true)
Future<GradesRepository> gradesRepository(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return GradesRepository(db);
}

class GradesRepository {
  GradesRepository(this._db);

  final Database _db;

  /// Highest points first (A, B, C, D by default), ties by creation order.
  Future<List<Grade>> getAll() async {
    final rows = await _db.query(
      'grades',
      orderBy: 'points DESC, sort_order ASC, id ASC',
    );
    return rows.map(Grade.fromMap).toList();
  }

  Future<Grade> add(String name, int points) async {
    final maxRow = await _db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM grades',
    );
    final sortOrder = maxRow.first['next']! as int;
    final id = await _db.insert('grades', {
      'name': name,
      'points': points,
      'sort_order': sortOrder,
    });
    return Grade(id: id, name: name, points: points, sortOrder: sortOrder);
  }

  Future<void> update(Grade grade) async {
    await _db.update(
      'grades',
      {'name': grade.name, 'points': grade.points},
      where: 'id = ?',
      whereArgs: [grade.id],
    );
  }

  /// Deletes the grade and clears it from every member who had it -- the
  /// members themselves are kept, just left ungraded.
  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      await txn.update(
        'members',
        {'grade_id': null},
        where: 'grade_id = ?',
        whereArgs: [id],
      );
      await txn.delete('grades', where: 'id = ?', whereArgs: [id]);
    });
  }
}
