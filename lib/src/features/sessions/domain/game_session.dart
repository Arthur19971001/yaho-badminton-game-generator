import 'dart:convert';

import '../../members/domain/member.dart';
import 'game_round.dart';

/// One club meet-up on a given [date]: who attended, the last-used game
/// setup, and every generated round so far. Persisted verbatim in sqlite so
/// past sessions remain fully viewable/editable regardless of today's date.
class GameSession {
  const GameSession({
    required this.id,
    required this.date,
    required this.courts,
    required this.genderBalance,
    required this.attendeeIds,
    required this.rounds,
    required this.guests,
    required this.courtNames,
  });

  final int id;
  final DateTime date;
  final int courts;
  final bool genderBalance;
  final List<int> attendeeIds;
  final List<GameRound> rounds;

  /// Ad-hoc, session-scoped attendees who aren't part of the club roster
  /// (e.g. a visiting friend). Never written to the `members` table --
  /// stored inline on the session itself, same as [rounds]. Their ids are
  /// only meaningful within this one session's data.
  final List<Member> guests;

  /// Custom display label for each court, indexed by courtNumber - 1 (e.g.
  /// courtNames[0] labels courtNumber 1). Purely cosmetic -- courtNumber
  /// itself still drives assignment/matching everywhere else. A missing or
  /// blank entry falls back to "코트 N" via [labelForCourt].
  final List<String> courtNames;

  /// The label to show for a given [courtNumber]: its custom name if one's
  /// been set, otherwise the default "코트 N".
  String labelForCourt(int courtNumber) {
    final index = courtNumber - 1;
    if (index >= 0 && index < courtNames.length && courtNames[index].trim().isNotEmpty) {
      return courtNames[index];
    }
    return '코트 $courtNumber';
  }

  GameSession copyWith({
    int? courts,
    bool? genderBalance,
    List<int>? attendeeIds,
    List<GameRound>? rounds,
    List<Member>? guests,
    List<String>? courtNames,
  }) =>
      GameSession(
        id: id,
        date: date,
        courts: courts ?? this.courts,
        genderBalance: genderBalance ?? this.genderBalance,
        attendeeIds: attendeeIds ?? this.attendeeIds,
        rounds: rounds ?? this.rounds,
        guests: guests ?? this.guests,
        courtNames: courtNames ?? this.courtNames,
      );

  factory GameSession.fromRow(
    Map<String, Object?> row,
    List<int> attendeeIds,
  ) {
    final gamesRaw = jsonDecode(row['games_json']! as String) as List;
    final guestsRaw =
        jsonDecode((row['guests_json'] as String?) ?? '[]') as List;
    final courtNamesRaw =
        jsonDecode((row['court_names_json'] as String?) ?? '[]') as List;
    return GameSession(
      id: row['id']! as int,
      date: DateTime.parse(row['date']! as String),
      courts: row['courts']! as int,
      genderBalance: (row['gender_balance']! as int) == 1,
      attendeeIds: attendeeIds,
      rounds: gamesRaw
          .map((g) => GameRound.fromJson(g as Map<String, Object?>))
          .toList(),
      guests: guestsRaw
          .map((g) => Member.fromJson(g as Map<String, Object?>))
          .toList(),
      courtNames: courtNamesRaw.map((n) => n as String).toList(),
    );
  }

  Map<String, Object?> toUpdateMap() => {
        'courts': courts,
        'gender_balance': genderBalance ? 1 : 0,
        'games_json': jsonEncode(rounds.map((r) => r.toJson()).toList()),
        'guests_json': jsonEncode(guests.map((g) => g.toJson()).toList()),
        'court_names_json': jsonEncode(courtNames),
      };
}
