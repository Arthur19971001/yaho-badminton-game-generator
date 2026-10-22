import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/settings_repository.dart';

part 'alarm_sound_controller.g.dart';

/// The bundled default game-over alarm.
const defaultAlarmAsset = 'sounds/siren.wav';

/// Audio file extensions offered by the alarm sound picker.
const alarmSoundExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg'];

/// Which sound plays when a game timer runs out. [customPath] is a copy of
/// the user's chosen file inside the app's own support directory (so moving
/// or deleting the original doesn't break it); null means the default
/// siren.
class AlarmSound {
  const AlarmSound({this.customPath});

  final String? customPath;

  bool get isDefault => customPath == null;

  /// The original file name the user picked (the stored copy is prefixed
  /// with a timestamp to keep it unique), or "기본 사이렌".
  String get displayName {
    final path = customPath;
    if (path == null) return '기본 사이렌';
    final base = p.basename(path);
    final separator = base.indexOf('_');
    return separator == -1 ? base : base.substring(separator + 1);
  }

  /// The source to hand to an [AudioPlayer] -- falls back to the default
  /// siren if the custom file has since gone missing, so the alarm never
  /// silently fails to ring.
  Source get source {
    final path = customPath;
    if (path != null && File(path).existsSync()) return DeviceFileSource(path);
    return AssetSource(defaultAlarmAsset);
  }
}

@Riverpod(keepAlive: true)
class AlarmSoundController extends _$AlarmSoundController {
  @override
  Future<AlarmSound> build() async {
    final repo = await ref.watch(settingsRepositoryProvider.future);
    return AlarmSound(
      customPath: await repo.get(SettingsRepository.alarmSoundPathKey),
    );
  }

  /// Copies [sourcePath] into the app's support directory and makes it the
  /// alarm sound, replacing (and deleting) any previous custom sound.
  Future<void> setCustomSound(String sourcePath) async {
    final supportDir = await getApplicationSupportDirectory();
    final soundsDir = Directory(p.join(supportDir.path, 'alarm_sounds'));
    await soundsDir.create(recursive: true);
    final target = p.join(
      soundsDir.path,
      '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}',
    );
    await File(sourcePath).copy(target);

    await _save(target);
  }

  /// Goes back to the bundled siren.
  Future<void> resetToDefault() => _save(null);

  Future<void> _save(String? newPath) async {
    final previous = (await future).customPath;
    final repo = await ref.read(settingsRepositoryProvider.future);
    await repo.set(SettingsRepository.alarmSoundPathKey, newPath);
    state = AsyncData(AlarmSound(customPath: newPath));

    if (previous != null && previous != newPath) {
      try {
        await File(previous).delete();
      } on FileSystemException {
        // Already gone -- nothing to clean up.
      }
    }
  }
}
