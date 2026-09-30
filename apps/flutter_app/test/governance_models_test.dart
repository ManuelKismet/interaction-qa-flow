import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/governance/domain/governance_models.dart';

void main() {
  test('parses challenge and immutable answer version', () {
    final challenge = AnswerChallenge.fromJson({
      'id': 'challenge-1',
      'answer_id': 'answer-1',
      'submitted_by': 'user-1',
      'type': 'outdated',
      'reason': 'The portal changed.',
      'suggested_answer': 'Use the new portal.',
      'status': 'open',
      'reviewer_note': null,
      'created_at': '2026-09-25T10:00:00Z',
    });
    final version = AnswerVersion.fromJson({
      'id': 'version-1',
      'answer_id': 'answer-1',
      'version_number': 3,
      'body': 'Use the new portal.',
      'status_snapshot': 'verified',
      'changed_by': {
        'id': 'owner-1',
        'display_name': 'Finance Owner',
        'role': 'answer_owner',
      },
      'change_reason': 'Accepted challenge challenge-1',
      'created_at': '2026-09-25T11:00:00Z',
    });

    expect(challenge.type, 'outdated');
    expect(challenge.suggestedAnswer, 'Use the new portal.');
    expect(version.versionNumber, 3);
    expect(version.changedBy.displayName, 'Finance Owner');
  });

  test('parses review queue and department owner', () {
    final queueItem = ReviewQueueItem.fromJson({
      'type': 'review_due',
      'question_id': 'question-1',
      'question_title': 'How do I claim mileage?',
      'answer_id': 'answer-1',
      'department': {'id': 'department-1', 'name': 'Finance'},
      'relevant_at': '2026-09-25T10:00:00Z',
      'challenge_id': null,
      'challenge_type': null,
      'challenge_status': null,
    });
    final owner = DepartmentAnswerOwner.fromJson({
      'id': 'assignment-1',
      'department': {'id': 'department-1', 'name': 'Finance'},
      'user': {
        'id': 'owner-1',
        'display_name': 'Finance Owner',
        'role': 'answer_owner',
      },
    });

    expect(queueItem.type, 'review_due');
    expect(queueItem.department?.name, 'Finance');
    expect(owner.user.role, 'answer_owner');
  });

  test('parses duplicate suggestion queue item without an answer', () {
    final item = ReviewQueueItem.fromJson({
      'type': 'duplicate_suggestion',
      'question_id': 'question-2',
      'question_title': 'Where do I book holiday?',
      'answer_id': null,
      'department': {'id': 'department-1', 'name': 'People'},
      'relevant_at': '2026-09-25T10:00:00Z',
      'challenge_id': null,
      'challenge_type': null,
      'challenge_status': null,
      'duplicate_suggestion_id': 'suggestion-1',
      'duplicate_suggestion_status': 'open',
      'suggested_canonical_question_id': 'question-1',
      'suggested_canonical_title': 'How do I request annual leave?',
    });

    expect(item.answerId, isNull);
    expect(item.suggestedCanonicalTitle, 'How do I request annual leave?');
    expect(item.duplicateSuggestionStatus, 'open');
  });
}