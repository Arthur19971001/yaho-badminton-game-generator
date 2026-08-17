import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../database/app_database.dart';
import '../domain/game_session.dart';

part 'sessions_repository.g.dart';

@Riverpod(keepAlive: true)
Future<SessionsRepository> sessionsRepository(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return SessionsRepository(db);
}

class SessionsRepository {
  SessionsRepository(this._db);

  final Database _db;

  Future<List<GameSession>> getAll() async {
    final rows = await _db.query('sessions', orderBy: 'date DESC, id DESC');
    final sessions = <GameSession>[];
    for (final row in rows) {
      sessions.add(await _hydrate(row));
    }
    return sessions;
  }

  Future<GameSession?> getById(int id) async {
    final rows = await _db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _hydrate(rows.first);
  }

  Future<GameSession> _hydrate(Map<String, Object?> row) async {
    final attendeeRows = await _db.query(
      'session_attendees',
      columns: ['member_id'],
      where: 'session_id = ?',
      whereArgs: [row['id']! as int],
    );
    final attendeeIds =
        attendeeRows.map((r) => r['member_id']! as int).toList();
    return GameSession.fromRow(row, attendeeIds);
  }

  Future<GameSession> create(DateTime date, {int courts = 1}) async {
    final id = await _db.insert('sessions', {
      'date': date.toIso8601String(),
      'courts': courts,
      'gender_balance': 0,
      'games_json': jsonEncode(const []),
      'guests_json': jsonEncode(const []),
      'court_names_json': jsonEncode(const []),
    });
    return GameSession(
      id: id,
      date: date,
      courts: courts,
      genderBalance: false,
      attendeeIds: const [],
      rounds: const [],
      guests: const [],
      courtNames: const [],
    );
  }

  Future<void> delete(int id) async {
    await _db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setAttendees(int sessionId, List<int> memberIds) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'session_attendees',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      for (final memberId in memberIds) {
        await txn.insert('session_attendees', {
          'session_id': sessionId,
          'member_id': memberId,
        });
      }
    });
  }

  Future<void> save(GameSession session) async {
    await _db.update(
      'sessions',
      session.toUpdateMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }
}
