import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_startup/app_startup_provider.dart';
import '../app_startup/app_startup_widget.dart';
import '../features/grades/presentation/screens/grades_screen.dart';
import '../features/members/presentation/screens/members_screen.dart';
import '../features/sessions/presentation/screens/attendance_screen.dart';
import '../features/sessions/presentation/screens/game_setup_screen.dart';
import '../features/sessions/presentation/screens/results_screen.dart';
import '../features/sessions/presentation/screens/sessions_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import 'main_scaffold.dart';

part 'router_provider.g.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _membersShellKey =
    GlobalKey<NavigatorState>(debugLabel: 'membersShell');
final GlobalKey<NavigatorState> _sessionsShellKey =
    GlobalKey<NavigatorState>(debugLabel: 'sessionsShell');
final GlobalKey<NavigatorState> _gradesShellKey =
    GlobalKey<NavigatorState>(debugLabel: 'gradesShell');
final GlobalKey<NavigatorState> _settingsShellKey =
    GlobalKey<NavigatorState>(debugLabel: 'settingsShell');

@riverpod
RouterConfig<Object>? router(Ref ref) {
  final appStartupState = ref.watch(appStartupProvider);

  if (appStartupState.isLoading || appStartupState.hasError) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => NoTransitionPage(
            child: AppStartupWidget(onLoaded: (_) => const SizedBox.shrink()),
          ),
        ),
      ],
    );
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/members',
    debugLogDiagnostics: true,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _membersShellKey,
            routes: [
              GoRoute(
                path: '/members',
                builder: (context, state) => const MembersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _sessionsShellKey,
            routes: [
              GoRoute(
                path: '/sessions',
                builder: (context, state) => const SessionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _gradesShellKey,
            routes: [
              GoRoute(
                path: '/grades',
                builder: (context, state) => const GradesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsShellKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/sessions/:id/attendance',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AttendanceScreen(
          sessionId: int.parse(state.pathParameters['id']!),
          returnToSetup: state.uri.queryParameters['editing'] != 'true',
        ),
      ),
      GoRoute(
        path: '/sessions/:id/setup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => GameSetupScreen(
          sessionId: int.parse(state.pathParameters['id']!),
          fromResults: state.uri.queryParameters['from'] == 'results',
        ),
      ),
      GoRoute(
        path: '/sessions/:id/results',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ResultsScreen(
          sessionId: int.parse(state.pathParameters['id']!),
          initialViewMode: state.uri.queryParameters['view'],
          initialRoundId: int.tryParse(state.uri.queryParameters['roundId'] ?? ''),
        ),
      ),
    ],
  );
}
