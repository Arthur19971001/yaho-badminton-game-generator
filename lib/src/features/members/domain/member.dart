import 'gender.dart';

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.gender,
    this.gradeId,
    this.isUnknown = false,
  });

  final int id;
  final String name;
  final Gender gender;

  /// The member's grade (급수), or null if none is set -- optional, and an
  /// ungraded member counts as the lowest grade for grade-balanced games.
  final int? gradeId;

  /// True only for the [Member.unknown] placeholder -- never persisted,
  /// never returned by a repository.
  final bool isUnknown;

  factory Member.fromMap(Map<String, Object?> map) => Member(
        id: map['id']! as int,
        name: map['name']! as String,
        gender: Gender.fromDb(map['gender']! as String),
        gradeId: map['grade_id'] as int?,
      );

  /// Stand-in for a player id that shows up in a session's game history but
  /// no longer resolves to a real member (e.g. the member was deleted from
  /// the roster after already appearing in generated games). Rendered
  /// visibly instead of silently vanishing from the court, so a past
  /// session's fairness history stays inspectable rather than quietly
  /// showing a court "short" a player with no explanation.
  factory Member.unknown(int id) => Member(
        id: id,
        name: '알 수 없는 회원',
        gender: Gender.male,
        isUnknown: true,
      );

  Map<String, Object?> toInsertMap() => {
        'name': name,
        'gender': gender.name,
        'grade_id': gradeId,
      };

  /// Unlike [toInsertMap] (for the auto-incrementing `members` table row),
  /// this includes [id] explicitly -- used for session guests, whose id is
  /// assigned by the app itself and embedded directly in the session's own
  /// persisted data rather than in a database-generated column.
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'gender': gender.name,
        'gradeId': gradeId,
      };

  factory Member.fromJson(Map<String, Object?> json) => Member(
        id: json['id']! as int,
        name: json['name']! as String,
        gender: Gender.fromDb(json['gender']! as String),
        // Absent in guests persisted before grades existed.
        gradeId: json['gradeId'] as int?,
      );

  /// [gradeId] uses a sentinel default so callers can explicitly clear it
  /// (pass null) as opposed to leaving it unchanged (omit it).
  Member copyWith({
    String? name,
    Gender? gender,
    Object? gradeId = _unchanged,
  }) =>
      Member(
        id: id,
        name: name ?? this.name,
        gender: gender ?? this.gender,
        gradeId: identical(gradeId, _unchanged) ? this.gradeId : gradeId as int?,
      );
}

const _unchanged = Object();
