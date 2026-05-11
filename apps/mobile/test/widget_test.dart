import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:suklu_mobile/app.dart';

void main() {
  testWidgets('SukluApp builds root widget tree', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SukluApp()));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
