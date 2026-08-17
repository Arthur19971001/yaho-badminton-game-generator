// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Opens (and creates, on first launch) the local sqlite database used to
/// persist club members and session/game data.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// Opens (and creates, on first launch) the local sqlite database used to
/// persist club members and session/game data.

final class AppDatabaseProvider
    extends
        $FunctionalProvider<AsyncValue<Database>, Database, FutureOr<Database>>
    with $FutureModifier<Database>, $FutureProvider<Database> {
  /// Opens (and creates, on first launch) the local sqlite database used to
  /// persist club members and session/game data.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $FutureProviderElement<Database> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Database> create(Ref ref) {
    return appDatabase(ref);
  }
}

String _$appDatabaseHash() => r'aae3c56b7fdb0e85498840bc927cbd5c03939015';
