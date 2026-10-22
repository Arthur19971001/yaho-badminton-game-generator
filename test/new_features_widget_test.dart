// UI-level checks for the grade management screen and the results screen's
// player click (같이 친 횟수) / right-click (사용자 빼기) actions, against a
// real in-memory database.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yaho_badminton_game_generator/src/database/app_database.dart';
import 'package:yaho_badminton_game_generator/src/features/grades/presentation/screens/grades_screen.dart';
import 'package:yaho_badminton_game_generator/src/features/members/application/members_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/gender.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/application/session_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/application/sessions_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/presentation/widgets/games_table_view.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/presentation/widgets/player_chip.dart';

/// Lets real (ffi/isolate-backed) database work finish and animations run.
/// Used instead of pumpAndSettle, which never settles while a loading
/// spinner is on screen.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('grades screen lists defaults and adds a new grade',
      (tester) async {
    final db = await tester.runAsync(() => openAppDatabase(inMemoryDatabasePath));
    addTearDown(() => tester.runAsync(db!.close));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) async => db!)],
        child: const MaterialApp(home: GradesScreen()),
      ),
    );
    await settle(tester);

    for (final name in ['A급', 'B급', 'C급', 'D급']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('10점'), findsOneWidget);
    expect(find.text('4점'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'S');
    await tester.enterText(find.byType(TextFormField).at(1), '12');
    await tester.tap(find.text('저장'));
    await settle(tester);

    expect(find.text('S급'), findsOneWidget);
    expect(find.text('12점'), findsOneWidget);
  });

  testWidgets('player chip: click shows courtmates, right-click removes',
      (tester) async {
    late ProviderContainer container;
    late int sessionId;
    late Map<String, int> idByName;

    await tester.runAsync(() async {
      final db = await openAppDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);
      container.listen(membersControllerProvider, (_, _) {});
      container.listen(sessionsControllerProvider, (_, _) {});
      final membersNotifier = container.read(membersControllerProvider.notifier);
      for (final name in ['가', '나', '다', '라']) {
        await membersNotifier.addMember(name, Gender.male);
      }
      final members = await container.read(membersControllerProvider.future);
      idByName = {for (final m in members) m.name: m.id};
      final session = await container
          .read(sessionsControllerProvider.notifier)
          .createSession(DateTime(2026, 1, 1));
      sessionId = session.id;
      container.listen(sessionControllerProvider(sessionId), (_, _) {});
      await container.read(sessionControllerProvider(sessionId).future);
      final notifier =
          container.read(sessionControllerProvider(sessionId).notifier);
      await notifier.updateAttendees(members.map((m) => m.id).toList());
      // Everyone plays together in both games.
      await notifier.generateGames(
        courts: 1,
        gamesToGenerate: 2,
        genderBalance: false,
      );
    });

    Widget buildView() {
      final session =
          container.read(sessionControllerProvider(sessionId)).requireValue;
      final members = container.read(membersControllerProvider).requireValue;
      return GamesTableView(
        sessionId: sessionId,
        rounds: session.rounds,
        memberById: {for (final m in members) m.id: m},
        attendeeIds: session.attendeeIds,
        courtLabel: session.labelForCourt,
      );
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: Consumer(
          builder: (context, ref, _) {
            ref.watch(sessionControllerProvider(sessionId));
            return buildView();
          },
        ))),
      ),
    );
    await settle(tester);

    // Click 가's chip in game 2 -> counts through games 1~2.
    final gaChips = find.widgetWithText(PlayerChip, '가');
    expect(gaChips, findsNWidgets(2));
    await tester.tap(gaChips.at(1));
    await settle(tester);
    expect(find.text('가 · 같이 친 횟수'), findsOneWidget);
    expect(find.text('게임 1~2 기준 · 같은 코트에서 친 횟수'), findsOneWidget);
    expect(find.text('2회'), findsNWidgets(3));
    await tester.tap(find.text('닫기'));
    await settle(tester);

    // Click in game 1 -> only game 1 counted.
    await tester.tap(gaChips.at(0));
    await settle(tester);
    expect(find.text('게임 1 기준 · 같은 코트에서 친 횟수'), findsOneWidget);
    expect(find.text('1회'), findsNWidgets(3));
    await tester.tap(find.text('닫기'));
    await settle(tester);

    // Right-click -> 사용자 빼기 -> from game 2.
    await tester.tap(gaChips.at(0), buttons: kSecondaryButton);
    await settle(tester);
    await tester.tap(find.text('사용자 빼기'));
    await settle(tester);
    expect(find.text('가 빼기'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '2');
    await tester.tap(find.text('빼기'));
    await settle(tester);

    final session =
        container.read(sessionControllerProvider(sessionId)).requireValue;
    final ga = idByName['가']!;
    expect(session.rounds[0].courts.single.playerIds, contains(ga));
    expect(session.rounds[1].courts.single.playerIds, isNot(contains(ga)));
    expect(session.rounds[1].courts.single.playerIds, hasLength(3));
    expect(session.attendeeIds, isNot(contains(ga)));
    expect(find.text('3/4'), findsOneWidget);
  });
}
