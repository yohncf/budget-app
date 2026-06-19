import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app/views/login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Budget app mounts and displays login page', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(currentUser: null),
      ),
    );
    await tester.pump();

    // Verify that the login screen mounts
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Personal Ledger'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
