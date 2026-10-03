import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class GuestReportData {
  const GuestReportData({
    required this.title,
    required this.scope,
    required this.participantNames,
    required this.exportedAt,
    required this.questions,
  });

  final String title;
  final String scope;
  final List<String> participantNames;
  final DateTime exportedAt;
  final List<GuestReportQuestion> questions;
}

class GuestReportQuestion {
  const GuestReportQuestion({
    required this.path,
    required this.text,
    required this.answers,
    this.triggerParticipant,
    this.triggerAnswer,
  });

  final String path;
  final String text;
  final List<GuestReportAnswer> answers;
  final String? triggerParticipant;
  final String? triggerAnswer;
}

class GuestReportAnswer {
  const GuestReportAnswer({
    required this.participantName,
    required this.body,
    required this.followUps,
  });

  final String participantName;
  final String body;
  final List<GuestReportQuestion> followUps;
}

class GuestPortableSection {
  const GuestPortableSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

class GuestPortableDocument {
  const GuestPortableDocument({
    required this.title,
    required this.scope,
    required this.exportedAt,
    required this.sections,
  });

  final String title;
  final String scope;
  final DateTime exportedAt;
  final List<GuestPortableSection> sections;
}

GuestReportData composeGuestReport({
  required Map<String, dynamic> session,
  required bool allParticipants,
  required String? participantId,
  required DateTime exportedAt,
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

  List<GuestReportQuestion> renderQuestion(
    Map<String, dynamic> question, {
    required String path,
    required String? ownerId,
    required String? triggerAnswerBody,
    required bool nested,
  }) {
    final targetId =
        question['target_participant_id'] ?? participants.firstOrNull?['id'];
    if (!allParticipants &&
        !nested &&
        question['scope'] == 'participant' &&
        targetId != participantId) {
      return const [];
    }
    final existingAnswers = (question['answers'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final targetIds = nested
        ? [ownerId].whereType<String>().toList()
        : allParticipants
        ? question['scope'] == 'participant'
            ? [targetId].whereType<String>().toList()
            : [
                ...participants
                    .map((participant) => participant['id'])
                    .whereType<String>(),
                ...existingAnswers
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

    final answers = <GuestReportAnswer>[];
    for (final target in targetIds) {
      final answer = existingAnswers.firstWhere(
        (item) => item['participant_id'] == target,
        orElse: () => {
          'participant_id': target,
          'body': '',
          'follow_ups': const [],
        },
      );
      final answerBody = answer['body'] as String? ?? '';
      final followUps = <GuestReportQuestion>[];
      for (final (index, item) in (answer['follow_ups'] as List? ?? const [])
          .indexed) {
        if (item is Map) {
          followUps.addAll(
            renderQuestion(
              Map<String, dynamic>.from(item),
              path: '$path.${index + 1}',
              ownerId: answer['participant_id'] as String?,
              triggerAnswerBody: answerBody,
              nested: true,
            ),
          );
        }
      }
      answers.add(
        GuestReportAnswer(
          participantName: nameFor(answer['participant_id'] as String?),
          body: answerBody,
          followUps: followUps,
        ),
      );
    }
    return [
      GuestReportQuestion(
        path: path,
        text: question['text'] as String? ?? '',
        answers: answers,
        triggerParticipant: ownerId == null ? null : nameFor(ownerId),
        triggerAnswer: triggerAnswerBody,
      ),
    ];
  }

  final questions = <GuestReportQuestion>[];
  for (final (index, question) in (session['questions'] as List? ?? const [])
      .indexed) {
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
  final reportParticipants = allParticipants
      ? participants
      : participants
            .where((participant) => participant['id'] == participantId)
            .toList();
  return GuestReportData(
    title: session['title'] as String? ?? 'Interact session',
    scope: allParticipants
        ? 'All participants'
        : 'Selected participant — ${nameFor(participantId)}',
    participantNames: [
      for (final participant in reportParticipants)
        participant['name'] as String? ?? 'Participant',
    ],
    exportedAt: exportedAt.toUtc(),
    questions: questions,
  );
}

Future<Uint8List> buildGuestReportPdf(GuestReportData report) async {
  final fontBytes = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
  final font = pw.Font.ttf(fontBytes);
  final pdf = pw.Document(
    title: report.title,
    subject: report.scope,
    creator: 'IntQAFlow Interact',
  );
  final content = <pw.Widget>[
    pw.Text(
      report.title,
      style: pw.TextStyle(font: font, fontSize: 22, color: PdfColors.blueGrey900),
    ),
    pw.SizedBox(height: 12),
    pw.Text('Report scope: ${report.scope}', style: pw.TextStyle(font: font)),
    pw.Text(
      'Participants: ${report.participantNames.isEmpty ? 'Not selected' : report.participantNames.join(', ')}',
      style: pw.TextStyle(font: font),
    ),
    pw.Text(
      'Exported: ${report.exportedAt.toIso8601String()}',
      style: pw.TextStyle(font: font),
    ),
    pw.SizedBox(height: 14),
  ];

  void addQuestion(GuestReportQuestion question, {required int depth}) {
    content.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 10),
          pw.Text(
            'Path ${question.path}${depth > 0 ? ' · Follow-up' : ''}',
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColors.blueGrey600,
            ),
          ),
          if (question.triggerParticipant != null)
            pw.Text(
              'Follow-up prompted by ${question.triggerParticipant}: '
              '${question.triggerAnswer?.trim().isNotEmpty == true ? question.triggerAnswer : 'Unanswered.'}',
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: PdfColors.blueGrey600,
              ),
            ),
          pw.Text(
            question.text,
            style: pw.TextStyle(font: font, fontSize: 15),
          ),
        ],
      ),
    );
    if (question.answers.isEmpty) {
      content.add(_pdfAnswer(font, 'Answer', 'Unanswered.'));
      return;
    }
    for (final answer in question.answers) {
      content.add(
        _pdfAnswer(
          font,
          'Answer — ${answer.participantName}',
          answer.body.trim().isEmpty ? 'Unanswered.' : answer.body,
        ),
      );
      for (final followUp in answer.followUps) {
        addQuestion(followUp, depth: depth + 1);
      }
    }
  }

  if (report.questions.isEmpty) {
    content.add(
      pw.Text('No questions are available in this report.', style: pw.TextStyle(font: font)),
    );
  } else {
    for (final question in report.questions) {
      addQuestion(question, depth: 0);
    }
  }
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 48),
      theme: pw.ThemeData.withFont(base: font, bold: font),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (_) => content,
    ),
  );
  return pdf.save();
}

Future<Uint8List> buildGuestPortablePdf(
  GuestPortableDocument document,
) async {
  final fontBytes = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
  final font = pw.Font.ttf(fontBytes);
  final pdf = pw.Document(
    title: document.title,
    subject: document.scope,
    creator: 'IntQAFlow',
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 48),
      theme: pw.ThemeData.withFont(base: font, bold: font),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
      ),
      build: (_) => [
        pw.Text(
          document.title,
          style: pw.TextStyle(font: font, fontSize: 22),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Report scope: ${document.scope}',
          style: pw.TextStyle(font: font),
        ),
        pw.Text(
          'Exported: ${document.exportedAt.toIso8601String()}',
          style: pw.TextStyle(font: font),
        ),
        pw.SizedBox(height: 16),
        for (final section in document.sections) ...[
          pw.Text(
            section.heading,
            style: pw.TextStyle(font: font, fontSize: 15),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            section.body.trim().isEmpty ? 'Not provided.' : section.body,
            style: pw.TextStyle(font: font, fontSize: 11),
          ),
          pw.SizedBox(height: 14),
        ],
        if (document.sections.isEmpty)
          pw.Text(
            'No report content is available.',
            style: pw.TextStyle(font: font),
          ),
      ],
    ),
  );
  return pdf.save();
}

String buildGuestPortableHtml(GuestPortableDocument document) {
  final sections = document.sections.map((section) {
    return '<section><h2>${_escapeHtml(section.heading)}</h2><p>${_escapeHtml(section.body.trim().isEmpty ? 'Not provided.' : section.body)}</p></section>';
  }).join('\n');
  return '''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_escapeHtml(document.title)} — PDF fallback</title>
<style>
body { max-width: 850px; margin: 24px auto; padding: 32px; font: 16px Arial, sans-serif; line-height: 1.55; }
p { white-space: pre-wrap; overflow-wrap: anywhere; }
section { margin-top: 24px; border-top: 1px solid #bbb; padding-top: 12px; }
.toolbar { position: sticky; top: 0; background: white; padding: 12px; }
@page { margin: 18mm; }
@media print { .toolbar { display: none; } body { margin: 0; padding: 0; } }
</style></head><body>
<nav class="toolbar"><button onclick="window.print()">Print / Save PDF fallback</button></nav>
<h1>${_escapeHtml(document.title)}</h1>
<p>Report scope: ${_escapeHtml(document.scope)}<br>
Exported: ${_escapeHtml(document.exportedAt.toIso8601String())}</p>
$sections
</body></html>''';
}

pw.Widget _pdfAnswer(
  pw.Font font,
  String heading,
  String body,
) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.SizedBox(height: 6),
    pw.Text(heading, style: pw.TextStyle(font: font, fontSize: 11)),
    pw.Text(body, style: pw.TextStyle(font: font, fontSize: 10)),
    pw.SizedBox(height: 6),
  ],
);

String guestReportFilename(GuestReportData report) {
  return _pdfFilename(report.title, report.exportedAt);
}

String guestPortableFilename(GuestPortableDocument document) =>
    _pdfFilename(document.title, document.exportedAt);

String _pdfFilename(String title, DateTime exportedAt) {
  final safeTitle = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final date = exportedAt.toUtc().toIso8601String().substring(0, 10);
  return '${safeTitle.isEmpty ? 'interact-report' : safeTitle}-$date.pdf';
}

String buildGuestReportDocument({
  required Map<String, dynamic> session,
  required bool allParticipants,
  required String? participantId,
  required DateTime generatedAt,
}) {
  final report = composeGuestReport(
    session: session,
    allParticipants: allParticipants,
    participantId: participantId,
    exportedAt: generatedAt,
  );
  String answerHtml(GuestReportAnswer answer, String path) {
    final body = answer.body.trim().isEmpty
        ? '<span class="empty">Unanswered.</span>'
        : _escapeHtml(answer.body);
    final children = <String>[
      '<article class="answer"><h3>Answer — '
          '${_escapeHtml(answer.participantName)}</h3><p>$body</p></article>',
    ];
    for (final followUp in answer.followUps) {
      children.add(questionHtml(followUp, depth: path.split('.').length));
    }
    return children.join('\n');
  }

  String questionHtml(GuestReportQuestion question, {int depth = 0}) {
    final indent = (depth * 10).clamp(0, 28);
    final attribution = question.triggerParticipant == null
        ? ''
        : '<p class="context">Follow-up prompted by '
              '${_escapeHtml(question.triggerParticipant!)}: '
              '${question.triggerAnswer?.trim().isNotEmpty == true ? _escapeHtml(question.triggerAnswer!) : 'Unanswered.'}</p>';
    final answers = question.answers.isEmpty
        ? '<article class="answer"><h3>Answer</h3><p class="empty">Unanswered.</p></article>'
        : question.answers
              .map((answer) => answerHtml(answer, question.path))
              .join('\n');
    return '''
<section class="question" style="margin-left: ${indent}px">
  <p class="path">Path ${_escapeHtml(question.path)}</p>
  $attribution
  <h2>${_escapeHtml(question.text)}</h2>
  $answers
</section>''';
  }

  final participantList = report.participantNames
      .map(_escapeHtml)
      .join(', ');
  final questions = report.questions
      .map((question) => questionHtml(question))
      .join('\n');
  return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="referrer" content="no-referrer">
  <title>${_escapeHtml(report.title)} — Interact report</title>
  <style>
    :root { font-family: Arial, Helvetica, sans-serif; color: #202124; }
    body { margin: 0; background: #f1f3f4; }
    .toolbar { position: sticky; top: 0; padding: 12px 24px; background: #fff; }
    button { padding: 9px 16px; font: inherit; cursor: pointer; }
    main { max-width: 850px; margin: 24px auto; padding: 40px; background: #fff; }
    .metadata { line-height: 1.6; overflow-wrap: anywhere; }
    .question { margin-top: 24px; padding-top: 16px; border-top: 1px solid #dadce0; }
    .question h2, .answer p { overflow-wrap: anywhere; white-space: pre-wrap; }
    .path, .context { color: #5f6368; font-size: 13px; }
    .answer { margin: 12px 0; padding: 12px 16px; border-left: 3px solid #365f9f; background: #f8f9fa; }
    .answer p { line-height: 1.55; }
    .empty { color: #5f6368; font-style: italic; }
    @page { size: auto; margin: 18mm; }
    @media print { body { background: #fff; } .toolbar { display: none; } main { max-width: none; margin: 0; padding: 0; } }
    @media screen and (max-width: 600px) { main { margin: 0; padding: 24px 18px; } }
  </style>
</head>
<body>
  <nav class="toolbar" aria-label="PDF fallback">
    <button type="button" onclick="window.print()">Print / Save PDF fallback</button>
    <button type="button" onclick="window.close()">Close preview</button>
  </nav>
  <main>
    <h1>${_escapeHtml(report.title)}</h1>
    <section class="metadata">
      <div><strong>Storage:</strong> Private on this device</div>
      <div><strong>Report scope:</strong> ${_escapeHtml(report.scope)}</div>
      <div><strong>Participants:</strong> $participantList</div>
      <div><strong>Exported:</strong> ${_escapeHtml(report.exportedAt.toIso8601String())}</div>
    </section>
    ${questions.isEmpty ? '<p class="empty">No questions are available in this report.</p>' : questions}
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
