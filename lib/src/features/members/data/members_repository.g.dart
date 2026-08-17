// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'members_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(membersRepository)
final membersRepositoryProvider = MembersRepositoryProvider._();

final class MembersRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<MembersRepository>,
          MembersRepository,
          FutureOr<MembersRepository>
        >
    with
        $FutureModifier<MembersRepository>,
        $FutureProvider<MembersRepository> {
  MembersRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'membersRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$membersRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<MembersRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MembersRepository> create(Ref ref) {
    return membersRepository(ref);
  }
}

String _$membersRepositoryHash() => r'f37aff10ff86e907e3fb489592629b9ff8fd0a86';
