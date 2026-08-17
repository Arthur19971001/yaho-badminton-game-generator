// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionController)
final sessionControllerProvider = SessionControllerFamily._();

final class SessionControllerProvider
    extends $AsyncNotifierProvider<SessionController, GameSession> {
  SessionControllerProvider._({
    required SessionControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'sessionControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionControllerHash();

  @override
  String toString() {
    return r'sessionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SessionController create() => SessionController();

  @override
  bool operator ==(Object other) {
    return other is SessionControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionControllerHash() => r'd85c3135b24528879b35466a05fd4e382a3791f1';

final class SessionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SessionController,
          AsyncValue<GameSession>,
          GameSession,
          FutureOr<GameSession>,
          int
        > {
  SessionControllerFamily._()
    : super(
        retry: null,
        name: r'sessionControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionControllerProvider call(int sessionId) =>
      SessionControllerProvider._(argument: sessionId, from: this);

  @override
  String toString() => r'sessionControllerProvider';
}

abstract class _$SessionController extends $AsyncNotifier<GameSession> {
  late final _$args = ref.$arg as int;
  int get sessionId => _$args;

  FutureOr<GameSession> build(int sessionId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<GameSession>, GameSession>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<GameSession>, GameSession>,
              AsyncValue<GameSession>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
