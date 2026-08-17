// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_timer_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-wide, per-game countdown timer -- lives independently of any screen,
/// so it keeps running when the user navigates away from the game it was
/// started for (or to a different view entirely), and only one can be
/// active anywhere in the app at once. When it hits zero it loops a loud
/// siren and pops a modal "시간 종료" dialog (on the root navigator, so it
/// surfaces no matter what screen is currently showing) until dismissed.

@ProviderFor(GameTimerController)
final gameTimerControllerProvider = GameTimerControllerProvider._();

/// App-wide, per-game countdown timer -- lives independently of any screen,
/// so it keeps running when the user navigates away from the game it was
/// started for (or to a different view entirely), and only one can be
/// active anywhere in the app at once. When it hits zero it loops a loud
/// siren and pops a modal "시간 종료" dialog (on the root navigator, so it
/// surfaces no matter what screen is currently showing) until dismissed.
final class GameTimerControllerProvider
    extends $NotifierProvider<GameTimerController, GameTimerState?> {
  /// App-wide, per-game countdown timer -- lives independently of any screen,
  /// so it keeps running when the user navigates away from the game it was
  /// started for (or to a different view entirely), and only one can be
  /// active anywhere in the app at once. When it hits zero it loops a loud
  /// siren and pops a modal "시간 종료" dialog (on the root navigator, so it
  /// surfaces no matter what screen is currently showing) until dismissed.
  GameTimerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gameTimerControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gameTimerControllerHash();

  @$internal
  @override
  GameTimerController create() => GameTimerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GameTimerState? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GameTimerState?>(value),
    );
  }
}

String _$gameTimerControllerHash() =>
    r'd02b75b289606f3bbc42a662bacdcf2e0484d36c';

/// App-wide, per-game countdown timer -- lives independently of any screen,
/// so it keeps running when the user navigates away from the game it was
/// started for (or to a different view entirely), and only one can be
/// active anywhere in the app at once. When it hits zero it loops a loud
/// siren and pops a modal "시간 종료" dialog (on the root navigator, so it
/// surfaces no matter what screen is currently showing) until dismissed.

abstract class _$GameTimerController extends $Notifier<GameTimerState?> {
  GameTimerState? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<GameTimerState?, GameTimerState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GameTimerState?, GameTimerState?>,
              GameTimerState?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
