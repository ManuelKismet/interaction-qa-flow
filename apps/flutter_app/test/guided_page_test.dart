import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/guided/application/guided_providers.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_page.dart';

class _TemplateTestRepository extends GuidedRepository {
  _TemplateTestRepository(this.template) : super(Dio());

  final GuidedTemplate template;
  List<GuidedTemplateQuestion>? savedVersion;

  @override
  Future<List<GuidedSessionSummary>> listSessions({String? status}) async =>
      const [];

  @override
  Future<List<GuidedTemplate>> listTemplates() async => [template];

  @override
  Future<void> versionTemplate(
    String id,
    List<GuidedTemplateQuestion> questions,
  ) async {
    savedVersion = questions;
  }
}

void main() {
  testWidgets('new template version uses edited draft and preserves snapshots', (
    tester,
  ) async {
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
    final repository = _TemplateTestRepository(template);
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
}
