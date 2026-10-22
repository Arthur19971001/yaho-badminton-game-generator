// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'members_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MembersController)
final membersControllerProvider = MembersControllerProvider._();

final class MembersControllerProvider
    extends $AsyncNotifierProvider<MembersController, List<Member>> {
  MembersControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'membersControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$membersControllerHash();

  @$internal
  @override
  MembersController create() => MembersController();
}

String _$membersControllerHash() => r'25b9b2cf57a6f927b993217f82a28923cc7928aa';

abstract class _$MembersController extends $AsyncNotifier<List<Member>> {
  FutureOr<List<Member>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Member>>, List<Member>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Member>>, List<Member>>,
              AsyncValue<List<Member>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
