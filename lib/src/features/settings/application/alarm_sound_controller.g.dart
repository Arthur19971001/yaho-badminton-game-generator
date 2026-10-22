// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alarm_sound_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AlarmSoundController)
final alarmSoundControllerProvider = AlarmSoundControllerProvider._();

final class AlarmSoundControllerProvider
    extends $AsyncNotifierProvider<AlarmSoundController, AlarmSound> {
  AlarmSoundControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'alarmSoundControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$alarmSoundControllerHash();

  @$internal
  @override
  AlarmSoundController create() => AlarmSoundController();
}

String _$alarmSoundControllerHash() =>
    r'f0e6761c27591a1a83f960b3c734d2d974bd6ab7';

abstract class _$AlarmSoundController extends $AsyncNotifier<AlarmSound> {
  FutureOr<AlarmSound> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AlarmSound>, AlarmSound>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AlarmSound>, AlarmSound>,
              AsyncValue<AlarmSound>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
