import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yaho_badminton_game_generator/src/app.dart';
import 'package:yaho_badminton_game_generator/src/database/app_database.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/presentation/widgets/court_slot.dart';
import 'package:yaho_badminton_game_generator/src/features/sessions/presentation/widgets/player_chip.dart';

/// Creates one new session (via the sessions branch's "add" FAB + accepting
/// the date picker's default date), marks every one of [attendeeNames] as
/// attending, then hand-builds two empty games (round id 1 and 2 -- ids are
/// scoped per-session, so this is true for *every* session created this
/// way, not just the first) via the "빈 게임 추가" action -- everyone starts
/// resting on 0 courts in both, for full deterministic control. Must be
/// called while the sessions list ("세션" app bar title) is on screen; ends
/// on that new session's results screen (default table view).
Future<void> _createSessionWithTwoEmptyGames(
  WidgetTester tester, {
  required List<String> attendeeNames,
}) async {
  // Scope to the AppBar -- the shell's NavigationRail also has a '세션'
  // destination label mounted at the same time, making bare find.text
  // ambiguous (findsNWidgets(2)).
  expect(find.widgetWithText(AppBar, '세션'), findsOneWidget);

  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  await tester.tap(find.text('확인'));
  await tester.pumpAndSettle();

  expect(find.text('참여 인원 선택'), findsOneWidget);
  for (final name in attendeeNames) {
    await tester.tap(find.widgetWithText(CheckboxListTile, name));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('저장하고 게임 설정으로'));
  await tester.pumpAndSettle();
  expect(find.text('게임 생성 설정'), findsOneWidget);

  // Game 1 (round id 1): empty courts, everyone resting.
  await tester.ensureVisible(find.text('빈 게임 추가'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('빈 게임 추가'));
  await tester.pumpAndSettle();
  expect(find.text('게임 결과'), findsOneWidget);
  expect(find.text('게임 1'), findsOneWidget);

  // Game 2 (round id 2): reached via the results screen's own "add" action,
  // which reopens the setup screen with fromResults=true and pops straight
  // back to results afterwards.
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  expect(find.text('게임 생성 설정'), findsOneWidget);
  await tester.ensureVisible(find.text('빈 게임 추가'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('빈 게임 추가'));
  await tester.pumpAndSettle();
  expect(find.text('게임 결과'), findsOneWidget);
  expect(find.text('게임 2'), findsOneWidget);
}

/// Pops the root navigator back from a just-built session's results screen
/// (results -> setup -> attendance pushed on top of the sessions list) to
/// the sessions list branch, so a second, independent session can be
/// created from the same still-running app/db instead of relaunching the
/// whole app (relaunching mid-test was tried first and found to leave
/// go_router's *platform*-reported route -- which persists across a second
/// `pumpWidget` within the same test process -- pointing at the old
/// session's route instead of resetting to '/members', so the second
/// "session" silently never got created). Pops until no back button is
/// left rather than a fixed count, since exactly how many pushes are on the
/// stack is an implementation detail of the setup/results navigation flow.
/// Taps the back button directly (rather than via [WidgetTester.pageBack],
/// which only recognizes the English "Back" tooltip or a Cupertino back
/// button) since the app's locale is Korean, so the AppBar back button's
/// tooltip is localized to "뒤로".
Future<void> _returnToSessionsList(WidgetTester tester) async {
  var guard = 0;
  while (find.byTooltip('뒤로').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('뒤로').first);
    await tester.pumpAndSettle();
    guard++;
    expect(guard, lessThan(10), reason: 'too many back-navigations; stuck?');
  }
  // Scope to the AppBar -- the shell's NavigationRail also has a '세션'
  // destination label mounted at the same time, making bare find.text
  // ambiguous (findsNWidgets(2)).
  expect(find.widgetWithText(AppBar, '세션'), findsOneWidget);
}

/// Drags [playerName] from game 1's resting bench onto game 1's (sole)
/// court, while still on the table view. Used to give one specific player
/// ("P") a playing status in game 1 while everyone else -- including "Q" --
/// stays resting in both games.
Future<void> _dragOntoGame1Court(WidgetTester tester, String playerName) async {
  final firstGameCard = find.byType(Card).first;
  final courtInFirstGame =
      find.descendant(of: firstGameCard, matching: find.byType(CourtSlot));
  expect(courtInFirstGame, findsOneWidget);

  final chip = find.descendant(
    of: firstGameCard,
    matching: find.widgetWithText(Chip, playerName),
  );
  expect(chip, findsOneWidget);

  await tester.drag(
    chip,
    tester.getCenter(courtInFirstGame) - tester.getCenter(chip),
  );
  await tester.pumpAndSettle();
}

/// Reads the currently-displayed content of the person-view cell for
/// [roundId] x [playerId] (located via the stable key added to
/// [ScheduleGridView]'s cells), returning either the resting label ('휴식')
/// or the court label text (e.g. '코트 1').
String _cellContent(WidgetTester tester, int roundId, int playerId) {
  final cell = find.byKey(ValueKey('schedule-cell-$roundId-$playerId'));
  expect(
    cell,
    findsOneWidget,
    reason: 'expected exactly one schedule cell for round $roundId, '
        'player $playerId',
  );

  if (find
      .descendant(of: cell, matching: find.text('휴식'))
      .evaluate()
      .isNotEmpty) {
    return '휴식';
  }

  final texts = tester
      .widgetList<Text>(find.descendant(of: cell, matching: find.byType(Text)))
      .map((t) => t.data)
      .whereType<String>()
      .toList();
  return texts.isNotEmpty ? texts.first : '<no text found in cell>';
}

/// End-to-end smoke test driving the real app UI: register members, create
/// a session, pick attendees, generate games, and switch between the table
/// and full views. Uses a fresh in-memory database per run so it never
/// touches the real app's persisted data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('members -> session -> attendance -> generate -> views', (
    tester,
  ) async {
    final db = await openAppDatabase(inMemoryDatabasePath);
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('회원 관리'), findsWidgets);

    const members = [
      ('철수', false),
      ('영희', true),
      ('민수', false),
      ('지은', true),
      ('현우', false),
      ('수진', true),
      ('동현', false),
      ('은지', true),
    ];

    for (final (name, isFemale) in members) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), name);
      if (isFemale) {
        await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('여'),
        ));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('저장'),
      ));
      await tester.pumpAndSettle();
    }

    for (final (name, _) in members) {
      expect(find.text(name), findsOneWidget);
    }

    // Tap the rail icon rather than the label text -- the shell keeps both
    // branch screens (and their matching-text AppBar titles) mounted at
    // once, so "세션" as text is ambiguous.
    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Accept the date picker's default (today) selection.
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('참여 인원 선택'), findsOneWidget);
    for (final (name, _) in members) {
      // The members shell screen stays mounted underneath, so scope to the
      // CheckboxListTile (unique to this screen) instead of bare text.
      await tester.tap(find.widgetWithText(CheckboxListTile, name));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('저장하고 게임 설정으로'));
    await tester.pumpAndSettle();

    expect(find.text('게임 생성 설정'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '생성할 게임 수'), '4');
    await tester.enterText(find.widgetWithText(TextField, '예약한 코트 수'), '2');
    // Gender balance on -- the first 예/아니오 toggle (the second one is
    // 급수 밸런스).
    await tester.tap(find.text('예').first);
    await tester.pumpAndSettle();

    // The court-name fields can push the generate button below the fold.
    await tester.ensureVisible(find.text('게임 생성'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('게임 생성'));
    await tester.pumpAndSettle();

    expect(find.text('게임 결과'), findsOneWidget);
    expect(find.text('게임 1'), findsOneWidget);
    expect(find.text('코트 1'), findsWidgets);
    expect(find.text('코트 2'), findsWidgets);

    // Game 4's card is below the fold in the reorderable list.
    await tester.scrollUntilVisible(find.text('게임 4'), 300);
    await tester.pumpAndSettle();
    expect(find.text('게임 4'), findsOneWidget);

    // Switch to full view.
    await tester.tap(find.byIcon(Icons.grid_view));
    await tester.pumpAndSettle();

    expect(find.text('코트 1'), findsOneWidget);

    // On the first game, "previous" is disabled; DropdownMenu pre-renders
    // an invisible copy of its entries to measure their width, so a bare
    // find.text('게임 N') is ambiguous -- use button enablement instead to
    // confirm navigation actually moved.
    IconButton previousButton() =>
        tester.widget(find.widgetWithIcon(IconButton, Icons.chevron_left));
    expect(previousButton().onPressed, isNull);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(previousButton().onPressed, isNotNull);

    // Switch to the per-person grid view: one row per person, one column
    // per game, showing which court they played (or that they rested).
    await tester.tap(find.byIcon(Icons.person_search));
    await tester.pumpAndSettle();

    expect(find.text('이름'), findsOneWidget);
    expect(find.text('게임 1'), findsOneWidget);
    expect(find.text('게임 4'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsWidgets);
    // All 8 attendees fill both courts every round in this scenario, so
    // nobody ever rests.
    expect(find.text('휴식'), findsNothing);

    // Switch back to table view.
    await tester.tap(find.byIcon(Icons.table_chart_outlined));
    await tester.pumpAndSettle();

    expect(find.text('게임 1'), findsOneWidget);

    // Drag-and-drop: move a player from game 1's court 2 into court 1,
    // which should overflow it to 5 players and flag it red.
    final firstGameCard = find.byType(Card).first;
    final courtsInFirstGame =
        find.descendant(of: firstGameCard, matching: find.byType(CourtSlot));
    expect(courtsInFirstGame, findsNWidgets(2));

    final court1Center = tester.getCenter(courtsInFirstGame.at(0));
    final chipInCourt2 = find
        .descendant(
          of: courtsInFirstGame.at(1),
          matching: find.byType(PlayerChip),
        )
        .first;
    final chipCenter = tester.getCenter(chipInCourt2);

    await tester.drag(chipInCourt2, court1Center - chipCenter);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: firstGameCard, matching: find.byIcon(Icons.error)),
      findsOneWidget,
    );

    // Delete that (now-overflowing) game and confirm the rest renumber.
    await tester.tap(find.descendant(
      of: firstGameCard,
      matching: find.byIcon(Icons.delete_outline),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('삭제'),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('게임 3'), 300);
    await tester.pumpAndSettle();
    expect(find.text('게임 3'), findsOneWidget);
    expect(find.text('게임 4'), findsNothing);
  });

  testWidgets('guest flow: add, auto-attend, place, remove, empty game', (
    tester,
  ) async {
    final db = await openAppDatabase(inMemoryDatabasePath);
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    for (final name in ['가영', '나영', '다영', '라영']) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), name);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('저장'),
      ));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Add a guest -- not a club member, should show up under its own
    // "게스트" section and be auto-checked as attending. The dialog must
    // say "게스트 추가", not the member dialog's default "회원 추가", even
    // though it's the same underlying form.
    await tester.tap(find.byIcon(Icons.person_add_alt_1));
    await tester.pumpAndSettle();
    expect(find.text('게스트 추가'), findsOneWidget);
    expect(find.text('회원 추가'), findsNothing);
    await tester.enterText(find.byType(TextFormField), '손님1');
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('저장'),
    ));
    await tester.pumpAndSettle();

    final guestTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '손님1'),
    );
    expect(guestTile.value, isTrue);

    for (final name in ['가영', '나영', '다영', '라영']) {
      await tester.tap(find.widgetWithText(CheckboxListTile, name));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('저장하고 게임 설정으로'));
    await tester.pumpAndSettle();
    expect(find.text('게임 생성 설정'), findsOneWidget);

    // Brand-new session defaults to 1 court -- create an empty game by hand
    // instead of running the generator.
    await tester.ensureVisible(find.text('빈 게임 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('빈 게임 추가'));
    await tester.pumpAndSettle();

    expect(find.text('게임 결과'), findsOneWidget);
    expect(find.text('게임 1'), findsOneWidget);
    expect(find.text('0/4'), findsOneWidget);
    // Everyone (4 members + the guest) starts on the bench, including the
    // guest by name.
    expect(find.text('손님1'), findsOneWidget);

    // Drag the guest from the resting bench into the empty court.
    final courtSlot = find.byType(CourtSlot).first;
    final guestChip = find.widgetWithText(Chip, '손님1').first;

    await tester.drag(
      guestChip,
      tester.getCenter(courtSlot) - tester.getCenter(guestChip),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/4'), findsOneWidget);

    // Now remove the guest entirely via the attendance edit flow, reached
    // through the setup screen's "참여 인원 수정" action.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('게임 생성 설정'), findsOneWidget);

    await tester.tap(find.text('참여 인원 수정'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.widgetWithText(CheckboxListTile, '손님1'),
      matching: find.byIcon(Icons.close),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CheckboxListTile, '손님1'), findsNothing);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    // Back on results: the guest still placed in the court from earlier
    // shows as an unknown player instead of silently vanishing.
    expect(find.text('게임 생성 설정'), findsOneWidget);
  });

  testWidgets('custom court names replace the default 코트 N label everywhere', (
    tester,
  ) async {
    final db = await openAppDatabase(inMemoryDatabasePath);
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    // Keep the club roster small (no scrolling needed to check every box)
    // and make up the rest of the 12 attendees needed to fill 3 courts via
    // guests added directly from the game setup screen.
    for (var i = 1; i <= 4; i++) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '회원$i');
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('저장'),
      ));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    for (var i = 1; i <= 4; i++) {
      await tester.tap(find.widgetWithText(CheckboxListTile, '회원$i'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('저장하고 게임 설정으로'));
    await tester.pumpAndSettle();
    expect(find.text('게임 생성 설정'), findsOneWidget);

    // Add 8 guests right from the setup screen to reach 12 attendees total.
    for (var i = 1; i <= 8; i++) {
      await tester.tap(find.text('게스트 추가'));
      await tester.pumpAndSettle();
      if (i == 1) {
        // This is a separate call site from the attendance screen's guest
        // dialog -- confirm it also got the "게스트 추가" title fix.
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('게스트 추가'),
          ),
          findsOneWidget,
        );
      }
      await tester.enterText(find.byType(TextFormField), '손님$i');
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('저장'),
      ));
      await tester.pumpAndSettle();
    }
    expect(find.text('참여 인원: 12명'), findsOneWidget);

    // 3 courts -> 3 name fields should appear, prefilled empty.
    await tester.enterText(find.widgetWithText(TextField, '예약한 코트 수'), '3');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '코트 1 이름'), findsOneWidget);
    expect(find.widgetWithText(TextField, '코트 2 이름'), findsOneWidget);
    expect(find.widgetWithText(TextField, '코트 3 이름'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '코트 1 이름'), '19번');
    await tester.enterText(find.widgetWithText(TextField, '코트 2 이름'), '20번');
    await tester.enterText(find.widgetWithText(TextField, '코트 3 이름'), '30번');
    await tester.enterText(find.widgetWithText(TextField, '생성할 게임 수'), '2');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('게임 생성'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('게임 생성'));
    await tester.pumpAndSettle();

    expect(find.text('게임 결과'), findsOneWidget);
    // Table view: custom labels show up, default "코트 N" no longer does.
    expect(find.text('19번'), findsWidgets);
    expect(find.text('20번'), findsWidgets);
    expect(find.text('30번'), findsWidgets);
    expect(find.text('코트 1'), findsNothing);
    expect(find.text('코트 2'), findsNothing);
    expect(find.text('코트 3'), findsNothing);

    // Full view: same custom labels.
    await tester.tap(find.byIcon(Icons.grid_view));
    await tester.pumpAndSettle();
    expect(find.text('19번'), findsWidgets);

    // Going back to setup and reopening it should show the saved names
    // pre-filled, not blank.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '코트 1 이름'), findsOneWidget);
    final refilled = tester.widget<TextField>(
      find.widgetWithText(TextField, '코트 1 이름'),
    );
    expect(refilled.controller?.text, '19번');
  });

  testWidgets(
    'person-view drag-and-drop: swapping a playing cell with a resting '
    'cell across two different games',
    (tester) async {
      // One fresh in-memory DB, one app launch, for the whole test => member
      // ids are assigned 1..5 in the order added below (stable across both
      // sessions created further down), and GameRound.nextId assigns round
      // ids 1 and 2 to game 1 and game 2 of *each* session (round ids are
      // scoped per-session) -- both relied on to build the schedule-cell
      // keys directly instead of re-deriving them at runtime.
      const members = ['가영', '나영', '다영', '라영', '마영'];
      const pName = '가영';
      const pId = 1;
      const qId = 2;
      const game1RoundId = 1;
      const game2RoundId = 2;

      final db = await openAppDatabase(inMemoryDatabasePath);
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      for (final name in members) {
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), name);
        await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('저장'),
        ));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byIcon(Icons.event_outlined));
      await tester.pumpAndSettle();

      // --- Session 1 / Scenario A: drag P's (playing) game-1 cell onto Q's
      // (resting) game-2 cell. ---
      await _createSessionWithTwoEmptyGames(tester, attendeeNames: members);
      await _dragOntoGame1Court(tester, pName);
      // P now on the sole court in game 1; confirm the mechanical drag
      // worked (no silent no-op) before moving on.
      expect(find.text('1/4'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_search));
      await tester.pumpAndSettle();

      // Before the swap: P plays game 1, Q rests in both games, P rests in
      // game 2 -- the deterministic baseline the "add empty game" action
      // guarantees.
      final beforePGame1 = _cellContent(tester, game1RoundId, pId);
      final beforeQGame1 = _cellContent(tester, game1RoundId, qId);
      final beforePGame2 = _cellContent(tester, game2RoundId, pId);
      final beforeQGame2 = _cellContent(tester, game2RoundId, qId);
      expect(beforePGame1, '코트 1');
      expect(beforeQGame1, '휴식');
      expect(beforePGame2, '휴식');
      expect(beforeQGame2, '휴식');

      final sourceA = find.byKey(const ValueKey('schedule-cell-1-1')); // P/game1
      final targetA = find.byKey(const ValueKey('schedule-cell-2-2')); // Q/game2
      await tester.drag(
        sourceA,
        tester.getCenter(targetA) - tester.getCenter(sourceA),
      );
      await tester.pumpAndSettle();

      final afterPGame1 = _cellContent(tester, game1RoundId, pId);
      final afterQGame1 = _cellContent(tester, game1RoundId, qId);
      final afterPGame2 = _cellContent(tester, game2RoundId, pId);
      final afterQGame2 = _cellContent(tester, game2RoundId, qId);

      // P leaves game 1's court; Q takes over P's exact old court there.
      expect(afterPGame1, '휴식');
      expect(afterQGame1, '코트 1');
      // P ends up resting in game 2 (unchanged visually -- was already
      // resting). Q's own game-2 cell -- the one actually dropped onto --
      // shows NO visible change at all: still '휴식', even though Q no
      // longer has any explicit presence in game 2's data (the UI's
      // "resting" label is really just "not found on any court", so it
      // can't distinguish "explicitly resting" from "not present in this
      // round at all").
      expect(afterPGame2, '휴식');
      expect(afterQGame2, '휴식');

      // --- Session 2 / Scenario B: same baseline, opposite drag direction
      // -- drag Q's resting game-2 cell onto P's playing game-1 cell.
      // Reuses the same running app/db (see _returnToSessionsList's doc for
      // why a second full app relaunch doesn't work here). ---
      await _returnToSessionsList(tester);
      await _createSessionWithTwoEmptyGames(tester, attendeeNames: members);
      await _dragOntoGame1Court(tester, pName);
      expect(find.text('1/4'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_search));
      await tester.pumpAndSettle();

      expect(_cellContent(tester, game1RoundId, pId), '코트 1');
      expect(_cellContent(tester, game1RoundId, qId), '휴식');
      expect(_cellContent(tester, game2RoundId, pId), '휴식');
      expect(_cellContent(tester, game2RoundId, qId), '휴식');

      final sourceB = find.byKey(const ValueKey('schedule-cell-2-2')); // Q/game2
      final targetB = find.byKey(const ValueKey('schedule-cell-1-1')); // P/game1
      await tester.drag(
        sourceB,
        tester.getCenter(targetB) - tester.getCenter(sourceB),
      );
      await tester.pumpAndSettle();

      // Reverse drag direction produces the identical end state as
      // Scenario A -- the swap's net effect doesn't depend on which side
      // was dragged from vs. dropped onto.
      expect(_cellContent(tester, game1RoundId, pId), '휴식');
      expect(_cellContent(tester, game1RoundId, qId), '코트 1');
      expect(_cellContent(tester, game2RoundId, pId), '휴식');
      expect(_cellContent(tester, game2RoundId, qId), '휴식');
    },
  );
}
