import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/domain/taetigkeit/taetigkeit.dart';
import 'package:nami/presentation/widgets/member_roles_statistik_pie.dart';

void main() {
  Widget buildTestWidget(List<Taetigkeit> roles) {
    return MaterialApp(
      home: Scaffold(body: MemberRolesStatistikPie(roles: roles)),
    );
  }

  testWidgets('renders nothing when all roles share one stufe', (tester) async {
    final roles = [
      Taetigkeit(
        stufe: Stufe.woelfling,
        art: TaetigkeitsArt.mitglied,
        start: DateTime(2022, 1, 1),
        ende: DateTime(2022, 4, 1),
      ),
      Taetigkeit(
        stufe: Stufe.woelfling,
        art: TaetigkeitsArt.leitung,
        start: DateTime(2022, 4, 1),
        ende: DateTime(2022, 8, 1),
      ),
    ];

    await tester.pumpWidget(buildTestWidget(roles));

    expect(
      find.descendant(
        of: find.byType(MemberRolesStatistikPie),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('renders pie when multiple stufen are present', (tester) async {
    final roles = [
      Taetigkeit(
        stufe: Stufe.woelfling,
        art: TaetigkeitsArt.mitglied,
        start: DateTime(2022, 1, 1),
        ende: DateTime(2022, 4, 1),
      ),
      Taetigkeit(
        stufe: Stufe.rover,
        art: TaetigkeitsArt.leitung,
        start: DateTime(2022, 4, 1),
        ende: DateTime(2022, 8, 1),
      ),
    ];

    await tester.pumpWidget(buildTestWidget(roles));

    expect(
      find.descendant(
        of: find.byType(MemberRolesStatistikPie),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });
}
