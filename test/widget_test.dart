// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learining_portal/main.dart';

void main() {
  testWidgets(
    'App builds smoke test',
    (WidgetTester tester) async {
      // This app requires Firebase initialization for providers.
      // Keep this as a placeholder test until a proper Firebase test setup is added.
      await tester.pumpWidget(
        MyApp(
          initialAuthState: InitialAuthState(isAuthenticated: false),
        ),
      );
      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);
    },
    skip: true,
  );
}
