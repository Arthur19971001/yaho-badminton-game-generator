// SessionController.removePlayerFromGames ("사용자 빼기"): removes a player
// from game N onwards (leaving their court slot empty), drops them from the
// attendee list, and is fully undoable -- attendees included.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yaho_badminton_game_generator/src/database/app_database.dart';
import 'package:yaho_badminton_game_generator/src/features/members/application/members_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/gender.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/application/session_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/application/sessions_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/data/sessions_repository.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/game_round.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/game_session.dart';

class _Fixture {
  _Fixture(this.container, this.db, this.sessionId, this.playerIds);

  final ProviderContainer container;
  final Database db;
  final int sessionId;
  final List<int> playerIds;

  SessionController get notifier =>
      container.read(sessionControllerProvider(sessionId).notifier);

  GameSession get state =>
      container.read(sessionControllerProvider(sessionId)).requireValue;

  Future<GameSession?> reloadFromDb() => SessionsRepository(db).getById(sessionId);
}

/// 6 members, 4 generated games on 1 court.
Future<_Fixture> _setUp() async {
  final db = await openAppDatabase(inMemoryDatabasePath);
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
  );
  addTearDown(container.dispose);
  container.listen(membersControllerProvider, (_, _) {});
  container.listen(sessionsControllerProvider, (_, _) {});

  final membersNotifier = container.read(membersControllerProvider.notifier);
  for (final name in ['a', 'b', 'c', 'd', 'e', 'f']) {
    await membersNotifier.addMember(name, Gender.male);
  }
  final members = await container.read(membersControllerProvider.future);
  final ids = members.map((m) => m.id).toList();

  final session = await container
      .read(sessionsControllerProvider.notifier)
      .createSession(DateTime(2026, 1, 1));
  container.listen(sessionControllerProvider(session.id), (_, _) {});
  await container.read(sessionControllerProvider(session.id).future);
  final notifier = container.read(
    sessionControllerProvider(session.id).notifier,
  );
  await notifier.updateAttendees(ids);
  await notifier.generateGames(
    courts: 1,
    gamesToGenerate: 4,
    genderBalance: false,
  );
  return _Fixture(container, db, session.id, ids);
}

bool _appearsIn(GameRound round, int playerId) =>
    round.restingPlayerIds.contains(playerId) ||
    round.courts.any((c) => c.playerIds.contains(playerId));

void main() {
  setUpAll(sqfliteFfiInit);

  test('from game 3: gone from games 3-4, untouched in 1-2, not attending',
      () async {
    final f = await _setUp();
    final target = f.playerIds.first;
    final before = f.state.rounds;

    await f.notifier.removePlayerFromGames(
      playerId: target,
      fromGameNumber: 3,
    );

    final after = f.state.rounds;
    expect(after[0].toJson(), before[0].toJson());
    expect(after[1].toJson(), before[1].toJson());
    for (final round in after.skip(2)) {
      expect(_appearsIn(round, target), isFalse);
    }
    // Where they were on court, the slot is left empty (3/4), not refilled.
    for (var i = 2; i < 4; i++) {
      final wasPlaying =
          before[i].courts.single.playerIds.contains(target);
      expect(after[i].courts.single.playerIds.length, wasPlaying ? 3 : 4);
    }
    expect(f.state.attendeeIds, isNot(contains(target)));

    final persisted = await f.reloadFromDb();
    expect(persisted!.attendeeIds, isNot(contains(target)));
    expect(_appearsIn(persisted.rounds[3], target), isFalse);
  });

  test('from game 1 removes them from every game', () async {
    final f = await _setUp();
    final target = f.playerIds[1];

    await f.notifier.removePlayerFromGames(
      playerId: target,
      fromGameNumber: 1,
    );

    expect(f.state.rounds.any((r) => _appearsIn(r, target)), isFalse);
    expect(f.state.attendeeIds, isNot(contains(target)));
  });

  test('0 keeps every game as-is but drops them from attendees', () async {
    final f = await _setUp();
    final target = f.playerIds[2];
    final before = f.state.rounds.map((r) => r.toJson()).toList();

    await f.notifier.removePlayerFromGames(
      playerId: target,
      fromGameNumber: 0,
    );

    expect(f.state.rounds.map((r) => r.toJson()).toList(), before);
    expect(f.state.attendeeIds, isNot(contains(target)));
  });

  test('undo restores both the games and the attendee list', () async {
    final f = await _setUp();
    final target = f.playerIds.first;
    final roundsBefore = f.state.rounds.map((r) => r.toJson()).toList();
    final attendeesBefore = f.state.attendeeIds;

    await f.notifier.removePlayerFromGames(
      playerId: target,
      fromGameNumber: 1,
    );
    await f.notifier.undo();

    expect(f.state.rounds.map((r) => r.toJson()).toList(), roundsBefore);
    expect(f.state.attendeeIds, attendeesBefore);
    final persisted = await f.reloadFromDb();
    expect(persisted!.attendeeIds.toSet(), attendeesBefore.toSet());
  });
}
