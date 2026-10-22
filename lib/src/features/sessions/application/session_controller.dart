import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../grades/data/grades_repository.dart';
import '../../grades/domain/grade.dart';
import '../../members/data/members_repository.dart';
import '../../members/domain/gender.dart';
import '../../members/domain/member.dart';
import '../data/sessions_repository.dart';
import '../domain/court_assignment.dart';
import '../domain/game_generator.dart';
import '../domain/game_round.dart';
import '../domain/game_session.dart';
import 'sessions_controller.dart';

part 'session_controller.g.dart';

@riverpod
class SessionController extends _$SessionController {
  Future<void> _mutationQueue = Future.value();

  /// Snapshots of this session from just before each mutation, most-recent
  /// last, for [undo]. Capped so a very long editing session doesn't grow
  /// this unboundedly.
  static const _maxHistory = 50;
  final List<GameSession> _history = [];

  @override
  Future<GameSession> build(int sessionId) async {
    final repo = await ref.watch(sessionsRepositoryProvider.future);
    final session = await repo.getById(sessionId);
    if (session == null) {
      throw StateError('Session $sessionId not found');
    }
    return session;
  }

  /// Runs [action] only after every previously-queued mutation for this
  /// session has fully finished (read, compute, persist). Without this, two
  /// mutations issued back-to-back -- e.g. two quick drags, or a delete
  /// fired while a generate is still saving -- would each read the same
  /// stale `state.requireValue` and whichever finishes its persist last
  /// would silently overwrite the other's change.
  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _mutationQueue.then((_) => action());
    _mutationQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _persist(GameSession session) async {
    final previous = state.value;
    if (previous != null) {
      _history.add(previous);
      if (_history.length > _maxHistory) _history.removeAt(0);
    }
    final repo = await ref.read(sessionsRepositoryProvider.future);
    await repo.save(session);
    state = AsyncData(session);
  }

  bool get canUndo => _history.isNotEmpty;

  /// Restores this session to how it was just before the last edit
  /// (drag/swap/reorder/generate/etc.) -- bound to Cmd+Z on the results
  /// screen. Repeated calls keep walking further back through [_history].
  /// Does NOT itself get pushed onto the undo history, so undoing twice in
  /// a row goes back two edits rather than undoing the undo.
  Future<void> undo() {
    return _serialized(() async {
      if (_history.isEmpty) return;
      final previous = _history.removeLast();
      final repo = await ref.read(sessionsRepositoryProvider.future);
      await repo.save(previous);
      // Attendees live in their own table, not in the session row that
      // save() writes -- restore them too when the undone edit changed
      // them (guest add/remove, removing a player).
      if (!listEquals(previous.attendeeIds, state.value?.attendeeIds)) {
        await repo.setAttendees(sessionId, previous.attendeeIds);
        ref.invalidate(sessionsControllerProvider);
      }
      state = AsyncData(previous);
    });
  }

  Future<void> updateAttendees(List<int> memberIds) {
    return _serialized(() async {
      final repo = await ref.read(sessionsRepositoryProvider.future);
      await repo.setAttendees(sessionId, memberIds);
      final current = state.requireValue;
      state = AsyncData(current.copyWith(attendeeIds: memberIds));
      ref.invalidate(sessionsControllerProvider);
    });
  }

  /// Adds a one-off guest (not a club member) to this session and marks
  /// them as attending immediately. Guests live only inside this session's
  /// own data -- they're never written to the `members` table, so they
  /// never show up in the club roster or in any other session.
  Future<void> addGuest(String name, Gender gender, {int? gradeId}) {
    return _serialized(() async {
      final current = state.requireValue;
      final nextGuestId = current.guests.isEmpty
          ? -1
          : current.guests
                  .map((g) => g.id)
                  .reduce((a, b) => a < b ? a : b) -
              1;
      final guest = Member(
        id: nextGuestId,
        name: name,
        gender: gender,
        gradeId: gradeId,
      );
      final newAttendeeIds = [...current.attendeeIds, nextGuestId];

      final repo = await ref.read(sessionsRepositoryProvider.future);
      await repo.setAttendees(sessionId, newAttendeeIds);
      await _persist(current.copyWith(
        guests: [...current.guests, guest],
        attendeeIds: newAttendeeIds,
      ));
      ref.invalidate(sessionsControllerProvider);
    });
  }

  /// Removes a guest from the roster and today's attendee list. Any rounds
  /// already generated with them keep referencing their id -- same as a
  /// deleted club member, they'll show up there as an unknown player rather
  /// than rewriting history.
  Future<void> removeGuest(int guestId) {
    return _serialized(() async {
      final current = state.requireValue;
      final newGuests = current.guests.where((g) => g.id != guestId).toList();
      final newAttendeeIds =
          current.attendeeIds.where((id) => id != guestId).toList();

      final repo = await ref.read(sessionsRepositoryProvider.future);
      await repo.setAttendees(sessionId, newAttendeeIds);
      await _persist(current.copyWith(
        guests: newGuests,
        attendeeIds: newAttendeeIds,
      ));
      ref.invalidate(sessionsControllerProvider);
    });
  }

  /// Sets custom display labels for each court (e.g. the venue's own court
  /// numbers), independent of generating/adding games. [names] is indexed
  /// by courtNumber - 1; a blank or missing entry falls back to "코트 N".
  Future<void> updateCourtNames(List<String> names) {
    return _serialized(() async {
      final current = state.requireValue;
      await _persist(current.copyWith(courtNames: names));
    });
  }

  /// Runs the generator against the full round history so far and appends
  /// the newly generated rounds -- used both for the first "generate N
  /// games" action and for later "add N more games" actions.
  Future<void> generateGames({
    required int courts,
    required int gamesToGenerate,
    required bool genderBalance,
    bool gradeBalance = false,
  }) {
    return _serialized(() async {
      final current = state.requireValue;
      final membersRepo = await ref.read(membersRepositoryProvider.future);
      final allMembers = await membersRepo.getAll();
      final attendeeSet = current.attendeeIds.toSet();
      final attendees = [...allMembers, ...current.guests]
          .where((m) => attendeeSet.contains(m.id))
          .toList();

      Map<int, int>? gradePoints;
      if (gradeBalance) {
        final gradesRepo = await ref.read(gradesRepositoryProvider.future);
        gradePoints = resolveGradePoints(
          {for (final m in attendees) m.id: m.gradeId},
          await gradesRepo.getAll(),
        );
      }

      final newRounds = GameGenerator().generate(
        attendees: attendees,
        courts: courts,
        gamesToGenerate: gamesToGenerate,
        genderBalance: genderBalance,
        gradePoints: gradePoints,
        existingRounds: current.rounds,
      );

      await _persist(current.copyWith(
        courts: courts,
        genderBalance: genderBalance,
        gradeBalance: gradeBalance,
        rounds: [...current.rounds, ...newRounds],
      ));
      ref.invalidate(sessionsControllerProvider);
    });
  }

  /// Creates one new round with empty courts and everyone marked resting,
  /// so the user can build a game entirely by hand via drag-and-drop
  /// instead of running the balancing algorithm.
  Future<void> addEmptyGame({required int courts}) {
    return _serialized(() async {
      final current = state.requireValue;
      final nextGameNumber = current.rounds.isEmpty
          ? 1
          : current.rounds
                  .map((r) => r.gameNumber)
                  .reduce((a, b) => a > b ? a : b) +
              1;

      final round = GameRound(
        id: GameRound.nextId(current.rounds),
        gameNumber: nextGameNumber,
        courts: [
          for (var i = 0; i < courts; i++)
            CourtAssignment(courtNumber: i + 1, playerIds: const []),
        ],
        restingPlayerIds: List.of(current.attendeeIds),
      );

      await _persist(current.copyWith(rounds: [...current.rounds, round]));
      ref.invalidate(sessionsControllerProvider);
    });
  }

  Future<void> deleteGame(int roundId) {
    return _serialized(() async {
      final current = state.requireValue;
      final remaining = current.rounds.where((r) => r.id != roundId).toList();
      final renumbered = [
        for (var i = 0; i < remaining.length; i++)
          remaining[i].copyWith(gameNumber: i + 1),
      ];
      await _persist(current.copyWith(rounds: renumbered));
      ref.invalidate(sessionsControllerProvider);
    });
  }

  /// Deletes a single court from one game, moving anyone who was on it to
  /// that game's resting bench instead of dropping them. If that was the
  /// game's last court, the whole game is deleted too (same renumbering as
  /// [deleteGame]) -- a game with zero courts left has nothing to show.
  Future<void> deleteCourt({
    required int roundId,
    required int courtNumber,
  }) {
    return _serialized(() async {
      final current = state.requireValue;
      final roundIndex = current.rounds.indexWhere((r) => r.id == roundId);
      if (roundIndex == -1) return;
      final round = current.rounds[roundIndex];
      final courtIndex =
          round.courts.indexWhere((c) => c.courtNumber == courtNumber);
      if (courtIndex == -1) return;

      final removedCourt = round.courts[courtIndex];
      final remainingCourts = [...round.courts]..removeAt(courtIndex);
      final newResting = [...round.restingPlayerIds];
      for (final playerId in removedCourt.playerIds) {
        if (!newResting.contains(playerId)) newResting.add(playerId);
      }

      if (remainingCourts.isEmpty) {
        final remaining =
            current.rounds.where((r) => r.id != roundId).toList();
        final renumbered = [
          for (var i = 0; i < remaining.length; i++)
            remaining[i].copyWith(gameNumber: i + 1),
        ];
        await _persist(current.copyWith(rounds: renumbered));
      } else {
        final newRounds = [...current.rounds];
        newRounds[roundIndex] = round.copyWith(
          courts: remainingCourts,
          restingPlayerIds: newResting,
        );
        await _persist(current.copyWith(rounds: newRounds));
      }
      ref.invalidate(sessionsControllerProvider);
    });
  }

  /// Same as [deleteCourt], but for every game that has a court numbered
  /// [courtNumber] -- e.g. the venue's court itself became unavailable for
  /// the rest of the session, not just for one game. Any game left with
  /// zero courts by this is deleted too, and the remaining games
  /// renumbered once at the end (not per removal).
  Future<void> deleteCourtFromAllGames(int courtNumber) {
    return _serialized(() async {
      final current = state.requireValue;
      final updatedRounds = <GameRound>[];
      for (final round in current.rounds) {
        final courtIndex =
            round.courts.indexWhere((c) => c.courtNumber == courtNumber);
        if (courtIndex == -1) {
          updatedRounds.add(round);
          continue;
        }
        final removedCourt = round.courts[courtIndex];
        final remainingCourts = [...round.courts]..removeAt(courtIndex);
        if (remainingCourts.isEmpty) continue;
        final newResting = [...round.restingPlayerIds];
        for (final playerId in removedCourt.playerIds) {
          if (!newResting.contains(playerId)) newResting.add(playerId);
        }
        updatedRounds.add(
          round.copyWith(courts: remainingCourts, restingPlayerIds: newResting),
        );
      }
      final renumbered = [
        for (var i = 0; i < updatedRounds.length; i++)
          updatedRounds[i].copyWith(gameNumber: i + 1),
      ];
      await _persist(current.copyWith(rounds: renumbered));
      ref.invalidate(sessionsControllerProvider);
    });
  }

  /// "사용자 빼기": takes [playerId] out of every game numbered
  /// [fromGameNumber] or later (their court spot is left empty -- flagged
  /// as under capacity -- and they're dropped from that game's bench), and
  /// removes them from today's attendees so later "게임 추가 생성" runs
  /// don't bring them back. [fromGameNumber] 0 leaves every existing game
  /// untouched and only removes them from the attendee list. Guests keep
  /// their guest entry so earlier games still show their name. Undoable.
  Future<void> removePlayerFromGames({
    required int playerId,
    required int fromGameNumber,
  }) {
    return _serialized(() async {
      final current = state.requireValue;
      final newRounds = [
        for (final round in current.rounds)
          if (fromGameNumber < 1 || round.gameNumber < fromGameNumber)
            round
          else
            round.copyWith(
              courts: [
                for (final court in round.courts)
                  court.copyWith(
                    playerIds:
                        court.playerIds.where((id) => id != playerId).toList(),
                  ),
              ],
              restingPlayerIds: round.restingPlayerIds
                  .where((id) => id != playerId)
                  .toList(),
            ),
      ];
      final newAttendeeIds =
          current.attendeeIds.where((id) => id != playerId).toList();

      final repo = await ref.read(sessionsRepositoryProvider.future);
      await repo.setAttendees(sessionId, newAttendeeIds);
      await _persist(current.copyWith(
        rounds: newRounds,
        attendeeIds: newAttendeeIds,
      ));
      ref.invalidate(sessionsControllerProvider);
    });
  }

  /// Reorders the game list (e.g. via drag handle in the table view).
  /// `newIndex` follows [ReorderableListView] semantics (already accounts
  /// for the removed item), and games are renumbered 1..N to match their
  /// new position -- their stable [GameRound.id] is left untouched.
  Future<void> reorderGames(int oldIndex, int newIndex) {
    return _serialized(() async {
      final current = state.requireValue;
      final rounds = [...current.rounds];
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = rounds.removeAt(oldIndex);
      rounds.insert(newIndex, moved);
      final renumbered = [
        for (var i = 0; i < rounds.length; i++)
          rounds[i].copyWith(gameNumber: i + 1),
      ];
      await _persist(current.copyWith(rounds: renumbered));
    });
  }

  /// Moves [playerId] within round [roundId] to court [toCourtNumber], or
  /// to the resting bench when [toCourtNumber] is null. Used by the results
  /// screen's drag-and-drop reassignment. Does not enforce the 4-per-court
  /// cap -- the UI is responsible for flagging courts that end up over
  /// capacity so the user can fix the mistake themselves. Keys off the
  /// round's stable [GameRound.id] rather than its display-only gameNumber,
  /// since delete/reorder can renumber games while a drag is in flight.
  Future<void> movePlayer({
    required int roundId,
    required int playerId,
    required int? toCourtNumber,
  }) {
    return _serialized(() async {
      final current = state.requireValue;
      final roundIndex = current.rounds.indexWhere((r) => r.id == roundId);
      if (roundIndex == -1) return;
      final round = current.rounds[roundIndex];

      final newCourts = [
        for (final court in round.courts)
          court.copyWith(
            playerIds: court.playerIds.where((id) => id != playerId).toList(),
          ),
      ];
      final newResting =
          round.restingPlayerIds.where((id) => id != playerId).toList();

      if (toCourtNumber == null) {
        newResting.add(playerId);
      } else {
        final courtIndex =
            newCourts.indexWhere((c) => c.courtNumber == toCourtNumber);
        if (courtIndex == -1) return;
        newCourts[courtIndex] = newCourts[courtIndex].copyWith(
          playerIds: [...newCourts[courtIndex].playerIds, playerId],
        );
      }

      final newRounds = [...current.rounds];
      newRounds[roundIndex] =
          round.copyWith(courts: newCourts, restingPlayerIds: newResting);
      await _persist(current.copyWith(rounds: newRounds));
    });
  }

  /// Swaps exactly the two dragged-from/dropped-onto cells: whichever
  /// court (or the resting bench) [playerIdA] held in round [roundIdA] now
  /// holds [playerIdB], and whatever [playerIdB] held in round [roundIdB]
  /// now holds [playerIdA]. Nothing else changes -- in particular,
  /// [playerIdB]'s own (unrelated) status in round [roundIdA] and
  /// [playerIdA]'s own (unrelated) status in round [roundIdB] are left
  /// exactly as they were, even if either of them independently had some
  /// activity there. E.g. dragging A's game-3 court cell onto B's game-4
  /// resting cell changes ONLY those two cells: A's game-3 becomes resting,
  /// B's game-4 becomes that court -- B's own game-3 status and A's own
  /// game-4 status are untouched.
  ///
  /// When [roundIdA] == [roundIdB] this is a same-round swap (used by the
  /// table view: dropping a chip directly onto another one there) -- with
  /// only one round involved there's no "other round" to leave untouched,
  /// so it's just a direct trade of the two players' statuses within that
  /// round.
  ///
  /// For a cross-round swap, the destination court is matched by court
  /// *number* (stable across rounds) rather than by court-list index, so
  /// this also handles [playerIdA] == [playerIdB] correctly -- the same
  /// person dragged between two of their own games trades their own two
  /// statuses between those rounds.
  Future<void> swapPlayers({
    required int roundIdA,
    required int playerIdA,
    required int roundIdB,
    required int playerIdB,
  }) {
    return _serialized(() async {
      if (roundIdA == roundIdB && playerIdA == playerIdB) return;
      final current = state.requireValue;
      final roundIndexA = current.rounds.indexWhere((r) => r.id == roundIdA);
      final roundIndexB = current.rounds.indexWhere((r) => r.id == roundIdB);
      if (roundIndexA == -1 || roundIndexB == -1) return;

      int? courtIndexOf(GameRound round, int playerId) {
        for (var i = 0; i < round.courts.length; i++) {
          if (round.courts[i].playerIds.contains(playerId)) return i;
        }
        return null;
      }

      final newRounds = [...current.rounds];

      if (roundIndexA == roundIndexB) {
        final round = newRounds[roundIndexA];
        final courts = [...round.courts];
        var resting = [...round.restingPlayerIds];
        final courtIndexA = courtIndexOf(round, playerIdA);
        final courtIndexB = courtIndexOf(round, playerIdB);

        void removeFrom(int? courtIndex, int playerId) {
          if (courtIndex != null) {
            courts[courtIndex] = courts[courtIndex].copyWith(
              playerIds:
                  courts[courtIndex].playerIds.where((id) => id != playerId).toList(),
            );
          } else {
            resting = resting.where((id) => id != playerId).toList();
          }
        }

        void addTo(int? courtIndex, int playerId) {
          if (courtIndex != null) {
            if (courts[courtIndex].playerIds.contains(playerId)) return;
            courts[courtIndex] = courts[courtIndex]
                .copyWith(playerIds: [...courts[courtIndex].playerIds, playerId]);
          } else {
            if (resting.contains(playerId)) return;
            resting.add(playerId);
          }
        }

        removeFrom(courtIndexA, playerIdA);
        removeFrom(courtIndexB, playerIdB);
        addTo(courtIndexB, playerIdA);
        addTo(courtIndexA, playerIdB);

        newRounds[roundIndexA] =
            round.copyWith(courts: courts, restingPlayerIds: resting);
      } else {
        final roundA = newRounds[roundIndexA];
        final roundB = newRounds[roundIndexB];
        final courtIndexInA = courtIndexOf(roundA, playerIdA);
        final courtIndexInB = courtIndexOf(roundB, playerIdB);
        final courtNumberInA =
            courtIndexInA == null ? null : roundA.courts[courtIndexInA].courtNumber;
        final courtNumberInB =
            courtIndexInB == null ? null : roundB.courts[courtIndexInB].courtNumber;

        GameRound applyCellSwap(
          GameRound round,
          int playerId,
          int? removeFromCourtIndex,
          int? addToCourtNumber,
        ) {
          final courts = [...round.courts];
          var resting = [...round.restingPlayerIds];

          if (removeFromCourtIndex != null) {
            courts[removeFromCourtIndex] = courts[removeFromCourtIndex].copyWith(
              playerIds: courts[removeFromCourtIndex]
                  .playerIds
                  .where((id) => id != playerId)
                  .toList(),
            );
          } else {
            resting = resting.where((id) => id != playerId).toList();
          }

          final targetIndex = addToCourtNumber == null
              ? -1
              : courts.indexWhere((c) => c.courtNumber == addToCourtNumber);
          if (targetIndex != -1) {
            if (!courts[targetIndex].playerIds.contains(playerId)) {
              courts[targetIndex] = courts[targetIndex].copyWith(
                playerIds: [...courts[targetIndex].playerIds, playerId],
              );
            }
          } else if (!resting.contains(playerId)) {
            // No court by that number in this round (e.g. different court
            // counts per round) -- fall back to resting rather than drop
            // the player entirely.
            resting.add(playerId);
          }

          return round.copyWith(courts: courts, restingPlayerIds: resting);
        }

        newRounds[roundIndexA] =
            applyCellSwap(roundA, playerIdA, courtIndexInA, courtNumberInB);
        newRounds[roundIndexB] =
            applyCellSwap(roundB, playerIdB, courtIndexInB, courtNumberInA);
      }

      await _persist(current.copyWith(rounds: newRounds));
    });
  }

  /// Swaps two games' positions directly -- unlike [reorderGames], which
  /// shifts everything between the old and new position, this only ever
  /// touches the two given rounds (and their gameNumber labels), so
  /// dragging either one's header onto the other always exchanges them,
  /// regardless of which was dragged from/to or which has the lower game
  /// number.
  Future<void> swapGamePositions(int roundIdA, int roundIdB) {
    return _serialized(() async {
      if (roundIdA == roundIdB) return;
      final current = state.requireValue;
      final indexA = current.rounds.indexWhere((r) => r.id == roundIdA);
      final indexB = current.rounds.indexWhere((r) => r.id == roundIdB);
      if (indexA == -1 || indexB == -1) return;

      final rounds = [...current.rounds];
      final roundA = rounds[indexA];
      final roundB = rounds[indexB];
      rounds[indexA] = roundB.copyWith(gameNumber: roundA.gameNumber);
      rounds[indexB] = roundA.copyWith(gameNumber: roundB.gameNumber);

      await _persist(current.copyWith(rounds: rounds));
    });
  }
}
