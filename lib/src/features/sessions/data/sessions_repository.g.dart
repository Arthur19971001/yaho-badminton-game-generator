// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessions_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionsRepository)
final sessionsRepositoryProvider = SessionsRepositoryProvider._();

final class SessionsRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SessionsRepository>,
          SessionsRepository,
          FutureOr<SessionsRepository>
        >
    with
        $FutureModifier<SessionsRepository>,
        $FutureProvider<SessionsRepository> {
  SessionsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionsRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<SessionsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SessionsRepository> create(Ref ref) {
    return sessionsRepository(ref);
  }
}

String _$sessionsRepositoryHash() =>
    r'70933ed50741b841ba4d98cdbcbfa9a5f75d2def';
