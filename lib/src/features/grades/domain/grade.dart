/// A club skill grade (급수), e.g. A/B/C/D, each worth [points] for
/// grade-balanced game generation -- two teams of 2 are considered evenly
/// matched when their summed points are close (A10+C6 = B8+B8 = 16).
class Grade {
  const Grade({
    required this.id,
    required this.name,
    required this.points,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final int points;
  final int sortOrder;

  factory Grade.fromMap(Map<String, Object?> map) => Grade(
        id: map['id']! as int,
        name: map['name']! as String,
        points: map['points']! as int,
        sortOrder: map['sort_order']! as int,
      );

  Grade copyWith({String? name, int? points}) => Grade(
        id: id,
        name: name ?? this.name,
        points: points ?? this.points,
        sortOrder: sortOrder,
      );
}

/// Resolves every [gradeIdByPlayerId] entry to its grade's points. A player
/// with no grade (or one pointing at a since-deleted grade) counts as the
/// lowest grade currently defined -- i.e. D by default -- so ungraded
/// players are never treated as stronger than anyone graded. With no grades
/// defined at all, everyone is 0 (grade balancing becomes a no-op).
Map<int, int> resolveGradePoints(
  Map<int, int?> gradeIdByPlayerId,
  List<Grade> grades,
) {
  final pointsByGradeId = {for (final g in grades) g.id: g.points};
  final fallback = grades.isEmpty
      ? 0
      : grades.map((g) => g.points).reduce((a, b) => a < b ? a : b);
  return {
    for (final entry in gradeIdByPlayerId.entries)
      entry.key: pointsByGradeId[entry.value] ?? fallback,
  };
}
