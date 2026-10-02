import 'package:int_qa_flow/features/guided/domain/guided_models.dart';

String buildGuidedReportDocument({
  required GuidedSessionDetail session,
  required bool allParticipants,
  required String? participantId,
  required DateTime generatedAt,
}) {
  final participantNames = {
    for (final participant in session.participants) participant.id: participant.name,
  };
  String participantName(String? id) =>
      participantNames[id] ?? 'Participant';

  bool isRelevant(GuidedQuestion question) {
    if (question.deletedAt != null) return false;
    if (allParticipants) return true;
    if (question.source == 'follow_up') {
      return participantId != null &&
          question.targetParticipantId == participantId;
    }
    if (question.scope == 'shared') return true;
    return participantId != null &&
        question.targetParticipantId == participantId;
  }

  List<String> answerTargets(GuidedQuestion question) {
    if (!allParticipants) {
      return participantId == null ? const [] : [participantId];
    }
    if (question.scope == 'participant' &&
        question.targetParticipantId != null) {
      return [question.targetParticipantId!];
    }
    final ids = <String>[
      for (final participant in session.participants) participant.id,
    ];
    for (final answer in question.answers) {
      if (!ids.contains(answer.participantId)) ids.add(answer.participantId);
    }
    return ids;
  }

  List<String> renderQuestion(
    GuidedQuestion question, {
    required List<int> path,
    String? parentText,
    GuidedAnswer? triggerAnswer,
  }) {
    if (!isRelevant(question)) return const [];
    final depth = path.length - 1;
    final indent = (depth * 10).clamp(0, 28);
    final targets = answerTargets(question);
    final sections = <String>[
      '''
<section class="question${question.source == 'follow_up' ? ' follow-up' : ''}" style="margin-left: ${indent}px">
  <p class="path">Path ${path.join('.')} · ${question.source == 'follow_up' ? 'Follow-up' : 'Question'}</p>
  ${parentText == null ? '' : '<p class="parent">Parent question: ${_escapeHtml(parentText)}</p>'}
  ${triggerAnswer == null ? '' : '<p class="parent">Triggered by ${_escapeHtml(participantName(triggerAnswer.participantId))}: ${_escapeHtml(triggerAnswer.body.trim().isEmpty ? 'Unanswered.' : triggerAnswer.body)}</p>'}
  <h2>${_escapeHtml(question.text)}</h2>
</section>''',
    ];
    if (targets.isEmpty) {
      sections.add(
        '<article class="answer" style="margin-left: ${indent}px"><h3>Answer</h3><p>Unanswered.</p></article>',
      );
    } else {
      for (final targetId in targets) {
        GuidedAnswer? answer;
        for (final candidate in question.answers) {
          if (candidate.participantId == targetId) {
            answer = candidate;
            break;
          }
        }
        sections.add('''
<article class="answer" style="margin-left: ${indent}px">
  <h3>Answer — ${_escapeHtml(participantName(targetId))}</h3>
  <p>${answer == null || answer.body.trim().isEmpty ? 'Unanswered.' : _escapeHtml(answer.body)}</p>
</article>''');
        if (answer != null) {
          for (final (index, followUp) in question.followUps.indexed) {
            if (followUp.triggeringAnswerId == answer.id &&
                isRelevant(followUp)) {
              sections.addAll(
                renderQuestion(
                  followUp,
                  path: [...path, index + 1],
                  parentText: question.text,
                  triggerAnswer: answer,
                ),
              );
            }
          }
        }
      }
    }

    final linkedAnswerIds = question.answers.map((item) => item.id).toSet();
    for (final (index, followUp) in question.followUps.indexed) {
      if ((followUp.triggeringAnswerId == null ||
              !linkedAnswerIds.contains(followUp.triggeringAnswerId)) &&
          isRelevant(followUp)) {
        sections.add('''
<article class="answer" style="margin-left: ${indent}px">
  <h3>Follow-up trigger answer unavailable</h3>
  <p>Parent question: ${_escapeHtml(question.text)}</p>
 </article>''');
        sections.addAll(renderQuestion(
          followUp,
          path: [...path, index + 1],
          parentText: question.text,
        ));
      }
    }
    return sections;
  }

  final scope = allParticipants
      ? 'All participants'
      : 'Active participant — ${participantId == null ? 'Not selected' : participantName(participantId)}';
  final participantSummary = allParticipants
      ? session.participants.map((item) => _escapeHtml(item.name)).join(', ')
      : _escapeHtml(participantId == null ? 'Not selected' : participantName(participantId));
  final questions = <String>[];
  for (final (index, question) in session.questions.indexed) {
    questions.addAll(renderQuestion(question, path: [index + 1]));
  }
  final questionContent = questions.where((item) => item.isNotEmpty).join('\n');

  return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="referrer" content="no-referrer">
  <title>${_escapeHtml(session.title)} — Interact report</title>
  <style>
    :root { color-scheme: light; font-family: Arial, Helvetica, sans-serif; color: #202124; }
    body { margin: 0; background: #f1f3f4; }
    .toolbar { position: sticky; top: 0; display: flex; gap: 12px; padding: 12px 24px; background: #fff; border-bottom: 1px solid #dadce0; }
    button { padding: 9px 16px; font: inherit; cursor: pointer; }
    main { max-width: 850px; margin: 24px auto; padding: 40px; background: #fff; box-shadow: 0 1px 5px #0002; }
    h1 { margin: 0 0 16px; font-size: 28px; }
    .metadata { line-height: 1.6; overflow-wrap: anywhere; }
    .question { margin-top: 24px; padding-top: 16px; border-top: 1px solid #dadce0; break-inside: auto; }
    .question h2 { margin: 8px 0 12px; font-size: 20px; white-space: pre-wrap; overflow-wrap: anywhere; break-after: avoid-page; }
    .question.follow-up { margin-top: 12px; border-top-style: dashed; }
    .path, .parent { margin: 4px 0; color: #5f6368; font-size: 13px; }
    .answer { margin: 12px 0; padding: 12px 16px; border-left: 3px solid #365f9f; background: #f8f9fa; break-inside: auto; }
    .answer h3 { margin: 0 0 6px; font-size: 15px; break-after: avoid-page; }
    .answer p { margin: 0; line-height: 1.55; white-space: pre-wrap; overflow-wrap: anywhere; }
    .empty { color: #5f6368; font-style: italic; }
    @page { size: auto; margin: 18mm; }
    @media print {
      body { background: #fff; }
      .toolbar { display: none; }
      main { max-width: none; margin: 0; padding: 0; box-shadow: none; }
      .question { border-color: #aaa; }
      .answer { background: #fff; }
    }
    @media screen and (max-width: 600px) {
      main { margin: 0; padding: 24px 18px; }
      .toolbar { padding: 10px 12px; }
    }
  </style>
</head>
<body>
  <nav class="toolbar" aria-label="Report actions">
    <button type="button" onclick="window.print()">Print / Save PDF</button>
    <button type="button" onclick="window.close()">Close preview</button>
  </nav>
  <main>
    <h1>${_escapeHtml(session.title)}</h1>
    <section class="metadata">
      <div><strong>Owner:</strong> ${_escapeHtml(session.ownerText?.trim().isNotEmpty == true ? session.ownerText! : 'Not specified')}</div>
      <div><strong>Context / reference:</strong> ${_escapeHtml(session.contextReference?.trim().isNotEmpty == true ? session.contextReference! : 'Not specified')}</div>
      <div><strong>Report scope:</strong> ${_escapeHtml(scope)}</div>
      <div><strong>Participants:</strong> $participantSummary</div>
      <div><strong>Session status:</strong> ${_escapeHtml(session.status)}</div>
      <div><strong>Generated at (UTC):</strong> ${_escapeHtml(generatedAt.toUtc().toIso8601String())}</div>
    </section>
    ${questionContent.isEmpty ? '<p class="empty">No questions are available in this report.</p>' : questionContent}
  </main>
</body>
</html>''';
}

String _escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
