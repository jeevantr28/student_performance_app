// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_performance_app/prediction_unavailable_screen.dart';

void main() {
  testWidgets('prediction screen states that the feature is unavailable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PredictionUnavailableScreen()),
    );

    expect(find.text('Prediction is not available yet'), findsOneWidget);
    expect(find.textContaining('sample-data estimate'), findsOneWidget);
  });
}
