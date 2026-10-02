class UserSummary {
  const UserSummary({
    required this.id,
    required this.displayName,
    required this.role,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    role: json['role'] as String,
  );

  final String id;
  final String displayName;
  final String role;
}

class DepartmentSummary {
  const DepartmentSummary({required this.id, required this.name});

  factory DepartmentSummary.fromJson(Map<String, dynamic> json) =>
      DepartmentSummary(id: json['id'] as String, name: json['name'] as String);

  final String id;
  final String name;
}

class TeamSummary {
  const TeamSummary({
    required this.id,
    required this.name,
    this.departmentId,
    this.department,
    this.description,
    this.status,
  });

  factory TeamSummary.fromJson(Map<String, dynamic> json) => TeamSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    departmentId: json['department_id'] as String?,
    department: json['department'] == null
        ? null
        : DepartmentSummary.fromJson(
            json['department'] as Map<String, dynamic>,
          ),
    description: json['description'] as String?,
    status: json['status'] as String?,
  );

  final String id;
  final String name;
  final String? departmentId;
  final DepartmentSummary? department;
  final String? description;
  final String? status;
}

class SemanticSearchResult {
  const SemanticSearchResult({
    required this.questionId,
    required this.title,
    required this.acceptedAnswerBody,
    required this.similarity,
    required this.confidence,
    required this.answerStatus,
    required this.answerId,
    required this.challengeCount,
    required this.hasOpenChallenge,
    required this.canonicalQuestionId,
    required this.canonicalTitle,
    required this.matchedQuestionId,
    required this.matchedQuestionIds,
    required this.matchedText,
    required this.matchSource,
    required this.matchMethod,
    this.answerVerifiedBy,
    this.answerVerifiedAt,
    this.answerFreshnessStatus,
    this.canonicalBody,
    this.resolvedAt,
    this.department,
    this.team,
  });

  factory SemanticSearchResult.fromJson(Map<String, dynamic> json) =>
      SemanticSearchResult(
        questionId: json['question_id'] as String,
        title: json['title'] as String,
        acceptedAnswerBody: json['accepted_answer_body'] as String?,
        similarity: (json['similarity'] as num).toDouble(),
        confidence: json['confidence'] as String,
        answerStatus: json['answer_status'] as String?,
        answerId: json['answer_id'] as String?,
        challengeCount: json['challenge_count'] as int,
        hasOpenChallenge: json['has_open_challenge'] as bool,
        canonicalQuestionId: json['canonical_question_id'] as String,
        canonicalTitle: json['canonical_title'] as String,
        matchedQuestionId: json['matched_question_id'] as String,
        matchedQuestionIds: (json['matched_question_ids'] as List<dynamic>)
            .cast<String>(),
        matchedText: json['matched_text'] as String,
        matchSource: json['match_source'] as String,
        matchMethod: json['match_method'] as String? ?? 'semantic',
        canonicalBody: json['canonical_body'] as String?,
        resolvedAt: _date(json['resolved_at']),
        answerVerifiedBy: json['answer_verified_by'] as String?,
        answerVerifiedAt: json['answer_verified_at'] == null
            ? null
            : DateTime.parse(json['answer_verified_at'] as String),
        answerFreshnessStatus: json['answer_freshness_status'] as String?,
        department: json['department'] == null
            ? null
            : DepartmentSummary.fromJson(
                json['department'] as Map<String, dynamic>,
              ),
        team: json['team'] == null
            ? null
            : TeamSummary.fromJson(json['team'] as Map<String, dynamic>),
      );

  final String questionId;
  final String title;
  final String? acceptedAnswerBody;
  final double similarity;
  final String confidence;
  final String? answerStatus;
  final String? answerId;
  final int challengeCount;
  final bool hasOpenChallenge;
  final String canonicalQuestionId;
  final String canonicalTitle;
  final String matchedQuestionId;
  final List<String> matchedQuestionIds;
  final String matchedText;
  final String matchSource;
  final String matchMethod;
  final String? canonicalBody;
  final DateTime? resolvedAt;
  final String? answerVerifiedBy;
  final DateTime? answerVerifiedAt;
  final String? answerFreshnessStatus;
  final DepartmentSummary? department;
  final TeamSummary? team;
}

class QuestionSummary {
  const QuestionSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.answerCount,
    this.department,
    this.team,
  });

  factory QuestionSummary.fromJson(Map<String, dynamic> json) =>
      QuestionSummary(
        id: json['id'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        answerCount: json['answer_count'] as int,
        department: json['department'] == null
            ? null
            : DepartmentSummary.fromJson(
                json['department'] as Map<String, dynamic>,
              ),
        team: json['team'] == null
            ? null
            : TeamSummary.fromJson(json['team'] as Map<String, dynamic>),
      );

  final String id;
  final String title;
  final String status;
  final DateTime createdAt;
  final int answerCount;
  final DepartmentSummary? department;
  final TeamSummary? team;
}

class AnswerDetail {
  const AnswerDetail({
    required this.id,
    required this.body,
    required this.status,
    required this.author,
    required this.helpfulCount,
    required this.notHelpfulCount,
    required this.isAccepted,
    required this.createdAt,
    required this.challengeCount,
    required this.hasOpenChallenge,
    this.verifiedByUser,
    this.verifiedAt,
    this.reviewDueAt,
    this.lastReviewedAt,
    this.freshnessStatus,
  });

  factory AnswerDetail.fromJson(Map<String, dynamic> json) => AnswerDetail(
    id: json['id'] as String,
    body: json['body'] as String,
    status: json['status'] as String,
    author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
    helpfulCount: json['helpful_count'] as int,
    notHelpfulCount: json['not_helpful_count'] as int,
    isAccepted: json['is_accepted'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
    challengeCount: json['challenge_count'] as int,
    hasOpenChallenge: json['has_open_challenge'] as bool,
    verifiedByUser: json['verified_by_user'] == null
        ? null
        : UserSummary.fromJson(
            json['verified_by_user'] as Map<String, dynamic>,
          ),
    verifiedAt: _date(json['verified_at']),
    reviewDueAt: _date(json['review_due_at']),
    lastReviewedAt: _date(json['last_reviewed_at']),
    freshnessStatus: json['freshness_status'] as String?,
  );

  final String id;
  final String body;
  final String status;
  final UserSummary author;
  final int helpfulCount;
  final int notHelpfulCount;
  final bool isAccepted;
  final DateTime createdAt;
  final int challengeCount;
  final bool hasOpenChallenge;
  final UserSummary? verifiedByUser;
  final DateTime? verifiedAt;
  final DateTime? reviewDueAt;
  final DateTime? lastReviewedAt;
  final String? freshnessStatus;
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

class QuestionDetail {
  const QuestionDetail({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    required this.author,
    required this.answers,
    required this.acceptedAnswer,
    required this.commentCount,
    required this.aliases,
    this.canonicalQuestion,
    this.resolvedAt,
    this.department,
    this.team,
  });

  factory QuestionDetail.fromJson(Map<String, dynamic> json) => QuestionDetail(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String?,
    status: json['status'] as String,
    author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
    department: json['department'] == null
        ? null
        : DepartmentSummary.fromJson(
            json['department'] as Map<String, dynamic>,
          ),
    team: json['team'] == null
        ? null
        : TeamSummary.fromJson(json['team'] as Map<String, dynamic>),
    answers: (json['answers'] as List<dynamic>)
        .map((item) => AnswerDetail.fromJson(item as Map<String, dynamic>))
        .toList(),
    acceptedAnswer: json['accepted_answer'] == null
        ? null
        : AnswerDetail.fromJson(
            json['accepted_answer'] as Map<String, dynamic>,
          ),
    commentCount: json['comment_count'] as int,
    canonicalQuestion: json['canonical_question'] == null
        ? null
        : CanonicalQuestionSummary.fromJson(
            json['canonical_question'] as Map<String, dynamic>,
          ),
    aliases: (json['aliases'] as List<dynamic>)
        .map((item) => QuestionAlias.fromJson(item as Map<String, dynamic>))
        .toList(),
    resolvedAt: _date(json['resolved_at']),
  );

  final String id;
  final String title;
  final String? body;
  final String status;
  final UserSummary author;
  final DepartmentSummary? department;
  final TeamSummary? team;
  final List<AnswerDetail> answers;
  final AnswerDetail? acceptedAnswer;
  final int commentCount;
  final CanonicalQuestionSummary? canonicalQuestion;
  final List<QuestionAlias> aliases;
  final DateTime? resolvedAt;
}

class CanonicalQuestionSummary {
  const CanonicalQuestionSummary({required this.id, required this.title});

  factory CanonicalQuestionSummary.fromJson(Map<String, dynamic> json) =>
      CanonicalQuestionSummary(
        id: json['id'] as String,
        title: json['title'] as String,
      );

  final String id;
  final String title;
}

class QuestionAlias {
  const QuestionAlias({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory QuestionAlias.fromJson(Map<String, dynamic> json) => QuestionAlias(
    id: json['id'] as String,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final String title;
  final DateTime createdAt;
}

class CommentDetail {
  const CommentDetail({
    required this.id,
    required this.body,
    required this.author,
    required this.createdAt,
    this.answerId,
  });

  factory CommentDetail.fromJson(Map<String, dynamic> json) => CommentDetail(
    id: json['id'] as String,
    body: json['body'] as String,
    author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
    createdAt: DateTime.parse(json['created_at'] as String),
    answerId: json['answer_id'] as String?,
  );

  final String id;
  final String body;
  final UserSummary author;
  final DateTime createdAt;
  final String? answerId;
}
