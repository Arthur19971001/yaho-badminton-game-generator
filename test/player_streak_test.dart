import 'package:flutter_test/flutter_test.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/court_assignment.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/game_round.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/presentation/widgets/player_streak.dart';

GameRound roundWith({required int id, required List<int> playing, required List<int> resting}) {
  return GameRound(
    id: id,
    gameNumber: id,
    courts: [CourtAssignment(courtNumber: 1, playerIds: playing)],
    restingPlayerIds: resting,
  );
}

void main() {
  group('consecutiveGamesPlayed', () {
    test('increments as the run progresses, not a fixed total', () {
      // Player 1 plays games 1-3 straight -- game1 shows 1, game2 shows 2,
      // game3 shows 3 (counting up TO that game, inclusive).
      final rounds = [
        roundWith(id: 1, playing: [1, 2, 3, 4], resting: []),
        roundWith(id: 2, playing: [1, 2, 3, 4], resting: []),
        roundWith(id: 3, playing: [1, 2, 3, 4], resting: []),
      ];
      expect(consecutiveGamesPlayed(rounds, 0, 1), 1);
      expect(consecutiveGamesPlayed(rounds, 1, 1), 2);
      expect(consecutiveGamesPlayed(rounds, 2, 1), 3);
    });

    test('a rest in between restarts the count from 1', () {
      // Player 1 plays 1-3, rests game 4, plays 5-6: games 1/2/3 show
      // 1/2/3, game4 shows 0 (resting), games 5/6 show 1/2.
      final rounds = [
        roundWith(id: 1, playing: [1, 2, 3, 4], resting: []),
        roundWith(id: 2, playing: [1, 2, 3, 4], resting: []),
        roundWith(id: 3, playing: [1, 2, 3, 4], resting: []),
        roundWith(id: 4, playing: [2, 3, 4, 5], resting: [1]),
        roundWith(id: 5, playing: [1, 2, 3, 4], resting: []),
        roundWith(id: 6, playing: [1, 2, 3, 4], resting: []),
      ];
      expect(consecutiveGamesPlayed(rounds, 0, 1), 1);
      expect(consecutiveGamesPlayed(rounds, 1, 1), 2);
      expect(consecutiveGamesPlayed(rounds, 2, 1), 3);
      expect(consecutiveGamesPlayed(rounds, 3, 1), 0); // resting
      expect(consecutiveGamesPlayed(rounds, 4, 1), 1);
      expect(consecutiveGamesPlayed(rounds, 5, 1), 2);
    });

    test('returns 0 for a player resting in the given round', () {
      final rounds = [
        roundWith(id: 1, playing: [1, 2, 3, 4], resting: []),
        roundWith(id: 2, playing: [2, 3, 4, 5], resting: [1]),
      ];
      expect(consecutiveGamesPlayed(rounds, 1, 1), 0);
    });

    test('a single isolated game played is a streak of 1', () {
      final rounds = [
        roundWith(id: 1, playing: [1, 2, 3, 4], resting: [5]),
        roundWith(id: 2, playing: [2, 3, 4, 5], resting: [1]),
      ];
      expect(consecutiveGamesPlayed(rounds, 0, 1), 1);
      expect(consecutiveGamesPlayed(rounds, 0, 5), 0);
    });

    test('later games in the same run keep counting past a game with no prior history', () {
      // Games seen so far only start at index 0 in these tests, but a
      // player playing straight through to round 4 should show 4, not
      // reset early.
      final rounds = [
        roundWith(id: 1, playing: [1], resting: []),
        roundWith(id: 2, playing: [1], resting: []),
        roundWith(id: 3, playing: [1], resting: []),
        roundWith(id: 4, playing: [1], resting: []),
      ];
      expect(consecutiveGamesPlayed(rounds, 3, 1), 4);
    });
  });
}
