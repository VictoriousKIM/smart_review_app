// Smart Review App widget tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic widget test', (WidgetTester tester) async {
    // Simple test to verify Flutter test environment works
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Hello World'))),
      ),
    );

    // Verify that the text is displayed
    expect(find.text('Hello World'), findsOneWidget);
  });

  testWidgets('Material 3 theme test', (WidgetTester tester) async {
    // Test Material 3 theme configuration
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const Scaffold(body: Center(child: Text('Theme Test'))),
      ),
    );

    // Verify that the text is displayed
    expect(find.text('Theme Test'), findsOneWidget);

    // Verify Material 3 is enabled
    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.theme?.useMaterial3, isTrue);
  });
}
