import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/app.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';

void main() {
  testWidgets('opens the local guest workspace without a login gate', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const IntQaFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IntQAFlow guest workspace'), findsOneWidget);
    expect(find.text('Knowledge'), findsOneWidget);
    expect(find.text('Interact'), findsOneWidget);
    expect(find.byTooltip('Sign in or create account'), findsOneWidget);
  });
}
