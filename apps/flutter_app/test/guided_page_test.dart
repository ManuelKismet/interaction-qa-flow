import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_page.dart';

class _TemplateTestRepository extends GuidedRepository {
  _TemplateTestRepository() : super(Dio());

  final List<GuidedTemplate> templates = [];
  List<GuidedTemplateQuestion>? savedVersion;
  String? restoredTemplateId;

  void addTemplate(GuidedTemplate template) => templates.add(template);

  @override
  Future<List<GuidedSessionSummary>> listSessions({String? status}) async =>
      const [];

  @override
  Future<List<GuidedTemplate>> listTemplates() async => templates;

  @override
  Future<void> versionTemplate(
    String id,
    List<GuidedTemplateQuestion> questions,
  ) async {
    savedVersion = questions;
  }

  @override
  Future<void> restoreTemplate(String id) async {
    restoredTemplateId = id;
    final index = templates.indexWhere((template) => template.id == id);
    final template = templates[index];
    templates[index] = GuidedTemplate(
      id: template.id,
      name: template.name,
      description: template.description,
      status: 'active',
      currentVersion: template.currentVersion,
      questions: template.questions,
    );
  }
}

void main() {
  testWidgets('Interact navigation toolbar fits a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const template = GuidedTemplate(
      id: 'template-1',
      name: 'Template',
      status: 'active',
      currentVersion: 1,
      questions: [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidedRepositoryProvider.overrideWithValue(
            _TemplateTestRepository()..addTemplate(template),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: GuidedPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IntQAFlow Interact'), findsOneWidget);
    expect(find.text('New session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new template version uses edited draft and preserves snapshots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const originalQuestion = GuidedTemplateQuestion(
      id: 'question-1',
      text: 'Original template question',
      scope: 'shared',
      orderIndex: 0,
    );
    const template = GuidedTemplate(
      id: 'template-1',
      name: 'Template',
      status: 'active',
      currentVersion: 1,
      questions: [originalQuestion],
    );
    final repository = _TemplateTestRepository()..addTemplate(template);
    final existingSessionSnapshot = const GuidedQuestion(
      id: 'session-question-1',
      text: 'Original template question',
      scope: 'shared',
      source: 'manual',
      answers: [],
      followUps: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidedRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: Scaffold(body: GuidedPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(ListView).first).width,
      lessThanOrEqualTo(1040),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as new version'));
    await tester.pumpAndSettle();

    final questionField = find.byKey(
      const ValueKey('template-question-question-1'),
    );
    await tester.enterText(questionField, 'Updated template question');
    await tester.tap(find.text('Save new version'));
    await tester.pumpAndSettle();

    expect(repository.savedVersion, hasLength(1));
    expect(repository.savedVersion!.single.text, 'Updated template question');
    expect(repository.savedVersion!.single.orderIndex, 0);
    expect(template.questions.single.text, 'Original template question');
    expect(existingSessionSnapshot.text, 'Original template question');
  });

  testWidgets('archived templates can be restored without changing versions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const template = GuidedTemplate(
      id: 'archived-template',
      name: 'Archived template',
      status: 'archived',
      currentVersion: 3,
      questions: [
        GuidedTemplateQuestion(
          id: 'question-1',
          text: 'Keep this question',
          scope: 'shared',
          orderIndex: 0,
        ),
      ],
    );
    final repository = _TemplateTestRepository()..addTemplate(template);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidedRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: Scaffold(body: GuidedPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    expect(find.text('Archived template'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Save as new version'), findsNothing);
    expect(find.text('Duplicate'), findsNothing);
    expect(find.text('Archive'), findsNothing);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(repository.restoredTemplateId, template.id);
    final restored = repository.templates.single;
    expect(restored.status, 'active');
    expect(restored.currentVersion, template.currentVersion);
    expect(restored.questions.single.text, template.questions.single.text);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNotNull);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Save as new version'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
  });
}
