import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride_track/main.dart';

void main() {
  testWidgets('Smoke test: Ensure app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const StrideTrackApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
