import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

part 'app_database.g.dart';

/// Opens (and creates, on first launch) the local sqlite database used to
/// persist club members and session/game data.
@Riverpod(keepAlive: true)
Future<Database> appDatabase(Ref ref) async {
  final supportDir = await getApplicationSupportDirectory();
  final dbPath = p.join(supportDir.path, 'yaho_badminton.db');
  return openAppDatabase(dbPath);
}

/// Opens (creating on first launch) the app's sqlite database at [path].
/// Shared by the real provider above and by tests that want the exact same
/// schema against an in-memory or temp-file database.
Future<Database> openAppDatabase(String path) {
  sqfliteFfiInit();

  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            gender TEXT NOT NULL,
            grade_id INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            courts INTEGER NOT NULL DEFAULT 1,
            gender_balance INTEGER NOT NULL DEFAULT 0,
            grade_balance INTEGER NOT NULL DEFAULT 0,
            games_json TEXT NOT NULL DEFAULT '[]',
            guests_json TEXT NOT NULL DEFAULT '[]',
            court_names_json TEXT NOT NULL DEFAULT '[]'
          )
        ''');

        // No FK on member_id: an attendee id can be a real members.id, or a
        // negative id belonging to a guest embedded in that session's own
        // guests_json (guests never get a members table row).
        await db.execute('''
          CREATE TABLE session_attendees (
            session_id INTEGER NOT NULL,
            member_id INTEGER NOT NULL,
            PRIMARY KEY (session_id, member_id),
            FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
          )
        ''');

        await _createGradesTable(db);
        await _createSettingsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Guests are ad-hoc, session-scoped attendees who never touch the
          // `members` table -- stored inline on the session itself, same
          // idea as games_json.
          await db.execute(
            "ALTER TABLE sessions ADD COLUMN guests_json TEXT NOT NULL DEFAULT '[]'",
          );
        }
        if (oldVersion < 3) {
          // Drop the member_id -> members FK: guest attendee ids are
          // negative and intentionally don't reference any members row.
          // SQLite can't alter a constraint in place, so rebuild the table.
          await db.execute('''
            CREATE TABLE session_attendees_new (
              session_id INTEGER NOT NULL,
              member_id INTEGER NOT NULL,
              PRIMARY KEY (session_id, member_id),
              FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'INSERT INTO session_attendees_new SELECT * FROM session_attendees',
          );
          await db.execute('DROP TABLE session_attendees');
          await db.execute(
            'ALTER TABLE session_attendees_new RENAME TO session_attendees',
          );
        }
        if (oldVersion < 4) {
          // Custom per-court display labels (e.g. the venue's own court
          // numbers), purely cosmetic -- stored inline like games_json.
          await db.execute(
            "ALTER TABLE sessions ADD COLUMN court_names_json TEXT NOT NULL DEFAULT '[]'",
          );
        }
        if (oldVersion < 5) {
          // Member grades (급수) + app-wide settings (e.g. the alarm sound).
          // Purely additive: existing members/sessions rows are never
          // rebuilt or deleted -- columns are only appended, and every
          // pre-existing member starts out on grade D.
          await _createGradesTable(db);
          await _createSettingsTable(db);
          await db.execute('ALTER TABLE members ADD COLUMN grade_id INTEGER');
          await db.execute(
            'ALTER TABLE sessions ADD COLUMN grade_balance INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            "UPDATE members SET grade_id = (SELECT id FROM grades WHERE name = 'D')",
          );
        }
      },
    ),
  );
}

/// Default grades seeded on first launch (and when upgrading to v5). The
/// admin can add/rename/re-score/delete these afterwards from the
/// "급수 관리" screen.
const defaultGrades = [('A', 10), ('B', 8), ('C', 6), ('D', 4)];

// No FK from members.grade_id: deleting a grade explicitly clears it on
// every member who had it (see GradesRepository.delete), and an
// unresolvable grade_id is treated the same as "no grade" anyway.
Future<void> _createGradesTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE grades (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      points INTEGER NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0
    )
  ''');
  for (var i = 0; i < defaultGrades.length; i++) {
    final (name, points) = defaultGrades[i];
    await db.insert('grades', {
      'name': name,
      'points': points,
      'sort_order': i,
    });
  }
}

Future<void> _createSettingsTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT
    )
  ''');
}
