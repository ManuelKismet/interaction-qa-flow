import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';

// Retain pending edits across routes, but never across an authority change.
final guidedPendingEditsProvider = Provider.family<GuidedPendingEdits, String>(
  (ref, sessionId) {
    final repository = ref.watch(guidedRepositoryProvider);
    final drafts = GuidedPendingEdits(
      repository: repository,
      sessionId: sessionId,
      onChanged: () {
        if (ref.mounted) ref.notifyListeners();
      },
    );
    ref.onDispose(drafts.close);
    return drafts;
  },
);

class _PendingEdit {
  const _PendingEdit({
    required this.question,
    required this.baseline,
    required this.value,
    this.participantId,
    this.answerId,
    this.branchesCollapsed = false,
  });

  final GuidedQuestion question;
  String get questionId => question.id;
  final String baseline;
  final String value;
  final String? participantId;
  final String? answerId;
  final bool branchesCollapsed;
}

class GuidedPendingEdits {
  GuidedPendingEdits({
    required this.repository,
    required this.sessionId,
    required this.onChanged,
  });

  final GuidedRepository repository;
  final String sessionId;
  final void Function() onChanged;
  final Map<String, _PendingEdit> _pending = {};
  final Map<String, String> _confirmed = {};
  Timer? _timer;
  int? _revision;
  bool _saving = false;
  bool _retrying = false;
  Completer<void>? _completion;
  bool _closed = false;
  bool _needsFullRead = false;
  bool conflict = false;
  String? error;
  GuidedSaveState state = GuidedSaveState.idle;

  Map<String, String> get values => {
    ..._confirmed,
    ..._pending.map((key, edit) => MapEntry(key, edit.value)),
  };

  bool get isBusy => _saving || _retrying;
  int? get revision => _revision;

  static String questionKey(String id) => 'question-$id';
  static String answerKey(String id, String participantId) =>
      'answer-$id-$participantId';

  void reconcile(GuidedSessionDetail session, {bool complete = true}) {
    if (session.id != sessionId || _closed || _saving) return;
    if (_pending.isEmpty) {
      if (_revision != null && session.revision < _revision!) return;
      _revision = session.revision;
      _confirmed.clear();
      return;
    }
    if (_revision != null && session.revision < _revision!) return;
    for (final entry in _pending.entries) {
      final remote = _remoteValue(session, entry.value);
      if (remote == null && !complete) {
        _needsFullRead = true;
        continue;
      }
      if (remote == null ||
          (remote != entry.value.baseline &&
          remote != _confirmed[entry.key] &&
          remote != entry.value.value)) {
        conflict = true;
        error = 'This session changed. Your pending edits are retained. Review the server version.';
        state = GuidedSaveState.failed;
        _timer?.cancel();
        return;
      }
    }
  }

  GuidedQuestion? _findQuestion(GuidedSessionDetail session, String questionId) {
    GuidedQuestion? find(List<GuidedQuestion> questions) {
      for (final question in questions) {
        if (question.id == questionId) return question;
        final nested = find(question.followUps);
        if (nested != null) return nested;
      }
      return null;
    }
    return find(session.questions);
  }

  String? _remoteValue(GuidedSessionDetail session, _PendingEdit edit) {
    final question = _findQuestion(session, edit.questionId);
    if (question == null || question.deletedAt != null ||
        question.scope != edit.question.scope ||
        question.source != edit.question.source ||
        question.targetParticipantId != edit.question.targetParticipantId ||
        question.triggeringAnswerId != edit.question.triggeringAnswerId ||
        (edit.participantId != null &&
            !session.participants.any((item) => item.id == edit.participantId)) ||
        (question.targetParticipantId != null &&
            !session.participants.any((item) => item.id == question.targetParticipantId))) {
      return null;
    }
    if (question.triggeringAnswerId != null) {
      GuidedAnswer? findAnswer(List<GuidedQuestion> questions) {
        for (final item in questions) {
          for (final answer in item.answers) {
            if (answer.id == question.triggeringAnswerId) return answer;
          }
          final nested = findAnswer(item.followUps);
          if (nested != null) return nested;
        }
        return null;
      }
      final parent = findAnswer(session.questions);
      if (parent == null ||
          (question.targetParticipantId != null &&
              parent.participantId != question.targetParticipantId)) {
        return null;
      }
    }
    if (edit.participantId == null) return question.text;
    final answer = question.answerFor(edit.participantId);
    if (edit.answerId != null && answer?.id != edit.answerId) return null;
    return answer?.body ?? '';
  }

  Future<void> question(GuidedQuestion question, String value) async {
    _stage(questionKey(question.id), _PendingEdit(
      question: question,
      baseline: question.text,
      value: value,
    ));
  }

  Future<void> answer(
    GuidedQuestion question,
    GuidedAnswer? answer,
    String participantId,
    String value,
  ) async {
    _stage(answerKey(question.id, participantId), _PendingEdit(
      question: question,
      participantId: participantId,
      answerId: answer?.id,
      branchesCollapsed: answer?.branchesCollapsed ?? false,
      baseline: answer?.body ?? '',
      value: value,
    ));
  }

  void _stage(String key, _PendingEdit edit) {
    if (_closed) return;
    try {
      repository.ensureCurrent();
    } catch (failure) {
      error = failure.toString();
      state = GuidedSaveState.failed;
      onChanged();
      return;
    }
    final previous = _pending[key];
    final baseline = previous?.baseline ?? _confirmed[key] ?? edit.baseline;
    _pending[key] = _PendingEdit(
      question: previous?.question ?? edit.question,
      participantId: edit.participantId,
      answerId: edit.answerId,
      branchesCollapsed: edit.branchesCollapsed,
      baseline: baseline,
      value: edit.value,
    );
    _timer?.cancel();
    if (!conflict) {
      error = null;
      state = GuidedSaveState.editing;
      _timer = Timer(const Duration(milliseconds: 650), flush);
    }
    onChanged();
  }

  Future<void> flush() async {
    _timer?.cancel();
    if (_saving) return _completion!.future;
    if (_closed || _retrying || _pending.isEmpty || conflict) return;
    _completion = Completer<void>();
    _saving = true;
    state = GuidedSaveState.saving;
    onChanged();
    try {
      repository.ensureCurrent();
      if (_revision == null) throw StateError('Reload this session before saving.');
      if (_needsFullRead) {
        final session = await repository.getSession(sessionId);
        if (_closed) return;
        if (session.revision != _revision ||
            _pending.values.any((edit) => _remoteValue(session, edit) == null)) {
          throw const GuidedConflict();
        }
        _needsFullRead = false;
      }
      while (_pending.isNotEmpty && !_closed && !conflict) {
        final entry = _pending.entries.first;
        final edit = entry.value;
        int? acknowledgedRevision;
        void acknowledge(int revision) => acknowledgedRevision = revision;
        if (edit.participantId == null) {
          if (edit.value.trim().isEmpty) {
            throw StateError('Question title cannot be blank. Your edit is not saved.');
          }
          await repository.updateQuestion(
            edit.questionId, edit.value, expectedRevision: _revision,
            onRevision: acknowledge,
          );
        } else if (edit.answerId != null) {
          await repository.updateAnswer(
            edit.answerId!, body: edit.value, expectedRevision: _revision,
            onRevision: acknowledge,
          );
        } else {
          await repository.saveAnswer(
            questionId: edit.questionId,
            participantId: edit.participantId!,
            body: edit.value,
            branchesCollapsed: edit.branchesCollapsed,
            expectedRevision: _revision,
            onRevision: acknowledge,
          );
        }
        if (_closed) return;
        _revision = acknowledgedRevision ?? _revision! + 1;
        _confirmed[entry.key] = edit.value;
        if (identical(_pending[entry.key], edit)) {
          _pending.remove(entry.key);
        } else {
          final newer = _pending[entry.key]!;
          _pending[entry.key] = _PendingEdit(
            question: newer.question,
            participantId: newer.participantId,
            answerId: newer.answerId,
            branchesCollapsed: newer.branchesCollapsed,
            baseline: edit.value,
            value: newer.value,
          );
        }
      }
      if (conflict) {
        state = GuidedSaveState.failed;
      } else {
        state = _pending.isEmpty ? GuidedSaveState.saved : GuidedSaveState.editing;
        error = null;
      }
    } catch (failure) {
      if (_closed) return;
      conflict = failure is GuidedConflict;
      error = failure.toString();
      state = GuidedSaveState.failed;
    } finally {
      _saving = false;
      _completion!.complete();
      if (!_closed) onChanged();
    }
  }

  // A retry reconciles ambiguous network failures before sending any mutation.
  Future<void> retry() async {
    if (_closed || isBusy) return;
    _retrying = true;
    state = GuidedSaveState.saving;
    onChanged();
    try {
      final session = await repository.getSession(sessionId);
      if (_closed) return;
      for (final entry in _pending.entries.toList()) {
        final remote = _remoteValue(session, entry.value);
        final remoteAnswer = entry.value.participantId == null
            ? null
            : _findQuestion(session, entry.value.questionId)
                ?.answerFor(entry.value.participantId);
        final acknowledged = entry.value.participantId == null ||
            remoteAnswer != null;
        if (acknowledged && remote == entry.value.value) {
          _pending.remove(entry.key);
          _confirmed[entry.key] = remote!;
        } else if (remote != entry.value.baseline) {
          throw const GuidedConflict();
        } else if (entry.value.participantId != null) {
          final edit = entry.value;
          _pending[entry.key] = _PendingEdit(
            question: edit.question,
            participantId: edit.participantId,
            answerId: remoteAnswer?.id,
            branchesCollapsed: remoteAnswer?.branchesCollapsed ?? false,
            baseline: edit.baseline,
            value: edit.value,
          );
        }
      }
      _revision = session.revision;
      _needsFullRead = false;
      conflict = false;
      error = null;
      _retrying = false;
      if (_pending.isEmpty) {
        state = GuidedSaveState.saved;
        onChanged();
      } else {
        await flush();
      }
    } catch (failure) {
      if (_closed) return;
      conflict = failure is GuidedConflict;
      error = failure.toString();
      state = GuidedSaveState.failed;
      onChanged();
    } finally {
      _retrying = false;
    }
  }

  void useServerVersion() {
    if (isBusy || _closed) return;
    _timer?.cancel();
    _pending.clear();
    _confirmed.clear();
    _revision = null;
    _needsFullRead = false;
    conflict = false;
    error = null;
    state = GuidedSaveState.idle;
    onChanged();
  }

  void suspend() {
    if (_closed || _pending.isEmpty) return;
    _timer?.cancel();
    conflict = true;
    error = 'Editing access changed. Pending edits have not been sent.';
    state = GuidedSaveState.failed;
  }

  void close() {
    _closed = true;
    _timer?.cancel();
    _pending.clear();
    _confirmed.clear();
  }
}
