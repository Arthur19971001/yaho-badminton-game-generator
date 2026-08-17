import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/gender.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/member.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/game_generator.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/domain/game_round.dart';

List<Member> membersOf(int maleCount, int femaleCount) => [
      for (var i = 0; i < maleCount; i++)
        Member(id: i + 1, name: 'M$i', gender: Gender.male),
      for (var i = 0; i < femaleCount; i++)
        Member(id: 1000 + i, name: 'F$i', gender: Gender.female),
    ];

void expectValidRounds(
  List<GameRound> rounds, {
  required int courts,
  bool genderBalance = false,
  Map<int, Gender>? genderById,
}) {
  for (final round in rounds) {
    final seen = <int>{};
    expect(round.courts.length, lessThanOrEqualTo(courts));
    for (final court in round.courts) {
      expect(court.playerIds.length, 4,
          reason: 'every court must have exactly 4 players');
      for (final id in court.playerIds) {
        expect(seen.contains(id), isFalse,
            reason: 'a player cannot appear twice in the same round');
        seen.add(id);
      }
      if (genderBalance && genderById != null) {
        final males =
            court.playerIds.where((id) => genderById[id] == Gender.male).length;
        expect(
          males == 0 || males == 2 || males == 4,
          isTrue,
          reason: 'gender-balanced court must be 4:0, 2:2 or 0:4, got $males males',
        );
      }
    }
    for (final restingId in round.restingPlayerIds) {
      expect(seen.contains(restingId), isFalse);
    }
  }
}

void main() {
  group('GameGenerator', () {
    test('returns nothing for fewer than 4 attendees', () {
      final rounds = GameGenerator().generate(
        attendees: membersOf(2, 1),
        courts: 1,
        gamesToGenerate: 4,
        genderBalance: false,
      );
      expect(rounds, isEmpty);
    });

    test('every court always has exactly 4 players, no duplicates', () {
      final members = membersOf(6, 6);
      final rounds = GameGenerator(random: _seeded()).generate(
        attendees: members,
        courts: 2,
        gamesToGenerate: 10,
        genderBalance: false,
      );
      expect(rounds.length, 10);
      expectValidRounds(rounds, courts: 2);
    });

    test('game numbers are sequential starting at 1', () {
      final members = membersOf(4, 4);
      final rounds = GameGenerator(random: _seeded()).generate(
        attendees: members,
        courts: 1,
        gamesToGenerate: 5,
        genderBalance: false,
      );
      expect(rounds.map((r) => r.gameNumber).toList(), [1, 2, 3, 4, 5]);
    });

    test('play counts stay balanced when everyone can rotate', () {
      final members = membersOf(5, 5);
      final rounds = GameGenerator(random: _seeded()).generate(
        attendees: members,
        courts: 2,
        gamesToGenerate: 20,
        genderBalance: false,
      );

      final playCount = <int, int>{for (final m in members) m.id: 0};
      for (final round in rounds) {
        for (final court in round.courts) {
          for (final id in court.playerIds) {
            playCount[id] = playCount[id]! + 1;
          }
        }
      }

      final counts = playCount.values.toList();
      final maxCount = counts.reduce((a, b) => a > b ? a : b);
      final minCount = counts.reduce((a, b) => a < b ? a : b);
      expect(maxCount - minCount, lessThanOrEqualTo(2),
          reason: 'play counts: $playCount');
    });

    test('gender balance mode never produces a 3:1 court', () {
      final members = membersOf(7, 9);
      final genderById = {for (final m in members) m.id: m.gender};
      final rounds = GameGenerator(random: _seeded()).generate(
        attendees: members,
        courts: 3,
        gamesToGenerate: 15,
        genderBalance: true,
      );
      expectValidRounds(
        rounds,
        courts: 3,
        genderBalance: true,
        genderById: genderById,
      );
    });

    test('gender balance mode keeps play counts balanced across genders', () {
      // Regression test: the split search used to pick the split closest to
      // males.length (i.e. always maximize the majority gender) instead of
      // one proportional to each gender's share of the attendee pool, so
      // with an even 6/6 split every male played every round while females
      // barely played at all.
      final members = membersOf(6, 6);
      final rounds = GameGenerator(random: _seeded()).generate(
        attendees: members,
        courts: 2,
        gamesToGenerate: 12,
        genderBalance: true,
      );

      final playCount = <int, int>{for (final m in members) m.id: 0};
      for (final round in rounds) {
        for (final court in round.courts) {
          for (final id in court.playerIds) {
            playCount[id] = playCount[id]! + 1;
          }
        }
      }
      final counts = playCount.values.toList();
      final maxCount = counts.reduce((a, b) => a > b ? a : b);
      final minCount = counts.reduce((a, b) => a < b ? a : b);
      expect(maxCount - minCount, lessThanOrEqualTo(2),
          reason: 'play counts: $playCount');
    });

    test('gender balance handles a single-gender roster', () {
      final members = membersOf(8, 0);
      final genderById = {for (final m in members) m.id: m.gender};
      final rounds = GameGenerator(random: _seeded()).generate(
        attendees: members,
        courts: 2,
        gamesToGenerate: 6,
        genderBalance: true,
      );
      expectValidRounds(
        rounds,
        courts: 2,
        genderBalance: true,
        genderById: genderById,
      );
    });

    test('gender balance handles odd totals of one gender via benching', () {
      // 3 males + 5 females = 8 (fills 2 courts exactly), odd male count
      // forces the generator to bench extra players to keep 2:2/4:0/0:4.
      final members = membersOf(3, 5);
      final genderById = {for (final m in members) m.id: m.gender};
      final rounds = GameGenerator(random: _seeded()).generate(
        attendees: members,
        courts: 2,
        gamesToGenerate: 6,
        genderBalance: true,
      );
      expectValidRounds(
        rounds,
        courts: 2,
        genderBalance: true,
        genderById: genderById,
      );
    });

    test('adding more games continues from prior history without reset', () {
      final members = membersOf(6, 6);
      final generator = GameGenerator(random: _seeded());
      final firstBatch = generator.generate(
        attendees: members,
        courts: 2,
        gamesToGenerate: 8,
        genderBalance: false,
      );

      final secondBatch = generator.generate(
        attendees: members,
        courts: 2,
        gamesToGenerate: 4,
        genderBalance: false,
        existingRounds: firstBatch,
      );

      expect(secondBatch.map((r) => r.gameNumber).toList(), [9, 10, 11, 12]);

      final combined = [...firstBatch, ...secondBatch];
      expectValidRounds(combined, courts: 2);

      final playCount = <int, int>{for (final m in members) m.id: 0};
      for (final round in combined) {
        for (final court in round.courts) {
          for (final id in court.playerIds) {
            playCount[id] = playCount[id]! + 1;
          }
        }
      }
      final counts = playCount.values.toList();
      final maxCount = counts.reduce((a, b) => a > b ? a : b);
      final minCount = counts.reduce((a, b) => a < b ? a : b);
      expect(maxCount - minCount, lessThanOrEqualTo(2));
    });

    test('players who sat out in prior history are prioritized next', () {
      // 5 attendees, 1 court (4 slots) -- exactly 1 rests each round.
      final members = membersOf(3, 2);
      final generator = GameGenerator(random: _seeded());
      final rounds = generator.generate(
        attendees: members,
        courts: 1,
        gamesToGenerate: 5,
        genderBalance: false,
      );

      final restCount = <int, int>{for (final m in members) m.id: 0};
      for (final round in rounds) {
        for (final id in round.restingPlayerIds) {
          restCount[id] = restCount[id]! + 1;
        }
      }
      final counts = restCount.values.toList();
      final maxRest = counts.reduce((a, b) => a > b ? a : b);
      final minRest = counts.reduce((a, b) => a < b ? a : b);
      expect(maxRest - minRest, lessThanOrEqualTo(1),
          reason: 'rest counts: $restCount');
    });
  });
}

// A fixed seed keeps these tests deterministic across runs.
Random _seeded() => Random(42);
