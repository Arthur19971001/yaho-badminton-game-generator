import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yaho_badminton_game_generator/src/features/grades/application/grades_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/grades/domain/grade.dart';
import 'package:yaho_badminton_game_generator/src/features/members/application/members_controller.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/gender.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/member.dart';
import 'package:yaho_badminton_game_generator/src/features/members/presentation/screens/members_screen.dart';

/// Smoke test for the members screen, with the controller overridden so it
/// never touches the real sqlite database (unavailable under `flutter test`).
void main() {
  testWidgets('members screen lists members from the controller', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membersControllerProvider.overrideWith(_FakeMembersController.new),
          gradesControllerProvider.overrideWith(_FakeGradesController.new),
        ],
        child: const MaterialApp(home: MembersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('홍길동'), findsOneWidget);
    // Grade is only shown in the edit dialog, not in the list itself.
    expect(find.text('D급'), findsNothing);
    expect(find.textContaining('D ('), findsNothing);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('회원 수정'), findsOneWidget);
    expect(find.text('D (4점)'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    // An ungraded member's edit dialog shows the lowest grade, and the
    // dropdown has no "없음" choice.
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '김영희'), findsOneWidget);
    expect(find.text('D (4점)'), findsOneWidget);
    await tester.tap(find.text('D (4점)'));
    await tester.pumpAndSettle();
    expect(find.text('A (10점)'), findsWidgets);
    expect(find.text('없음'), findsNothing);
  });
}

class _FakeMembersController extends MembersController {
  @override
  Future<List<Member>> build() async => const [
        Member(id: 1, name: '홍길동', gender: Gender.male, gradeId: 4),
        Member(id: 2, name: '김영희', gender: Gender.female),
      ];
}

class _FakeGradesController extends GradesController {
  @override
  Future<List<Grade>> build() async => const [
        Grade(id: 1, name: 'A', points: 10, sortOrder: 0),
        Grade(id: 4, name: 'D', points: 4, sortOrder: 3),
      ];
}
