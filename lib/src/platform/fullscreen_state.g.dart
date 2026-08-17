// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fullscreen_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the app is currently in real OS-level fullscreen (the PPT-style
/// presentation view). [ResultsScreen] owns the actual toggle/listener and
/// updates this; other widgets -- like [GameTimerBadge], which needs to
/// disable its tap-to-jump-to-game behavior during a presentation instead
/// of disrupting it -- just read it.

@ProviderFor(FullscreenState)
final fullscreenStateProvider = FullscreenStateProvider._();

/// Whether the app is currently in real OS-level fullscreen (the PPT-style
/// presentation view). [ResultsScreen] owns the actual toggle/listener and
/// updates this; other widgets -- like [GameTimerBadge], which needs to
/// disable its tap-to-jump-to-game behavior during a presentation instead
/// of disrupting it -- just read it.
final class FullscreenStateProvider
    extends $NotifierProvider<FullscreenState, bool> {
  /// Whether the app is currently in real OS-level fullscreen (the PPT-style
  /// presentation view). [ResultsScreen] owns the actual toggle/listener and
  /// updates this; other widgets -- like [GameTimerBadge], which needs to
  /// disable its tap-to-jump-to-game behavior during a presentation instead
  /// of disrupting it -- just read it.
  FullscreenStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fullscreenStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fullscreenStateHash();

  @$internal
  @override
  FullscreenState create() => FullscreenState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$fullscreenStateHash() => r'787c25d72d0fcae217d41fe53591d51be31e5945';

/// Whether the app is currently in real OS-level fullscreen (the PPT-style
/// presentation view). [ResultsScreen] owns the actual toggle/listener and
/// updates this; other widgets -- like [GameTimerBadge], which needs to
/// disable its tap-to-jump-to-game behavior during a presentation instead
/// of disrupting it -- just read it.

abstract class _$FullscreenState extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
