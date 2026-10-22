import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../members/application/members_controller.dart';
import '../data/grades_repository.dart';
import '../domain/grade.dart';

part 'grades_controller.g.dart';

@riverpod
class GradesController extends _$GradesController {
  @override
  Future<List<Grade>> build() async {
    final repo = await ref.watch(gradesRepositoryProvider.future);
    return repo.getAll();
  }

  Future<void> addGrade(String name, int points) async {
    final repo = await ref.read(gradesRepositoryProvider.future);
    await repo.add(name, points);
    ref.invalidateSelf();
    await future;
  }

  Future<void> updateGrade(Grade grade) async {
    final repo = await ref.read(gradesRepositoryProvider.future);
    await repo.update(grade);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteGrade(int id) async {
    final repo = await ref.read(gradesRepositoryProvider.future);
    await repo.delete(id);
    ref.invalidateSelf();
    // Members who had this grade were just cleared to "no grade".
    ref.invalidate(membersControllerProvider);
    await future;
  }
}
