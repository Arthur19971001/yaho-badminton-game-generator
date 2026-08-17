import 'dart:math';

import '../../members/domain/gender.dart';
import '../../members/domain/member.dart';
import 'court_assignment.dart';
import 'game_round.dart';

/// Generates balanced badminton doubles rounds for a session.
///
/// Fairness goals (in priority order):
///  1. Every court always has exactly 4 players.
///  2. If [genderBalance] is on, every court is either 2 male + 2 female,
///     or all-male, or all-female -- never a 3:1 split.
///  3. Play count stays as even as possible across all attendees (players
///     who have played less so far are prioritized for the next round).
///  4. Players are paired with people they haven't shared a court with yet
///     as much as possible.
///
/// [existingRounds] seeds the fairness bookkeeping so that calling this
/// again to "add N more games" continues optimizing from the full history
/// instead of restarting from scratch.
class GameGenerator {
  GameGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<GameRound> generate({
    required List<Member> attendees,
    required int courts,
    required int gamesToGenerate,
    required bool genderBalance,
    List<GameRound> existingRounds = const [],
  }) {
    if (attendees.length < 4 || courts < 1 || gamesToGenerate < 1) return [];

    // Keyed by id so a caller accidentally passing duplicate-id entries
    // can't make the same person occupy two slots in the same round.
    final memberById = {for (final m in attendees) m.id: m};
    final ids = memberById.keys.toList();
    final idSet = ids.toSet();

    final playCount = <int, int>{for (final id in ids) id: 0};
    final togetherCount = <int, Map<int, int>>{for (final id in ids) id: {}};

    void applyCourt(List<int> playerIds) {
      for (final playerId in playerIds) {
        playCount[playerId] = (playCount[playerId] ?? 0) + 1;
      }
      for (var i = 0; i < playerIds.length; i++) {
        for (var j = i + 1; j < playerIds.length; j++) {
          final a = playerIds[i];
          final b = playerIds[j];
          togetherCount[a]![b] = (togetherCount[a]![b] ?? 0) + 1;
          togetherCount[b]![a] = (togetherCount[b]![a] ?? 0) + 1;
        }
      }
    }

    void recordRound(GameRound round) {
      for (final court in round.courts) {
        applyCourt(court.playerIds);
      }
    }

    // Seed fairness bookkeeping from history, ignoring anyone who isn't
    // part of today's attendee set.
    for (final round in existingRounds) {
      for (final court in round.courts) {
        applyCourt(court.playerIds.where(idSet.contains).toList());
      }
    }

    var nextGameNumber = existingRounds.isEmpty
        ? 1
        : existingRounds.map((r) => r.gameNumber).reduce(max) + 1;
    var nextId = GameRound.nextId(existingRounds);

    final slotsPerRound = courts * 4;
    final generated = <GameRound>[];

    for (var g = 0; g < gamesToGenerate; g++) {
      final round = _generateRound(
        id: nextId,
        gameNumber: nextGameNumber,
        ids: ids,
        memberById: memberById,
        playCount: playCount,
        togetherCount: togetherCount,
        slotsPerRound: slotsPerRound,
        genderBalance: genderBalance,
      );
      if (round == null) break;

      nextGameNumber++;
      nextId++;
      recordRound(round);
      generated.add(round);
    }

    return generated;
  }

  GameRound? _generateRound({
    required int id,
    required int gameNumber,
    required List<int> ids,
    required Map<int, Member> memberById,
    required Map<int, int> playCount,
    required Map<int, Map<int, int>> togetherCount,
    required int slotsPerRound,
    required bool genderBalance,
  }) {
    var target = (min(ids.length, slotsPerRound) ~/ 4) * 4;
    if (target < 4) return null;

    List<int> playingMales = const [];
    List<int> playingFemales = const [];

    if (genderBalance) {
      final males = ids
          .where((id) => memberById[id]!.gender == Gender.male)
          .toList();
      final females = ids
          .where((id) => memberById[id]!.gender == Gender.female)
          .toList();

      _PmSplit? split;
      while (target >= 4) {
        split = _findFeasibleSplit(target, males, females);
        if (split != null) break;
        target -= 4;
      }
      if (split == null) return null;

      playingMales = _pickByPriority(males, split.malesPlaying, playCount);
      playingFemales =
          _pickByPriority(females, split.femalesPlaying, playCount);
    }

    final playing = genderBalance
        ? [...playingMales, ...playingFemales]
        : _pickByPriority(ids, target, playCount);

    final resting = ids.where((id) => !playing.contains(id)).toList();

    final courtGroups = genderBalance
        ? _assignGenderBalancedCourts(
            playingMales, playingFemales, memberById, togetherCount)
        : _groupIntoFours(playing, togetherCount);

    courtGroups.shuffle(_random);

    return GameRound(
      id: id,
      gameNumber: gameNumber,
      courts: [
        for (var i = 0; i < courtGroups.length; i++)
          CourtAssignment(courtNumber: i + 1, playerIds: courtGroups[i]),
      ],
      restingPlayerIds: resting,
    );
  }

  /// Picks how many males vs. females play this round out of [target] total
  /// slots so that court composition can stay strictly 2:2 / 4:0 / 0:4.
  /// Only even male/female counts admit that split, so this searches every
  /// even split closest to a proportional share.
  _PmSplit? _findFeasibleSplit(
    int target,
    List<int> males,
    List<int> females,
  ) {
    final totalPeople = males.length + females.length;
    // Proportional to each gender's share of the attendee pool -- this is
    // what keeps per-person play counts balanced *across* genders, since it
    // makes pm/males.length == pf/females.length (equal participation
    // rate for both genders every round), not just within one gender.
    final naturalPm =
        totalPeople == 0 ? 0.0 : target * males.length / totalPeople;

    _PmSplit? best;
    var bestDiff = double.infinity;

    final upperBound = min(males.length, target);
    for (var pm = 0; pm <= upperBound; pm += 2) {
      final pf = target - pm;
      if (pf < 0 || pf > females.length) continue;
      final diff = (pm - naturalPm).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = _PmSplit(pm, pf);
      }
    }
    return best;
  }

  /// Takes the [count] players with the lowest play count so far (i.e. most
  /// deserving of a game), shuffling ties so repeated runs don't always
  /// bench/prioritize the same people.
  List<int> _pickByPriority(
    List<int> pool,
    int count,
    Map<int, int> playCount,
  ) {
    final sorted = [...pool]..shuffle(_random);
    sorted.sort((a, b) => playCount[a]!.compareTo(playCount[b]!));
    return sorted.take(count).toList();
  }

  List<List<int>> _assignGenderBalancedCourts(
    List<int> playingMales,
    List<int> playingFemales,
    Map<int, Member> memberById,
    Map<int, Map<int, int>> togetherCount,
  ) {
    final malesPool = [...playingMales];
    final femalesPool = [...playingFemales];

    var mixedCourts = min(malesPool.length, femalesPool.length) ~/ 2;
    while (mixedCourts > 0) {
      final remainingMales = malesPool.length - mixedCourts * 2;
      final remainingFemales = femalesPool.length - mixedCourts * 2;
      if (remainingMales % 4 == 0 && remainingFemales % 4 == 0) break;
      mixedCourts--;
    }

    final groups = <List<int>>[];
    for (var i = 0; i < mixedCourts; i++) {
      final malePair = _pickPair(malesPool, togetherCount);
      final femalePair = _pickPair(femalesPool, togetherCount);
      groups.add([...malePair, ...femalePair]);
    }

    groups.addAll(_groupIntoFours(malesPool, togetherCount));
    groups.addAll(_groupIntoFours(femalesPool, togetherCount));
    return groups;
  }

  /// Removes and returns 2 ids from [pool], preferring the pair that has
  /// shared a court together the least so far.
  List<int> _pickPair(List<int> pool, Map<int, Map<int, int>> togetherCount) {
    pool.shuffle(_random);
    final a = pool.removeAt(0);
    pool.sort((x, y) =>
        (togetherCount[a]?[x] ?? 0).compareTo(togetherCount[a]?[y] ?? 0));
    final b = pool.removeAt(0);
    return [a, b];
  }

  /// Greedily partitions [pool] (expected to have a length that's a
  /// multiple of 4) into groups of 4, minimizing repeat pairings.
  List<List<int>> _groupIntoFours(
    List<int> pool,
    Map<int, Map<int, int>> togetherCount,
  ) {
    final remaining = [...pool]..shuffle(_random);
    final groups = <List<int>>[];

    while (remaining.length >= 4) {
      final seed = remaining.removeAt(0);
      final group = [seed];
      for (var i = 0; i < 3 && remaining.isNotEmpty; i++) {
        remaining.sort((a, b) {
          final costA =
              group.fold(0, (sum, p) => sum + (togetherCount[p]?[a] ?? 0));
          final costB =
              group.fold(0, (sum, p) => sum + (togetherCount[p]?[b] ?? 0));
          return costA.compareTo(costB);
        });
        group.add(remaining.removeAt(0));
      }
      groups.add(group);
    }
    return groups;
  }
}

class _PmSplit {
  const _PmSplit(this.malesPlaying, this.femalesPlaying);
  final int malesPlaying;
  final int femalesPlaying;
}
