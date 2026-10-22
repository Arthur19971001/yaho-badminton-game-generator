import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../database/app_database.dart';
import '../domain/gender.dart';
import '../domain/member.dart';

part 'members_repository.g.dart';

@Riverpod(keepAlive: true)
Future<MembersRepository> membersRepository(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return MembersRepository(db);
}

class MembersRepository {
  MembersRepository(this._db);

  final Database _db;

  Future<List<Member>> getAll() async {
    final rows = await _db.query('members', orderBy: 'name ASC');
    return rows.map(Member.fromMap).toList();
  }

  Future<Member> add(String name, Gender gender, {int? gradeId}) async {
    final member = Member(id: 0, name: name, gender: gender, gradeId: gradeId);
    final id = await _db.insert('members', member.toInsertMap());
    return Member(id: id, name: name, gender: gender, gradeId: gradeId);
  }

  Future<void> update(Member member) async {
    await _db.update(
      'members',
      member.toInsertMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  Future<void> delete(int id) async {
    await _db.delete('members', where: 'id = ?', whereArgs: [id]);
  }
}
