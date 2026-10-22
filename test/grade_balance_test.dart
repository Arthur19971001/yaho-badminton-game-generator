import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaho_badminton_game_generator/src/features/grades/domain/grade.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/gender.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/member.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/court_assignment.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/courtmate_counts.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/game_generator.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/game_round.dart';

const _gradeA = Grade(id: 1, name: 'A', points: 10, sortOrder: 0);
const _gradeB = Grade(id: 2, name: 'B', points: 8, sortOrder: 1);
const _gradeC = Grade(id: 3, name: 'C', points: 6, sortOrder: 2);
const _gradeD = Grade(id: 4, name: 'D', points: 4, sortOrder: 3);
const _grades = [_gradeA, _gradeB, _gradeC, _gradeD];

/// Smallest |team1 - team2| point gap over the 2-vs-2 splits of [court]
/// (only man+woman teams for a 2:2 court when [mixedOnly]).
int bestGap(
  List<int> court,
  Map<int, int> points, {
  Map<int, Gender>? genderById,
  bool mixedOnly = false,
}) {
  const splits = [
    ([0, 1], [2, 3]),
    ([0, 2], [1, 3]),
    ([0, 3], [1, 2]),
  ];
  final isMixed = mixedOnly &&
      court.where((id) => genderById![id] == Gender.male).length == 2;
  var best = 1 << 30;
  for (final (a, b) in splits) {
    if (isMixed && genderById![court[a[0]]] == genderById[court[a[1]]]) {
      continue;
    }
    final gap = (points[court[a[0]]]! +
            points[court[a[1]]]! -
            points[court[b[0]]]! -
            points[court[b[1]]]!)
        .abs();
    best = min(best, gap);
  }
  return best;
}

void main() {
  group('resolveGradePoints', () {
    test('uses each grade\'s points, ungraded = lowest grade', () {
      final points = resolveGradePoints(
        {1: _gradeA.id, 2: _gradeC.id, 3: null, 4: 999},
        _grades,
      );
      expect(points, {1: 10, 2: 6, 3: 4, 4: 4});
    });

    test('falls back to the lowest remaining grade once D is deleted', () {
      final points = resolveGradePoints(
        {1: null},
        [_gradeA, _gradeB, _gradeC],
      );
      expect(points, {1: 6});
    });
  });

  group('GameGenerator grade balance', () {
    test('every court splits into two equal-point teams', () {
      // Two of each grade -> a perfectly balanced layout always exists.
      final gradeIds = [for (final g in _grades) ...[g.id, g.id]];
      final members = [
        for (var i = 0; i < gradeIds.length; i++)
          Member(
            id: i + 1,
            name: 'P$i',
            gender: Gender.male,
            gradeId: gradeIds[i],
          ),
      ];
      final points = resolveGradePoints(
        {for (final m in members) m.id: m.gradeId},
        _grades,
      );

      for (var seed = 0; seed < 5; seed++) {
        final rounds = GameGenerator(random: Random(seed)).generate(
          attendees: members,
          courts: 2,
          gamesToGenerate: 12,
          genderBalance: false,
          gradePoints: points,
        );
        expect(rounds, hasLength(12));
        for (final round in rounds) {
          for (final court in round.courts) {
            expect(court.playerIds, hasLength(4));
            expect(
              bestGap(court.playerIds, points),
              0,
              reason: 'seed $seed game ${round.gameNumber}: ${court.playerIds}',
            );
          }
        }
      }
    });

    test('combined with gender balance: 2:2 courts, mixed teams balanced', () {
      final members = [
        for (final (i, g) in _grades.indexed)
          Member(id: i + 1, name: 'M$i', gender: Gender.male, gradeId: g.id),
        for (final (i, g) in _grades.indexed)
          Member(
            id: 100 + i,
            name: 'F$i',
            gender: Gender.female,
            gradeId: g.id,
          ),
      ];
      final genderById = {for (final m in members) m.id: m.gender};
      final points = resolveGradePoints(
        {for (final m in members) m.id: m.gradeId},
        _grades,
      );

      final rounds = GameGenerator(random: Random(7)).generate(
        attendees: members,
        courts: 2,
        gamesToGenerate: 10,
        genderBalance: true,
        gradePoints: points,
      );
      for (final round in rounds) {
        for (final court in round.courts) {
          final males = court.playerIds
              .where((id) => genderById[id] == Gender.male)
              .length;
          expect(males == 0 || males == 2 || males == 4, isTrue);
          expect(
            bestGap(
              court.playerIds,
              points,
              genderById: genderById,
              mixedOnly: true,
            ),
            0,
            reason: 'game ${round.gameNumber}: ${court.playerIds}',
          );
        }
      }
    });

    test('balances better than grade-blind generation', () {
      final random = Random(3);
      final members = [
        for (var i = 0; i < 14; i++)
          Member(
            id: i + 1,
            name: 'P$i',
            gender: Gender.male,
            gradeId: _grades[random.nextInt(_grades.length)].id,
          ),
      ];
      final points = resolveGradePoints(
        {for (final m in members) m.id: m.gradeId},
        _grades,
      );

      int totalGap(List<GameRound> rounds) => rounds
          .expand((r) => r.courts)
          .fold(0, (sum, c) => sum + bestGap(c.playerIds, points));

      final balanced = GameGenerator(random: Random(1)).generate(
        attendees: members,
        courts: 3,
        gamesToGenerate: 10,
        genderBalance: false,
        gradePoints: points,
      );
      final blind = GameGenerator(random: Random(1)).generate(
        attendees: members,
        courts: 3,
        gamesToGenerate: 10,
        genderBalance: false,
      );
      expect(totalGap(balanced), lessThan(totalGap(blind)));
    });
  });

  group('courtmateCounts', () {
    GameRound round(int n, List<List<int>> courts, {List<int> resting = const []}) =>
        GameRound(
          id: n,
          gameNumber: n,
          courts: [
            for (final (i, ids) in courts.indexed)
              CourtAssignment(courtNumber: i + 1, playerIds: ids),
          ],
          restingPlayerIds: resting,
        );

    final rounds = [
      round(1, [[1, 2, 3, 4], [5, 6, 7, 8]]),
      round(2, [[1, 5, 6, 7], [2, 3, 4, 8]]),
      round(3, [[1, 2, 5, 8], [3, 4, 6, 7]]),
      round(4, [[2, 3, 4, 5]], resting: [1, 6, 7, 8]),
    ];

    test('counts only games up to and including the given one', () {
      expect(
        courtmateCounts(rounds, playerId: 1, throughIndex: 0),
        {2: 1, 3: 1, 4: 1},
      );
      expect(
        courtmateCounts(rounds, playerId: 1, throughIndex: 2),
        {2: 2, 3: 1, 4: 1, 5: 2, 6: 1, 7: 1, 8: 1},
      );
    });

    test('resting games add nothing; out-of-range index covers all', () {
      expect(
        courtmateCounts(rounds, playerId: 1, throughIndex: 3),
        courtmateCounts(rounds, playerId: 1, throughIndex: 99),
      );
      expect(
        courtmateCounts(rounds, playerId: 1, throughIndex: 3),
        courtmateCounts(rounds, playerId: 1, throughIndex: 2),
      );
    });
  });
}
