// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'results_jump_request.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ResultsJumpRequestController)
final resultsJumpRequestControllerProvider =
    ResultsJumpRequestControllerProvider._();

final class ResultsJumpRequestControllerProvider
    extends
        $NotifierProvider<ResultsJumpRequestController, ResultsJumpRequest?> {
  ResultsJumpRequestControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resultsJumpRequestControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resultsJumpRequestControllerHash();

  @$internal
  @override
  ResultsJumpRequestController create() => ResultsJumpRequestController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResultsJumpRequest? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResultsJumpRequest?>(value),
    );
  }
}

String _$resultsJumpRequestControllerHash() =>
    r'3dab210816c854930a9fe6807c4b788a44393c69';

abstract class _$ResultsJumpRequestController
    extends $Notifier<ResultsJumpRequest?> {
  ResultsJumpRequest? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ResultsJumpRequest?, ResultsJumpRequest?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ResultsJumpRequest?, ResultsJumpRequest?>,
              ResultsJumpRequest?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
