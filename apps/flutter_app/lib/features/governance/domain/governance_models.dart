import 'package:int_qa_flow/features/questions/domain/question_models.dart';

class AnswerChallenge {
  const AnswerChallenge({
    required this.id,
    required this.answerId,
    required this.type,
    required this.reason,
    required this.status,
    required this.submittedBy,
    required this.createdAt,
    this.suggestedAnswer,
    this.reviewerNote,
  });

  factory AnswerChallenge.fromJson(Map<String, dynamic> json) => AnswerChallenge(
        id: json['id'] as String,
        answerId: json['answer_id'] as String,
        type: json['type'] as String,
        reason: json['reason'] as String,
        status: json['status'] as String,
        submittedBy: json['submitted_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        suggestedAnswer: json['suggested_answer'] as String?,
        reviewerNote: json['reviewer_note'] as String?,
      );

  final String id;
  final String answerId;
  final String type;
  final String reason;
  final String status;
  final String submittedBy;
  final DateTime createdAt;
  final String? suggestedAnswer;
  final String? reviewerNote;
}

class AnswerVersion {
  const AnswerVersion({
    required this.id,
    required this.answerId,
    required this.versionNumber,
    required this.body,
    required this.status,
    required this.changedBy,
    required this.createdAt,
    this.reason,
  });

  factory AnswerVersion.fromJson(Map<String, dynamic> json) => AnswerVersion(
        id: json['id'] as String,
        answerId: json['answer_id'] as String,
        versionNumber: json['version_number'] as int,
        body: json['body'] as String,
        status: json['status_snapshot'] as String,
        changedBy: UserSummary.fromJson(
          json['changed_by'] as Map<String, dynamic>,
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
        reason: json['change_reason'] as String?,
      );

  final String id;
  final String answerId;
  final int versionNumber;
  final String body;
  final String status;
  final UserSummary changedBy;
  final DateTime createdAt;
  final String? reason;
}

class ReviewQueueItem {
  const ReviewQueueItem({
    required this.type,
    required this.questionId,
    required this.questionTitle,
    this.answerId,
    this.department,
    this.relevantAt,
    this.challengeId,
    this.challengeType,
    this.challengeStatus,
    this.duplicateSuggestionId,
    this.duplicateSuggestionStatus,
    this.suggestedCanonicalQuestionId,
    this.suggestedCanonicalTitle,
  });

  factory ReviewQueueItem.fromJson(Map<String, dynamic> json) => ReviewQueueItem(
        type: json['type'] as String,
        questionId: json['question_id'] as String,
        questionTitle: json['question_title'] as String,
        answerId: json['answer_id'] as String?,
        department: json['department'] == null
            ? null
            : DepartmentSummary.fromJson(
                json['department'] as Map<String, dynamic>,
              ),
        relevantAt: json['relevant_at'] == null
            ? null
            : DateTime.parse(json['relevant_at'] as String),
        challengeId: json['challenge_id'] as String?,
        challengeType: json['challenge_type'] as String?,
        challengeStatus: json['challenge_status'] as String?,
        duplicateSuggestionId: json['duplicate_suggestion_id'] as String?,
        duplicateSuggestionStatus:
          json['duplicate_suggestion_status'] as String?,
        suggestedCanonicalQuestionId:
          json['suggested_canonical_question_id'] as String?,
        suggestedCanonicalTitle: json['suggested_canonical_title'] as String?,
      );

  final String type;
  final String questionId;
  final String questionTitle;
  final String? answerId;
  final DepartmentSummary? department;
  final DateTime? relevantAt;
  final String? challengeId;
  final String? challengeType;
  final String? challengeStatus;
  final String? duplicateSuggestionId;
  final String? duplicateSuggestionStatus;
  final String? suggestedCanonicalQuestionId;
  final String? suggestedCanonicalTitle;
}

class DepartmentAnswerOwner {
  const DepartmentAnswerOwner({
    required this.id,
    required this.department,
    required this.user,
  });

  factory DepartmentAnswerOwner.fromJson(Map<String, dynamic> json) =>
      DepartmentAnswerOwner(
        id: json['id'] as String,
        department: DepartmentSummary.fromJson(
          json['department'] as Map<String, dynamic>,
        ),
        user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String id;
  final DepartmentSummary department;
  final UserSummary user;
}

class TeamMembership {
  const TeamMembership({
    required this.id,
    required this.teamId,
    required this.user,
  });

  factory TeamMembership.fromJson(Map<String, dynamic> json) => TeamMembership(
        id: json['id'] as String,
        teamId: json['team_id'] as String,
        user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String id;
  final String teamId;
  final UserSummary user;
}