import '../../domain/game_round.dart';

bool _isPlaying(GameRound round, int playerId) =>
    round.courts.any((court) => court.playerIds.contains(playerId));

/// How many games in a row [playerId] has played (regardless of which
/// court), counting backward from [roundIndex] *inclusive* and stopping at
/// the first earlier game they weren't playing -- an incrementing count as
/// the run progresses, not the run's total length. e.g. if a player plays
/// games 1-3, rests game 4, then plays games 5-6: game1 shows "1", game2
/// shows "2", game3 shows "3", game4 shows "0" (resting), game5 shows "1",
/// game6 shows "2". Returns 0 if the player isn't playing in [roundIndex].
int consecutiveGamesPlayed(
  List<GameRound> rounds,
  int roundIndex,
  int playerId,
) {
  if (!_isPlaying(rounds[roundIndex], playerId)) return 0;

  var count = 1;
  var i = roundIndex - 1;
  while (i >= 0 && _isPlaying(rounds[i], playerId)) {
    count++;
    i--;
  }

  return count;
}
