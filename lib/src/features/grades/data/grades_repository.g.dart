// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grades_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(gradesRepository)
final gradesRepositoryProvider = GradesRepositoryProvider._();

final class GradesRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<GradesRepository>,
          GradesRepository,
          FutureOr<GradesRepository>
        >
    with $FutureModifier<GradesRepository>, $FutureProvider<GradesRepository> {
  GradesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gradesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gradesRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<GradesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GradesRepository> create(Ref ref) {
    return gradesRepository(ref);
  }
}

String _$gradesRepositoryHash() => r'dc3b311e49431f111a323967a98125b57b5e56a3';
