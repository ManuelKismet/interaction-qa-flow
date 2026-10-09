import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/app.dart';
import 'package:int_qa_flow/core/theme/app_theme.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage_interface.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/shared/utils/responsive.dart';

class _Storage implements GuestStorage {
  String? value;
  @override
  String? read() => value;
  @override
  void write(String value) => this.value = value;
  @override
  void remove() => value = null;
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(360, 740),
    const Size(390, 844),
    const Size(600, 900),
    const Size(1100, 900),
    const Size(740, 360),
  ]) {
    testWidgets('Guest Knowledge and Interact remain usable at $size', (
      tester,
    ) async {
      _viewport(tester, size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guestWorkspaceStoreProvider.overrideWithValue(
              GuestWorkspaceStore(_Storage()),
            ),
          ],
          child: const IntQaFlowApp(firebaseReady: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final switcher = find.byTooltip('Switch Knowledge or Interact');
      if (switcher.evaluate().isNotEmpty) {
        await tester.tap(switcher);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Interact').last);
      } else {
        await tester.tap(find.text('Interact').last);
      }
      await tester.pumpAndSettle();
      final create = find.text('Create session locally');
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      expect(create.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      final button = find.ancestor(
        of: create,
        matching: find.byType(FilledButton),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    });
  }
  testWidgets('compact controls preserve large text and keyboard scrolling', (
    tester,
  ) async {
    _viewport(tester, const Size(320, 640));
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: Builder(
            builder: (context) => AppTheme.responsiveBuilder(context, child),
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => SingleChildScrollView(
              padding: Responsive.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Organisation workspace',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const TextField(
                    decoration: InputDecoration(labelText: 'Session title'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => taps++,
                    child: const Text('Add shared question'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fieldContext = tester.element(find.byType(TextField));
    expect(MediaQuery.textScalerOf(fieldContext).scale(14), 28);
    final button = find.widgetWithText(FilledButton, 'Add shared question');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
