import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/sessions_repository.dart';
import '../domain/game_session.dart';

part 'sessions_controller.g.dart';

@riverpod
class SessionsController extends _$SessionsController {
  @override
  Future<List<GameSession>> build() async {
    final repo = await ref.watch(sessionsRepositoryProvider.future);
    return repo.getAll();
  }

  Future<GameSession> createSession(DateTime date) async {
    final repo = await ref.read(sessionsRepositoryProvider.future);
    final session = await repo.create(date);
    ref.invalidateSelf();
    await future;
    return session;
  }

  Future<void> deleteSession(int id) async {
    final repo = await ref.read(sessionsRepositoryProvider.future);
    await repo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}
