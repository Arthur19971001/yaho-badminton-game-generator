import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/sessions/presentation/widgets/game_timer_badge.dart';
import 'navigation/router_provider.dart';
import 'theme/theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: '야호 배드민턴 게임 생성기',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      builder: (context, child) => Column(
        children: [
          const GameTimerBadge(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
