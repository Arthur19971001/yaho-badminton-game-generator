enum Gender {
  male,
  female;

  String get label => switch (this) {
        Gender.male => '남',
        Gender.female => '여',
      };

  static Gender fromDb(String value) => Gender.values.byName(value);
}
