import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app/main.dart';

void main() {
  testWidgets('Budget app mounts and displays dashboard', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BudgetApp());

    // Verify that the navigation rail items are present
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
  });
}
