class GuidedParticipant {
  const GuidedParticipant({
    required this.id,
    required this.name,
    this.roleLabel,
    this.notes,
  });

  factory GuidedParticipant.fromJson(Map<String, dynamic> json) {
    return GuidedParticipant(
      id: json['id'] as String,
      name: json['name'] as String,
      roleLabel: json['role_label'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String name;
  final String? roleLabel;
  final String? notes;
}

class GuidedAnswer {
  const GuidedAnswer({
    required this.id,
    required this.questionId,
    required this.participantId,
    required this.body,
    required this.branchesCollapsed,
  });

  factory GuidedAnswer.fromJson(Map<String, dynamic> json) {
    return GuidedAnswer(
      id: json['id'] as String,
      questionId: json['question_id'] as String,
      participantId: json['participant_id'] as String,
      body: json['body'] as String? ?? '',
      branchesCollapsed: json['branches_collapsed'] as bool? ?? false,
    );
  }

  final String id;
  final String questionId;
  final String participantId;
  final String body;
  final bool branchesCollapsed;
}

class GuidedQuestion {
  const GuidedQuestion({
    required this.id,
    required this.text,
    required this.scope,
    required this.source,
    required this.answers,
    required this.followUps,
    this.targetParticipantId,
    this.triggeringAnswerId,
    this.deletedAt,
    this.knowledgeQuestionId,
  });

  factory GuidedQuestion.fromJson(Map<String, dynamic> json) {
    return GuidedQuestion(
      id: json['id'] as String,
      text: json['text'] as String,
      scope: json['scope'] as String,
      source: json['source'] as String,
      targetParticipantId: json['target_participant_id'] as String?,
      triggeringAnswerId: json['triggering_answer_id'] as String?,
      deletedAt: json['deleted_at'] as String?,
      knowledgeQuestionId: json['knowledge_question_id'] as String?,
      answers: (json['answers'] as List<dynamic>? ?? const [])
          .map((item) => GuidedAnswer.fromJson(item as Map<String, dynamic>))
          .toList(),
      followUps: (json['follow_ups'] as List<dynamic>? ?? const [])
          .map((item) => GuidedQuestion.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String text;
  final String scope;
  final String source;
  final String? targetParticipantId;
  final String? triggeringAnswerId;
  final String? deletedAt;
  final String? knowledgeQuestionId;
  final List<GuidedAnswer> answers;
  final List<GuidedQuestion> followUps;

  GuidedAnswer? answerFor(String? participantId) {
    if (participantId == null) return null;
    for (final answer in answers) {
      if (answer.participantId == participantId) return answer;
    }
    return null;
  }
}

class GuidedSessionSummary {
  const GuidedSessionSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.visibility,
    required this.revision,
    required this.updatedAt,
    this.createdById,
    this.ownerText,
    this.contextReference,
    this.departmentId,
    this.teamId,
    this.templateId,
    this.templateVersionId,
  });

  factory GuidedSessionSummary.fromJson(Map<String, dynamic> json) {
    return GuidedSessionSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      visibility: json['visibility'] as String,
      revision: json['revision'] as int? ?? 1,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdById: json['created_by'] as String?,
      ownerText: json['owner_text'] as String?,
      contextReference: json['context_reference'] as String?,
      departmentId: json['department_id'] as String?,
      teamId: json['team_id'] as String?,
      templateId: json['template_id'] as String?,
      templateVersionId: json['template_version_id'] as String?,
    );
  }

  final String id;
  final String title;
  final String status;
  final String visibility;
  final int revision;
  final DateTime updatedAt;
  final String? createdById;
  final String? ownerText;
  final String? contextReference;
  final String? departmentId;
  final String? teamId;
  final String? templateId;
  final String? templateVersionId;
}

class GuidedSessionDetail extends GuidedSessionSummary {
  const GuidedSessionDetail({
    required super.id,
    required super.title,
    required super.status,
    required super.visibility,
    required super.revision,
    required super.updatedAt,
    required this.participants,
    required this.questions,
    required this.preparedQuestionCount,
    required this.followUpCount,
    super.createdById,
    super.ownerText,
    super.contextReference,
    super.departmentId,
    super.teamId,
    super.templateId,
    super.templateVersionId,
  });

  factory GuidedSessionDetail.fromJson(Map<String, dynamic> json) {
    final summary = GuidedSessionSummary.fromJson(json);
    return GuidedSessionDetail(
      id: summary.id,
      title: summary.title,
      status: summary.status,
      visibility: summary.visibility,
      revision: summary.revision,
      updatedAt: summary.updatedAt,
      createdById: summary.createdById,
      ownerText: summary.ownerText,
      contextReference: summary.contextReference,
      departmentId: summary.departmentId,
      teamId: summary.teamId,
      templateId: summary.templateId,
      templateVersionId: summary.templateVersionId,
      participants: (json['participants'] as List<dynamic>? ?? const [])
          .map((item) => GuidedParticipant.fromJson(item as Map<String, dynamic>))
          .toList(),
      questions: (json['questions'] as List<dynamic>? ?? const [])
          .map((item) => GuidedQuestion.fromJson(item as Map<String, dynamic>))
          .toList(),
      preparedQuestionCount: json['prepared_question_count'] as int? ?? 0,
      followUpCount: json['follow_up_count'] as int? ?? 0,
    );
  }

  final List<GuidedParticipant> participants;
  final List<GuidedQuestion> questions;
  final int preparedQuestionCount;
  final int followUpCount;
}

class GuidedTemplateQuestion {
  const GuidedTemplateQuestion({
    required this.id,
    required this.text,
    required this.scope,
    required this.orderIndex,
    this.participantReference,
    this.parentTemplateQuestionId,
  });

  factory GuidedTemplateQuestion.fromJson(Map<String, dynamic> json) {
    return GuidedTemplateQuestion(
      id: json['id'] as String,
      text: json['text'] as String,
      scope: json['scope'] as String,
      orderIndex: json['order_index'] as int,
      participantReference: json['participant_reference'] as String?,
      parentTemplateQuestionId: json['parent_template_question_id'] as String?,
    );
  }

  final String id;
  final String text;
  final String scope;
  final int orderIndex;
  final String? participantReference;
  final String? parentTemplateQuestionId;
}

class GuidedTemplate {
  const GuidedTemplate({
    required this.id,
    required this.name,
    required this.status,
    required this.currentVersion,
    required this.questions,
    this.description,
    this.createdById,
  });

  factory GuidedTemplate.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as Map<String, dynamic>?;
    return GuidedTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      currentVersion: json['current_version'] as int,
      createdById: json['created_by'] as String?,
      questions: (version?['questions'] as List<dynamic>? ?? const [])
          .map((item) => GuidedTemplateQuestion.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String name;
  final String? description;
  final String status;
  final int currentVersion;
  final List<GuidedTemplateQuestion> questions;
  final String? createdById;
}

enum GuidedViewMode {
  allRelevant('All relevant', 'all_relevant'),
  sharedOnly('Shared only', 'shared_only'),
  participantOnly('This participant', 'participant_only');

  const GuidedViewMode(this.label, this.apiValue);
  final String label;
  final String apiValue;
}

enum GuidedSaveState { idle, editing, saving, saved, failed }

class KnowledgeProposal {
  const KnowledgeProposal({
    required this.id,
    required this.questionText,
    required this.answerText,
    required this.status,
    required this.createdAt,
  });

  factory KnowledgeProposal.fromJson(Map<String, dynamic> json) {
    return KnowledgeProposal(
      id: json['id'] as String,
      questionText: json['proposed_question_text'] as String,
      answerText: json['proposed_answer_text'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String questionText;
  final String answerText;
  final String status;
  final DateTime createdAt;
}

class GuidedRevision {
  const GuidedRevision({
    required this.revisionNumber,
    required this.change,
    required this.createdAt,
  });

  factory GuidedRevision.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    return GuidedRevision(
      revisionNumber: json['revision_number'] as int,
      change: summary['change'] as String? ?? 'Saved',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final int revisionNumber;
  final String change;
  final DateTime createdAt;
}