import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

void main() {
  test('parses accepted answer question detail', () {
    final answer = {
      'id': 'answer-1',
      'body': 'Use the Finance form.',
      'status': 'community',
      'author': {
        'id': 'user-2',
        'display_name': 'Finance Owner',
        'role': 'answer_owner',
      },
      'helpful_count': 3,
      'not_helpful_count': 1,
      'is_accepted': true,
      'created_at': '2026-09-25T10:00:00Z',
      'challenge_count': 1,
      'has_open_challenge': true,
      'verified_by_user': {
        'id': 'user-2',
        'display_name': 'Finance Owner',
        'role': 'answer_owner',
      },
      'verified_at': '2026-09-25T10:30:00Z',
      'review_due_at': '2027-03-24T10:30:00Z',
      'last_reviewed_at': '2026-09-25T10:30:00Z',
      'freshness_status': 'challenged',
    };

    final detail = QuestionDetail.fromJson({
      'id': 'question-1',
      'title': 'How do I claim mileage?',
      'body': 'I need the current process.',
      'status': 'resolved',
      'author': {
        'id': 'user-1',
        'display_name': 'Question Author',
        'role': 'employee',
      },
      'department': {'id': 'department-1', 'name': 'Finance'},
      'team': {
        'id': 'team-1',
        'name': 'Payroll',
        'department_id': 'department-1',
      },
      'answers': [answer],
      'accepted_answer': answer,
      'comment_count': 2,
      'canonical_question': null,
      'aliases': [
        {
          'id': 'question-2',
          'title': 'Where do I book holiday?',
          'created_at': '2026-09-24T10:00:00Z',
        },
      ],
      'resolved_at': '2026-09-25T11:00:00Z',
    });

    expect(detail.status, 'resolved');
    expect(detail.acceptedAnswer?.isAccepted, isTrue);
    expect(detail.acceptedAnswer?.helpfulCount, 3);
    expect(detail.acceptedAnswer?.freshnessStatus, 'challenged');
    expect(detail.acceptedAnswer?.challengeCount, 1);
    expect(detail.department?.name, 'Finance');
    expect(detail.team?.name, 'Payroll');
    expect(detail.commentCount, 2);
    expect(detail.aliases.single.title, 'Where do I book holiday?');
  });

  test('parses semantic search result without vector data', () {
    final result = SemanticSearchResult.fromJson({
      'question_id': 'question-1',
      'canonical_question_id': 'question-1',
      'canonical_title': 'How do I claim mileage?',
      'canonical_body': 'Current policy',
      'matched_question_id': 'question-2',
      'matched_question_ids': ['question-1', 'question-2'],
      'matched_text': 'Where do I claim mileage?',
      'match_source': 'historical_question',
      'match_method': 'semantic',
      'answer_id': 'answer-1',
      'title': 'How do I claim mileage?',
      'accepted_answer_body': 'Use the Finance form.',
      'department': {'id': 'department-1', 'name': 'Finance'},
      'team': {
        'id': 'team-1',
        'name': 'Payroll',
        'department_id': 'department-1',
      },
      'similarity': 0.91,
      'confidence': 'high_confidence',
      'question_status': 'resolved',
      'answer_status': 'verified',
      'answer_verified_by': 'user-2',
      'answer_verified_at': '2026-09-25T10:30:00Z',
      'answer_freshness_status': 'current',
      'challenge_count': 0,
      'has_open_challenge': false,
      'created_at': '2026-09-25T10:00:00Z',
      'updated_at': '2026-09-25T11:00:00Z',
      'resolved_at': '2026-09-25T11:00:00Z',
      'visibility': 'organisation',
    });

    expect(result.questionId, 'question-1');
    expect(result.acceptedAnswerBody, 'Use the Finance form.');
    expect(result.confidence, 'high_confidence');
    expect(result.department?.name, 'Finance');
    expect(result.team?.name, 'Payroll');
    expect(result.similarity, 0.91);
    expect(result.answerVerifiedBy, 'user-2');
    expect(result.answerVerifiedAt, DateTime.utc(2026, 9, 25, 10, 30));
    expect(result.answerFreshnessStatus, 'current');
    expect(result.hasOpenChallenge, isFalse);
    expect(result.canonicalQuestionId, 'question-1');
    expect(result.matchedQuestionIds, hasLength(2));
    expect(result.matchSource, 'historical_question');
    expect(result.matchMethod, 'semantic');
  });

  test('parses an open semantic search result without an answer', () {
    final result = SemanticSearchResult.fromJson({
      'question_id': 'question-open',
      'canonical_question_id': 'question-open',
      'canonical_title': 'How do I correct a mileage claim?',
      'canonical_body': null,
      'matched_question_id': 'question-open',
      'matched_question_ids': ['question-open'],
      'matched_text': 'How do I correct a mileage claim?',
      'match_source': 'canonical',
      'match_method': 'keyword',
      'answer_id': null,
      'title': 'How do I correct a mileage claim?',
      'accepted_answer_body': null,
      'department': null,
      'team': null,
      'similarity': 0.91,
      'confidence': 'high_confidence',
      'question_status': 'open',
      'answer_status': null,
      'answer_verified_by': null,
      'answer_verified_at': null,
      'answer_freshness_status': null,
      'challenge_count': 0,
      'has_open_challenge': false,
      'created_at': '2026-09-25T10:00:00Z',
      'updated_at': '2026-09-25T10:00:00Z',
      'resolved_at': null,
      'visibility': 'organisation',
    });

    expect(result.questionId, 'question-open');
    expect(result.acceptedAnswerBody, isNull);
    expect(result.answerId, isNull);
    expect(result.answerStatus, isNull);
    expect(result.matchMethod, 'keyword');
  });

  test('parses a linked historical question', () {
    final detail = QuestionDetail.fromJson({
      'id': 'question-2',
      'title': 'Where do I book holiday?',
      'body': null,
      'status': 'resolved',
      'author': {
        'id': 'user-1',
        'display_name': 'Employee',
        'role': 'employee',
      },
      'department': {'id': 'department-1', 'name': 'People'},
      'team': null,
      'answers': const [],
      'accepted_answer': null,
      'comment_count': 0,
      'canonical_question': {
        'id': 'question-1',
        'title': 'How do I request annual leave?',
      },
      'aliases': const [],
      'resolved_at': null,
    });

    expect(detail.canonicalQuestion?.id, 'question-1');
    expect(detail.aliases, isEmpty);
  });
}
