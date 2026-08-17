// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessions_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionsController)
final sessionsControllerProvider = SessionsControllerProvider._();

final class SessionsControllerProvider
    extends $AsyncNotifierProvider<SessionsController, List<GameSession>> {
  SessionsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionsControllerHash();

  @$internal
  @override
  SessionsController create() => SessionsController();
}

String _$sessionsControllerHash() =>
    r'99cbe5c237eb4d6f1fcf150d90980321e7e589c0';

abstract class _$SessionsController extends $AsyncNotifier<List<GameSession>> {
  FutureOr<List<GameSession>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<GameSession>>, List<GameSession>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<GameSession>>, List<GameSession>>,
              AsyncValue<List<GameSession>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
