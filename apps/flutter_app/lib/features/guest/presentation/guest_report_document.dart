String buildGuestReportDocument({
  required Map<String, dynamic> session,
  required bool allParticipants,
  required String? participantId,
  required DateTime generatedAt,
}) {
  final participants = (session['participants'] as List? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  final participantNames = {
    for (final participant in participants)
      if (participant['id'] is String)
        participant['id'] as String:
            participant['name'] as String? ?? 'Participant',
  };
  String nameFor(String? id) => participantNames[id] ?? 'Participant';

  List<String> renderQuestion(
    Map<String, dynamic> question, {
    required String path,
    required String? ownerId,
    required String? triggerAnswerBody,
    required bool nested,
  }) {
    final questionId =
        question['target_participant_id'] ?? participants.firstOrNull?['id'];
    if (!allParticipants &&
        !nested &&
        question['scope'] == 'participant' &&
        questionId != participantId) {
      return const [];
    }
    final questionText = question['text'] as String? ?? '';
    final indent = (path.split('.').length - 1) * 10;
    final boundedIndent = indent.clamp(0, 28);
    final answers = (question['answers'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final targetIds = nested
        ? [ownerId].whereType<String>().toList()
        : allParticipants
        ? question['scope'] == 'participant'
            ? [questionId].whereType<String>().toList()
            : [
                ...participants
                    .map((participant) => participant['id'])
                    .whereType<String>(),
                ...answers
                    .map((answer) => answer['participant_id'])
                    .whereType<String>()
                    .where(
                      (id) => !participants.any(
                        (participant) => participant['id'] == id,
                      ),
                    ),
              ]
        : [participantId].whereType<String>().toList();
    if (targetIds.isEmpty) targetIds.add('');
    final visibleAnswers = [
      for (final targetId in targetIds)
        answers.firstWhere(
          (answer) => answer['participant_id'] == targetId,
          orElse: () => {
            'participant_id': targetId,
            'body': '',
            'follow_ups': const [],
          },
        ),
    ];
    final triggerText = triggerAnswerBody?.trim().isNotEmpty == true
        ? _escapeHtml(triggerAnswerBody!)
        : 'Unanswered.';
    final html = <String>[
      '<section class="question${nested ? ' follow-up' : ''}" '
      'style="margin-left: ${boundedIndent}px">',
      '<p class="path">Path ${_escapeHtml(path)}${nested ? ' · Follow-up' : ''}</p>',
      if (ownerId != null)
        '<p class="context">Triggered by ${_escapeHtml(nameFor(ownerId))}: '
        '$triggerText</p>',
      '<h2>${_escapeHtml(questionText)}</h2>',
    ];
    for (final answer in visibleAnswers) {
      final answerOwnerId = answer['participant_id'] as String?;
      final body = answer['body'] as String? ?? '';
      html.add(
        '<article class="answer">'
        '<h3>Answer — ${_escapeHtml(nameFor(answerOwnerId))}</h3>'
        '<p>${body.trim().isEmpty ? '<span class="empty">Unanswered.</span>' : _escapeHtml(body)}</p>'
        '</article>',
      );
      for (final (index, followUp) in (answer['follow_ups'] as List? ?? const []).indexed) {
        if (followUp is Map) {
          html.addAll(
            renderQuestion(
              Map<String, dynamic>.from(followUp),
              path: '$path.${index + 1}',
              ownerId: answerOwnerId,
              triggerAnswerBody: body,
              nested: true,
            ),
          );
        }
      }
    }
    html.add('</section>');
    return html;
  }

  final questions = <String>[];
  for (final (index, question) in (session['questions'] as List? ?? const []).indexed) {
    if (question is Map) {
      questions.addAll(
        renderQuestion(
          Map<String, dynamic>.from(question),
          path: '${index + 1}',
          ownerId: null,
          triggerAnswerBody: null,
          nested: false,
        ),
      );
    }
  }
  final scope = allParticipants
      ? 'All participants'
      : 'Selected participant — ${_escapeHtml(nameFor(participantId))}';
  final reportParticipants = allParticipants
      ? participants
      : participants
            .where((participant) => participant['id'] == participantId)
            .toList();
  final participantList = reportParticipants
      .map((participant) => _escapeHtml(participant['name'] as String? ?? 'Participant'))
      .join(', ');
  final title = session['title'] as String? ?? 'Interact session';
  return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="referrer" content="no-referrer">
  <title>${_escapeHtml(title)} — Interact report</title>
  <style>
    :root { font-family: Arial, Helvetica, sans-serif; color: #202124; }
    body { margin: 0; background: #f1f3f4; }
    .toolbar {
      position: sticky; top: 0; display: flex; gap: 12px;
      padding: 12px 24px; background: #fff; border-bottom: 1px solid #dadce0;
    }
    button { padding: 9px 16px; font: inherit; cursor: pointer; }
    main { max-width: 850px; margin: 24px auto; padding: 40px; background: #fff; }
    .metadata { line-height: 1.6; overflow-wrap: anywhere; }
    .question { margin-top: 24px; padding-top: 16px; border-top: 1px solid #dadce0; }
    .question.follow-up { border-top-style: dashed; }
    .question h2 { overflow-wrap: anywhere; }
    .path, .context { color: #5f6368; font-size: 13px; overflow-wrap: anywhere; }
    .answer {
      margin: 12px 0; padding: 12px 16px; border-left: 3px solid #365f9f;
      background: #f8f9fa; break-inside: avoid;
    }
    .answer p { margin: 0; line-height: 1.55; white-space: pre-wrap; overflow-wrap: anywhere; }
    .empty { color: #5f6368; font-style: italic; }
    @page { size: auto; margin: 18mm; }
    @media print {
      body { background: #fff; }
      .toolbar { display: none; }
      main { max-width: none; margin: 0; padding: 0; }
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
    <h1>${_escapeHtml(title)}</h1>
    <section class="metadata">
      <div><strong>Storage:</strong> Private on this device</div>
      <div><strong>Report scope:</strong> ${_escapeHtml(scope)}</div>
      <div><strong>Participants:</strong> $participantList</div>
      <div><strong>Generated at (UTC):</strong>
        ${_escapeHtml(generatedAt.toUtc().toIso8601String())}</div>
    </section>
    ${questions.isEmpty
      ? '<p class="empty">No questions are available in this report.</p>'
      : questions.join('\n')}
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
