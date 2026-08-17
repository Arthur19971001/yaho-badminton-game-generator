/// A single court's player assignment within one [GameRound].
///
/// [playerIds] is expected to contain exactly 4 ids, but the UI allows
/// manual drag-and-drop edits that can temporarily overshoot that count --
/// the model itself stays permissive so the results screen can flag the
/// invalid state instead of silently rejecting the edit.
class CourtAssignment {
  const CourtAssignment({
    required this.courtNumber,
    required this.playerIds,
  });

  final int courtNumber;
  final List<int> playerIds;

  static const capacity = 4;
  bool get isFull => playerIds.length == capacity;
  bool get isOverCapacity => playerIds.length > capacity;

  CourtAssignment copyWith({int? courtNumber, List<int>? playerIds}) =>
      CourtAssignment(
        courtNumber: courtNumber ?? this.courtNumber,
        playerIds: playerIds ?? this.playerIds,
      );

  Map<String, Object?> toJson() => {
        'courtNumber': courtNumber,
        'playerIds': playerIds,
      };

  factory CourtAssignment.fromJson(Map<String, Object?> json) =>
      CourtAssignment(
        courtNumber: json['courtNumber']! as int,
        playerIds: (json['playerIds']! as List)
            .map((e) => e as int)
            .toList(growable: false),
      );
}
