import 'game_round.dart';

/// How many times each other player shared a court with [playerId] in
/// `rounds[0..throughIndex]` (inclusive) -- partners and opponents alike.
/// Players who never shared a court with them are absent (count 0).
/// [throughIndex] is clamped to the available rounds, so passing the last
/// index (or anything beyond) covers the whole session.
Map<int, int> courtmateCounts(
  List<GameRound> rounds, {
  required int playerId,
  required int throughIndex,
}) {
  final counts = <int, int>{};
  final last = throughIndex.clamp(-1, rounds.length - 1);
  for (var i = 0; i <= last; i++) {
    for (final court in rounds[i].courts) {
      if (!court.playerIds.contains(playerId)) continue;
      for (final other in court.playerIds) {
        if (other == playerId) continue;
        counts[other] = (counts[other] ?? 0) + 1;
      }
    }
  }
  return counts;
}
