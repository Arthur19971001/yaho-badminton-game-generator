import 'gender.dart';

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.gender,
    this.isUnknown = false,
  });

  final int id;
  final String name;
  final Gender gender;

  /// True only for the [Member.unknown] placeholder -- never persisted,
  /// never returned by a repository.
  final bool isUnknown;

  factory Member.fromMap(Map<String, Object?> map) => Member(
        id: map['id']! as int,
        name: map['name']! as String,
        gender: Gender.fromDb(map['gender']! as String),
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
      };

  /// Unlike [toInsertMap] (for the auto-incrementing `members` table row),
  /// this includes [id] explicitly -- used for session guests, whose id is
  /// assigned by the app itself and embedded directly in the session's own
  /// persisted data rather than in a database-generated column.
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'gender': gender.name,
      };

  factory Member.fromJson(Map<String, Object?> json) => Member(
        id: json['id']! as int,
        name: json['name']! as String,
        gender: Gender.fromDb(json['gender']! as String),
      );

  Member copyWith({String? name, Gender? gender}) => Member(
        id: id,
        name: name ?? this.name,
        gender: gender ?? this.gender,
      );
}
