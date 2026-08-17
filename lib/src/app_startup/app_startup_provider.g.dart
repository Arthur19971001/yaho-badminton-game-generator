// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_startup_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs one-time app initialization (currently: opening the local database)
/// before the main navigation shell is shown.

@ProviderFor(appStartup)
final appStartupProvider = AppStartupProvider._();

/// Runs one-time app initialization (currently: opening the local database)
/// before the main navigation shell is shown.

final class AppStartupProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Runs one-time app initialization (currently: opening the local database)
  /// before the main navigation shell is shown.
  AppStartupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appStartupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appStartupHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return appStartup(ref);
  }
}

String _$appStartupHash() => r'd4ac28a952beb42f2f8c34f8e01c8e2cc3148a47';
