import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/app.dart';

void main() {
  testWidgets('opens the local guest workspace without a login gate', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: IntQaFlowApp(firebaseReady: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IntQAFlow guest workspace'), findsOneWidget);
    expect(find.text('Knowledge'), findsOneWidget);
    expect(find.text('Interact'), findsOneWidget);
    expect(find.text('Sign in to IntQAFlow'), findsNothing);
    expect(find.text('Add a local question'), findsOneWidget);
    expect(find.text('Search Knowledge'), findsOneWidget);
    expect(find.text('Saved Q&A'), findsOneWidget);
    await tester.tap(find.text('Saved Q&A'));
    await tester.pumpAndSettle();
    expect(find.text('Search Knowledge'), findsOneWidget);
    await tester.tap(find.text('Back to add a local question'));
    await tester.pumpAndSettle();
    expect(find.text('Create session locally'), findsNothing);
    await tester.tap(find.text('Interact'));
    await tester.pumpAndSettle();
    expect(find.text('Create session locally'), findsOneWidget);
  });
}
