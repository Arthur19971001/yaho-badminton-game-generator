// Regression coverage for SessionController.deleteCourt and
// deleteCourtFromAllGames: deleting a single court moves its players to
// that game's resting bench (not dropping them), deletes the whole game
// if it was the last court, and deleteCourtFromAllGames applies that
// across every game with a matching court number in one pass.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yaho_badminton_game_generator/src/database/app_database.dart';
import 'package:yaho_badminton_game_generator/src/features/members/application/members_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/gender.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/application/session_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/application/sessions_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/game_session.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SessionController.deleteCourt', () {
    test('moves that court\'s players to resting and leaves other courts alone',
        () async {
      final db = await openAppDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);
      container.listen(membersControllerProvider, (_, _) {});
      container.listen(sessionsControllerProvider, (_, _) {});

      final membersNotifier =
          container.read(membersControllerProvider.notifier);
      await membersNotifier.addMember('a', Gender.male);
      await membersNotifier.addMember('b', Gender.male);
      await membersNotifier.addMember('c', Gender.male);
      final members = await container.read(membersControllerProvider.future);
      final byName = {for (final m in members) m.name: m.id};

      final session = await container
          .read(sessionsControllerProvider.notifier)
          .createSession(DateTime(2026, 2, 1));
      container.listen(sessionControllerProvider(session.id), (_, _) {});
      await container.read(sessionControllerProvider(session.id).future);
      final sessionNotifier =
          container.read(sessionControllerProvider(session.id).notifier);
      await sessionNotifier
          .updateAttendees(members.map((m) => m.id).toList());

      GameSession state() =>
          container.read(sessionControllerProvider(session.id)).requireValue;

      await sessionNotifier.addEmptyGame(courts: 2);
      final roundId = state().rounds[0].id;
      await sessionNotifier.movePlayer(
          roundId: roundId, playerId: byName['a']!, toCourtNumber: 1);
      await sessionNotifier.movePlayer(
          roundId: roundId, playerId: byName['b']!, toCourtNumber: 2);

      await sessionNotifier.deleteCourt(roundId: roundId, courtNumber: 1);

      final round = state().rounds.firstWhere((r) => r.id == roundId);
      expect(round.courts.map((c) => c.courtNumber), [2],
          reason: 'court 1 should be gone, court 2 untouched');
      expect(round.courts.first.playerIds, [byName['b']!],
          reason: "court 2's own occupant should be unaffected");
      expect(round.restingPlayerIds.contains(byName['a']!), isTrue,
          reason: 'a should move to resting, not vanish, when court 1 is deleted');
    });

    test('deletes the whole game when its last court is deleted', () async {
      final db = await openAppDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);
      container.listen(membersControllerProvider, (_, _) {});
      container.listen(sessionsControllerProvider, (_, _) {});

      final membersNotifier =
          container.read(membersControllerProvider.notifier);
      await membersNotifier.addMember('a', Gender.male);
      final members = await container.read(membersControllerProvider.future);

      final session = await container
          .read(sessionsControllerProvider.notifier)
          .createSession(DateTime(2026, 2, 2));
      container.listen(sessionControllerProvider(session.id), (_, _) {});
      await container.read(sessionControllerProvider(session.id).future);
      final sessionNotifier =
          container.read(sessionControllerProvider(session.id).notifier);
      await sessionNotifier
          .updateAttendees(members.map((m) => m.id).toList());

      GameSession state() =>
          container.read(sessionControllerProvider(session.id)).requireValue;

      // 3 games, 1 court each -- deleting game 2's only court should
      // remove game 2 entirely and renumber game 3 down to game 2.
      await sessionNotifier.addEmptyGame(courts: 1);
      await sessionNotifier.addEmptyGame(courts: 1);
      await sessionNotifier.addEmptyGame(courts: 1);
      final roundIds = state().rounds.map((r) => r.id).toList();

      await sessionNotifier.deleteCourt(roundId: roundIds[1], courtNumber: 1);

      final rounds = state().rounds;
      expect(rounds.length, 2, reason: 'game 2 should be gone entirely');
      expect(rounds.map((r) => r.id), [roundIds[0], roundIds[2]],
          reason: 'the remaining games should be the original 1st and 3rd');
      expect(rounds.map((r) => r.gameNumber), [1, 2],
          reason: 'remaining games should be renumbered 1..N');
    });
  });

  group('SessionController.deleteCourtFromAllGames', () {
    test(
        'removes that court number from every game, deleting any game left with none, in one renumbering pass',
        () async {
      final db = await openAppDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);
      container.listen(membersControllerProvider, (_, _) {});
      container.listen(sessionsControllerProvider, (_, _) {});

      final membersNotifier =
          container.read(membersControllerProvider.notifier);
      await membersNotifier.addMember('a', Gender.male);
      await membersNotifier.addMember('b', Gender.male);
      final members = await container.read(membersControllerProvider.future);
      final byName = {for (final m in members) m.name: m.id};

      final session = await container
          .read(sessionsControllerProvider.notifier)
          .createSession(DateTime(2026, 2, 3));
      container.listen(sessionControllerProvider(session.id), (_, _) {});
      await container.read(sessionControllerProvider(session.id).future);
      final sessionNotifier =
          container.read(sessionControllerProvider(session.id).notifier);
      await sessionNotifier
          .updateAttendees(members.map((m) => m.id).toList());

      GameSession state() =>
          container.read(sessionControllerProvider(session.id)).requireValue;

      // Game 1: 2 courts (court 1 has 'a'). Game 2: 1 court only (court 1
      // has 'b') -- deleting court 1 everywhere should empty game 2
      // entirely (deleting it) while game 1 just loses that one court.
      await sessionNotifier.addEmptyGame(courts: 2);
      await sessionNotifier.addEmptyGame(courts: 1);
      final roundIds = state().rounds.map((r) => r.id).toList();
      await sessionNotifier.movePlayer(
          roundId: roundIds[0], playerId: byName['a']!, toCourtNumber: 1);
      await sessionNotifier.movePlayer(
          roundId: roundIds[1], playerId: byName['b']!, toCourtNumber: 1);

      await sessionNotifier.deleteCourtFromAllGames(1);

      final rounds = state().rounds;
      expect(rounds.length, 1,
          reason: 'game 2 (which only had court 1) should be gone entirely');
      final remaining = rounds.single;
      expect(remaining.gameNumber, 1);
      expect(remaining.courts.map((c) => c.courtNumber), [2],
          reason: "game 1 should keep its court 2, court 1 removed");
      expect(remaining.restingPlayerIds.contains(byName['a']!), isTrue,
          reason: 'a should move to resting in game 1, not vanish');
    });
  });
}
