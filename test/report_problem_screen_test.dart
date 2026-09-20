import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/screens/report_problem_screen.dart';

void main() {
  testWidgets('report screen is a simple description and send flow', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ReportProblemScreen()));

    expect(find.text('Report a problem'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Send report'), findsOneWidget);
    expect(find.text('What gets sent'), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
  });
}
