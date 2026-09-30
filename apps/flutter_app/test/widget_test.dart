import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/app.dart';

void main() {
  testWidgets('shows IntQAFlow Knowledge and platform modules', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: IntQaFlowApp()));

    expect(find.text('IntQAFlow Knowledge'), findsOneWidget);
    expect(find.text('What do you need to know?'), findsOneWidget);
    expect(find.text('Ask a question'), findsOneWidget);
    expect(find.text('Add detail (optional)'), findsOneWidget);
    expect(find.text('Ask'), findsWidgets);
    expect(find.text('Knowledge'), findsOneWidget);
    expect(find.text('Questions'), findsOneWidget);
    expect(find.text('Interact'), findsOneWidget);
    expect(find.text('Review'), findsNothing);
    expect(find.text('Admin'), findsNothing);

    final platformDestinations = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destination) => destination.label);
    expect(platformDestinations, isNot(contains('Questions')));
  });
}
