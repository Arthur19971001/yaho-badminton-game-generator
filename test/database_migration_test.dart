// Upgrading an existing v4 database (real data from before grades existed)
// to v5 must keep every member, session, attendee and guest exactly as it
// was -- only new columns/tables are added, and pre-existing members are
// mapped to grade D.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yaho_badminton_game_generator/src/database/app_database.dart';
import 'package:yaho_badminton_game_generator/src/features/grades/data/grades_repository.dart';
import 'package:yaho_badminton_game_generator/src/features/members/data/members_repository.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/gender.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/data/sessions_repository.dart';

/// Creates a database file with the exact v4 schema and some data in it.
Future<void> _createV4Database(String path) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            gender TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            courts INTEGER NOT NULL DEFAULT 1,
            gender_balance INTEGER NOT NULL DEFAULT 0,
            games_json TEXT NOT NULL DEFAULT '[]',
            guests_json TEXT NOT NULL DEFAULT '[]',
            court_names_json TEXT NOT NULL DEFAULT '[]'
          )
        ''');
        await db.execute('''
          CREATE TABLE session_attendees (
            session_id INTEGER NOT NULL,
            member_id INTEGER NOT NULL,
            PRIMARY KEY (session_id, member_id),
            FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
          )
        ''');
      },
    ),
  );

  for (final (name, gender) in [
    ('김철수', 'male'),
    ('이영희', 'female'),
    ('박민수', 'male'),
    ('최지은', 'female'),
  ]) {
    await db.insert('members', {'name': name, 'gender': gender});
  }
  final games = [
    {
      'id': 1,
      'gameNumber': 1,
      'courts': [
        {
          'courtNumber': 1,
          'playerIds': [1, 2, 3, -1],
        },
      ],
      'restingPlayerIds': [4],
    },
  ];
  await db.insert('sessions', {
    'date': DateTime(2026, 1, 1).toIso8601String(),
    'courts': 1,
    'gender_balance': 1,
    'games_json': jsonEncode(games),
    // A guest persisted before guests carried a gradeId.
    'guests_json': jsonEncode([
      {'id': -1, 'name': '게스트', 'gender': 'male'},
    ]),
    'court_names_json': jsonEncode(['19번']),
  });
  for (final memberId in [1, 2, 3, 4, -1]) {
    await db.insert('session_attendees', {
      'session_id': 1,
      'member_id': memberId,
    });
  }
  await db.close();
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('v4 -> v5 keeps every row and maps existing members to grade D',
      () async {
    final dir = await Directory.systemTemp.createTemp('yaho_migration_');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'yaho_badminton.db');
    await _createV4Database(path);

    final db = await openAppDatabase(path);
    addTearDown(db.close);
    expect(await db.getVersion(), 5);

    final grades = await GradesRepository(db).getAll();
    expect(
      grades.map((g) => (g.name, g.points)).toList(),
      [('A', 10), ('B', 8), ('C', 6), ('D', 4)],
    );
    final gradeD = grades.firstWhere((g) => g.name == 'D');

    final members = await MembersRepository(db).getAll();
    expect(
      members.map((m) => m.name).toSet(),
      {'김철수', '이영희', '박민수', '최지은'},
    );
    expect(members.every((m) => m.gradeId == gradeD.id), isTrue);

    final sessions = await SessionsRepository(db).getAll();
    expect(sessions, hasLength(1));
    final session = sessions.single;
    expect(session.genderBalance, isTrue);
    expect(session.gradeBalance, isFalse);
    expect(session.attendeeIds.toSet(), {1, 2, 3, 4, -1});
    expect(session.courtNames, ['19번']);
    expect(session.rounds.single.courts.single.playerIds, [1, 2, 3, -1]);
    expect(session.rounds.single.restingPlayerIds, [4]);
    expect(session.guests.single.name, '게스트');
    expect(session.guests.single.gradeId, isNull);
  });

  test('fresh database is created at v5 with default grades', () async {
    final db = await openAppDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final grades = await GradesRepository(db).getAll();
    expect(grades.map((g) => g.name).toList(), ['A', 'B', 'C', 'D']);
  });

  test('deleting a grade keeps its members, just ungraded', () async {
    final db = await openAppDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final gradesRepo = GradesRepository(db);
    final membersRepo = MembersRepository(db);
    final gradeB =
        (await gradesRepo.getAll()).firstWhere((g) => g.name == 'B');
    final member =
        await membersRepo.add('홍길동', Gender.male, gradeId: gradeB.id);

    await gradesRepo.delete(gradeB.id);

    final after = await membersRepo.getAll();
    expect(after.single.id, member.id);
    expect(after.single.gradeId, isNull);
  });
}
