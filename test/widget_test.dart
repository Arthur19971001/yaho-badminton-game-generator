import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
        ],
        child: const MaterialApp(home: MembersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('홍길동'), findsOneWidget);
  });
}

class _FakeMembersController extends MembersController {
  @override
  Future<List<Member>> build() async => const [
        Member(id: 1, name: '홍길동', gender: Gender.male),
      ];
}
