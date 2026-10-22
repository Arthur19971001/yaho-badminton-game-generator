// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grades_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GradesController)
final gradesControllerProvider = GradesControllerProvider._();

final class GradesControllerProvider
    extends $AsyncNotifierProvider<GradesController, List<Grade>> {
  GradesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gradesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gradesControllerHash();

  @$internal
  @override
  GradesController create() => GradesController();
}

String _$gradesControllerHash() => r'f83564c842e276baf72d311bea87c4e19c691ea4';

abstract class _$GradesController extends $AsyncNotifier<List<Grade>> {
  FutureOr<List<Grade>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Grade>>, List<Grade>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Grade>>, List<Grade>>,
              AsyncValue<List<Grade>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
