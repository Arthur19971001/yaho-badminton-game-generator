import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../database/app_database.dart';

part 'settings_repository.g.dart';

@Riverpod(keepAlive: true)
Future<SettingsRepository> settingsRepository(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return SettingsRepository(db);
}

/// App-wide key/value settings persisted in the `settings` table.
class SettingsRepository {
  SettingsRepository(this._db);

  final Database _db;

  static const alarmSoundPathKey = 'alarm_sound_path';

  Future<String?> get(String key) async {
    final rows = await _db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Stores [value] under [key]; a null [value] removes the setting.
  Future<void> set(String key, String? value) async {
    if (value == null) {
      await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await _db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
