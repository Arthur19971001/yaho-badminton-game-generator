import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/members_repository.dart';
import '../domain/gender.dart';
import '../domain/member.dart';

part 'members_controller.g.dart';

@riverpod
class MembersController extends _$MembersController {
  @override
  Future<List<Member>> build() async {
    final repo = await ref.watch(membersRepositoryProvider.future);
    return repo.getAll();
  }

  Future<void> addMember(String name, Gender gender) async {
    final repo = await ref.read(membersRepositoryProvider.future);
    await repo.add(name, gender);
    ref.invalidateSelf();
    await future;
  }

  Future<void> updateMember(Member member) async {
    final repo = await ref.read(membersRepositoryProvider.future);
    await repo.update(member);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteMember(int id) async {
    final repo = await ref.read(membersRepositoryProvider.future);
    await repo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}
