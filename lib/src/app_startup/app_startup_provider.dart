import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';

part 'app_startup_provider.g.dart';

/// Runs one-time app initialization (currently: opening the local database)
/// before the main navigation shell is shown.
@riverpod
Future<void> appStartup(Ref ref) async {
  ref.onDispose(() {});
  await ref.watch(appDatabaseProvider.future);
}
