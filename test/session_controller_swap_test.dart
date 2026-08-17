// Regression coverage for SessionController.swapPlayers: same-round and
// cross-round swaps between playing and resting statuses. Exercises the
// controller directly (no UI) against an in-memory sqlite DB +
// ProviderContainer. A cross-round swap is implemented as two independent
// same-round swaps (once in round A, once in round B), so a player displaced
// from their original round correctly takes over whatever status the other
// player held there, rather than vanishing from that round entirely.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yaho_badminton_game_generator/src/database/app_database.dart';
import 'package:yaho_badminton_game_generator/src/features/members/application/members_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/gender.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/application/session_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/application/sessions_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/game_round.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/game_session.dart';

String dumpRound(String label, GameRound r) {
  final courts = {for (final c in r.courts) c.courtNumber: c.playerIds};
  return '$label: id=${r.id} courts=$courts resting=${r.restingPlayerIds}';
}

void main() {
  // sqflite_common_ffi needs its ffi loader initialized once per process.
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SessionController.swapPlayers diagnostic', () {
    test('Scenario 1: SAME-ROUND rest<->court', () async {
      final db = await openAppDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);
      // These providers are autoDispose; keep them alive for the whole test
      // via a standing listener, otherwise they get torn down between
      // `await`s with nothing left watching them.
      container.listen(membersControllerProvider, (_, _) {});
      container.listen(sessionsControllerProvider, (_, _) {});

      final membersNotifier = container.read(
        membersControllerProvider.notifier,
      );
      await membersNotifier.addMember('P', Gender.male);
      await membersNotifier.addMember('Q', Gender.male);
      await membersNotifier.addMember('X1', Gender.male);
      await membersNotifier.addMember('X2', Gender.male);
      await membersNotifier.addMember('X3', Gender.female);
      await membersNotifier.addMember('X4', Gender.female);
      final members = await container.read(membersControllerProvider.future);
      final byName = {for (final m in members) m.name: m.id};
      final p = byName['P']!;
      final q = byName['Q']!;

      final session = await container
          .read(sessionsControllerProvider.notifier)
          .createSession(DateTime(2026, 1, 1));
      container.listen(sessionControllerProvider(session.id), (_, _) {});
      // Wait for the notifier's initial build (reading the session back
      // from the repo) to complete before issuing any mutation -- mutating
      // methods call `state.requireValue`, which throws while still loading.
      await container.read(sessionControllerProvider(session.id).future);
      final sessionNotifier = container.read(
        sessionControllerProvider(session.id).notifier,
      );
      await sessionNotifier.updateAttendees(members.map((m) => m.id).toList());

      GameSession state() =>
          container.read(sessionControllerProvider(session.id)).requireValue;

      // addEmptyGame(courts:1) twice to get two known empty rounds.
      await sessionNotifier.addEmptyGame(courts: 1);
      await sessionNotifier.addEmptyGame(courts: 1);
      final roundOneId = state().rounds[0].id;

      await sessionNotifier.movePlayer(
        roundId: roundOneId,
        playerId: p,
        toCourtNumber: 1,
      );

      debugPrint('--- Scenario 1: BEFORE swap ---');
      debugPrint(dumpRound('round1', state().rounds[0]));

      await sessionNotifier.swapPlayers(
        roundIdA: roundOneId,
        playerIdA: p,
        roundIdB: roundOneId,
        playerIdB: q,
      );

      final round1After = state().rounds.firstWhere((r) => r.id == roundOneId);
      debugPrint('--- Scenario 1: AFTER swap ---');
      debugPrint(dumpRound('round1', round1After));

      final court1 = round1After.courts.firstWhere((c) => c.courtNumber == 1);
      expect(
        court1.playerIds,
        [q],
        reason:
            'Spec: whichever court playerIdA (P) held in roundA now holds playerIdB (Q)',
      );
      expect(
        round1After.restingPlayerIds.contains(p),
        isTrue,
        reason: 'Spec: P should now be resting in round1',
      );
      expect(
        court1.playerIds.contains(p),
        isFalse,
        reason: 'P should no longer be on any court in round1',
      );
    });

    test(
      'Scenario 2: CROSS-ROUND court<->court, matched by court number -- only the two dragged cells change',
      () async {
        final db = await openAppDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        );
        addTearDown(container.dispose);
        container.listen(membersControllerProvider, (_, _) {});
        container.listen(sessionsControllerProvider, (_, _) {});

        final membersNotifier = container.read(
          membersControllerProvider.notifier,
        );
        await membersNotifier.addMember('P', Gender.male);
        await membersNotifier.addMember('Q', Gender.male);
        await membersNotifier.addMember('R', Gender.male);
        await membersNotifier.addMember('X2', Gender.male);
        await membersNotifier.addMember('X3', Gender.female);
        await membersNotifier.addMember('X4', Gender.female);
        final members = await container.read(membersControllerProvider.future);
        final byName = {for (final m in members) m.name: m.id};
        final p = byName['P']!;
        final r = byName['R']!;

        final session = await container
            .read(sessionsControllerProvider.notifier)
            .createSession(DateTime(2026, 1, 1));
        container.listen(sessionControllerProvider(session.id), (_, _) {});
        // Wait for the notifier's initial build (reading the session back
        // from the repo) to complete before issuing any mutation -- mutating
        // methods call `state.requireValue`, which throws while still loading.
        await container.read(sessionControllerProvider(session.id).future);
        final sessionNotifier = container.read(
          sessionControllerProvider(session.id).notifier,
        );
        await sessionNotifier.updateAttendees(
          members.map((m) => m.id).toList(),
        );

        GameSession state() =>
            container.read(sessionControllerProvider(session.id)).requireValue;

        // 2 courts per round this time -- P plays court *1* in round1, R
        // plays court *2* in round2 (deliberately different numbers, so the
        // swap has a visible effect instead of round-tripping back to the
        // same number).
        await sessionNotifier.addEmptyGame(courts: 2);
        await sessionNotifier.addEmptyGame(courts: 2);
        final roundOneId = state().rounds[0].id;
        final roundTwoId = state().rounds[1].id;

        await sessionNotifier.movePlayer(
          roundId: roundOneId,
          playerId: p,
          toCourtNumber: 1,
        );
        await sessionNotifier.movePlayer(
          roundId: roundTwoId,
          playerId: r,
          toCourtNumber: 2,
        );

        debugPrint('--- Scenario 2: BEFORE swap ---');
        debugPrint(dumpRound('round1', state().rounds[0]));
        debugPrint(dumpRound('round2', state().rounds[1]));

        await sessionNotifier.swapPlayers(
          roundIdA: roundOneId,
          playerIdA: p,
          roundIdB: roundTwoId,
          playerIdB: r,
        );

        final round1After = state().rounds.firstWhere(
          (round) => round.id == roundOneId,
        );
        final round2After = state().rounds.firstWhere(
          (round) => round.id == roundTwoId,
        );
        debugPrint('--- Scenario 2: AFTER swap ---');
        debugPrint(dumpRound('round1', round1After));
        debugPrint(dumpRound('round2', round2After));

        // P's game-1 cell should now hold whatever R's game-2 cell held
        // (court number 2) -- P stays in round1, just on a different court
        // there; P never relocates to round2.
        expect(
          round1After.courts
              .firstWhere((c) => c.courtNumber == 2)
              .playerIds
              .contains(p),
          isTrue,
          reason: "P's round1 cell should now be court 2 (R's old number)",
        );
        expect(
          round1After.courts
              .firstWhere((c) => c.courtNumber == 1)
              .playerIds
              .contains(p),
          isFalse,
          reason: 'P should no longer be on round1 court 1',
        );
        // R's game-2 cell should now hold court number 1 (P's old number),
        // staying in round2.
        expect(
          round2After.courts
              .firstWhere((c) => c.courtNumber == 1)
              .playerIds
              .contains(r),
          isTrue,
          reason: "R's round2 cell should now be court 1 (P's old number)",
        );
        expect(
          round2After.courts
              .firstWhere((c) => c.courtNumber == 2)
              .playerIds
              .contains(r),
          isFalse,
          reason: 'R should no longer be on round2 court 2',
        );
      },
    );

    test(
      'Scenario 2b: CROSS-ROUND court<->court with the SAME court number is a no-op (accepted tradeoff)',
      () async {
        final db = await openAppDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        );
        addTearDown(container.dispose);
        container.listen(membersControllerProvider, (_, _) {});
        container.listen(sessionsControllerProvider, (_, _) {});

        final membersNotifier = container.read(
          membersControllerProvider.notifier,
        );
        await membersNotifier.addMember('P', Gender.male);
        await membersNotifier.addMember('R', Gender.male);
        final members = await container.read(membersControllerProvider.future);
        final byName = {for (final m in members) m.name: m.id};
        final p = byName['P']!;
        final r = byName['R']!;

        final session = await container
            .read(sessionsControllerProvider.notifier)
            .createSession(DateTime(2026, 1, 6));
        container.listen(sessionControllerProvider(session.id), (_, _) {});
        await container.read(sessionControllerProvider(session.id).future);
        final sessionNotifier = container.read(
          sessionControllerProvider(session.id).notifier,
        );
        await sessionNotifier.updateAttendees(
          members.map((m) => m.id).toList(),
        );

        GameSession state() =>
            container.read(sessionControllerProvider(session.id)).requireValue;

        await sessionNotifier.addEmptyGame(courts: 1);
        await sessionNotifier.addEmptyGame(courts: 1);
        final roundOneId = state().rounds[0].id;
        final roundTwoId = state().rounds[1].id;

        await sessionNotifier.movePlayer(
          roundId: roundOneId,
          playerId: p,
          toCourtNumber: 1,
        );
        await sessionNotifier.movePlayer(
          roundId: roundTwoId,
          playerId: r,
          toCourtNumber: 1,
        );

        await sessionNotifier.swapPlayers(
          roundIdA: roundOneId,
          playerIdA: p,
          roundIdB: roundTwoId,
          playerIdB: r,
        );

        final round1After = state().rounds.firstWhere(
          (round) => round.id == roundOneId,
        );
        final round2After = state().rounds.firstWhere(
          (round) => round.id == roundTwoId,
        );

        // Both were already on "court number 1" in their own round, so
        // swapping by court number reproduces the same value for each --
        // an accepted no-op, per the chosen "swap only the two dragged
        // cells, matched by court number" design.
        expect(round1After.courts.first.playerIds, [p]);
        expect(round2After.courts.first.playerIds, [r]);
      },
    );

    test(
      'Scenario 3 vs 4: CROSS-ROUND rest<->court, both directions, full state dump',
      () async {
        final db = await openAppDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        );
        addTearDown(container.dispose);
        container.listen(membersControllerProvider, (_, _) {});
        container.listen(sessionsControllerProvider, (_, _) {});

        final membersNotifier = container.read(
          membersControllerProvider.notifier,
        );
        await membersNotifier.addMember('P', Gender.male);
        await membersNotifier.addMember('Q', Gender.male);
        await membersNotifier.addMember('X1', Gender.male);
        await membersNotifier.addMember('X2', Gender.male);
        await membersNotifier.addMember('X3', Gender.female);
        await membersNotifier.addMember('X4', Gender.female);
        final members = await container.read(membersControllerProvider.future);
        final byName = {for (final m in members) m.name: m.id};
        final p = byName['P']!;
        final q = byName['Q']!;

        final session = await container
            .read(sessionsControllerProvider.notifier)
            .createSession(DateTime(2026, 1, 1));
        container.listen(sessionControllerProvider(session.id), (_, _) {});
        // Wait for the notifier's initial build (reading the session back
        // from the repo) to complete before issuing any mutation -- mutating
        // methods call `state.requireValue`, which throws while still loading.
        await container.read(sessionControllerProvider(session.id).future);
        final sessionNotifier = container.read(
          sessionControllerProvider(session.id).notifier,
        );
        await sessionNotifier.updateAttendees(
          members.map((m) => m.id).toList(),
        );

        GameSession state() =>
            container.read(sessionControllerProvider(session.id)).requireValue;

        await sessionNotifier.addEmptyGame(courts: 1);
        await sessionNotifier.addEmptyGame(courts: 1);
        final roundOneId = state().rounds[0].id;
        final roundTwoId = state().rounds[1].id;

        // P plays court1 in round1. Q is fully untouched (resting by default
        // in both round1 and round2). P is also untouched in round2 (resting
        // by default there too).
        await sessionNotifier.movePlayer(
          roundId: roundOneId,
          playerId: p,
          toCourtNumber: 1,
        );

        debugPrint(
          '--- Scenario 3: BEFORE swap (shared pre-state for 3 and 4) ---',
        );
        debugPrint(dumpRound('round1', state().rounds[0]));
        debugPrint(dumpRound('round2', state().rounds[1]));

        // ---- Scenario 3: swapPlayers(roundIdA: round1, playerIdA: P,
        //                              roundIdB: round2, playerIdB: Q) ----
        await sessionNotifier.swapPlayers(
          roundIdA: roundOneId,
          playerIdA: p,
          roundIdB: roundTwoId,
          playerIdB: q,
        );

        final s3Round1 = state().rounds.firstWhere((r) => r.id == roundOneId);
        final s3Round2 = state().rounds.firstWhere((r) => r.id == roundTwoId);
        debugPrint(
          '--- Scenario 3: AFTER swapPlayers(A=round1/P, B=round2/Q) ---',
        );
        debugPrint(dumpRound('round1', s3Round1));
        debugPrint(dumpRound('round2', s3Round2));

        final s3R1C1 = s3Round1.courts.firstWhere((c) => c.courtNumber == 1);
        final s3R2C1 = s3Round2.courts.firstWhere((c) => c.courtNumber == 1);

        // Only the two dragged/dropped cells change: P's round1 cell (was
        // court1) becomes whatever Q's round2 cell was (resting), and Q's
        // round2 cell (was resting) becomes whatever P's round1 cell was
        // (court1). P does NOT relocate to round2, and Q does NOT relocate
        // to round1 -- each stays in their own round, just with a new
        // status there.
        expect(
          s3R1C1.playerIds.contains(p),
          isFalse,
          reason: 'P should no longer be on round1 court1',
        );
        expect(
          s3Round1.restingPlayerIds.contains(p),
          isTrue,
          reason: "P's round1 cell should become resting (Q's old status)",
        );
        expect(
          s3R2C1.playerIds.contains(q),
          isTrue,
          reason: "Q's round2 cell should become court1 (P's old status)",
        );
        expect(
          s3Round2.restingPlayerIds.contains(q),
          isFalse,
          reason: 'Q should no longer be resting in round2',
        );
        // Collateral / untouched: Q's own round1 status and P's own round2
        // status were never part of this swap and must stay exactly as
        // they were (both were resting by default, untouched).
        expect(
          s3Round1.restingPlayerIds.contains(q),
          isTrue,
          reason:
              "Q's own round1 status is unrelated to this swap and "
              'must remain untouched (still resting)',
        );
        expect(
          s3Round2.restingPlayerIds.contains(p),
          isTrue,
          reason:
              "P's own round2 status is unrelated to this swap and "
              'must remain untouched (still resting)',
        );

        // Reset to the identical pre-swap state for scenario 4. Instead of a
        // second db/container (which would give P/Q *different* member ids
        // there, since they share one "members" table -- confusing the
        // structural comparison below with meaningless id differences), we
        // create a SECOND, independent SESSION in the *same* container/db,
        // reusing the exact same P/Q member ids -- sessions are fully
        // independent (separate round lists), same as two different club
        // meet-ups the same two people attend.
        final session4 = await container
            .read(sessionsControllerProvider.notifier)
            .createSession(DateTime(2026, 1, 2));
        container.listen(sessionControllerProvider(session4.id), (_, _) {});
        await container.read(sessionControllerProvider(session4.id).future);
        final sessionNotifier4 = container.read(
          sessionControllerProvider(session4.id).notifier,
        );
        await sessionNotifier4.updateAttendees(
          members.map((m) => m.id).toList(),
        );

        GameSession state4() =>
            container.read(sessionControllerProvider(session4.id)).requireValue;

        await sessionNotifier4.addEmptyGame(courts: 1);
        await sessionNotifier4.addEmptyGame(courts: 1);
        final roundOneId4 = state4().rounds[0].id;
        final roundTwoId4 = state4().rounds[1].id;

        // Identical pre-swap shape to scenario 3: P plays court1 in round1;
        // Q untouched (resting by default) in both rounds; P untouched
        // (resting by default) in round2.
        await sessionNotifier4.movePlayer(
          roundId: roundOneId4,
          playerId: p,
          toCourtNumber: 1,
        );

        debugPrint(
          '--- Scenario 4: BEFORE swap (identical setup to scenario 3) ---',
        );
        debugPrint(dumpRound('round1', state4().rounds[0]));
        debugPrint(dumpRound('round2', state4().rounds[1]));

        // ---- Scenario 4: SAME pre-state, but A/B arguments swapped:
        //      swapPlayers(roundIdA: round2, playerIdA: Q,
        //                  roundIdB: round1, playerIdB: P) ----
        await sessionNotifier4.swapPlayers(
          roundIdA: roundTwoId4,
          playerIdA: q,
          roundIdB: roundOneId4,
          playerIdB: p,
        );

        final s4Round1 = state4().rounds.firstWhere((r) => r.id == roundOneId4);
        final s4Round2 = state4().rounds.firstWhere((r) => r.id == roundTwoId4);
        debugPrint(
          '--- Scenario 4: AFTER swapPlayers(A=round2/Q, B=round1/P) ---',
        );
        debugPrint(dumpRound('round1', s4Round1));
        debugPrint(dumpRound('round2', s4Round2));

        // Compare scenario 4's result to scenario 3's result directly --
        // same P/Q member ids in both, since they share the same container's
        // member roster, only the *session* (and thus the round set) differs.
        final s4R1Courts = {
          for (final c in s4Round1.courts) c.courtNumber: c.playerIds,
        };
        final s3R1Courts = {
          for (final c in s3Round1.courts) c.courtNumber: c.playerIds,
        };
        final s4R2Courts = {
          for (final c in s4Round2.courts) c.courtNumber: c.playerIds,
        };
        final s3R2Courts = {
          for (final c in s3Round2.courts) c.courtNumber: c.playerIds,
        };

        final s3R1RestingHasP = s3Round1.restingPlayerIds.contains(p);
        final s3R1RestingHasQ = s3Round1.restingPlayerIds.contains(q);
        final s3R2RestingHasP = s3Round2.restingPlayerIds.contains(p);
        final s3R2RestingHasQ = s3Round2.restingPlayerIds.contains(q);
        final s4R1RestingHasP = s4Round1.restingPlayerIds.contains(p);
        final s4R1RestingHasQ = s4Round1.restingPlayerIds.contains(q);
        final s4R2RestingHasP = s4Round2.restingPlayerIds.contains(p);
        final s4R2RestingHasQ = s4Round2.restingPlayerIds.contains(q);

        debugPrint('Scenario 3 vs 4 comparison:');
        debugPrint('  round1 courts: s3=$s3R1Courts vs s4=$s4R1Courts');
        debugPrint('  round2 courts: s3=$s3R2Courts vs s4=$s4R2Courts');
        debugPrint(
          '  round1 resting has P: s3=$s3R1RestingHasP vs s4=$s4R1RestingHasP',
        );
        debugPrint(
          '  round1 resting has Q: s3=$s3R1RestingHasQ vs s4=$s4R1RestingHasQ',
        );
        debugPrint(
          '  round2 resting has P: s3=$s3R2RestingHasP vs s4=$s4R2RestingHasP',
        );
        debugPrint(
          '  round2 resting has Q: s3=$s3R2RestingHasQ vs s4=$s4R2RestingHasQ',
        );

        expect(
          s4R1Courts[1],
          s3R1Courts[1],
          reason:
              'Scenario 4 should produce the same round1 court1 occupant as scenario 3 '
              'if swapPlayers is symmetric in the A/B argument order',
        );
        expect(
          s4R2RestingHasP,
          s3R2RestingHasP,
          reason:
              'Scenario 4 should leave P resting-in-round2 the same as scenario 3 '
              'if swapPlayers is symmetric in the A/B argument order',
        );
        expect(
          s4R1RestingHasP,
          s3R1RestingHasP,
          reason:
              'round1 resting-P status should match between scenario 3 and 4',
        );
        expect(
          s4R2RestingHasQ,
          s3R2RestingHasQ,
          reason:
              'round2 resting-Q status should match between scenario 3 and 4',
        );
      },
    );

    test(
      'Scenario 5: a long sequence of overlapping swaps never duplicates a player within a court',
      () async {
        final db = await openAppDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        );
        addTearDown(container.dispose);
        container.listen(membersControllerProvider, (_, _) {});
        container.listen(sessionsControllerProvider, (_, _) {});

        final membersNotifier = container.read(
          membersControllerProvider.notifier,
        );
        final names = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
        for (final name in names) {
          await membersNotifier.addMember(name, Gender.male);
        }
        final members = await container.read(membersControllerProvider.future);
        final byName = {for (final m in members) m.name: m.id};

        final session = await container
            .read(sessionsControllerProvider.notifier)
            .createSession(DateTime(2026, 1, 3));
        container.listen(sessionControllerProvider(session.id), (_, _) {});
        await container.read(sessionControllerProvider(session.id).future);
        final sessionNotifier = container.read(
          sessionControllerProvider(session.id).notifier,
        );
        await sessionNotifier.updateAttendees(
          members.map((m) => m.id).toList(),
        );

        GameSession state() =>
            container.read(sessionControllerProvider(session.id)).requireValue;

        // 4 rounds, 2 courts each -- everyone starts resting.
        for (var i = 0; i < 4; i++) {
          await sessionNotifier.addEmptyGame(courts: 2);
        }
        final roundIds = state().rounds.map((r) => r.id).toList();

        // Place a handful of players onto courts across the rounds by hand.
        await sessionNotifier.movePlayer(
          roundId: roundIds[0],
          playerId: byName['a']!,
          toCourtNumber: 1,
        );
        await sessionNotifier.movePlayer(
          roundId: roundIds[0],
          playerId: byName['b']!,
          toCourtNumber: 1,
        );
        await sessionNotifier.movePlayer(
          roundId: roundIds[1],
          playerId: byName['c']!,
          toCourtNumber: 2,
        );
        await sessionNotifier.movePlayer(
          roundId: roundIds[2],
          playerId: byName['d']!,
          toCourtNumber: 1,
        );

        // A long, overlapping sequence of same-round AND cross-round swaps,
        // deliberately re-touching the same players/rounds/courts multiple
        // times (the kind of repeated editing a real user session would do),
        // interleaving both directions (A/B argument order).
        final sequence = [
          (roundIds[0], byName['a']!, roundIds[2], byName['d']!),
          (roundIds[2], byName['d']!, roundIds[0], byName['a']!),
          (roundIds[0], byName['b']!, roundIds[1], byName['c']!),
          (roundIds[1], byName['c']!, roundIds[0], byName['b']!),
          (roundIds[0], byName['a']!, roundIds[0], byName['e']!),
          (roundIds[2], byName['a']!, roundIds[3], byName['f']!),
          (roundIds[3], byName['f']!, roundIds[2], byName['a']!),
          (roundIds[1], byName['b']!, roundIds[3], byName['g']!),
          (roundIds[0], byName['e']!, roundIds[1], byName['h']!),
          (roundIds[3], byName['a']!, roundIds[0], byName['h']!),
        ];

        for (final (rA, pA, rB, pB) in sequence) {
          await sessionNotifier.swapPlayers(
            roundIdA: rA,
            playerIdA: pA,
            roundIdB: rB,
            playerIdB: pB,
          );

          // After EVERY swap in the sequence, every court in every round must
          // contain each player at most once -- a duplicate here is exactly
          // the "5 people shown on a 4-person court, with one name twice"
          // symptom reported from the live app.
          for (final round in state().rounds) {
            for (final court in round.courts) {
              final counts = <int, int>{};
              for (final id in court.playerIds) {
                counts[id] = (counts[id] ?? 0) + 1;
              }
              final duplicated = counts.entries
                  .where((e) => e.value > 1)
                  .map((e) => e.key);
              expect(
                duplicated,
                isEmpty,
                reason:
                    'round ${round.id} court ${court.courtNumber} has a duplicated '
                    'player id after swap ($rA/$pA <-> $rB/$pB): '
                    '${court.playerIds}',
              );
            }
          }
        }
      },
    );

    test(
      'Scenario 6: realistic multi-court/multi-round session, cross-round rest<->court swap, full accounting invariant',
      () async {
        final db = await openAppDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        );
        addTearDown(container.dispose);
        container.listen(membersControllerProvider, (_, _) {});
        container.listen(sessionsControllerProvider, (_, _) {});

        final membersNotifier = container.read(
          membersControllerProvider.notifier,
        );
        // 14 members, closer to a real club session than the earlier 6-8
        // person scenarios.
        final names = [
          'a',
          'b',
          'c',
          'd',
          'e',
          'f',
          'g',
          'h',
          'i',
          'j',
          'k',
          'l',
          'm',
          'n',
        ];
        for (final name in names) {
          await membersNotifier.addMember(name, Gender.male);
        }
        final members = await container.read(membersControllerProvider.future);
        final byName = {for (final m in members) m.name: m.id};
        final attendeeIds = members.map((m) => m.id).toList();

        final session = await container
            .read(sessionsControllerProvider.notifier)
            .createSession(DateTime(2026, 1, 4));
        container.listen(sessionControllerProvider(session.id), (_, _) {});
        await container.read(sessionControllerProvider(session.id).future);
        final sessionNotifier = container.read(
          sessionControllerProvider(session.id).notifier,
        );
        await sessionNotifier.updateAttendees(attendeeIds);

        GameSession state() =>
            container.read(sessionControllerProvider(session.id)).requireValue;

        void assertEveryAttendeeAccountedForExactlyOnce(String when) {
          for (final round in state().rounds) {
            final seen = <int, int>{};
            for (final court in round.courts) {
              for (final id in court.playerIds) {
                seen[id] = (seen[id] ?? 0) + 1;
              }
            }
            for (final id in round.restingPlayerIds) {
              seen[id] = (seen[id] ?? 0) + 1;
            }
            for (final id in attendeeIds) {
              expect(
                seen[id] ?? 0,
                1,
                reason:
                    '$when: attendee $id should appear exactly once (across '
                    'all courts + resting) in round ${round.id}, found '
                    '${seen[id] ?? 0} times (courts='
                    '${round.courts.map((c) => c.playerIds)}, '
                    'resting=${round.restingPlayerIds})',
              );
            }
          }
        }

        // 4 rounds, 2 courts each (mirrors the 12-16 player / 2-3 court real
        // sessions this was reported against), everyone starts resting.
        for (var i = 0; i < 4; i++) {
          await sessionNotifier.addEmptyGame(courts: 2);
        }
        final roundIds = state().rounds.map((r) => r.id).toList();

        // Hand-place a realistic, staggered set of court assignments across
        // rounds/courts -- NOT everyone playing every round, multiple courts
        // per round in use, mirroring a real generated schedule.
        // Deliberately leaves 'd' untouched (resting) in round 1 (index 0) --
        // that's the exact pre-condition the reported scenario needs.
        final placements = <(int roundIdx, String name, int court)>[
          (0, 'a', 1),
          (0, 'b', 1),
          (0, 'c', 2),
          (0, 'n', 2),
          (1, 'e', 1),
          (1, 'f', 1),
          (1, 'g', 2),
          (1, 'h', 2),
          (1, 'i', 1),
          (2, 'j', 1),
          (2, 'k', 1),
          (2, 'l', 2),
          (2, 'm', 2),
          (3, 'a', 1),
          (3, 'e', 1),
          (3, 'j', 2),
          (3, 'n', 2),
        ];
        for (final (roundIdx, name, court) in placements) {
          await sessionNotifier.movePlayer(
            roundId: roundIds[roundIdx],
            playerId: byName[name]!,
            toCourtNumber: court,
          );
        }

        assertEveryAttendeeAccountedForExactlyOnce('before any swap');

        // The exact reported scenario: player J is playing a court in round 3
        // (0-indexed round 2 == "game 3"); player D is resting in round 1
        // (0-indexed round 0 == "game 1", never touched by movePlayer above).
        // Drag J's game-3 cell onto D's game-1 cell.
        await sessionNotifier.swapPlayers(
          roundIdA: roundIds[2],
          playerIdA: byName['j']!,
          roundIdB: roundIds[0],
          playerIdB: byName['d']!,
        );

        assertEveryAttendeeAccountedForExactlyOnce(
          'after the cross-round swap',
        );

        final round1After = state().rounds.firstWhere(
          (r) => r.id == roundIds[0],
        );
        final round3After = state().rounds.firstWhere(
          (r) => r.id == roundIds[2],
        );
        final d = byName['d']!;
        final j = byName['j']!;

        // Only the two dragged/dropped cells change: J's round3 cell (was
        // court1) becomes resting (D's old status), and D's round1 cell (was
        // resting) becomes court1 (J's old status) -- D stays in round1, J
        // stays in round3; neither relocates to the other's round.
        final round3Court1 = round3After.courts.firstWhere(
          (c) => c.courtNumber == 1,
        );
        expect(
          round3Court1.playerIds.contains(j),
          isFalse,
          reason: "J should no longer be on round 3's court 1",
        );
        expect(
          round3After.restingPlayerIds.contains(j),
          isTrue,
          reason: "J's round3 cell should become resting (D's old status)",
        );

        final round1Court1 = round1After.courts.firstWhere(
          (c) => c.courtNumber == 1,
        );
        expect(
          round1Court1.playerIds.contains(d),
          isTrue,
          reason: "D's round1 cell should become court 1 (J's old status)",
        );
        expect(
          round1After.restingPlayerIds.contains(d),
          isFalse,
          reason: 'D should no longer be resting in round 1',
        );

        // Collateral / untouched: D's own round3 status and J's own round1
        // status were never part of this swap and must stay exactly as they
        // were (both were resting by default, untouched).
        expect(
          round3After.restingPlayerIds.contains(d),
          isTrue,
          reason:
              "D's own round3 status is unrelated to this swap and "
              'must remain untouched (still resting)',
        );
        expect(
          round1After.restingPlayerIds.contains(j),
          isTrue,
          reason:
              "J's own round1 status is unrelated to this swap and "
              'must remain untouched (still resting)',
        );

        // Also note: player J was ALSO independently playing court 2 in
        // round 4 (untouched by this swap) -- confirm that's undisturbed.
        final round4 = state().rounds.firstWhere((r) => r.id == roundIds[3]);
        final round4Court2 = round4.courts.firstWhere(
          (c) => c.courtNumber == 2,
        );
        expect(
          round4Court2.playerIds.contains(j),
          isTrue,
          reason:
              "J's unrelated round-4 court assignment should be untouched "
              'by a swap that only involves round 1 and round 3',
        );
      },
    );

    test(
      'Scenario 7: same player dragged between two of their own games trades their own two statuses',
      () async {
        final db = await openAppDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        );
        addTearDown(container.dispose);
        container.listen(membersControllerProvider, (_, _) {});
        container.listen(sessionsControllerProvider, (_, _) {});

        final membersNotifier = container.read(
          membersControllerProvider.notifier,
        );
        await membersNotifier.addMember('a', Gender.male);
        await membersNotifier.addMember('x1', Gender.male);
        await membersNotifier.addMember('x2', Gender.male);
        await membersNotifier.addMember('x3', Gender.male);
        final members = await container.read(membersControllerProvider.future);
        final byName = {for (final m in members) m.name: m.id};
        final a = byName['a']!;

        final session = await container
            .read(sessionsControllerProvider.notifier)
            .createSession(DateTime(2026, 1, 5));
        container.listen(sessionControllerProvider(session.id), (_, _) {});
        await container.read(sessionControllerProvider(session.id).future);
        final sessionNotifier = container.read(
          sessionControllerProvider(session.id).notifier,
        );
        await sessionNotifier.updateAttendees(
          members.map((m) => m.id).toList(),
        );

        GameSession state() =>
            container.read(sessionControllerProvider(session.id)).requireValue;

        // Two rounds, 2 courts each -- mirrors the reported layout (custom
        // court numbers/labels, 'a' playing court 1 in round 2 while resting
        // in round 1).
        await sessionNotifier.addEmptyGame(courts: 2);
        await sessionNotifier.addEmptyGame(courts: 2);
        final round1Id = state().rounds[0].id;
        final round2Id = state().rounds[1].id;

        await sessionNotifier.movePlayer(
          roundId: round2Id,
          playerId: a,
          toCourtNumber: 1,
        );

        // Exactly the reported drag: a's game-2 court-1 cell onto a's own
        // game-1 resting cell.
        await sessionNotifier.swapPlayers(
          roundIdA: round2Id,
          playerIdA: a,
          roundIdB: round1Id,
          playerIdB: a,
        );

        final round1After = state().rounds.firstWhere((r) => r.id == round1Id);
        final round2After = state().rounds.firstWhere((r) => r.id == round2Id);

        expect(
          round1After.courts
              .firstWhere((c) => c.courtNumber == 1)
              .playerIds
              .contains(a),
          isTrue,
          reason: 'a should now play court 1 in round 1 (was resting there)',
        );
        expect(
          round2After.restingPlayerIds.contains(a),
          isTrue,
          reason: 'a should now be resting in round 2 (was playing court 1)',
        );
        expect(
          round2After.courts.every((c) => !c.playerIds.contains(a)),
          isTrue,
          reason: 'a should no longer be on any court in round 2',
        );

        // Every other attendee's status in both rounds must be untouched.
        for (final name in ['x1', 'x2', 'x3']) {
          final id = byName[name]!;
          expect(
            round1After.restingPlayerIds.contains(id),
            isTrue,
            reason: '$name should still be resting in round 1, untouched',
          );
          expect(
            round2After.restingPlayerIds.contains(id),
            isTrue,
            reason: '$name should still be resting in round 2, untouched',
          );
        }
      },
    );

    test(
      'Scenario 8: undo restores the state from before the last edit',
      () async {
        final db = await openAppDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        );
        addTearDown(container.dispose);
        container.listen(membersControllerProvider, (_, _) {});
        container.listen(sessionsControllerProvider, (_, _) {});

        final membersNotifier = container.read(
          membersControllerProvider.notifier,
        );
        await membersNotifier.addMember('P', Gender.male);
        await membersNotifier.addMember('Q', Gender.male);
        final members = await container.read(membersControllerProvider.future);
        final byName = {for (final m in members) m.name: m.id};
        final p = byName['P']!;
        final q = byName['Q']!;

        final session = await container
            .read(sessionsControllerProvider.notifier)
            .createSession(DateTime(2026, 1, 7));
        container.listen(sessionControllerProvider(session.id), (_, _) {});
        await container.read(sessionControllerProvider(session.id).future);
        final sessionNotifier = container.read(
          sessionControllerProvider(session.id).notifier,
        );
        await sessionNotifier.updateAttendees(
          members.map((m) => m.id).toList(),
        );

        GameSession state() =>
            container.read(sessionControllerProvider(session.id)).requireValue;

        await sessionNotifier.addEmptyGame(courts: 1);
        final roundId = state().rounds[0].id;

        await sessionNotifier.movePlayer(
          roundId: roundId,
          playerId: p,
          toCourtNumber: 1,
        );
        final afterFirstMove = state();
        expect(
          afterFirstMove.rounds[0].courts.first.playerIds.contains(p),
          isTrue,
        );

        await sessionNotifier.movePlayer(
          roundId: roundId,
          playerId: q,
          toCourtNumber: 1,
        );
        expect(
          state().rounds[0].courts.first.playerIds,
          containsAll([p, q]),
          reason: 'both P and Q should be on the court after the 2nd move',
        );

        // Undo once: back to right after the first move (only P on court).
        await sessionNotifier.undo();
        expect(
          state().rounds[0].courts.first.playerIds,
          [p],
          reason: 'undo should revert only the most recent edit',
        );

        // Undo again: back to the empty starting round (nobody on court).
        await sessionNotifier.undo();
        expect(
          state().rounds[0].courts.first.playerIds,
          isEmpty,
          reason: 'a second undo should revert the first move too',
        );

        // A third undo goes back before addEmptyGame itself (that mutation
        // is undoable too), to zero rounds.
        await sessionNotifier.undo();
        expect(
          state().rounds,
          isEmpty,
          reason: 'a third undo should revert the addEmptyGame call too',
        );

        // No more history left -- undoing again is a safe no-op.
        expect(sessionNotifier.canUndo, isFalse);
        await sessionNotifier.undo();
        expect(
          state().rounds,
          isEmpty,
          reason: 'undo with no more history left should be a no-op',
        );
      },
    );
  });
}
