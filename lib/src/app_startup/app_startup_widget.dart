import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_startup_error_widget.dart';
import 'app_startup_loading_widget.dart';
import 'app_startup_provider.dart';

/// Shows a loading indicator while [appStartupProvider] runs, an error
/// screen with a retry button if it fails, and otherwise builds [onLoaded].
class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({required this.onLoaded, super.key});

  final WidgetBuilder onLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startupState = ref.watch(appStartupProvider);

    return startupState.when(
      data: (_) => onLoaded(context),
      loading: () => const AppStartupLoadingWidget(),
      error: (error, stack) => AppStartupErrorWidget(
        message: '$error',
        onRetry: () => ref.invalidate(appStartupProvider),
      ),
    );
  }
}
