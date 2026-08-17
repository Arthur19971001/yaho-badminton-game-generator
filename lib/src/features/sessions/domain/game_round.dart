import 'court_assignment.dart';

/// One generated (or manually created) round of simultaneous games.
///
/// [id] is a stable identity assigned once and never reused or changed --
/// it's what drag-and-drop and other in-flight UI interactions should key
/// off of. [gameNumber] is purely the user-facing display label: it gets
/// renumbered 1..N whenever games are deleted or reordered, so it must
/// never be used as a lookup key.
class GameRound {
  const GameRound({
    required this.id,
    required this.gameNumber,
    required this.courts,
    required this.restingPlayerIds,
  });

  final int id;
  final int gameNumber;
  final List<CourtAssignment> courts;
  final List<int> restingPlayerIds;

  /// The next unused, stable round id given the rounds generated/created so
  /// far this session -- ids only ever increase and are never reused, even
  /// across deletions, so an id always refers to at most one round ever.
  static int nextId(List<GameRound> existingRounds) {
    if (existingRounds.isEmpty) return 1;
    return existingRounds.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  GameRound copyWith({
    int? gameNumber,
    List<CourtAssignment>? courts,
    List<int>? restingPlayerIds,
  }) =>
      GameRound(
        id: id,
        gameNumber: gameNumber ?? this.gameNumber,
        courts: courts ?? this.courts,
        restingPlayerIds: restingPlayerIds ?? this.restingPlayerIds,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'gameNumber': gameNumber,
        'courts': courts.map((c) => c.toJson()).toList(),
        'restingPlayerIds': restingPlayerIds,
      };

  factory GameRound.fromJson(Map<String, Object?> json) => GameRound(
        // Older persisted sessions predate the id field; gameNumber was the
        // de-facto identity back then, so it's a safe one-time fallback.
        id: json['id'] as int? ?? json['gameNumber']! as int,
        gameNumber: json['gameNumber']! as int,
        courts: (json['courts']! as List)
            .map((c) => CourtAssignment.fromJson(c as Map<String, Object?>))
            .toList(),
        restingPlayerIds: ((json['restingPlayerIds'] as List?) ?? const [])
            .map((e) => e as int)
            .toList(),
      );
}
