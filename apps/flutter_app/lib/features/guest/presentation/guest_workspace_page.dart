import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/auth/sign_in_page.dart';
import 'package:int_qa_flow/core/platform/pdf_download.dart';
import 'package:int_qa_flow/core/platform/print_page.dart';
import 'package:int_qa_flow/features/guest/application/personal_workspace_status.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/personal_workspace_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_interact_helpers.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_report_document.dart';
import 'package:int_qa_flow/features/knowledge/application/knowledge_search_sources.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';
import 'package:int_qa_flow/shared/widgets/knowledge_section_tabs.dart';
import 'package:share_plus/share_plus.dart';

part 'group_interact_editor.dart';

void _showPdfFontFallbackNotice(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        kIsWeb
            ? 'The bundled PDF font lacks some characters. No partial PDF was created; the full report is opening in browser print. Check its preview for glyph support.'
            : 'The bundled PDF font lacks some characters, so no partial PDF was created. Use the web report’s browser-print export to retain the full text.',
      ),
    ),
  );
}

var _personalWorkspaceStatusOwnerSequence = 0;

class _PersonalWorkspaceWrite {
  const _PersonalWorkspaceWrite({
    required this.action,
    required this.kind,
    required this.sourceKey,
    required this.sourceId,
    this.title,
    this.data,
    this.deleteAfterCreate = false,
    this.reconcileRecordId,
    this.reconcileRevision,
  });

  /// `create`, `update`, `delete` or `reconcile`. A `reconcile` write restores
  /// an item after an account removal whose outcome was not confirmed: the
  /// latest same-UID account state is read before choosing create or update.
  final String action;
  final String kind;
  final String sourceKey;
  final String sourceId;
  final String? title;
  final Map<String, dynamic>? data;
  final bool deleteAfterCreate;

  /// The account record (ID and revision) the unconfirmed removal targeted.
  final String? reconcileRecordId;
  final int? reconcileRevision;
}

class _PersonalReconcileConflict implements Exception {
  const _PersonalReconcileConflict(this.remote);

  final Map<String, dynamic> remote;
}

String _pdfFontPreviewMessage() => kIsWeb
    ? 'If the bundled font lacks a character, direct PDF is skipped. The full report opens in browser print; check print preview for glyph support.'
    : 'If the bundled font lacks a character, direct PDF is skipped. Use the web report’s browser-print export to retain the full text.';

class GuestWorkspacePage extends ConsumerStatefulWidget {
  const GuestWorkspacePage({
    required this.firebaseReady,
    this.initialKnowledgeItemId,
    this.initialKnowledgeSection = KnowledgeSection.ask,
    this.onKnowledgeSectionChanged,
    this.initialWorkspaceTab = 0,
    this.onWorkspaceTabChanged,
    this.personalWorkspaceEnabled = false,
    this.sharedIdentityActive = false,
    this.accountUser,
    this.membershipStatus,
    this.authUnavailable = false,
    this.onRetryAccount,
    this.initialSessionId,
    this.onSessionRouteChanged,
    super.key,
  });

  final bool firebaseReady;
  final String? initialKnowledgeItemId;
  final KnowledgeSection initialKnowledgeSection;
  final ValueChanged<KnowledgeSection>? onKnowledgeSectionChanged;
  final int initialWorkspaceTab;
  final ValueChanged<int>? onWorkspaceTabChanged;
  final bool personalWorkspaceEnabled;
  final bool sharedIdentityActive;
  final User? accountUser;
  final AccountMembershipStatus? membershipStatus;
  final bool authUnavailable;
  final VoidCallback? onRetryAccount;

  /// Interact session opened in the dedicated session editor.
  final String? initialSessionId;

  /// Called when the session editor opens (`id`) or closes (`null`) so a
  /// router can reflect the editor in the URL. Without it the editor is
  /// in-page state only.
  final ValueChanged<String?>? onSessionRouteChanged;

  @override
  ConsumerState<GuestWorkspacePage> createState() => _GuestWorkspacePageState();
}

class _GuestWorkspacePageState extends ConsumerState<GuestWorkspacePage>
    with WidgetsBindingObserver {
  GuestWorkspaceData? _data;
  late GuestWorkspaceStore _store;
  String? _loadError;
  String? _pendingImportJson;
  String _saveStatus = 'Saved on this device';
  bool _unsavedChanges = false;
  bool _isLoading = false;
  int _dataRevision = 0;
  int _savedRevision = 0;
  Future<bool>? _saveOperation;
  Timer? _autosaveTimer;
  List<Map<String, dynamic>> _personalItems = [];
  List<Map<String, dynamic>> _pendingPersonalItems = [];
  final Map<String, _PersonalWorkspaceWrite> _pendingPersonalWrites = {};
  String? _personalError;
  List<Map<String, dynamic>> _pendingPersonalImport = [];
  bool _personalImportNeedsReselection = false;
  String? _personalConflictSourceKey;
  bool _personalConflictReloadFailed = false;
  int _personalGeneration = 0;
  final Set<VoidCallback> _accountScopedDialogClosers = {};
  int _personalRefreshGeneration = 0;
  String? _personalOwnerUid;
  bool _personalLoading = false;
  String? _personalLoadedUid;
  String? _openSessionId;
  _PersonalWorkspaceWrite? _inFlightPersonalWrite;
  // Account removals that were sent but whose outcome was not confirmed,
  // keyed by source key, with the record they targeted.
  final Map<String, Map<String, dynamic>> _uncertainPersonalDeletes = {};
  bool _personalSaving = false;
  bool _personalImportSaving = false;
  int _personalWriteGeneration = 0;
  final int _workspaceStatusOwner = ++_personalWorkspaceStatusOwnerSequence;
  late final PersonalWorkspaceStatusController _workspaceStatusController;
  int _workspaceStatusRevision = 0;
  bool _workspaceStatusClaimed = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(guestWorkspaceStoreProvider);
    _workspaceStatusController = ref.read(
      personalWorkspaceStatusProvider.notifier,
    );
    _personalOwnerUid = _verifiedPersonalUid;
    _openSessionId = widget.initialSessionId;
    WidgetsBinding.instance.addObserver(this);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshPersonalWorkspace());
    });
    _publishWorkspaceSaveStatus(claim: true);
  }

  @override
  void didUpdateWidget(covariant GuestWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSessionId != oldWidget.initialSessionId) {
      _openSessionId = widget.initialSessionId;
    }
    final uid = _verifiedPersonalUid;
    if (uid == _personalOwnerUid) return;
    if (_openSessionId != null) {
      _openSessionId = null;
      final onRouteChanged = widget.onSessionRouteChanged;
      if (onRouteChanged != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _openSessionId == null) onRouteChanged(null);
        });
      }
    }
    _personalGeneration++;
    _personalRefreshGeneration++;
    _personalOwnerUid = uid;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _closeAccountScopedDialogs(),
    );
    _personalItems = [];
    _pendingPersonalItems = [];
    _pendingPersonalWrites.clear();
    _uncertainPersonalDeletes.clear();
    _pendingPersonalImport = [];
    _personalImportNeedsReselection = false;
    _personalConflictSourceKey = null;
    _personalConflictReloadFailed = false;
    _personalError = null;
    _personalLoading = false;
    _personalImportSaving = false;
    _publishWorkspaceSaveStatus(claim: true);
    if (uid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshPersonalWorkspace());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushPendingSave());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    if (_savedRevision < _dataRevision) {
      unawaited(_flushPendingSave());
    }
    _workspaceStatusRevision++;
    final statusController = _workspaceStatusController;
    final statusOwner = _workspaceStatusOwner;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      statusController.clear(statusOwner);
    });
    super.dispose();
  }

  bool get _hasPendingWorkspaceChanges =>
      _savedRevision < _dataRevision ||
      _unsavedChanges ||
      _pendingPersonalWrites.isNotEmpty ||
      _pendingPersonalImport.isNotEmpty ||
      _personalImportSaving ||
      _personalSaving ||
      _personalConflictSourceKey != null;

  void _publishWorkspaceSaveStatus({bool claim = false}) {
    final revision = ++_workspaceStatusRevision;
    final uid = _verifiedPersonalUid;
    final shouldClaim = claim || !_workspaceStatusClaimed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _workspaceStatusRevision) return;
      _workspaceStatusController.publish(
        ownerGeneration: _workspaceStatusOwner,
        uid: uid,
        hasPendingChanges: _hasPendingWorkspaceChanges,
        claim: shouldClaim,
      );
      if (shouldClaim) _workspaceStatusClaimed = true;
    });
  }

  Future<void> _load() async {
    if (_isLoading) return;
    final revisionAtStart = _dataRevision;
    setState(() => _isLoading = true);
    try {
      final data = await _store.load();
      if (mounted) {
        setState(() {
          if (_dataRevision == revisionAtStart && _data == null) {
            _data = data;
            _savedRevision = _dataRevision;
          }
          _loadError = null;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _loadError =
              'Unable to read local guest data. The stored copy was not changed.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? get _verifiedPersonalUid {
    if (!widget.personalWorkspaceEnabled || !widget.firebaseReady) return null;
    final user = _currentAccountUser;
    return isVerifiedRegisteredFirebaseUser(user) ? user!.uid : null;
  }

  Future<void> _refreshPersonalWorkspace() async {
    final uid = _verifiedPersonalUid;
    if (uid == null || !mounted) return;
    final generation = _personalGeneration;
    final refreshGeneration = ++_personalRefreshGeneration;
    final writeGeneration = _personalWriteGeneration;
    setState(() {
      _personalLoading = true;
      _personalError = null;
    });
    _publishWorkspaceSaveStatus();
    try {
      final items = await ref
          .read(personalWorkspaceRepositoryProvider)
          .listItems(expectedUid: uid);
      if (!mounted ||
          generation != _personalGeneration ||
          refreshGeneration != _personalRefreshGeneration ||
          uid != _verifiedPersonalUid) {
        return;
      }
      if (writeGeneration != _personalWriteGeneration) {
        setState(() => _personalLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && uid == _verifiedPersonalUid) {
            unawaited(_refreshPersonalWorkspace());
          }
        });
        _publishWorkspaceSaveStatus();
        return;
      }
      setState(() {
        _personalItems = items;
        _personalLoading = false;
        _personalLoadedUid = uid;
      });
    } on Object {
      if (!mounted ||
          generation != _personalGeneration ||
          refreshGeneration != _personalRefreshGeneration ||
          uid != _verifiedPersonalUid) {
        return;
      }
      setState(() {
        _personalLoading = false;
        _personalLoadedUid = uid;
        _personalError =
            'Personal account work could not be loaded. Local work is unchanged; retry when connected.';
      });
    }
  }

  GuestWorkspaceData _withPersonalWorkspace(GuestWorkspaceData local) {
    List<Map<String, dynamic>> combine(
      String kind,
      List<Map<String, dynamic>> localItems,
    ) {
      final personal = <String, Map<String, dynamic>>{};
      for (final record in _personalItems.where(
        (item) => item['kind'] == kind,
      )) {
        final data = record['data'];
        if (data is Map<String, dynamic> && data['id'] is String) {
          personal[data['id'] as String] = data;
        }
      }
      for (final record in _pendingPersonalItems.where(
        (item) => item['kind'] == kind,
      )) {
        final data = record['data'];
        if (data is Map<String, dynamic> && data['id'] is String) {
          personal[data['id'] as String] = data;
        }
      }
      for (final write in _pendingPersonalWrites.values.where(
        (item) => item.kind == kind && item.action == 'delete',
      )) {
        personal.remove(write.sourceId);
      }
      return [
        ...personal.values,
        for (final item in localItems)
          if (!personal.containsKey(item['id'])) item,
      ];
    }

    return GuestWorkspaceData(
      knowledge: combine('knowledge', local.knowledge),
      sessions: combine('interact_session', local.sessions),
      templates: combine('template', local.templates),
    );
  }

  String _storageStatus(String kind, Map<String, dynamic> item) {
    final id = item['id'];
    if (id is! String) return 'Local on this device';
    final write = _pendingPersonalWrites['$kind:$id'];
    if (write?.action == 'delete') {
      return _personalError == null
          ? 'Local copy · account removal pending'
          : 'Local copy · account removal not confirmed';
    }
    final isPersonal = [..._personalItems, ..._pendingPersonalItems].any(
      (record) =>
          record['kind'] == kind && (record['data'] as Map?)?['id'] == id,
    );
    if (!isPersonal) return 'Local on this device';
    if (write != null) {
      return _personalError == null
          ? 'Personal account · saving changes'
          : 'Personal account · save not confirmed';
    }
    return 'Personal account · saved';
  }

  void _save(
    GuestWorkspaceData submitted, {
    Set<String> accountPrivateKeys = const {},
  }) {
    final previousLocal = _data ?? const GuestWorkspaceData();
    final uid = _verifiedPersonalUid;
    final remoteKeys = {
      for (final record in _personalItems)
        if (record['kind'] is String &&
            record['data'] is Map &&
            (record['data'] as Map)['id'] is String)
          '${record['kind']}:${(record['data'] as Map)['id']}',
      for (final write in _pendingPersonalWrites.values)
        if (write.action != 'delete') '${write.kind}:${write.sourceId}',
    };

    List<Map<String, dynamic>> keepLocal(
      String kind,
      List<Map<String, dynamic>> previous,
      List<Map<String, dynamic>> next,
    ) {
      final previousById = {
        for (final item in previous)
          if (item['id'] is String) item['id'] as String: item,
      };
      final nextById = {
        for (final item in next)
          if (item['id'] is String) item['id'] as String: item,
      };
      final local = <Map<String, dynamic>>[];
      for (final entry in previousById.entries) {
        if (remoteKeys.contains('$kind:${entry.key}')) {
          local.add(entry.value);
        } else if (nextById.containsKey(entry.key)) {
          local.add(nextById[entry.key]!);
        }
      }
      for (final entry in nextById.entries) {
        if (!previousById.containsKey(entry.key) &&
            !remoteKeys.contains('$kind:${entry.key}') &&
            !accountPrivateKeys.contains('$kind:${entry.key}')) {
          local.add(entry.value);
        }
      }
      return local;
    }

    final local = uid == null
        ? submitted
        : GuestWorkspaceData(
            knowledge: keepLocal(
              'knowledge',
              previousLocal.knowledge,
              submitted.knowledge,
            ),
            sessions: keepLocal(
              'interact_session',
              previousLocal.sessions,
              submitted.sessions,
            ),
            templates: keepLocal(
              'template',
              previousLocal.templates,
              submitted.templates,
            ),
          );
    setState(() {
      _data = local;
      _dataRevision++;
      _saveStatus = 'Saving locally…';
    });
    _publishWorkspaceSaveStatus();
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: 250),
      _flushPendingSave,
    );
    if (uid != null) {
      unawaited(_syncPersonalWorkspace(uid, submitted));
    }
  }

  void _createWorkspaceItem({
    required String kind,
    required Map<String, dynamic> item,
    required GuestWorkspaceData updated,
  }) {
    final uid = _verifiedPersonalUid;
    final accountItem = uid == null
        ? item
        : {
            ...item,
            if (kind == 'knowledge' || kind == 'interact_session')
              'visibility': 'private_account',
          };
    final submitted = uid == null
        ? updated
        : switch (kind) {
            'knowledge' => updated.copyWith(
              knowledge: [
                accountItem,
                ...updated.knowledge.where(
                  (value) => value['id'] != item['id'],
                ),
              ],
            ),
            'interact_session' => updated.copyWith(
              sessions: [
                accountItem,
                ...updated.sessions.where((value) => value['id'] != item['id']),
              ],
            ),
            'template' => updated.copyWith(
              templates: [
                accountItem,
                ...updated.templates.where(
                  (value) => value['id'] != item['id'],
                ),
              ],
            ),
            _ => updated,
          };
    _save(
      submitted,
      accountPrivateKeys: uid == null ? const {} : {'$kind:${item['id']}'},
    );
    if (uid == null) return;
    final sourceId = item['id'] as String;
    final write = _PersonalWorkspaceWrite(
      action: 'create',
      kind: kind,
      sourceKey: _personalSourceKey(kind, sourceId),
      sourceId: sourceId,
      title: _personalTitle(kind, accountItem),
      data: accountItem,
    );
    _enqueuePersonalWrite(write);
    unawaited(
      _processPersonalWrites(
        uid,
        _personalGeneration,
        ref.read(personalWorkspaceRepositoryProvider),
      ),
    );
  }

  Future<void> _syncPersonalWorkspace(
    String uid,
    GuestWorkspaceData submitted,
  ) async {
    final generation = _personalGeneration;
    final repository = ref.read(personalWorkspaceRepositoryProvider);
    final submittedByKey = {
      for (final item in submitted.knowledge) 'knowledge:${item['id']}': item,
      for (final item in submitted.sessions)
        'interact_session:${item['id']}': item,
      for (final item in submitted.templates) 'template:${item['id']}': item,
    };

    for (final record in _personalItems) {
      final data = record['data'];
      final kind = record['kind'];
      if (data is! Map<String, dynamic> ||
          kind is! String ||
          data['id'] is! String) {
        continue;
      }
      final key = '$kind:${data['id']}';
      final replacement = submittedByKey[key];
      if (_pendingPersonalWrites[key]?.action == 'reconcile') continue;
      if (replacement == null) {
        _enqueuePersonalWrite(
          _PersonalWorkspaceWrite(
            action: 'delete',
            kind: kind,
            sourceKey: record['source_key'] as String,
            sourceId: data['id'] as String,
          ),
        );
      } else if (jsonEncode(replacement) != jsonEncode(data) ||
          _personalTitle(kind, replacement) != record['title']) {
        _enqueuePersonalWrite(
          _PersonalWorkspaceWrite(
            action: 'update',
            kind: kind,
            sourceKey: record['source_key'] as String,
            sourceId: data['id'] as String,
            title: _personalTitle(kind, replacement),
            data: replacement,
          ),
        );
      }
    }

    for (final entry in _pendingPersonalWrites.entries.toList()) {
      final write = entry.value;
      if (write.action == 'delete') {
        // An undo restored an item whose account removal is still pending:
        // replace the removal so the restored item is kept in the account.
        final replacement = submittedByKey['${write.kind}:${write.sourceId}'];
        if (replacement == null) continue;
        final current = _personalItems
            .where((item) => item['source_key'] == write.sourceKey)
            .firstOrNull;
        // A removal that failed without confirmation may still have been
        // applied by the server, so the restore reconciles first.
        final uncertain = _uncertainPersonalDeletes[write.sourceKey];
        _enqueuePersonalWrite(
          _PersonalWorkspaceWrite(
            action: current == null || identical(_inFlightPersonalWrite, write)
                ? 'create'
                : uncertain != null
                ? 'reconcile'
                : 'update',
            kind: write.kind,
            sourceKey: write.sourceKey,
            sourceId: write.sourceId,
            title: _personalTitle(write.kind, replacement),
            data: replacement,
            reconcileRecordId: uncertain?['id'] as String?,
            reconcileRevision: uncertain?['revision'] as int?,
          ),
        );
        continue;
      }
      final replacement = submittedByKey['${write.kind}:${write.sourceId}'];
      if (replacement == null) {
        _enqueuePersonalWrite(
          _PersonalWorkspaceWrite(
            action: 'delete',
            kind: write.kind,
            sourceKey: write.sourceKey,
            sourceId: write.sourceId,
          ),
        );
      } else if (jsonEncode(replacement) != jsonEncode(write.data)) {
        _enqueuePersonalWrite(
          _PersonalWorkspaceWrite(
            action: write.action,
            kind: write.kind,
            sourceKey: write.sourceKey,
            sourceId: write.sourceId,
            title: _personalTitle(write.kind, replacement),
            data: replacement,
            deleteAfterCreate: write.deleteAfterCreate,
            reconcileRecordId: write.reconcileRecordId,
            reconcileRevision: write.reconcileRevision,
          ),
        );
      }
    }

    await _processPersonalWrites(uid, generation, repository);
  }

  void _enqueuePersonalWrite(_PersonalWorkspaceWrite write) {
    final key = '${write.kind}:${write.sourceId}';
    final previous = _pendingPersonalWrites[key];
    final nextWrite = write.action == 'delete' && previous?.action == 'create'
        ? _PersonalWorkspaceWrite(
            action: 'create',
            kind: previous!.kind,
            sourceKey: previous.sourceKey,
            sourceId: previous.sourceId,
            title: previous.title,
            data: previous.data,
            deleteAfterCreate: true,
          )
        : write;
    setState(() {
      _pendingPersonalWrites[key] = nextWrite;
      _pendingPersonalItems.removeWhere(
        (item) =>
            item['kind'] == nextWrite.kind &&
            (item['data'] as Map?)?['id'] == nextWrite.sourceId,
      );
      if (nextWrite.action != 'delete') {
        _pendingPersonalItems.add({
          'kind': nextWrite.kind,
          'data': nextWrite.data,
        });
      }
    });
  }

  Future<void> _processPersonalWrites(
    String uid,
    int generation,
    PersonalWorkspaceRepository repository, {
    String? prioritySourceKey,
  }) async {
    if (_personalSaving ||
        !mounted ||
        _personalError != null ||
        _personalConflictSourceKey != null) {
      return;
    }
    _personalSaving = true;
    _publishWorkspaceSaveStatus();
    try {
      while (mounted &&
          generation == _personalGeneration &&
          uid == _verifiedPersonalUid &&
          _pendingPersonalWrites.isNotEmpty) {
        final priorityEntry = prioritySourceKey == null
            ? null
            : _pendingPersonalWrites.entries
                  .where((entry) => entry.value.sourceKey == prioritySourceKey)
                  .firstOrNull;
        final entry = priorityEntry ?? _pendingPersonalWrites.entries.first;
        final write = entry.value;
        _inFlightPersonalWrite = write;
        try {
          Map<String, dynamic>? saved;
          final current = _personalItems
              .where((item) => item['source_key'] == write.sourceKey)
              .firstOrNull;
          if (current == null && write.action == 'delete') {
            saved = null;
          } else if (write.action == 'reconcile') {
            final latest = await repository.listItems(expectedUid: uid);
            if (!mounted ||
                generation != _personalGeneration ||
                uid != _verifiedPersonalUid) {
              return;
            }
            final remote = latest
                .where((item) => item['source_key'] == write.sourceKey)
                .firstOrNull;
            if (remote == null) {
              // The removal was applied: recreate idempotently by source key.
              saved = await repository.createItem(
                kind: write.kind,
                sourceKey: write.sourceKey,
                title: write.title!,
                data: write.data!,
                expectedUid: uid,
              );
              if (!_samePersonalContent(saved, write)) {
                throw _PersonalReconcileConflict(saved);
              }
            } else if (remote['id'] == write.reconcileRecordId &&
                remote['revision'] == write.reconcileRevision) {
              // The removal was not applied and nothing changed elsewhere.
              saved = await repository.updateItem(
                id: remote['id'] as String,
                expectedUid: uid,
                expectedRevision: write.reconcileRevision!,
                title: write.title!,
                data: write.data!,
              );
            } else if (_samePersonalContent(remote, write)) {
              // A previous restore whose response was lost already applied.
              saved = remote;
            } else {
              throw _PersonalReconcileConflict(remote);
            }
          } else if (write.action == 'create') {
            saved = await repository.createItem(
              kind: write.kind,
              sourceKey: write.sourceKey,
              title: write.title!,
              data: write.data!,
              expectedUid: uid,
            );
            final savedData = saved['data'];
            if (saved['title'] != write.title ||
                savedData is! Map ||
                jsonEncode(savedData) != jsonEncode(write.data)) {
              if (!mounted ||
                  generation != _personalGeneration ||
                  uid != _verifiedPersonalUid) {
                return;
              }
              saved = await repository.updateItem(
                id: saved['id'] as String,
                expectedUid: uid,
                expectedRevision: saved['revision'] as int,
                title: write.title!,
                data: write.data!,
              );
            }
          } else if (current == null) {
            throw StateError('The personal item is not loaded.');
          } else if (write.action != 'delete') {
            saved = await repository.updateItem(
              id: current['id'] as String,
              expectedUid: uid,
              expectedRevision: current['revision'] as int,
              title: write.title!,
              data: write.data!,
            );
          } else {
            _uncertainPersonalDeletes[write.sourceKey] = current;
            await repository.deleteItem(
              current['id'] as String,
              expectedUid: uid,
              expectedRevision: current['revision'] as int,
            );
          }
          if (!mounted ||
              generation != _personalGeneration ||
              uid != _verifiedPersonalUid) {
            return;
          }
          setState(() {
            _personalWriteGeneration++;
            _uncertainPersonalDeletes.remove(write.sourceKey);
            if (saved != null) {
              _personalItems.removeWhere(
                (item) => item['source_key'] == write.sourceKey,
              );
              _personalItems.add(saved);
            } else {
              _personalItems.removeWhere(
                (item) => item['source_key'] == write.sourceKey,
              );
            }
            if (identical(_pendingPersonalWrites[entry.key], write)) {
              _pendingPersonalWrites.remove(entry.key);
              _pendingPersonalItems.removeWhere(
                (item) =>
                    item['kind'] == write.kind &&
                    (item['data'] as Map?)?['id'] == write.sourceId,
              );
            }
          });
          if (write.deleteAfterCreate) {
            _enqueuePersonalWrite(
              _PersonalWorkspaceWrite(
                action: 'delete',
                kind: write.kind,
                sourceKey: write.sourceKey,
                sourceId: write.sourceId,
              ),
            );
          }
        } on _PersonalReconcileConflict catch (conflict) {
          if (mounted &&
              generation == _personalGeneration &&
              uid == _verifiedPersonalUid) {
            _showReconcileConflict(write, conflict.remote);
          }
          return;
        } on DioException catch (error) {
          if (error.response?.statusCode == 409) {
            final conflictWrite = write.action == 'reconcile'
                ? _reviewableRestore(entry.key, write)
                : write;
            await _reloadPersonalConflict(uid, generation, conflictWrite);
          } else if (mounted && generation == _personalGeneration) {
            setState(() {
              _personalError =
                  'A personal account change was not confirmed. Your local copy is unchanged; retry the account save.';
            });
          }
          return;
        } on Object {
          if (mounted && generation == _personalGeneration) {
            setState(() {
              _personalError =
                  'A personal account change was not confirmed. Your local copy is unchanged; retry the account save.';
            });
          }
          return;
        }
      }
      if (mounted && generation == _personalGeneration) {
        setState(() => _personalError = null);
      }
    } finally {
      _personalSaving = false;
      _inFlightPersonalWrite = null;
      if (mounted) {
        _publishWorkspaceSaveStatus();
        final nextUid = _verifiedPersonalUid;
        if (nextUid != null &&
            nextUid != uid &&
            _personalError == null &&
            _personalConflictSourceKey == null &&
            _pendingPersonalWrites.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && nextUid == _verifiedPersonalUid) {
              unawaited(
                _processPersonalWrites(
                  nextUid,
                  _personalGeneration,
                  ref.read(personalWorkspaceRepositoryProvider),
                ),
              );
            }
          });
        }
      }
    }
  }

  bool _samePersonalContent(
    Map<String, dynamic> record,
    _PersonalWorkspaceWrite write,
  ) =>
      record['title'] == write.title &&
      jsonEncode(record['data']) == jsonEncode(write.data);

  /// Turns a pending restore into an ordinary pending edit so the existing
  /// explicit conflict review decides whether it may replace the newer
  /// account version.
  _PersonalWorkspaceWrite _reviewableRestore(
    String key,
    _PersonalWorkspaceWrite write,
  ) {
    final reviewable = _PersonalWorkspaceWrite(
      action: 'update',
      kind: write.kind,
      sourceKey: write.sourceKey,
      sourceId: write.sourceId,
      title: write.title,
      data: write.data,
    );
    _uncertainPersonalDeletes.remove(write.sourceKey);
    if (identical(_pendingPersonalWrites[key], write)) {
      _pendingPersonalWrites[key] = reviewable;
    }
    return reviewable;
  }

  void _showReconcileConflict(
    _PersonalWorkspaceWrite write,
    Map<String, dynamic> remote,
  ) {
    setState(() {
      _reviewableRestore('${write.kind}:${write.sourceId}', write);
      _personalItems.removeWhere(
        (item) => item['source_key'] == write.sourceKey,
      );
      _personalItems.add(remote);
      _personalConflictSourceKey = write.sourceKey;
      _personalConflictReloadFailed = false;
      _personalError =
          'This account item changed elsewhere while its removal was being undone. Your restored copy is preserved; review the latest account version before choosing.';
    });
  }

  Future<void> _reloadPersonalConflict(
    String uid,
    int generation,
    _PersonalWorkspaceWrite write,
  ) async {
    if (mounted && generation == _personalGeneration) {
      setState(() {
        _personalConflictSourceKey = write.sourceKey;
        _personalConflictReloadFailed = true;
        _personalError =
            'This account item changed elsewhere. Your pending edit is preserved while the latest version is reloaded.';
      });
    }
    try {
      final items = await ref
          .read(personalWorkspaceRepositoryProvider)
          .listItems(expectedUid: uid);
      if (!mounted ||
          generation != _personalGeneration ||
          uid != _verifiedPersonalUid) {
        return;
      }
      setState(() {
        _personalItems = items;
        _personalConflictReloadFailed = false;
        _personalError =
            'The latest account version is loaded. Review it before choosing whether to keep your pending edit.';
      });
    } on Object {
      if (mounted &&
          generation == _personalGeneration &&
          uid == _verifiedPersonalUid) {
        setState(() {
          _personalConflictReloadFailed = true;
          _personalError =
              'The latest account version could not be loaded. Your pending edit is preserved; retry the reload before reconciling.';
        });
      }
    }
  }

  Future<void> _reloadPendingPersonalConflict() async {
    final sourceKey = _personalConflictSourceKey;
    final uid = _verifiedPersonalUid;
    if (sourceKey == null || uid == null) return;
    final write = _pendingPersonalWrites.values
        .where((item) => item.sourceKey == sourceKey)
        .firstOrNull;
    if (write == null) return;
    await _reloadPersonalConflict(uid, _personalGeneration, write);
  }

  Future<void> _reviewPersonalConflict() async {
    final sourceKey = _personalConflictSourceKey;
    if (sourceKey == null) return;
    final write = _pendingPersonalWrites.values
        .where((item) => item.sourceKey == sourceKey)
        .firstOrNull;
    if (write == null) return;
    final current = _personalItems
        .where((item) => item['source_key'] == sourceKey)
        .firstOrNull;
    final uid = _verifiedPersonalUid;
    if (uid == null) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review account version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              write.action == 'delete'
                  ? 'Your pending change: remove this account item.'
                  : 'Your pending edit: ${write.title ?? 'Updated item'}',
            ),
            const SizedBox(height: 12),
            if (current == null)
              const Text('The saved account copy no longer exists.')
            else
              Text(
                'Latest saved version (revision ${current['revision']}): '
                '${current['title']}',
              ),
            const SizedBox(height: 12),
            const Text(
              'Your pending edit remains available until you choose an option.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'account'),
            child: const Text('Use latest account version'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'pending'),
            child: Text(
              write.action == 'delete'
                  ? 'Remove latest account version'
                  : current == null
                  ? 'Restore my pending edit'
                  : 'Save my pending edit',
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted || uid != _verifiedPersonalUid) return;

    if (choice == 'account') {
      setState(() {
        _pendingPersonalWrites.remove('${write.kind}:${write.sourceId}');
        _pendingPersonalItems.removeWhere(
          (item) =>
              item['kind'] == write.kind &&
              (item['data'] as Map?)?['id'] == write.sourceId,
        );
        _personalConflictSourceKey = null;
        _personalConflictReloadFailed = false;
        _personalError = _pendingPersonalWrites.isEmpty
            ? null
            : 'Other account edits are still pending.';
      });
      _publishWorkspaceSaveStatus();
      return;
    }

    if (current == null && write.action == 'delete') {
      setState(() {
        _pendingPersonalWrites.remove('${write.kind}:${write.sourceId}');
        _pendingPersonalItems.removeWhere(
          (item) =>
              item['kind'] == write.kind &&
              (item['data'] as Map?)?['id'] == write.sourceId,
        );
        _personalConflictSourceKey = null;
        _personalConflictReloadFailed = false;
        _personalError = _pendingPersonalWrites.isEmpty
            ? null
            : 'Other account edits are still pending.';
      });
      _publishWorkspaceSaveStatus();
      return;
    }

    if (current == null) {
      try {
        final restored = await ref
            .read(personalWorkspaceRepositoryProvider)
            .importItems([
              {
                'kind': write.kind,
                'source_key': write.sourceKey,
                'title': write.title,
                'data': write.data,
              },
            ], expectedUid: uid);
        if (!mounted || uid != _verifiedPersonalUid) return;
        setState(() {
          _personalWriteGeneration++;
          _personalItems.removeWhere(
            (item) => item['source_key'] == write.sourceKey,
          );
          _personalItems.add(restored.single);
          _pendingPersonalWrites.remove('${write.kind}:${write.sourceId}');
          _pendingPersonalItems.removeWhere(
            (item) =>
                item['kind'] == write.kind &&
                (item['data'] as Map?)?['id'] == write.sourceId,
          );
          _personalConflictSourceKey = null;
          _personalConflictReloadFailed = false;
          _personalError = _pendingPersonalWrites.isEmpty
              ? null
              : 'Other account edits are still pending.';
        });
        _publishWorkspaceSaveStatus();
      } on Object {
        if (mounted) {
          setState(() {
            _personalError =
                'The pending edit could not be restored. It remains available; refresh account status before trying again.';
          });
          _publishWorkspaceSaveStatus();
        }
      }
      return;
    }

    setState(() {
      _personalConflictSourceKey = null;
      _personalConflictReloadFailed = false;
      _personalError = null;
    });
    _publishWorkspaceSaveStatus();
    await _retryPersonalWrites(sourceKey: sourceKey);
  }

  Future<void> _retryPersonalWrites({String? sourceKey}) async {
    final uid = _verifiedPersonalUid;
    if (!mounted || uid == null) return;
    if (_personalError != null) {
      setState(() => _personalError = null);
    }
    await _processPersonalWrites(
      uid,
      _personalGeneration,
      ref.read(personalWorkspaceRepositoryProvider),
      prioritySourceKey: sourceKey,
    );
  }

  String _personalTitle(String kind, Map<String, dynamic> item) =>
      kind == 'template'
      ? item['name'] as String? ?? 'Interact template'
      : item['title'] as String? ??
            (kind == 'knowledge' ? 'Knowledge item' : 'Interact session');

  String _personalSourceKey(String kind, String sourceId) {
    final key = '$kind:$sourceId';
    if (key.length > 128 || !RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(key)) {
      throw const FormatException(
        'This item has an unsupported local ID and cannot be saved to an account.',
      );
    }
    return key;
  }

  Future<bool> _flushPendingSave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    final operation = _saveOperation;
    if (operation != null) {
      return operation.then(
        (saved) => saved && _savedRevision == _dataRevision,
      );
    }
    final nextOperation = _writeLatestSnapshots(_store);
    _saveOperation = nextOperation;
    return nextOperation.whenComplete(() {
      if (identical(_saveOperation, nextOperation)) _saveOperation = null;
    });
  }

  Future<bool> _writeLatestSnapshots(GuestWorkspaceStore store) async {
    try {
      while (_savedRevision < _dataRevision) {
        final revision = _dataRevision;
        final snapshot = _data;
        if (snapshot == null) return false;
        await store.save(snapshot);
        _savedRevision = revision;
      }
      if (mounted && _savedRevision == _dataRevision) {
        setState(() {
          _saveStatus = 'Saved on this device';
          _unsavedChanges = false;
        });
      }
      if (mounted) _publishWorkspaceSaveStatus();
      return _savedRevision == _dataRevision;
    } on Object {
      if (mounted) {
        setState(() {
          _saveStatus = 'Unable to save locally';
          _unsavedChanges = true;
        });
        _publishWorkspaceSaveStatus();
      }
      return false;
    }
  }

  Future<bool> _saveBeforeLeaving() async {
    if (_data != null && !await _flushPendingSave()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to save local changes. Retry saving before leaving '
              'this workspace.',
            ),
          ),
        );
      }
      return false;
    }
    if (_personalConflictSourceKey != null) {
      _showPendingWorkspaceChanges();
      return false;
    }
    if (_pendingPersonalImport.isNotEmpty) {
      await _retryPersonalImport();
    }
    if (_pendingPersonalWrites.isNotEmpty) {
      await _retryPersonalWrites();
    }
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (mounted && _personalSaving && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (!_hasPendingWorkspaceChanges) return true;
    _showPendingWorkspaceChanges();
    return false;
  }

  void _showPendingWorkspaceChanges() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Finish or retry pending private account changes before leaving '
          'this workspace.',
        ),
      ),
    );
  }

  Future<void> _openGroupKnowledge(String groupId, String entryId) async {
    if (!await _saveBeforeLeaving() || !mounted) return;
    if (widget.onWorkspaceTabChanged != null) {
      context.push(
        '/guest/groups?groupId=${Uri.encodeQueryComponent(groupId)}'
        '&entryId=${Uri.encodeQueryComponent(entryId)}',
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SharedGuestGroupsPage(
          initialGroupId: groupId,
          initialEntryId: entryId,
        ),
      ),
    );
  }

  void _openSession(String id) {
    if (!mounted) return;
    setState(() => _openSessionId = id);
    widget.onSessionRouteChanged?.call(id);
  }

  void _closeSession() {
    if (!mounted || _openSessionId == null) return;
    setState(() => _openSessionId = null);
    widget.onSessionRouteChanged?.call(null);
  }

  void _closeAccountScopedDialogs() {
    final closers = _accountScopedDialogClosers.toList();
    _accountScopedDialogClosers.clear();
    for (final close in closers) {
      close();
    }
  }

  Map<String, dynamic>? _currentSessionSnapshot(String id) {
    final local = _data;
    if (local == null) return null;
    return _withPersonalWorkspace(
      local,
    ).sessions.where((item) => item['id'] == id).firstOrNull;
  }

  Future<void> _copySessionJson(Map<String, dynamic> session) async {
    final sessionId = session['id'];
    final uid = _verifiedPersonalUid;
    final generation = _personalGeneration;
    final isAccount = _storageStatus(
      'interact_session',
      session,
    ).startsWith('Personal account');
    VoidCallback? closeDialog;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        if (closeDialog == null) {
          final route = ModalRoute.of(dialogContext);
          final navigator = Navigator.of(dialogContext);
          closeDialog = () {
            if (route != null && route.isActive) {
              navigator.removeRoute(route, false);
            }
          };
          _accountScopedDialogClosers.add(closeDialog!);
        }
        return AlertDialog(
          title: const Text('Copy session JSON backup'),
          content: SingleChildScrollView(
            child: Text(
              'Copies only “${session['title'] ?? 'this session'}” as a JSON '
              'backup to your clipboard, including its participants, answers '
              'and follow-ups. Nothing is uploaded or shared. '
              '${isAccount ? 'This session is stored in your private account, so the full local JSON backup does not include it. ' : ''}'
              'It uses the local JSON backup format: “Import local JSON backup” '
              'previews it and only adds selected items whose ID is not already '
              'stored on this device.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Copy JSON'),
            ),
          ],
        );
      },
    );
    if (closeDialog != null) _accountScopedDialogClosers.remove(closeDialog);
    if (!mounted) return;
    final scopeUnchanged =
        uid == _verifiedPersonalUid && generation == _personalGeneration;
    if (confirmed != true && scopeUnchanged) return;
    final current = sessionId is String && scopeUnchanged
        ? _currentSessionSnapshot(sessionId)
        : null;
    final sameDestination =
        current != null &&
        _storageStatus(
              'interact_session',
              current,
            ).startsWith('Personal account') ==
            isAccount;
    if (!scopeUnchanged || !sameDestination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The account or session changed before copying. '
            'Nothing was copied.',
          ),
        ),
      );
      return;
    }
    final backup = GuestWorkspaceData(sessions: [current]).encodeBackup();
    try {
      await Clipboard.setData(ClipboardData(text: backup));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session JSON backup copied. Nothing was uploaded.'),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The session JSON backup could not be copied. Nothing was changed.',
          ),
        ),
      );
    }
  }

  void _handleWorkspaceTabChanged(int index) {
    final onChanged = widget.onWorkspaceTabChanged;
    if (onChanged == null) return;
    unawaited(() async {
      if (await _saveBeforeLeaving() && mounted) onChanged(index);
    }());
  }

  void _handleKnowledgeSectionChanged(KnowledgeSection section) {
    final onChanged = widget.onKnowledgeSectionChanged;
    if (onChanged == null) return;
    unawaited(() async {
      if (await _saveBeforeLeaving() && mounted) onChanged(section);
    }());
  }

  Future<void> _openSignIn({bool createAccount = false}) async {
    if (_data == null && _loadError == null) await _load();
    if (!mounted) return;
    if (!await _saveBeforeLeaving() || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SignInPage(createAccount: createAccount),
      ),
    );
  }

  Future<void> _openSharedGroups() async {
    if (!await _saveBeforeLeaving() || !mounted) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null && !user.isAnonymous && !user.emailVerified) {
      final signIn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verify your email to use Groups'),
          content: const Text(
            'Check your email for the verification link. After verifying, '
            'sign in again to access Groups. No new account is needed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      );
      if (signIn == true && mounted) await _openSignIn();
      return;
    }
    if (!isVerifiedRegisteredFirebaseUser(user)) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create an account to use Groups'),
          content: const Text(
            'Groups require a registered account with a verified email. '
            'Your local Knowledge, Interact sessions, and drafts stay on this '
            'device and are not uploaded by creating an account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'sign-in'),
              child: const Text('Already have an account? Sign in'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'create-account'),
              child: const Text('Create an account'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == 'sign-in') {
        await _openSignIn();
      } else if (action == 'create-account') {
        await _openSignIn(createAccount: true);
      }
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SharedGuestGroupsPage()),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text('Your local work stays on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      if (!await _saveBeforeLeaving() || !mounted) return;
      try {
        await ref.read(firebaseAuthProvider).signOut();
        _personalGeneration++;
        _closeAccountScopedDialogs();
        if (mounted) {
          setState(() {
            _personalItems = [];
            _pendingPersonalItems = [];
            _pendingPersonalWrites.clear();
            _uncertainPersonalDeletes.clear();
            _pendingPersonalImport = [];
            _personalImportNeedsReselection = false;
            _personalConflictSourceKey = null;
            _personalConflictReloadFailed = false;
            _personalError = null;
            _personalOwnerUid = null;
          });
          _publishWorkspaceSaveStatus();
        }
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to sign out right now. Your local work remains on this device.',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _clearLocalCopy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this device’s local work?'),
        content: const Text(
          'This permanently removes this browser’s local copy. '
          'Group content is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my work'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear local copy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final hadUnpersistedWork = _savedRevision < _dataRevision;
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    final pendingSave = _saveOperation;
    if (pendingSave != null) await pendingSave;
    try {
      await _store.clear();
    } on Object {
      if (mounted) {
        if (hadUnpersistedWork) {
          setState(() {
            _saveStatus = 'Unable to save locally';
            _unsavedChanges = true;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to clear the local copy. Your current work was kept.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _data = const GuestWorkspaceData();
      _dataRevision++;
      _saveStatus = 'Saving locally…';
    });
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: 250),
      _flushPendingSave,
    );
  }

  Future<void> _copyLocalBackup() async {
    final data = _data;
    if (data == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy local JSON backup?'),
        content: Text(
          'The backup includes local Knowledge, participant names, answers, '
          'follow-ups and templates. It is copied to this device’s clipboard; '
          'nothing is uploaded.'
          '${_verifiedPersonalUid != null ? ' Items stored only in your private account are not included; use “Copy session JSON backup” in a session for an account-only session.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Copy backup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final saved = !_unsavedChanges && await _flushPendingSave();
    final latest = _data;
    if (latest == null) return;
    final backupRevision = _dataRevision;
    try {
      await Clipboard.setData(ClipboardData(text: latest.encodeBackup()));
    } on Object {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to copy the local JSON backup.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved && backupRevision == _dataRevision
              ? 'Local JSON backup copied to clipboard.'
              : 'Latest local JSON backup copied to clipboard. Local changes are still not saved on this device; retry saving.',
        ),
      ),
    );
  }

  bool _hasMeaningfulWork(GuestWorkspaceData data) =>
      data.knowledge.isNotEmpty ||
      data.sessions.isNotEmpty ||
      data.templates.isNotEmpty;

  Future<void> _openPersonalImport() async {
    final uid = _verifiedPersonalUid;
    final local = _data;
    if (uid == null || local == null) return;
    if (!_hasMeaningfulWork(local)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is no local work to import.')),
      );
      return;
    }
    if (_unsavedChanges || !await _flushPendingSave()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Save local changes on this device before selecting an account import.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted || uid != _verifiedPersonalUid) return;
    final selection = await showDialog<_GuestImportSelection>(
      context: context,
      builder: (context) => _GuestImportPreview(
        data: local,
        title: 'Import local work into your personal account',
        confirmLabel: 'Import selected work',
        includeTemplates: true,
        personalAccountImport: true,
      ),
    );
    if (selection == null || !mounted || uid != _verifiedPersonalUid) return;
    final selected = <Map<String, dynamic>>[];
    void addItems(
      String kind,
      List<Map<String, dynamic>> items,
      Set<String> selectedIds,
    ) {
      for (final item in items) {
        if (!selectedIds.contains(item['id'])) continue;
        final sourceId = item['id'];
        if (sourceId is! String) continue;
        selected.add({
          'kind': kind,
          'source_key': _personalSourceKey(kind, sourceId),
          'title': _personalTitle(kind, item),
          'data': item,
        });
      }
    }

    try {
      addItems('knowledge', local.knowledge, selection.knowledgeIds);
      addItems('interact_session', local.sessions, selection.sessionIds);
      addItems('template', local.templates, selection.templateIds);
    } on FormatException catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
      return;
    }
    if (selected.isEmpty) return;
    _pendingPersonalImport = selected;
    _personalImportNeedsReselection = false;
    _publishWorkspaceSaveStatus();
    await _submitPersonalImport(uid, _personalGeneration);
  }

  Future<void> _retryPersonalImport() async {
    final uid = _verifiedPersonalUid;
    if (uid == null || _pendingPersonalImport.isEmpty) return;
    await _submitPersonalImport(uid, _personalGeneration);
  }

  Future<void> _submitPersonalImport(String uid, int generation) async {
    if (_personalImportSaving) return;
    final payload = _pendingPersonalImport;
    _personalImportSaving = true;
    _publishWorkspaceSaveStatus();
    try {
      final items = await ref
          .read(personalWorkspaceRepositoryProvider)
          .importItems(payload, expectedUid: uid);
      if (!mounted ||
          uid != _verifiedPersonalUid ||
          generation != _personalGeneration) {
        return;
      }
      setState(() {
        for (final item in items) {
          _personalItems.removeWhere(
            (existing) => existing['source_key'] == item['source_key'],
          );
          _personalItems.add(item);
        }
        _pendingPersonalImport = [];
        _personalImportNeedsReselection = false;
        _personalError = null;
      });
      _publishWorkspaceSaveStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selected work is available in your personal account. Local copies remain on this device.',
          ),
        ),
      );
    } on DioException catch (error) {
      if (!mounted ||
          uid != _verifiedPersonalUid ||
          generation != _personalGeneration) {
        return;
      }
      if ({413, 422}.contains(error.response?.statusCode)) {
        setState(() {
          _pendingPersonalImport = [];
          _personalImportNeedsReselection = true;
          _personalError =
              'This selection exceeds account import limits or contains invalid content. Select fewer items or smaller items and try again. Your local originals are unchanged.';
        });
        _publishWorkspaceSaveStatus();
        return;
      }
      setState(() {
        _personalError =
            'The account import was not confirmed. Local copies remain on this device; retry safely.';
      });
      _publishWorkspaceSaveStatus();
    } on Object {
      if (!mounted ||
          uid != _verifiedPersonalUid ||
          generation != _personalGeneration) {
        return;
      }
      setState(() {
        _personalError =
            'The account import was not confirmed. Local copies remain on this device; retry safely.';
      });
      _publishWorkspaceSaveStatus();
    } finally {
      if (mounted &&
          uid == _verifiedPersonalUid &&
          generation == _personalGeneration) {
        _personalImportSaving = false;
        _publishWorkspaceSaveStatus();
      }
    }
  }

  Future<void> _importLocalBackup() async {
    try {
      final source = await showDialog<String>(
        context: context,
        builder: (context) => _GuestBackupInputDialog(
          initialJson: _pendingImportJson ?? '',
          onChanged: (value) => _pendingImportJson = value,
        ),
      );
      if (source == null || !mounted) return;
      late final GuestWorkspaceData imported;
      try {
        imported = GuestWorkspaceData.decodeBackup(source);
      } on FormatException catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This is not a valid IntQAFlow local JSON backup. ${error.message}',
            ),
          ),
        );
        return;
      }
      final selection = await showDialog<_GuestImportSelection>(
        context: context,
        builder: (context) => _GuestImportPreview(
          data: imported,
          title: 'Preview local backup import',
          confirmLabel: 'Import selected locally',
        ),
      );
      if (selection == null || !mounted) return;
      final current = _data;
      if (current != null && (_unsavedChanges || !await _flushPendingSave())) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The import was cancelled because current local changes are not saved. Retry saving first.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      final importRevision = _dataRevision;
      final store = _store;
      late final GuestWorkspaceData merged;
      try {
        merged = await store.importSelected(
          imported: imported,
          knowledgeIds: selection.knowledgeIds,
          sessionIds: selection.sessionIds,
          templateIds: selection.templateIds,
        );
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to import the selected backup. Your current work was kept.',
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      if (_dataRevision != importRevision) return;
      setState(() {
        _data = merged;
        _dataRevision++;
        _savedRevision = _dataRevision;
        _saveStatus = 'Saved on this device';
        _unsavedChanges = false;
        _loadError = null;
      });
      _pendingImportJson = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected backup items imported locally.'),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The backup could not be imported. Your current local work was kept.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localData = _data;
    final data = localData == null ? null : _withPersonalWorkspace(localData);
    final groupIdentity = widget.firebaseReady
        ? ref.watch(authStateProvider).value ??
              ref.read(firebaseAuthProvider).currentUser
        : null;
    final canUseGroups =
        widget.firebaseReady && isVerifiedRegisteredFirebaseUser(groupIdentity);
    final guestGroupsState = canUseGroups
        ? ref.watch(currentGuestGroupsProvider)
        : null;
    final viewport = MediaQuery.sizeOf(context);
    final compactViewport = viewport.height < 300;
    final narrowViewport = viewport.width < 420;
    final workspaceNotices = <Widget>[
      if (_unsavedChanges)
        MaterialBanner(
          forceActionsBelow: narrowViewport,
          content: const Text(
            'Your changes are not saved. Keep this page open and retry.',
          ),
          actions: [
            TextButton(
              onPressed: _flushPendingSave,
              child: const Text('Retry saving'),
            ),
          ],
        ),
      if (widget.authUnavailable)
        const _AccountMembershipNotice(
          text:
              'Account status could not be verified. This workspace is local; organisation access is not assumed.',
        ),
      if (_verifiedPersonalUid != null &&
          localData != null &&
          _hasMeaningfulWork(localData))
        MaterialBanner(
          forceActionsBelow: narrowViewport,
          content: const Text(
            'This personal account is private to your verified identity. Local browser work remains separate until you choose items to import.',
          ),
          actions: [
            TextButton(
              onPressed: _personalSaving || _personalLoading
                  ? null
                  : _openPersonalImport,
              child: const Text('Import local work'),
            ),
          ],
        ),
      if (_personalError != null)
        MaterialBanner(
          forceActionsBelow: narrowViewport,
          content: Text(_personalError!),
          actions: [
            TextButton(
              onPressed: _personalImportNeedsReselection
                  ? _openPersonalImport
                  : _personalConflictSourceKey != null
                  ? _personalConflictReloadFailed
                        ? _reloadPendingPersonalConflict
                        : _reviewPersonalConflict
                  : _pendingPersonalImport.isNotEmpty
                  ? _retryPersonalImport
                  : _pendingPersonalWrites.isNotEmpty
                  ? _retryPersonalWrites
                  : _refreshPersonalWorkspace,
              child: Text(
                _personalImportNeedsReselection
                    ? 'Change selection'
                    : _personalConflictSourceKey != null
                    ? _personalConflictReloadFailed
                          ? 'Reload account version'
                          : 'Review account change'
                    : _pendingPersonalImport.isNotEmpty
                    ? 'Retry import'
                    : _pendingPersonalWrites.isNotEmpty
                    ? 'Retry account save'
                    : 'Retry account load',
              ),
            ),
          ],
        ),
      if (widget.membershipStatus == AccountMembershipStatus.noMembership)
        const _AccountMembershipNotice(
          text:
              'This signed-in account has no organisation membership. Groups require a verified registered account, but do not require organisation membership.',
        ),
      if (widget.membershipStatus == AccountMembershipStatus.inactive)
        const _AccountMembershipNotice(
          text:
              'This organisation membership is inactive. You can continue local work; contact your organisation administrator about access.',
        ),
      if (widget.membershipStatus == AccountMembershipStatus.unavailable)
        const _AccountMembershipNotice(
          text:
              'Organisation membership could not be verified. You can continue local work, but no organisation access is assumed.',
        ),
      if (widget.firebaseReady &&
          _hasSignedInNonGuestUser &&
          !widget.sharedIdentityActive)
        Padding(
          padding: const EdgeInsets.all(12),
          child: canUseGroups
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: _GuestInfoButton(
                    tooltip: 'Group identity information',
                    title: 'About Group identity',
                    content:
                        'Group access is associated with this signed-in verified identity. A separate account does not inherit its Group data.',
                  ),
                )
              : const Text(
                  'Verify this account’s email before using Groups. Local work remains available, and organisation membership is not required for Groups.',
                ),
        ),
      if (guestGroupsState?.hasError == true)
        MaterialBanner(
          forceActionsBelow: narrowViewport,
          content: const Text(
            'Existing group access could not be checked. This does not confirm that no groups are linked.',
          ),
          actions: [
            TextButton(
              onPressed: () => ref.invalidate(currentGuestGroupsProvider),
              child: const Text('Retry groups'),
            ),
          ],
        ),
      if (_loadError != null)
        MaterialBanner(
          forceActionsBelow: narrowViewport,
          content: Text(_loadError!),
          actions: [TextButton(onPressed: _load, child: const Text('Retry'))],
        ),
    ];
    return PopScope(
      canPop: !_hasPendingWorkspaceChanges && _openSessionId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_openSessionId != null) {
          _closeSession();
        } else if (_hasPendingWorkspaceChanges) {
          _showPendingWorkspaceChanges();
        }
      },
      child: DefaultTabController(
        length: 2,
        initialIndex: widget.initialWorkspaceTab,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: !_hasSignedInNonGuestUser ? 48 : kToolbarHeight,
            title: viewport.width < 320
                ? null
                : Row(
                    children: [
                      Flexible(
                        child: Text(
                          _verifiedPersonalUid != null
                              ? 'Personal workspace'
                              : _hasSignedInNonGuestUser
                              ? 'Registered local workspace'
                              : 'Guest workspace',
                          style: !_hasSignedInNonGuestUser
                              ? Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                )
                              : null,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _GuestNotice(
                        isRegistered: _hasSignedInNonGuestUser,
                        saveStatus: _saveStatus,
                      ),
                    ],
                  ),
            actions: [
              if (viewport.width < 320)
                _GuestNotice(
                  isRegistered: _hasSignedInNonGuestUser,
                  saveStatus: _saveStatus,
                ),
              if (compactViewport)
                Builder(
                  builder: (context) => PopupMenuButton<int>(
                    tooltip: 'Switch Knowledge or Interact',
                    onSelected: (index) {
                      if (widget.onWorkspaceTabChanged != null) {
                        _handleWorkspaceTabChanged(index);
                      } else {
                        DefaultTabController.of(context).animateTo(index);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 0, child: Text('Knowledge')),
                      PopupMenuItem(value: 1, child: Text('Interact')),
                    ],
                  ),
                ),
              _accountMenu(),
              PopupMenuButton<String>(
                tooltip: _hasSignedInNonGuestUser
                    ? 'Workspace options'
                    : 'Guest workspace options',
                onSelected: (value) {
                  if (value == 'clear') _clearLocalCopy();
                  if (value == 'backup') _copyLocalBackup();
                  if (value == 'import') _importLocalBackup();
                  if (value == 'account-import') _openPersonalImport();
                  if (value == 'groups') _openSharedGroups();
                },
                itemBuilder: (context) => [
                  if (widget.firebaseReady)
                    const PopupMenuItem(value: 'groups', child: Text('Groups')),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'backup',
                    child: Text('Copy local JSON backup'),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: Text('Import local JSON backup'),
                  ),
                  if (_verifiedPersonalUid != null)
                    const PopupMenuItem(
                      value: 'account-import',
                      child: Text('Import local work into my account'),
                    ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'clear',
                    child: Text(
                      _hasSignedInNonGuestUser
                          ? 'Clear local copy on this device'
                          : 'Clear local guest copy',
                    ),
                  ),
                ],
              ),
            ],
            bottom: compactViewport
                ? null
                : TabBar(
                    onTap: _handleWorkspaceTabChanged,
                    tabs: [
                      Tab(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Flexible(
                              child: Text(
                                'Knowledge',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _knowledgeInfoButton,
                          ],
                        ),
                      ),
                      Tab(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Flexible(
                              child: Text(
                                'Interact',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _interactInfoButton(_verifiedPersonalUid != null),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          body: data == null
              ? Center(
                  child: _loadError == null
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_loadError!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _isLoading ? null : _load,
                                icon: const Icon(Icons.refresh),
                                label: Text(
                                  _isLoading ? 'Retrying…' : 'Retry loading',
                                ),
                              ),
                            ],
                          ),
                        ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final scrollNotices = workspaceNotices.length > 1;
                    final noticeHeight = (constraints.maxHeight * 0.45)
                        .clamp(0.0, 220.0)
                        .toDouble();
                    return Column(
                      children: [
                        if (scrollNotices)
                          SizedBox(
                            height: noticeHeight,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: workspaceNotices,
                              ),
                            ),
                          )
                        else
                          ...workspaceNotices,
                        Expanded(
                          child: TabBarView(
                            children: [
                              _GuestKnowledgeTab(
                                items: data.knowledge,
                                initialKnowledgeItemId:
                                    widget.initialKnowledgeItemId,
                                initialKnowledgeSection:
                                    widget.initialKnowledgeSection,
                                onKnowledgeSectionChanged:
                                    _handleKnowledgeSectionChanged,
                                onOpenGroup: _openGroupKnowledge,
                                privateWorkspace: _verifiedPersonalUid != null,
                                searchIdentityKey: _verifiedPersonalUid == null
                                    ? null
                                    : '${_verifiedPersonalUid!}:${widget.membershipStatus?.name ?? AccountMembershipStatus.unavailable.name}',
                                searchOrganization: null,
                                searchPersonal: _verifiedPersonalUid == null
                                    ? null
                                    : (query) => ref
                                          .read(
                                            personalWorkspaceRepositoryProvider,
                                          )
                                          .searchKnowledge(
                                            query,
                                            expectedUid: _verifiedPersonalUid!,
                                          ),
                                searchGroups: _verifiedPersonalUid == null
                                    ? null
                                    : (query) => ref
                                          .read(guestGroupRepositoryProvider)
                                          .searchKnowledge(query),
                                reloadPersonalWorkspace:
                                    _refreshPersonalWorkspace,
                                storageStatus: (item) =>
                                    _storageStatus('knowledge', item),
                                isPersonalAccount: (item) => _storageStatus(
                                  'knowledge',
                                  item,
                                ).startsWith('Personal account'),
                                onCreate: (item) => _createWorkspaceItem(
                                  kind: 'knowledge',
                                  item: item,
                                  updated: data.copyWith(
                                    knowledge: [item, ...data.knowledge],
                                  ),
                                ),
                                onUpdate: (item) => _save(
                                  data.copyWith(
                                    knowledge: [
                                      for (final current in data.knowledge)
                                        current['id'] == item['id']
                                            ? item
                                            : current,
                                    ],
                                  ),
                                ),
                                onDelete: (id) => _deleteKnowledge(data, id),
                              ),
                              _GuestInteractTab(
                                data: data,
                                privateWorkspace: _verifiedPersonalUid != null,
                                storageStatus: _storageStatus,
                                onChange: _save,
                                onCreateItem: (kind, item, updated) =>
                                    _createWorkspaceItem(
                                      kind: kind,
                                      item: item,
                                      updated: updated,
                                    ),
                                onPrint: _printReport,
                                localSaveStatus: _saveStatus,
                                openSessionId: _openSessionId,
                                sessionLoading:
                                    _personalLoading ||
                                    (_verifiedPersonalUid != null &&
                                        _personalLoadedUid !=
                                            _verifiedPersonalUid),
                                onOpenSession: _openSession,
                                onCloseSession: _closeSession,
                                onCopySessionJson: _copySessionJson,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _deleteKnowledge(GuestWorkspaceData data, String id) async {
    final removed = data.knowledge
        .where((item) => item['id'] == id)
        .firstOrNull;
    if (removed == null) return;
    final isPersonal = _storageStatus(
      'knowledge',
      removed,
    ).startsWith('Personal account');
    _save(
      data.copyWith(
        knowledge: data.knowledge.where((item) => item['id'] != id).toList(),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPersonal
              ? 'Personal account copy removal queued. Any local copy remains '
                    'on this device.'
              : 'Local Knowledge item removed.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final current = _data ?? data;
            _save(current.copyWith(knowledge: [removed, ...current.knowledge]));
          },
        ),
      ),
    );
  }

  Future<void> _printReport(
    Map<String, dynamic> session,
    String? participantId,
  ) async {
    final participants = (session['participants'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final hasDuplicateParticipantIds = duplicateGuestParticipantIds(
      session,
    ).isNotEmpty;
    final matchingParticipantId =
        participants.any((participant) => participant['id'] == participantId)
        ? participantId
        : participants.firstOrNull?['id'] as String?;
    final selectedParticipantId = hasDuplicateParticipantIds
        ? null
        : matchingParticipantId;
    final selectedParticipantName =
        participants
                .where(
                  (participant) => participant['id'] == selectedParticipantId,
                )
                .firstOrNull?['name']
            as String? ??
        (hasDuplicateParticipantIds
            ? 'Unavailable (duplicate participant IDs)'
            : 'Not selected');
    final storageDescription =
        _storageStatus(
          'interact_session',
          session,
        ).startsWith('Personal account')
        ? 'Stored in your personal account'
        : 'Stored locally on this device';
    final allParticipants = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export session PDF'),
        content: Text(
          '$storageDescription. Choose the participant scope to preview '
          'before exporting. Current participant: $selectedParticipantName.',
        ),
        actions: [
          TextButton(
            onPressed: hasDuplicateParticipantIds
                ? null
                : () => Navigator.pop(context, false),
            child: Text(
              hasDuplicateParticipantIds
                  ? 'Selected participant unavailable'
                  : 'Selected participant',
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('All participants'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (allParticipants == null || !mounted) return;
    final report = composeGuestReport(
      session: session,
      allParticipants: allParticipants,
      participantId: selectedParticipantId,
      exportedAt: DateTime.now().toUtc(),
    );
    await showDialog<void>(
      context: context,
      builder: (context) => _GuestReportPreviewDialog(
        report: report,
        onDownload: () => _downloadPdf(
          report,
          session,
          allParticipants,
          selectedParticipantId,
        ),
        onShare: () =>
            _sharePdf(report, session, allParticipants, selectedParticipantId),
        onPrintFallback: () => openPrintableReport(
          buildGuestReportDocument(
            session: session,
            allParticipants: allParticipants,
            participantId: selectedParticipantId,
            generatedAt: report.exportedAt,
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _makePdf(GuestReportData report) =>
      buildGuestReportPdf(report);

  Future<void> _downloadPdf(
    GuestReportData report,
    Map<String, dynamic> session,
    bool allParticipants,
    String? participantId,
  ) async {
    try {
      final status = await _downloadPdfOrShareFile(
        await _makePdf(report),
        guestReportFilename(report),
      );
      if (status == ShareResultStatus.dismissed) return;
      if (status == ShareResultStatus.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                kIsWeb
                    ? 'Browser PDF download was requested. If no file appears, use Browser print / Save PDF.'
                    : 'Choose a destination in the system sheet to save the PDF.',
              ),
            ),
          );
        }
        return;
      }
      if (mounted) {
        await _showPdfFallback(report, session, allParticipants, participantId);
      }
    } on UnsupportedPdfCharactersException {
      if (mounted) {
        _showPdfFontFallbackNotice(context);
        if (kIsWeb) {
          await _showPdfFallback(
            report,
            session,
            allParticipants,
            participantId,
          );
        }
      }
    } on Object {
      if (mounted) {
        await _showPdfFallback(report, session, allParticipants, participantId);
      }
    }
  }

  Future<void> _sharePdf(
    GuestReportData report,
    Map<String, dynamic> session,
    bool allParticipants,
    String? participantId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share a PDF copy?'),
        content: const Text(
          'Recipients can keep or forward this PDF. Removing their group access later cannot revoke a copy they downloaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final bytes = await _makePdf(report);
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Share Interact PDF',
          text: 'Portable PDF copy. Recipients may retain or forward it.',
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: [guestReportFilename(report)],
          downloadFallbackEnabled: false,
          sharePositionOrigin: origin,
        ),
      );
      if (result.status == ShareResultStatus.dismissed) return;
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        if (mounted) {
          await _showPdfFallback(
            report,
            session,
            allParticipants,
            participantId,
          );
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF sharing was opened.')),
        );
      }
    } on UnsupportedPdfCharactersException {
      if (mounted) {
        _showPdfFontFallbackNotice(context);
        if (kIsWeb) {
          await _showPdfFallback(
            report,
            session,
            allParticipants,
            participantId,
          );
        }
      }
    } on Object {
      if (mounted) {
        await _showPdfFallback(report, session, allParticipants, participantId);
      }
    }
  }

  Future<void> _showPdfFallback(
    GuestReportData report,
    Map<String, dynamic> session,
    bool allParticipants,
    String? participantId,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF action unavailable'),
        content: const Text(
          'Direct download saves a PDF file. Browser print opens the report in a new tab; choose Print → Save as PDF in your browser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'print'),
            child: const Text('Browser print / Save PDF'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'download'),
            child: const Text('Try direct PDF download'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'print') {
      openPrintableReport(
        buildGuestReportDocument(
          session: session,
          allParticipants: allParticipants,
          participantId: participantId,
          generatedAt: report.exportedAt,
        ),
      );
    } else if (action == 'download') {
      try {
        final status = await _downloadPdfOrShareFile(
          await _makePdf(report),
          guestReportFilename(report),
        );
        if (status == ShareResultStatus.dismissed) return;
        if (status == ShareResultStatus.success && mounted && kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Browser PDF download was requested. If no file appears, use Browser print / Save PDF.',
              ),
            ),
          );
        } else if (status != ShareResultStatus.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Direct download is unavailable on this device. Use the print fallback.',
              ),
            ),
          );
        }
      } on UnsupportedPdfCharactersException {
        if (mounted) {
          _showPdfFontFallbackNotice(context);
          if (kIsWeb) {
            openPrintableReport(
              buildGuestReportDocument(
                session: session,
                allParticipants: allParticipants,
                participantId: participantId,
                generatedAt: report.exportedAt,
              ),
            );
          }
        }
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF download could not be started.')),
          );
        }
      }
    }
  }

  bool get _hasSignedInNonGuestUser {
    final user = _currentAccountUser;
    return user != null && !user.isAnonymous;
  }

  User? get _currentAccountUser {
    if (widget.accountUser != null) return widget.accountUser;
    if (!widget.firebaseReady) return null;
    return ref.read(firebaseAuthProvider).currentUser;
  }

  Widget _accountMenu() {
    final user = _currentAccountUser;
    final email = user?.email;
    final registered = user != null && !user.isAnonymous;
    final String stateText;
    final String explanation;
    if (widget.authUnavailable) {
      stateText = 'Account status unavailable';
      explanation =
          'Sign-in status could not be checked. No organisation access is assumed; local work remains on this device.';
    } else if (registered) {
      stateText = switch (widget.membershipStatus) {
        AccountMembershipStatus.noMembership => 'No organisation membership',
        AccountMembershipStatus.inactive => 'Organisation membership inactive',
        AccountMembershipStatus.unavailable =>
          'Organisation membership unavailable',
        _ => 'Registered personal account',
      };
      explanation = switch (widget.membershipStatus) {
        AccountMembershipStatus.noMembership =>
          'An account does not create an organisation membership. Groups '
              'require a verified registered account but do not require '
              'organisation membership.',
        AccountMembershipStatus.inactive =>
          'Organisation access is inactive. Local work remains on this device.',
        AccountMembershipStatus.unavailable =>
          'Organisation access could not be verified. No organisation access is being assumed.',
        _ =>
          'This registered personal account is separate from the local '
              'copy on this device. Importing local work is optional; organisation '
              'and group access remain separate.',
      };
    } else {
      stateText = 'Local guest workspace';
      explanation =
          'This is a local workspace. Knowledge, Interact sessions, answers, '
          'and templates stay in this browser until you choose items to import '
          'to a verified personal account or explicitly share selected copies '
          'with a group.';
    }

    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (action) {
        if (action == 'sign-in')
          _openSignIn();
        else if (action == 'create-account') {
          _openSignIn(createAccount: true);
        } else if (action == 'retry-account') {
          widget.onRetryAccount?.call();
        } else if (action == 'sign-out') {
          _signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stateText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (email != null) Text(email),
                Text(explanation),
              ],
            ),
          ),
        ),
        if (!registered && widget.firebaseReady) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'sign-in',
            child: Text('Already have an account? Sign in'),
          ),
          const PopupMenuItem(
            value: 'create-account',
            child: Text('Create account'),
          ),
        ],
        if (widget.onRetryAccount != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'retry-account',
            child: Text('Retry account check'),
          ),
        ],
        if (registered) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
        ],
      ],
      child: MediaQuery.sizeOf(context).width < 380
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.account_circle_outlined),
            )
          : const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_circle_outlined),
                  SizedBox(width: 4),
                  Text('Account'),
                ],
              ),
            ),
    );
  }
}

class _GuestNotice extends StatelessWidget {
  const _GuestNotice({required this.isRegistered, required this.saveStatus});

  final bool isRegistered;
  final String saveStatus;

  @override
  Widget build(BuildContext context) {
    final status = isRegistered
        ? 'Registered personal account · Local copy · $saveStatus'
        : 'Guest workspace · $saveStatus';
    final explanation = isRegistered
        ? 'Registered workspace. Local drafts stay in this browser profile '
              'and may be visible to people using it. This local copy is separate '
              'from your personal account. Importing selected items to your account '
              'is optional. Group and organisation access are separate.'
        : 'Guest workspace active in this browser profile. People using this '
              'profile can see its local work. Groups require a registered '
              'account with a verified email. Clearing browser data or losing '
              'this device can erase local work.';
    return _GuestInfoButton(
      tooltip: 'Workspace storage information',
      title: 'About this workspace',
      content: '$status\n\n$explanation',
    );
  }
}

const _knowledgeInfoButton = _GuestInfoButton(
  tooltip: 'Search help',
  title: 'About Knowledge search',
  content:
      'Search local Knowledge on this device and all '
      'personal-account Knowledge in your account, plus authorised '
      'organisation and Group Knowledge when available. Only your '
      'query is sent to those services; local content is never '
      'uploaded by search.',
);

Widget _interactInfoButton(bool privateWorkspace) => _GuestInfoButton(
  tooltip: 'Interact privacy information',
  title: 'About Interact storage',
  content: privateWorkspace
      ? 'New sessions are private to your account. Imported '
            'sessions and their edits stay in your personal '
            'account; group sharing is separate.'
      : 'New sessions stay on this device unless you explicitly '
            'import them. Imported sessions and their edits stay '
            'in your personal account; group sharing is separate.',
);

class _GuestInfoButton extends StatelessWidget {
  const _GuestInfoButton({
    required this.tooltip,
    required this.title,
    required this.content,
  });

  final String tooltip;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
    icon: const Icon(Icons.info_outline, size: 16),
  );
}

class _AccountMembershipNotice extends StatelessWidget {
  const _AccountMembershipNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Text(text),
  );
}

class _UnifiedKnowledgeSearchHit {
  const _UnifiedKnowledgeSearchHit({
    required this.id,
    required this.title,
    required this.source,
    required this.method,
    required this.relevance,
    required this.snippet,
    required this.icon,
    required this.onTap,
    this.storageStatus,
  });

  final String id;
  final String title;
  final String source;
  final String method;
  final double relevance;
  final String? snippet;
  final IconData icon;
  final VoidCallback onTap;
  final String? storageStatus;
}

class _GuestKnowledgeTab extends StatefulWidget {
  const _GuestKnowledgeTab({
    required this.items,
    required this.privateWorkspace,
    required this.initialKnowledgeSection,
    required this.onKnowledgeSectionChanged,
    required this.onOpenGroup,
    this.initialKnowledgeItemId,
    required this.searchIdentityKey,
    required this.searchOrganization,
    required this.searchPersonal,
    required this.searchGroups,
    required this.reloadPersonalWorkspace,
    required this.storageStatus,
    required this.isPersonalAccount,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> items;
  final bool privateWorkspace;
  final KnowledgeSection initialKnowledgeSection;
  final ValueChanged<KnowledgeSection>? onKnowledgeSectionChanged;
  final Future<void> Function(String, String) onOpenGroup;
  final String? initialKnowledgeItemId;
  final String? searchIdentityKey;
  final Future<List<SemanticSearchResult>> Function(String)? searchOrganization;
  final Future<Map<String, dynamic>> Function(String)? searchPersonal;
  final Future<Map<String, dynamic>> Function(String)? searchGroups;
  final Future<void> Function() reloadPersonalWorkspace;
  final String Function(Map<String, dynamic>) storageStatus;
  final bool Function(Map<String, dynamic>) isPersonalAccount;
  final ValueChanged<Map<String, dynamic>> onCreate;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final ValueChanged<String> onDelete;

  @override
  State<_GuestKnowledgeTab> createState() => _GuestKnowledgeTabState();
}

class _GuestKnowledgeTabState extends State<_GuestKnowledgeTab> {
  final _formKey = GlobalKey<FormState>();
  final _query = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _answer = TextEditingController();
  final _titleFocus = FocusNode();
  Timer? _searchTimer;
  int _searchGeneration = 0;
  List<SemanticSearchResult> _organizationResults = [];
  List<Map<String, dynamic>> _personalResults = [];
  List<Map<String, dynamic>> _groupResults = [];
  bool _organizationSearchFailed = false;
  bool _organizationSearchPartial = false;
  bool _personalSearchFailed = false;
  bool _groupSearchFailed = false;
  bool _personalSearchPartial = false;
  bool _groupSearchPartial = false;
  bool _remoteSearchLoading = false;
  bool _showSavedQuestions = false;

  @override
  void initState() {
    super.initState();
    _selectedKnowledgeItemId = widget.initialKnowledgeItemId;
    _showSavedQuestions =
        widget.initialKnowledgeSection == KnowledgeSection.questions ||
        widget.initialKnowledgeItemId != null;
  }

  String? _selectedKnowledgeItemId;

  void _selectKnowledgeSection(KnowledgeSection section) {
    setState(() {
      _showSavedQuestions = section == KnowledgeSection.questions;
      _selectedKnowledgeItemId = null;
    });
    widget.onKnowledgeSectionChanged?.call(section);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _query.dispose();
    _title.dispose();
    _body.dispose();
    _answer.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _GuestKnowledgeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchIdentityKey == widget.searchIdentityKey &&
        (oldWidget.searchOrganization != null) ==
            (widget.searchOrganization != null) &&
        (oldWidget.searchPersonal != null) == (widget.searchPersonal != null) &&
        (oldWidget.searchGroups != null) == (widget.searchGroups != null)) {
      return;
    }
    _searchGeneration++;
    _searchTimer?.cancel();
    _organizationResults = [];
    _personalResults = [];
    _groupResults = [];
    _selectedKnowledgeItemId = null;
    _organizationSearchFailed = false;
    _organizationSearchPartial = false;
    _personalSearchFailed = false;
    _groupSearchFailed = false;
    _personalSearchPartial = false;
    _groupSearchPartial = false;
    _remoteSearchLoading = false;
    if (_query.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleRemoteSearch(_query.text);
      });
    }
  }

  void _scheduleRemoteSearch(String value) {
    _searchTimer?.cancel();
    final generation = ++_searchGeneration;
    final query = value.trim();
    setState(() {
      _organizationResults = [];
      _personalResults = [];
      _groupResults = [];
      _organizationSearchFailed = false;
      _organizationSearchPartial = false;
      _personalSearchFailed = false;
      _groupSearchFailed = false;
      _personalSearchPartial = false;
      _groupSearchPartial = false;
      _remoteSearchLoading =
          query.isNotEmpty &&
          query.length <= 100 &&
          (widget.searchOrganization != null ||
              widget.searchPersonal != null ||
              widget.searchGroups != null);
    });
    if (!_remoteSearchLoading) return;
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_searchRemote(query, generation));
    });
  }

  Future<void> _searchRemote(String query, int generation) async {
    final identityKey = widget.searchIdentityKey;
    final sources = await searchKnowledgeSources(
      query,
      searchOrganisation: widget.searchOrganization,
      searchPrivateAccount: widget.searchPersonal,
      searchGroups: widget.searchGroups,
    );
    if (!mounted ||
        generation != _searchGeneration ||
        identityKey != widget.searchIdentityKey) {
      return;
    }
    setState(() {
      _organizationResults = sources.organisation;
      _personalResults = sources.privateAccount;
      _groupResults = sources.groups;
      _organizationSearchFailed = sources.failedSources.contains(
        'Organisation',
      );
      _organizationSearchPartial = sources.partialSources.contains(
        'Organisation',
      );
      _personalSearchFailed = sources.failedSources.contains('Private');
      _groupSearchFailed = sources.failedSources.contains('Groups');
      _personalSearchPartial = sources.partialSources.contains('Private');
      _groupSearchPartial = sources.partialSources.contains('Groups');
      _remoteSearchLoading = false;
    });
  }

  String _matchMethodLabel(String method) => switch (method) {
    'semantic' => 'meaning-based match',
    'hybrid' => 'keyword and meaning match',
    _ => 'keyword or prefix match',
  };

  String _snippet(String? text) {
    final value = text?.trim() ?? '';
    return value.length <= 240
        ? value
        : '${value.substring(0, 240).trimRight()}…';
  }

  String? _stringValue(Object? value) => value is String ? value : null;

  Future<void> _openPersonalResult(String id) async {
    if (!widget.items.any((item) => item['id'] == id)) {
      await widget.reloadPersonalWorkspace();
    }
    if (!mounted) return;
    if (!widget.items.any((item) => item['id'] == id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This personal-account result could not be loaded. Retry the account refresh.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _selectedKnowledgeItemId = id;
      _showSavedQuestions = true;
    });
  }

  String? _matchingSnippet(String query, List<String?> candidates) {
    final terms = query.toLowerCase().split(RegExp(r'\s+'));
    for (final candidate in candidates.whereType<String>()) {
      final folded = candidate.toLowerCase();
      final positions = terms
          .where((term) => term.isNotEmpty)
          .map(folded.indexOf)
          .where((index) => index >= 0)
          .toList();
      final index = positions.isEmpty
          ? null
          : positions.reduce((left, right) => left < right ? left : right);
      if (index == null) continue;
      final start = index > 70 ? index - 70 : 0;
      final end = (start + 240).clamp(0, candidate.length).toInt();
      return '${start > 0 ? '…' : ''}${candidate.substring(start, end)}'
          '${end < candidate.length ? '…' : ''}';
    }
    final nonempty = candidates.whereType<String>().toList();
    return nonempty.isEmpty ? null : nonempty.first;
  }

  Widget _remoteSearchResults(
    BuildContext context,
    String query,
    List<Map<String, dynamic>> localMatches,
  ) {
    if (query.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    if (query.trim().length > 100) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Authorised Knowledge search supports queries up to 100 characters. '
          'Local Knowledge remains searchable.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final personalById = {
      for (final result in _personalResults)
        if (result['source_id'] is String)
          result['source_id'] as String: result,
    };
    final localIds = localMatches
        .map((item) => item['id'])
        .whereType<String>()
        .toSet();
    final hits = <_UnifiedKnowledgeSearchHit>[];
    for (final result in _organizationResults) {
      final sourceLabels = <String>['Organisation: ${result.organisationName}'];
      if (result.department != null) {
        sourceLabels.add('Department: ${result.department!.name}');
      }
      if (result.team != null) sourceLabels.add('Team: ${result.team!.name}');
      final snippet = _matchingSnippet(query, [
        result.canonicalBody,
        result.acceptedAnswerBody,
      ]);
      hits.add(
        _UnifiedKnowledgeSearchHit(
          id: result.questionId,
          title: result.title,
          source: sourceLabels.join(' · '),
          method: _matchMethodLabel(result.matchMethod),
          relevance: result.relevanceScore,
          snippet: snippet ?? result.matchedText,
          icon: Icons.business_outlined,
          onTap: () => context.push('/questions/${result.questionId}'),
        ),
      );
    }
    for (final item in localMatches) {
      final id = item['id'] as String? ?? '';
      final accountResult = personalById[id];
      final accountData = accountResult?['data'] is Map
          ? Map<String, dynamic>.from(accountResult!['data'] as Map)
          : const <String, dynamic>{};
      final source = widget.isPersonalAccount(item) ? 'Private' : 'Local';
      final snippet =
          _stringValue(accountResult?['snippet']) ??
          _matchingSnippet(query, [
            _stringValue(item['body']),
            _stringValue(item['answer']),
          ]) ??
          _matchingSnippet(query, [
            _stringValue(accountData['body']),
            _stringValue(accountData['answer']),
          ]);
      final localRelevance = localKnowledgeRelevance(query, item);
      final accountRelevance =
          (accountResult?['relevance_score'] as num?)?.toDouble() ?? 0;
      final personalMethod = accountResult?['match_method'] as String?;
      hits.add(
        _UnifiedKnowledgeSearchHit(
          id: id,
          title: item['title'] as String? ?? '',
          source: source,
          method: personalMethod == null
              ? 'keyword or prefix match'
              : _matchMethodLabel(personalMethod),
          relevance: accountRelevance > localRelevance
              ? accountRelevance
              : localRelevance,
          snippet: snippet,
          icon: widget.isPersonalAccount(item)
              ? Icons.lock_outline
              : Icons.devices_outlined,
          onTap: () => _openPersonalResult(id),
          storageStatus: widget.storageStatus(item),
        ),
      );
    }
    for (final result in _personalResults) {
      final id =
          result['source_id'] as String? ?? result['id'] as String? ?? '';
      if (id.isEmpty || localIds.contains(id)) continue;
      Map<String, dynamic>? sourceItem;
      for (final item in widget.items) {
        if (item['id'] == id) {
          sourceItem = item;
          break;
        }
      }
      final isAccountSource =
          sourceItem == null || widget.isPersonalAccount(sourceItem);
      final data = result['data'] is Map
          ? Map<String, dynamic>.from(result['data'] as Map)
          : const <String, dynamic>{};
      hits.add(
        _UnifiedKnowledgeSearchHit(
          id: id,
          title: result['title'] as String? ?? '',
          source: isAccountSource ? 'Private' : 'Local',
          method: _matchMethodLabel(
            result['match_method'] as String? ?? 'keyword',
          ),
          relevance: (result['relevance_score'] as num?)?.toDouble() ?? 0,
          snippet: isAccountSource
              ? _stringValue(result['snippet']) ??
                    _matchingSnippet(query, [
                      _stringValue(data['body']),
                      _stringValue(data['answer']),
                    ])
              : _matchingSnippet(query, [
                  _stringValue(sourceItem['body']),
                  _stringValue(sourceItem['answer']),
                ]),
          icon: isAccountSource ? Icons.lock_outline : Icons.devices_outlined,
          onTap: () => _openPersonalResult(id),
          storageStatus: sourceItem == null
              ? null
              : widget.storageStatus(sourceItem),
        ),
      );
    }
    for (final result in _groupResults) {
      final id = result['id'] as String?;
      final groupId = result['group_id'] as String?;
      if (id == null || id.isEmpty || groupId == null || groupId.isEmpty) {
        continue;
      }
      final data = result['data'] is Map
          ? Map<String, dynamic>.from(result['data'] as Map)
          : const <String, dynamic>{};
      final title = result['title'] as String? ?? '';
      final groupName = result['group_name'] as String? ?? 'Group';
      hits.add(
        _UnifiedKnowledgeSearchHit(
          id: id,
          title: title,
          source: 'Group: $groupName',
          method: _matchMethodLabel(
            result['match_method'] as String? ?? 'keyword',
          ),
          relevance: (result['relevance_score'] as num?)?.toDouble() ?? 0,
          snippet:
              _stringValue(result['snippet']) ??
              _matchingSnippet(query, [
                _stringValue(data['body']),
                _stringValue(data['answer']),
              ]),
          icon: Icons.groups_outlined,
          onTap: () => widget.onOpenGroup(groupId, id),
        ),
      );
    }
    hits.sort((left, right) {
      final byScore = right.relevance.compareTo(left.relevance);
      return byScore != 0 ? byScore : left.id.compareTo(right.id);
    });
    final hasResults = hits.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_remoteSearchLoading)
          const LinearProgressIndicator(
            semanticsLabel: 'Searching authorized Knowledge sources',
          ),
        if (_organizationSearchFailed ||
            _organizationSearchPartial ||
            _personalSearchFailed ||
            _groupSearchFailed ||
            _personalSearchPartial ||
            _groupSearchPartial)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_organizationSearchFailed)
                  Text(
                    'Organisation search could not be completed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (_organizationSearchPartial)
                  Text(
                    'Organisation search reached its result limit. Some matches may be omitted.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (_personalSearchFailed)
                  Text(
                    'Personal-account search could not be completed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (_groupSearchFailed)
                  Text(
                    'Group search could not be completed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (_groupSearchPartial)
                  Text(
                    'Group search reached its result limit. Some matches may be omitted.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (_personalSearchPartial)
                  Text(
                    'Personal-account search reached its result limit. Some matches may be omitted.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (_organizationSearchFailed ||
                    _organizationSearchPartial ||
                    _personalSearchFailed ||
                    _personalSearchPartial ||
                    _groupSearchFailed ||
                    _groupSearchPartial)
                  TextButton(
                    onPressed: () => _scheduleRemoteSearch(_query.text),
                    child: const Text('Retry available sources'),
                  ),
              ],
            ),
          ),
        if (!_remoteSearchLoading &&
            !_organizationSearchFailed &&
            !_organizationSearchPartial &&
            !_personalSearchFailed &&
            !_groupSearchFailed &&
            !_personalSearchPartial &&
            !_groupSearchPartial &&
            !hasResults &&
            (widget.searchOrganization != null ||
                widget.searchPersonal != null ||
                widget.searchGroups != null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No matches in the available Knowledge sources.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (final hit in hits)
          Card(
            child: ListTile(
              leading: Icon(hit.icon),
              title: Text(hit.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(hit.source),
                      ),
                      Text(hit.method),
                    ],
                  ),
                  if (hit.storageStatus != null) Text(hit.storageStatus!),
                  if (hit.snippet != null && hit.snippet!.isNotEmpty)
                    Text(_snippet(hit.snippet)),
                ],
              ),
              onTap: hit.onTap,
            ),
          ),
      ],
    );
  }

  void _create() {
    if (!_formKey.currentState!.validate()) {
      _titleFocus.requestFocus();
      return;
    }
    final title = _title.text.trim();
    FocusScope.of(context).unfocus();
    widget.onCreate({
      'id': newGuestItemId(),
      'title': title,
      'body': _body.text.trim(),
      'answer': _answer.text.trim(),
      'visibility': widget.privateWorkspace ? 'private_account' : 'local_guest',
    });
    _title.clear();
    _body.clear();
    _answer.clear();
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditGuestKnowledgeDialog(
        item: item,
        isPersonalAccount: widget.isPersonalAccount(item),
      ),
    );
    if (updated != null && updated['title'].toString().isNotEmpty && mounted) {
      widget.onUpdate(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text;
    final matches = widget.items
        .where((item) => matchesGuestKeywordOrPrefix(query, item))
        .toList();
    final searchField = TextField(
      controller: _query,
      decoration: InputDecoration(
        labelText: 'Search Knowledge',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: MediaQuery.sizeOf(context).height < 300
            ? _knowledgeInfoButton
            : null,
      ),
      onChanged: (value) {
        _selectedKnowledgeItemId = null;
        setState(() {});
        _scheduleRemoteSearch(value);
      },
    );
    if (_showSavedQuestions) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.privateWorkspace) ...[
                KnowledgeSectionTabs(
                  selected: KnowledgeSection.questions,
                  onChanged: _selectKnowledgeSection,
                ),
                const SizedBox(height: 12),
              ],
              searchField,
              _remoteSearchResults(context, query, const []),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    if (_selectedKnowledgeItemId != null) {
                      _selectedKnowledgeItemId = null;
                    } else {
                      _showSavedQuestions = false;
                    }
                  }),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    _selectedKnowledgeItemId == null
                        ? widget.privateWorkspace
                              ? 'Back to Ask & search'
                              : 'Back to add a local question'
                        : 'Back to all Saved Q&A',
                  ),
                ),
              ),
              Text('Saved Q&A', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (matches
                  .where(
                    (item) =>
                        _selectedKnowledgeItemId == null ||
                        item['id'] == _selectedKnowledgeItemId,
                  )
                  .isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    widget.items.isEmpty
                        ? widget.privateWorkspace
                              ? 'No saved Q&A yet. Add private Knowledge to get started.'
                              : 'No saved Q&A yet. Add a local question to get started.'
                        : 'No local matches.',
                  ),
                ),
              for (final item in matches.where(
                (item) =>
                    _selectedKnowledgeItemId == null ||
                    item['id'] == _selectedKnowledgeItemId,
              ))
                Card(
                  child: ListTile(
                    title: Text(item['title'] as String? ?? ''),
                    subtitle: Text(
                      [item['body'], item['answer'], widget.storageStatus(item)]
                          .whereType<String>()
                          .where((text) => text.isNotEmpty)
                          .join('\n\n'),
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: widget.isPersonalAccount(item)
                              ? 'Edit personal-account Knowledge'
                              : 'Edit local Knowledge',
                          onPressed: () => _edit(item),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: widget.isPersonalAccount(item)
                              ? 'Remove personal-account Knowledge'
                              : 'Remove local Knowledge',
                          onPressed: () =>
                              widget.onDelete(item['id'] as String),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.privateWorkspace) ...[
              KnowledgeSectionTabs(
                selected: KnowledgeSection.ask,
                onChanged: _selectKnowledgeSection,
              ),
              const SizedBox(height: 12),
            ],
            searchField,
            _remoteSearchResults(context, query, matches),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.privateWorkspace
                        ? 'Add private Knowledge'
                        : 'Add a local question',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showSavedQuestions = true),
                  icon: const Icon(Icons.bookmark_outline),
                  label: const Text('Saved Q&A'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _title,
                    focusNode: _titleFocus,
                    decoration: const InputDecoration(labelText: 'Question'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a question.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _body,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Details'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _answer,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Answer'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: Text(
                  widget.privateWorkspace
                      ? 'Save to private account'
                      : 'Save locally',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestBackupInputDialog extends StatefulWidget {
  const _GuestBackupInputDialog({
    required this.initialJson,
    required this.onChanged,
  });

  final String initialJson;
  final ValueChanged<String> onChanged;

  @override
  State<_GuestBackupInputDialog> createState() =>
      _GuestBackupInputDialogState();
}

class _GuestBackupInputDialogState extends State<_GuestBackupInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialJson);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close({required bool preview}) {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, preview ? _controller.text : null);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Import local JSON backup'),
    content: SizedBox(
      width: 560,
      child: TextField(
        controller: _controller,
        minLines: 4,
        maxLines: 12,
        onChanged: widget.onChanged,
        decoration: const InputDecoration(
          labelText: 'Paste backup JSON',
          alignLabelWithHint: true,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => _close(preview: false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => _close(preview: true),
        child: const Text('Preview import'),
      ),
    ],
  );
}

class _EditGuestKnowledgeDialog extends StatefulWidget {
  const _EditGuestKnowledgeDialog({
    required this.item,
    required this.isPersonalAccount,
  });

  final Map<String, dynamic> item;
  final bool isPersonalAccount;

  @override
  State<_EditGuestKnowledgeDialog> createState() =>
      _EditGuestKnowledgeDialogState();
}

class _EditGuestKnowledgeDialogState extends State<_EditGuestKnowledgeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _answer;
  late final FocusNode _titleFocus;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item['title'] as String? ?? '');
    _body = TextEditingController(text: widget.item['body'] as String? ?? '');
    _answer = TextEditingController(
      text: widget.item['answer'] as String? ?? '',
    );
    _titleFocus = FocusNode();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _answer.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.isPersonalAccount
          ? 'Edit personal-account Knowledge'
          : 'Edit local Knowledge',
    ),
    content: Form(
      key: _formKey,
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              focusNode: _titleFocus,
              decoration: const InputDecoration(labelText: 'Question'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a question.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Details'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answer,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Answer'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) {
            _titleFocus.requestFocus();
            return;
          }
          Navigator.pop(context, {
            ...widget.item,
            'title': _title.text.trim(),
            'body': _body.text.trim(),
            'answer': _answer.text.trim(),
          });
        },
        child: Text(
          widget.isPersonalAccount ? 'Save account changes' : 'Save locally',
        ),
      ),
    ],
  );
}

class _GuestInteractTab extends StatefulWidget {
  const _GuestInteractTab({
    required this.data,
    required this.privateWorkspace,
    required this.storageStatus,
    required this.localSaveStatus,
    required this.onChange,
    required this.onCreateItem,
    required this.onPrint,
    required this.openSessionId,
    required this.sessionLoading,
    required this.onOpenSession,
    required this.onCloseSession,
    required this.onCopySessionJson,
  });

  final GuestWorkspaceData data;
  final bool privateWorkspace;
  final String Function(String, Map<String, dynamic>) storageStatus;
  final String localSaveStatus;
  final ValueChanged<GuestWorkspaceData> onChange;
  final void Function(
    String kind,
    Map<String, dynamic> item,
    GuestWorkspaceData updated,
  )
  onCreateItem;
  final void Function(Map<String, dynamic>, String?) onPrint;
  final String? openSessionId;
  final bool sessionLoading;
  final ValueChanged<String> onOpenSession;
  final VoidCallback onCloseSession;
  final ValueChanged<Map<String, dynamic>> onCopySessionJson;

  @override
  State<_GuestInteractTab> createState() => _GuestInteractTabState();
}

class _GuestInteractTabState extends State<_GuestInteractTab> {
  final _sessionFormKey = GlobalKey<FormState>();
  final _newSessionTitle = TextEditingController();
  final _newSessionParticipant = TextEditingController(text: 'Participant 1');
  final _sessionTitleFocus = FocusNode();
  final _participantFocus = FocusNode();
  String? _selectedTemplateId;

  @override
  void dispose() {
    _newSessionTitle.dispose();
    _newSessionParticipant.dispose();
    _sessionTitleFocus.dispose();
    _participantFocus.dispose();
    super.dispose();
  }

  bool _isPersonal(Map<String, dynamic> session) => widget
      .storageStatus('interact_session', session)
      .startsWith('Personal account');

  void _createSession() {
    if (!_sessionFormKey.currentState!.validate()) {
      if (_newSessionTitle.text.trim().isEmpty) {
        _sessionTitleFocus.requestFocus();
      } else {
        _participantFocus.requestFocus();
      }
      return;
    }
    final title = _newSessionTitle.text.trim();
    final participant = _newSessionParticipant.text.trim();
    final template = widget.data.templates
        .where((item) => item['id'] == _selectedTemplateId)
        .firstOrNull;
    final session = template == null
        ? <String, dynamic>{
            'id': newGuestItemId(),
            'title': title,
            'visibility': 'private_local',
            'participants': [
              {'id': newGuestItemId(), 'name': participant},
            ],
            'questions': <Map<String, dynamic>>[],
          }
        : createGuestSessionFromTemplate(
            template: template,
            id: newGuestItemId(),
            title: title,
            firstParticipantName: participant,
          );
    widget.onCreateItem(
      'interact_session',
      session,
      widget.data.copyWith(sessions: [session, ...widget.data.sessions]),
    );
    _newSessionTitle.clear();
    widget.onOpenSession(session['id'] as String);
  }

  Map<String, dynamic> _newQuestion(String text, List<String> participantIds) =>
      _newGuestQuestion(text, participantIds);

  void _updateSession(Map<String, dynamic> updated) {
    widget.onChange(
      widget.data.copyWith(
        sessions: [
          for (final session in widget.data.sessions)
            session['id'] == updated['id'] ? updated : session,
        ],
      ),
    );
  }

  void _deleteSession(Map<String, dynamic> session) {
    final isPersonalAccount = _isPersonal(session);
    if (widget.openSessionId == session['id']) widget.onCloseSession();
    widget.onChange(
      widget.data.copyWith(
        sessions: widget.data.sessions
            .where((item) => item['id'] != session['id'])
            .toList(),
      ),
    );
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isPersonalAccount
              ? 'Personal account session removal queued. Any local copy '
                    'remains on this device.'
              : 'Local session removed.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            widget.onChange(
              widget.data.copyWith(
                sessions: [session, ...widget.data.sessions],
              ),
            );
            final restoredToAccount = _isPersonal(session);
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  restoredToAccount
                      ? 'Session restore queued for your private account. '
                            'Check the save status.'
                      : isPersonalAccount
                      ? 'Session restored as a local copy on this device. '
                            'The private account removal is not undone.'
                      : 'Local session restored.',
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveTemplate(Map<String, dynamic> session) async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => _GuestRequiredTextDialog(
        title: widget.privateWorkspace
            ? 'Save private Interact template'
            : 'Save local template',
        submitLabel: widget.privateWorkspace
            ? 'Save to private account'
            : 'Save template',
        description:
            'Answers and participant names are not included. Participants '
            'become numbered slots; questions, shared or participant targets '
            'and follow-up branches are kept. '
            '${widget.privateWorkspace ? 'The template is saved privately in your account.' : 'The template stays on this device.'}',
        fields: [
          _GuestRequiredTextField(
            label: 'Template name',
            hintText: 'e.g. Weekly check-in',
            errorText: 'Enter a template name.',
          ),
        ],
      ),
    );
    if (values == null || !mounted) return;
    final template = createGuestTemplateFromSession(
      session: session,
      id: newGuestItemId(),
      name: values.single,
    );
    widget.onCreateItem(
      'template',
      template,
      widget.data.copyWith(templates: [template, ...widget.data.templates]),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.privateWorkspace
              ? 'Template save queued for your private account. Answers were '
                    'not included.'
              : 'Local template saved on this device. Answers were not '
                    'included.',
        ),
      ),
    );
  }

  String _editorStatus(Map<String, dynamic> session) {
    final status = widget.storageStatus('interact_session', session);
    if (status != 'Local on this device') return status;
    return switch (widget.localSaveStatus) {
      'Saved on this device' => 'Local · saved on this device',
      'Saving locally…' => 'Local · saving on this device…',
      _ => 'Local · not saved on this device; retry saving',
    };
  }

  @override
  Widget build(BuildContext context) {
    final openId = widget.openSessionId;
    if (openId != null) {
      final session = widget.data.sessions
          .where((item) => item['id'] == openId)
          .firstOrNull;
      if (session != null) {
        final isPersonalAccount = _isPersonal(session);
        return _GuestSessionEditor(
          key: ValueKey('guest-session-editor-$openId'),
          session: session,
          storageStatus: _editorStatus(session),
          isPersonalAccount: isPersonalAccount,
          privateWorkspace: widget.privateWorkspace,
          onBack: widget.onCloseSession,
          onChange: _updateSession,
          onDelete: () => _deleteSession(session),
          onSaveTemplate: () => _saveTemplate(session),
          onPrint: (participantId) => widget.onPrint(session, participantId),
          onCopyJson: () => widget.onCopySessionJson(session),
          makeQuestion: _newQuestion,
        );
      }
      return _GuestMissingSession(
        loading: widget.sessionLoading,
        onBack: widget.onCloseSession,
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (MediaQuery.sizeOf(context).height < 300)
              Align(
                alignment: Alignment.centerRight,
                child: _interactInfoButton(widget.privateWorkspace),
              ),
            if (widget.data.templates.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: _selectedTemplateId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Optional template',
                  hintText: 'Start blank or choose a template',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Start blank'),
                  ),
                  for (final template in widget.data.templates)
                    DropdownMenuItem(
                      value: template['id'] as String,
                      child: Text(
                        '${template['name'] as String? ?? 'Template'} · '
                        '${widget.storageStatus('template', template)}',
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedTemplateId = value),
              ),
            const SizedBox(height: 12),
            Form(
              key: _sessionFormKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 680
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: TextFormField(
                          controller: _newSessionTitle,
                          focusNode: _sessionTitleFocus,
                          decoration: const InputDecoration(
                            labelText: 'New Interact session',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            hintText: 'Session title',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a session title.'
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: TextFormField(
                          controller: _newSessionParticipant,
                          focusNode: _participantFocus,
                          decoration: const InputDecoration(
                            hintText: 'Participant',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a participant name.'
                              : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _createSession,
                icon: const Icon(Icons.add),
                label: Text(
                  widget.privateWorkspace
                      ? 'Create private session'
                      : 'Create session locally',
                ),
              ),
            ),
            const Divider(height: 28),
            Text('Sessions', style: Theme.of(context).textTheme.titleMedium),
            if (widget.data.sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Create a session to start capturing answers.'),
              ),
            for (final session in widget.data.sessions)
              Card(
                key: ValueKey('guest-session-tile-${session['id']}'),
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  leading: Icon(
                    _isPersonal(session)
                        ? Icons.lock_person_outlined
                        : Icons.phone_android_outlined,
                  ),
                  title: Text(
                    session['title'] as String? ?? 'Interact session',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${(session['participants'] as List? ?? const []).length} '
                    'participants · '
                    '${widget.storageStatus('interact_session', session)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: session['id'] is String
                      ? () => widget.onOpenSession(session['id'] as String)
                      : null,
                ),
              ),
            if (widget.data.templates.isNotEmpty) ...[
              const Divider(height: 28),
              Text('Templates', style: Theme.of(context).textTheme.titleMedium),
              for (final template in widget.data.templates)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(template['name'] as String? ?? 'Template'),
                  subtitle: Text(
                    '${widget.storageStatus('template', template)} · '
                    '${(template['questions'] as List? ?? const []).length} '
                    'questions',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuestMissingSession extends StatelessWidget {
  const _GuestMissingSession({required this.loading, required this.onBack});

  final bool loading;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading this session…'),
            ] else
              const Text(
                'This session is not available. It may have been removed, or '
                'it belongs to another account, device or workspace. Nothing '
                'was changed.',
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to sessions'),
            ),
          ],
        ),
      ),
    ),
  );
}

Map<String, dynamic> _newGuestQuestion(
  String text,
  List<String> participantIds,
) => {
  'id': newGuestItemId(),
  'text': text,
  'scope': 'shared',
  'answers': [
    for (final participantId in participantIds)
      {
        'participant_id': participantId,
        'body': '',
        'branches_collapsed': false,
        'follow_ups': <Map<String, dynamic>>[],
      },
  ],
};

class _GuestSessionEditor extends StatefulWidget {
  const _GuestSessionEditor({
    required this.session,
    required this.storageStatus,
    required this.isPersonalAccount,
    required this.privateWorkspace,
    required this.onBack,
    required this.onChange,
    required this.onDelete,
    required this.onSaveTemplate,
    required this.onPrint,
    required this.onCopyJson,
    required this.makeQuestion,
    this.groupName,
    super.key,
  });

  final Map<String, dynamic> session;
  final String storageStatus;
  final bool isPersonalAccount;
  final bool privateWorkspace;
  final VoidCallback onBack;
  final ValueChanged<Map<String, dynamic>> onChange;
  final VoidCallback onDelete;
  final VoidCallback onSaveTemplate;
  final ValueChanged<String?> onPrint;
  final VoidCallback onCopyJson;
  final Map<String, dynamic> Function(String, List<String>) makeQuestion;
  final String? groupName;

  @override
  State<_GuestSessionEditor> createState() => _GuestSessionEditorState();
}

class _GuestSessionEditorState extends State<_GuestSessionEditor> {
  final _scrollController = ScrollController();
  String? _selectedParticipantId;

  @override
  void initState() {
    super.initState();
    _selectedParticipantId = _participants.firstOrNull?['id'] as String?;
  }

  @override
  void didUpdateWidget(covariant _GuestSessionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session['id'] != widget.session['id'] ||
        !_participants.any(
          (participant) => participant['id'] == _selectedParticipantId,
        )) {
      _selectedParticipantId = _participants.firstOrNull?['id'] as String?;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _participants =>
      (widget.session['participants'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  String get _storageLabel => widget.groupName != null
      ? 'this Group copy'
      : widget.isPersonalAccount
      ? 'your private account'
      : 'this device';

  void _editSession(void Function(Map<String, dynamic>) update) {
    final session = _copyMap(widget.session);
    update(session);
    widget.onChange(session);
  }

  void _notify(String message, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), action: action));
  }

  /// Used inside a [SnackBarAction]: the action hides the current snack bar
  /// after its callback, so the follow-up message is queued instead of
  /// replacing (and then being hidden with) the current one.
  void _notifyAfterAction(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _storageFeedback({required String local, required String account}) =>
      widget.groupName != null
      ? 'Group copy draft changed. Save to confirm changes for members.'
      : widget.isPersonalAccount
      ? account
      : local;

  Future<void> _addParticipant() async {
    final values = await showDialog<List<String>>(
      context: context,
      useRootNavigator: widget.groupName == null,
      builder: (context) => _GuestRequiredTextDialog(
        title: 'Add participant',
        submitLabel: widget.groupName != null
            ? 'Add to Group draft'
            : widget.isPersonalAccount
            ? 'Add to account session'
            : 'Add participant locally',
        description:
            'The new participant becomes the active participant and gets a '
            'blank answer for every shared question.',
        fields: [
          _GuestRequiredTextField(
            label: 'Participant name',
            hintText: 'e.g. Sam (interviewee)',
            errorText: 'Enter a participant name.',
          ),
        ],
      ),
    );
    if (values == null || !mounted) return;
    final name = values.single;
    final id = newGuestItemId();
    _editSession((session) {
      (session['participants'] as List).add({'id': id, 'name': name});
      final roots = session['questions'] as List;
      for (final root in roots) {
        final question = root as Map<String, dynamic>;
        if (question['scope'] != 'participant') {
          _ensureAnswer(question, id);
        }
      }
    });
    setState(() => _selectedParticipantId = id);
  }

  Future<void> _renameActiveParticipant() async {
    final participant = _participants
        .where((item) => item['id'] == _selectedParticipantId)
        .firstOrNull;
    if (participant == null) return;
    final values = await showDialog<List<String>>(
      context: context,
      useRootNavigator: widget.groupName == null,
      builder: (context) => _GuestRequiredTextDialog(
        title: 'Rename participant',
        submitLabel: widget.groupName != null
            ? 'Update Group draft'
            : widget.isPersonalAccount
            ? 'Save account changes'
            : 'Save name locally',
        fields: [
          _GuestRequiredTextField(
            label: 'Participant name',
            hintText: 'e.g. Alex',
            initialValue: participant['name'] as String? ?? '',
            errorText: 'Enter a participant name.',
          ),
        ],
      ),
    );
    if (values == null || !mounted || participant['id'] is! String) {
      return;
    }
    final updatedName = values.single;
    final participantId = participant['id'] as String;
    _editSession((session) {
      for (final item in session['participants'] as List) {
        final current = item as Map<String, dynamic>;
        if (current['id'] == participantId) current['name'] = updatedName;
      }
    });
  }

  Future<void> _removeActiveParticipant() async {
    final participants = _participants;
    final participantIndex = participants.indexWhere(
      (item) => item['id'] == _selectedParticipantId,
    );
    if (participantIndex < 0) return;
    final participant = participants[participantIndex];
    final participantId = participant['id'] as String;
    final name = participant['name'] as String? ?? 'Participant';
    final blocked =
        participants.length < 2 ||
        guestParticipantHasContent(widget.session, participantId);
    if (blocked) {
      await showDialog<void>(
        context: context,
        useRootNavigator: widget.groupName == null,
        builder: (context) => AlertDialog(
          title: const Text('Participant cannot be removed'),
          content: Text(
            participants.length < 2
                ? 'A session needs at least one participant. Add another '
                      'participant before removing $name.'
                : '$name has answers, follow-ups or participant questions in '
                      'this session. Their content is kept; nothing was '
                      'changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: widget.groupName == null,
      builder: (context) => AlertDialog(
        title: const Text('Remove participant?'),
        content: Text(
          'Remove $name from this session? They have no answers or '
          'questions, so other participants’ answers and branches are '
          'unchanged. You can undo straight afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove participant'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _editSession(
      (session) => removeGuestParticipantWithoutContent(session, participantId),
    );
    _notify(
      _storageFeedback(
        local: 'Participant removed locally.',
        account:
            'Participant removal queued for your private account. Check the '
            'save status.',
      ),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          if (!mounted) return;
          _editSession((session) {
            final current = session['participants'] as List;
            if (current.any((item) => (item as Map)['id'] == participantId)) {
              return;
            }
            current.insert(
              participantIndex.clamp(0, current.length).toInt(),
              participant,
            );
            for (final root in session['questions'] as List) {
              final question = root as Map<String, dynamic>;
              if (question['scope'] != 'participant') {
                _ensureAnswer(question, participantId);
              }
            }
          });
          _notifyAfterAction(
            _storageFeedback(
              local: 'Participant restored locally.',
              account: 'Participant restore queued for your private account.',
            ),
          );
        },
      ),
    );
  }

  Future<void> _renameSession() async {
    final values = await showDialog<List<String>>(
      context: context,
      useRootNavigator: widget.groupName == null,
      builder: (context) => _GuestRequiredTextDialog(
        title: 'Rename session',
        submitLabel: widget.groupName != null
            ? 'Update Group draft'
            : widget.isPersonalAccount
            ? 'Save account changes'
            : 'Save title locally',
        fields: [
          _GuestRequiredTextField(
            label: 'Session title',
            hintText: 'e.g. Onboarding interview',
            initialValue: widget.session['title'] as String? ?? '',
            errorText: 'Enter a session title.',
          ),
        ],
      ),
    );
    if (values == null || !mounted) return;
    _editSession((session) => session['title'] = values.single);
  }

  Future<void> _addQuestion({required bool shared}) async {
    final sessionId = widget.session['id'];
    final initialParticipantIds = _participants
        .map((item) => item['id'] as String)
        .toList();
    if (initialParticipantIds.isEmpty) return;
    final targetParticipantId =
        initialParticipantIds.contains(_selectedParticipantId)
        ? _selectedParticipantId!
        : initialParticipantIds.first;
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => _GuestRequiredTextDialog(
        title: shared
            ? 'Add shared question'
            : 'Add question for active participant',
        submitLabel: 'Add question',
        description: shared
            ? 'Each participant gets a separate answer to this shared question.'
            : 'This question is for the active participant selected when you opened this dialog.',
        fields: const [
          _GuestRequiredTextField(
            label: 'Question text',
            hintText: 'e.g. What would you like to discuss today?',
            errorText: 'Enter a question.',
            maxLines: 4,
          ),
        ],
      ),
      useRootNavigator: widget.groupName == null,
    );
    if (values == null || !mounted || widget.session['id'] != sessionId) return;
    if (duplicateGuestParticipantIds(widget.session).isNotEmpty) {
      _notify(
        'Question editing is paused because participant IDs are duplicated.',
      );
      return;
    }
    final participantIds = _participants
        .map((item) => item['id'] as String)
        .toList();
    if (participantIds.isEmpty) {
      _notify('Add a participant before adding a question.');
      return;
    }
    if (!shared && !participantIds.contains(targetParticipantId)) {
      _notify(
        'The selected participant is no longer available. Choose a participant and try again.',
      );
      return;
    }
    final question = widget.makeQuestion(
      values.single.trim(),
      shared ? participantIds : [targetParticipantId],
    );
    question['scope'] = shared ? 'shared' : 'participant';
    if (!shared) question['target_participant_id'] = targetParticipantId;
    _editSession((session) => (session['questions'] as List).add(question));
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        widget.session['id'] != sessionId ||
        !_scrollController.hasClients)
      return;
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _removeRootQuestion(Map<String, dynamic> question) {
    final removed = _copyMap(question);
    final questions = widget.session['questions'] as List? ?? const [];
    final index = questions.indexWhere(
      (item) => (item as Map<String, dynamic>)['id'] == question['id'],
    );
    _editSession(
      (session) => (session['questions'] as List).removeWhere(
        (item) => (item as Map<String, dynamic>)['id'] == question['id'],
      ),
    );
    _notify(
      _storageFeedback(
        local: 'Local question removed.',
        account:
            'Question removal queued for your private account. Check the '
            'save status.',
      ),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          if (!mounted) return;
          _editSession((session) {
            final current = session['questions'] as List;
            if (current.any((item) => (item as Map)['id'] == removed['id'])) {
              return;
            }
            current.insert(index.clamp(0, current.length).toInt(), removed);
          });
          _notifyAfterAction(
            _storageFeedback(
              local: 'Local question restored.',
              account: 'Question restore queued for your private account.',
            ),
          );
        },
      ),
    );
  }

  void _removeFollowUp(
    String parentQuestionId,
    String participantId,
    String branchId,
  ) {
    Map<String, dynamic>? removed;
    var index = -1;
    _editSession((session) {
      final answer = _guestAnswerFor(
        session['questions'] as List,
        parentQuestionId,
        participantId,
      );
      final followUps = answer?['follow_ups'] as List?;
      if (followUps == null) return;
      index = followUps.indexWhere((item) => (item as Map)['id'] == branchId);
      if (index < 0) return;
      removed = _copyMap(followUps.removeAt(index) as Map<String, dynamic>);
    });
    final removedBranch = removed;
    if (removedBranch == null) return;
    _notify(
      _storageFeedback(
        local: 'Local follow-up removed.',
        account:
            'Follow-up removal queued for your private account. Check the '
            'save status.',
      ),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          if (!mounted) return;
          var restored = false;
          _editSession((session) {
            final answer = _guestAnswerFor(
              session['questions'] as List,
              parentQuestionId,
              participantId,
            );
            if (answer == null) return;
            final followUps =
                answer['follow_ups'] as List? ?? <Map<String, dynamic>>[];
            answer['follow_ups'] = followUps;
            if (followUps.any((item) => (item as Map)['id'] == branchId)) {
              return;
            }
            followUps.insert(
              index.clamp(0, followUps.length).toInt(),
              removedBranch,
            );
            restored = true;
          });
          _notifyAfterAction(
            restored
                ? _storageFeedback(
                    local: 'Local follow-up restored.',
                    account:
                        'Follow-up restore queued for your private account.',
                  )
                : 'The parent answer was removed, so the follow-up could not '
                      'be restored.',
          );
        },
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required bool duplicateIds,
    required bool statusPinned,
  }) {
    final theme = Theme.of(context);
    final title = widget.session['title'] as String? ?? 'Interact session';
    return LayoutBuilder(
      builder: (context, constraints) {
        final inlineActions =
            constraints.maxWidth >= 800 &&
            MediaQuery.textScalerOf(context).scale(14) <= 20;
        final destination = Chip(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          avatar: Icon(
            widget.isPersonalAccount
                ? Icons.lock_person_outlined
                : Icons.phone_android_outlined,
            size: 18,
          ),
          label: Text(
            widget.isPersonalAccount
                ? 'Destination: Private account'
                : 'Destination: Local · this device',
          ),
        );
        final pdfAction = OutlinedButton.icon(
          onPressed: () => widget.onPrint(_selectedParticipantId),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Download / Share PDF'),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Back to sessions',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                ),
                if (inlineActions) ...[
                  if (widget.groupName == null) destination,
                  const SizedBox(width: 8),
                  pdfAction,
                  const SizedBox(width: 8),
                ],
                PopupMenuButton<String>(
                  tooltip: 'More session actions',
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        _renameSession();
                      case 'template':
                        widget.onSaveTemplate();
                      case 'json':
                        widget.onCopyJson();
                      case 'delete':
                        widget.onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename session'),
                    ),
                    if (widget.groupName == null)
                      PopupMenuItem(
                        value: 'template',
                        enabled: !duplicateIds,
                        child: Text(
                          widget.privateWorkspace
                              ? 'Save as private template'
                              : 'Save as local template',
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'json',
                      child: Text('Copy session JSON backup'),
                    ),
                    if (widget.groupName == null) const PopupMenuDivider(),
                    if (widget.groupName == null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete session'),
                      ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.groupName == null && !inlineActions) destination,
                if (!inlineActions) pdfAction,
                if (!statusPinned)
                  Semantics(
                    liveRegion: true,
                    child: Text(widget.storageStatus),
                  ),
                if (widget.groupName != null)
                  Text('Shared · Group: ${widget.groupName}'),
                if (widget.groupName == null)
                  const _GuestInfoButton(
                    tooltip: 'Session lifecycle information',
                    title: 'About session lifecycle',
                    content:
                        'Local and private account sessions stay editable. They '
                        'have no draft, active, completed or archived status. '
                        'Delete removes a session with Undo while the message is '
                        'shown; private account changes are confirmed by the save '
                        'status. Organisation sessions use their own server '
                        'lifecycle.',
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _participantsSection(
    BuildContext context,
    List<Map<String, dynamic>> participants,
    String? activeParticipantId,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: participants.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Add a participant to start asking questions.'),
              )
            : DropdownButtonFormField<String>(
                key: ValueKey(activeParticipantId),
                initialValue: activeParticipantId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Active participant',
                  suffixIcon: _GuestInfoButton(
                    tooltip: 'Active participant help',
                    title: 'About the active participant',
                    content:
                        'Answers and individual questions are shown for this participant.',
                  ),
                ),
                items: [
                  for (final participant in participants)
                    DropdownMenuItem(
                      value: participant['id'] as String,
                      child: Text(
                        participant['name'] as String? ?? 'Participant',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedParticipantId = value),
              ),
      ),
      IconButton(
        tooltip: 'Add participant',
        onPressed: _addParticipant,
        icon: const Icon(Icons.person_add_alt_1),
      ),
      if (participants.isNotEmpty)
        PopupMenuButton<String>(
          tooltip: 'Active participant actions',
          icon: const Icon(Icons.manage_accounts_outlined),
          onSelected: (value) {
            if (value == 'rename') _renameActiveParticipant();
            if (value == 'remove') _removeActiveParticipant();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'rename',
              child: Text('Rename active participant'),
            ),
            PopupMenuItem(
              value: 'remove',
              child: Text('Remove active participant'),
            ),
          ],
        ),
    ],
  );

  Widget _questionActions(BuildContext context, bool hasParticipants) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 440;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const _GuestInfoButton(
                  tooltip: 'Question help',
                  title: 'About shared and participant questions',
                  content:
                      'Shared questions get separate answers from each '
                      'participant. Participant questions are asked only of '
                      'the active participant. Templates are optional.',
                ),
                FilledButton.tonal(
                  onPressed: hasParticipants
                      ? () => _addQuestion(shared: true)
                      : null,
                  child: const Text('Add shared question'),
                ),
                Tooltip(
                  message: 'Add question for the active participant',
                  child: FilledButton.tonal(
                    onPressed: hasParticipants
                        ? () => _addQuestion(shared: false)
                        : null,
                    child: Text(
                      compact
                          ? 'Add participant question'
                          : 'Add question for active participant',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final participants = _participants;
    final hasDuplicateParticipantIds = duplicateGuestParticipantIds(
      widget.session,
    ).isNotEmpty;
    final activeParticipant =
        participants
            .where((participant) => participant['id'] == _selectedParticipantId)
            .firstOrNull ??
        participants.firstOrNull;
    final activeParticipantId = activeParticipant?['id'] as String?;
    final questions = (widget.session['questions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((question) {
          if (question['scope'] != 'participant') return true;
          final targetId =
              question['target_participant_id'] ??
              participants.firstOrNull?['id'];
          return targetId == activeParticipantId;
        })
        .toList();
    Widget padded(Widget child) => SliverToBoxAdapter(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ),
      ),
    );
    return CustomScrollView(
      key: const ValueKey('guest-session-editor-scroll'),
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        padded(
          _header(
            context,
            duplicateIds: hasDuplicateParticipantIds,
            statusPinned:
                !hasDuplicateParticipantIds && activeParticipant != null,
          ),
        ),
        if (hasDuplicateParticipantIds) ...[
          padded(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'This saved session has duplicate participant IDs. Existing data is unchanged; participant editing and selected-participant reports are unavailable because answer ownership cannot be determined safely. Use All participants to view answers marked as ambiguous, and make a local backup before any manual repair.',
              ),
            ),
          ),
          padded(
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Question and answer editing is paused for this session.',
              ),
            ),
          ),
        ] else ...[
          padded(const Divider(height: 16)),
          padded(
            _participantsSection(context, participants, activeParticipantId),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (activeParticipant != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: _GuestActiveParticipantBarDelegate(
                name: activeParticipant['name'] as String? ?? 'Participant',
                status: widget.storageStatus,
                background: Theme.of(context).colorScheme.surface,
              ),
            ),
          if (questions.isEmpty && participants.isNotEmpty)
            padded(
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('No questions for this participant yet.'),
              ),
            ),
          for (final question in questions)
            padded(
              _GuestQuestionEditor(
                key: ValueKey(question['id']),
                question: question,
                isGroupCopy: widget.groupName != null,
                isPersonalAccount: widget.isPersonalAccount,
                participants: activeParticipant == null
                    ? const []
                    : [activeParticipant],
                onRemove: () => _removeRootQuestion(question),
                onRemoveFollowUp: _removeFollowUp,
                onUpdate: (updated) => _replaceQuestion(
                  widget.session,
                  updated,
                  (session) => widget.onChange(session),
                ),
                makeQuestion: widget.makeQuestion,
              ),
            ),
          padded(_questionActions(context, participants.isNotEmpty)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        padded(
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              widget.groupName != null
                  ? 'Edits affect this Group copy only, not the original. Use Save Group copy to confirm changes.'
                  : 'Changes are saved to $_storageLabel as you type.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}

class _GuestActiveParticipantBarDelegate
    extends SliverPersistentHeaderDelegate {
  const _GuestActiveParticipantBarDelegate({
    required this.name,
    required this.status,
    required this.background,
  });

  final String name;
  final String status;
  final Color background;

  static const double _height = 64;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: background,
    elevation: overlapsContent || shrinkOffset > 0 ? 2 : 0,
    child: ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: _height,
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active participant: $name',
                              key: const ValueKey(
                                'guest-active-participant-bar',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  @override
  bool shouldRebuild(
    covariant _GuestActiveParticipantBarDelegate oldDelegate,
  ) =>
      oldDelegate.name != name ||
      oldDelegate.status != status ||
      oldDelegate.background != background;
}

class _GuestQuestionEditor extends StatefulWidget {
  const _GuestQuestionEditor({
    required this.question,
    required this.isPersonalAccount,
    required this.participants,
    required this.onUpdate,
    required this.onRemove,
    required this.onRemoveFollowUp,
    required this.makeQuestion,
    this.nested = false,
    this.isGroupCopy = false,
    super.key,
  });

  final Map<String, dynamic> question;
  final bool isPersonalAccount;
  final List<Map<String, dynamic>> participants;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final VoidCallback onRemove;
  final void Function(String parentQuestionId, String participantId, String id)
  onRemoveFollowUp;
  final Map<String, dynamic> Function(String, List<String>) makeQuestion;
  final bool nested;
  final bool isGroupCopy;

  @override
  State<_GuestQuestionEditor> createState() => _GuestQuestionEditorState();
}

class _GuestQuestionEditorState extends State<_GuestQuestionEditor> {
  late final TextEditingController _questionText;
  final _questionFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _questionText = TextEditingController(
      text: widget.question['text'] as String? ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _GuestQuestionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.question['text'] as String? ?? '';
    if (_questionText.text.trim() != current && !_questionFocus.hasFocus) {
      _questionText.value = TextEditingValue(text: current);
    }
  }

  @override
  void dispose() {
    _questionText.dispose();
    _questionFocus.dispose();
    super.dispose();
  }

  void _updateQuestionText(String value) {
    final text = value.trim();
    setState(() {});
    // Keep the saved question intact while the user temporarily clears the field.
    if (text.isEmpty || text == widget.question['text']) return;
    final question = _copyMap(widget.question);
    question['text'] = text;
    widget.onUpdate(question);
  }

  List<Map<String, dynamic>> get _answers =>
      (widget.question['answers'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  void _updateAnswer(String participantId, String body) {
    final question = _copyMap(widget.question);
    final answers = question['answers'] as List? ?? <Map<String, dynamic>>[];
    question['answers'] = answers;
    var answer = _answerForParticipant(answers, participantId);
    if (answer == null) {
      answer = {
        'participant_id': participantId,
        'body': '',
        'branches_collapsed': false,
        'follow_ups': <Map<String, dynamic>>[],
      };
      answers.add(answer);
    }
    answer['body'] = body;
    widget.onUpdate(question);
  }

  void _addFollowUp(String participantId, String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    final question = _copyMap(widget.question);
    final answers = question['answers'] as List? ?? <Map<String, dynamic>>[];
    question['answers'] = answers;
    var answer = _answerForParticipant(answers, participantId);
    if (answer == null) {
      answer = {
        'participant_id': participantId,
        'body': '',
        'branches_collapsed': false,
        'follow_ups': <Map<String, dynamic>>[],
      };
      answers.add(answer);
    }
    final followUps = answer['follow_ups'] as List? ?? <Map<String, dynamic>>[];
    answer['follow_ups'] = followUps;
    final followUp = widget.makeQuestion(text, [participantId]);
    followUp['scope'] = 'participant';
    followUp['target_participant_id'] = participantId;
    followUps.add(followUp);
    widget.onUpdate(question);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.question['id'] as String;
    final scope = widget.question['scope'] as String? ?? 'shared';
    final target = widget.question['target_participant_id'] as String?;
    final applicable = widget.participants.where((participant) {
      return scope == 'shared' || participant['id'] == target;
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 440;
        return Card(
          color: widget.nested
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: widget.nested
                  ? Theme.of(context).colorScheme.outlineVariant
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: widget.nested && narrow ? 0 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: ValueKey('guest-question-text-$id'),
                  controller: _questionText,
                  focusNode: _questionFocus,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: widget.nested
                        ? 'Follow-up question text'
                        : 'Question text',
                    hintText: 'e.g. What would you like to discuss today?',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    errorText: _questionText.text.trim().isEmpty
                        ? 'Enter a question. The last saved text is kept.'
                        : null,
                  ),
                  onChanged: _updateQuestionText,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Delete question and undo',
                        onPressed: widget.onRemove,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.nested
                      ? 'Follow-up owned by ${widget.participants.firstOrNull?['name'] ?? 'participant'}’s answer'
                      : scope == 'shared'
                      ? 'Shared question'
                      : 'Question for ${widget.participants.firstOrNull?['name'] ?? 'participant'}',
                ),
                for (final participant in applicable)
                  _GuestAnswerEditor(
                    key: ValueKey('${id}_${participant['id']}'),
                    questionId: id,
                    participant: participant,
                    isPersonalAccount: widget.isPersonalAccount,
                    isGroupCopy: widget.isGroupCopy,
                    answer: _answers
                        .where(
                          (answer) =>
                              answer['participant_id'] == participant['id'],
                        )
                        .firstOrNull,
                    onAnswerChanged: (body) =>
                        _updateAnswer(participant['id'] as String, body),
                    onAddFollowUp: (text) =>
                        _addFollowUp(participant['id'] as String, text),
                    onUpdate: _replaceAnswer,
                    onRemoveFollowUp: widget.onRemoveFollowUp,
                    makeQuestion: widget.makeQuestion,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _replaceAnswer(Map<String, dynamic> updated) {
    final question = _copyMap(widget.question);
    final participantId = updated['participant_id'];
    final answers = question['answers'] as List? ?? <Map<String, dynamic>>[];
    final answerIndex = answers.indexWhere(
      (item) =>
          (item as Map<String, dynamic>)['participant_id'] == participantId,
    );
    if (answerIndex < 0) {
      answers.add(updated);
    } else {
      answers[answerIndex] = updated;
    }
    question['answers'] = answers;
    widget.onUpdate(question);
  }
}

Map<String, dynamic>? _answerForParticipant(
  List answers,
  String participantId,
) {
  for (final item in answers) {
    if (item is Map && item['participant_id'] == participantId) {
      return item.cast<String, dynamic>();
    }
  }
  return null;
}

class _GuestAnswerEditor extends StatefulWidget {
  const _GuestAnswerEditor({
    required this.questionId,
    required this.participant,
    required this.isPersonalAccount,
    required this.answer,
    required this.onAnswerChanged,
    required this.onAddFollowUp,
    required this.onUpdate,
    required this.onRemoveFollowUp,
    required this.makeQuestion,
    this.isGroupCopy = false,
    super.key,
  });

  final String questionId;
  final Map<String, dynamic> participant;
  final bool isPersonalAccount;
  final Map<String, dynamic>? answer;
  final ValueChanged<String> onAnswerChanged;
  final ValueChanged<String> onAddFollowUp;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final void Function(String parentQuestionId, String participantId, String id)
  onRemoveFollowUp;
  final Map<String, dynamic> Function(String, List<String>) makeQuestion;
  final bool isGroupCopy;

  @override
  State<_GuestAnswerEditor> createState() => _GuestAnswerEditorState();
}

class _GuestAnswerEditorState extends State<_GuestAnswerEditor> {
  final _followUpFormKey = GlobalKey<FormState>();
  late final TextEditingController _answer;
  final _followUp = TextEditingController();
  final _answerFocus = FocusNode();
  final _followUpFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _answer = TextEditingController(
      text: widget.answer?['body'] as String? ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _GuestAnswerEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.answer?['body'] as String? ?? '';
    if (_answer.text != current && !_answerFocus.hasFocus) {
      _answer.value = TextEditingValue(text: current);
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    _followUp.dispose();
    _answerFocus.dispose();
    _followUpFocus.dispose();
    super.dispose();
  }

  void _addFollowUp() {
    if (!_followUpFormKey.currentState!.validate()) {
      _followUpFocus.requestFocus();
      return;
    }
    widget.onAddFollowUp(_followUp.text);
    _followUp.clear();
  }

  @override
  Widget build(BuildContext context) {
    final branches = widget.answer?['follow_ups'] as List? ?? const [];
    final collapsed = widget.answer?['branches_collapsed'] as bool? ?? false;
    final participantName =
        widget.participant['name'] as String? ?? 'Participant';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: LayoutBuilder(
        builder: (context, editorConstraints) {
          final horizontalPadding = editorConstraints.maxWidth < 240
              ? 4.0
              : 12.0;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: 12,
                horizontal: horizontalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Participant answer · $participantName',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _answer,
                    focusNode: _answerFocus,
                    minLines: 2,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: widget.isGroupCopy
                          ? 'Group copy answer'
                          : widget.isPersonalAccount
                          ? 'Personal-account answer'
                          : 'Local answer',
                      hintText: 'Record $participantName’s answer…',
                      alignLabelWithHint: true,
                    ),
                    onChanged: widget.onAnswerChanged,
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compactActions = constraints.maxWidth < 200;
                      final actions = [
                        Tooltip(
                          message: 'Add answer-owned follow-up',
                          child: compactActions
                              ? IconButton(
                                  onPressed: _addFollowUp,
                                  icon: const Icon(Icons.add_comment_outlined),
                                )
                              : FilledButton.tonalIcon(
                                  onPressed: _addFollowUp,
                                  icon: const Icon(Icons.add_comment_outlined),
                                  label: const Text('Add follow-up'),
                                ),
                        ),
                        if (branches.isNotEmpty)
                          IconButton(
                            tooltip: collapsed
                                ? 'Expand follow-ups'
                                : 'Collapse follow-ups',
                            onPressed: () {
                              final updated = _copyMap(widget.answer!);
                              updated['branches_collapsed'] = !collapsed;
                              widget.onUpdate(updated);
                            },
                            icon: Icon(
                              collapsed ? Icons.expand_more : Icons.expand_less,
                            ),
                          ),
                        if (branches.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('${branches.length} follow-ups'),
                          ),
                      ];
                      final field = Form(
                        key: _followUpFormKey,
                        child: TextFormField(
                          controller: _followUp,
                          focusNode: _followUpFocus,
                          decoration: const InputDecoration(
                            labelText: 'Follow-up question',
                            hintText: 'e.g. Can you give an example?',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a follow-up question.'
                              : null,
                          onFieldSubmitted: (_) => _addFollowUp(),
                        ),
                      );
                      if (constraints.maxWidth < 440) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            field,
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: actions,
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: field),
                          const SizedBox(width: 8),
                          Wrap(spacing: 4, children: actions),
                        ],
                      );
                    },
                  ),
                  if (branches.isNotEmpty && !collapsed)
                    LayoutBuilder(
                      builder: (context, constraints) => Padding(
                        padding: EdgeInsets.only(
                          left: constraints.maxWidth < 440 ? 0 : 8,
                        ),
                        child: Column(
                          children: [
                            for (final branch in branches)
                              _GuestQuestionEditor(
                                isGroupCopy: widget.isGroupCopy,
                                key: ValueKey(
                                  (branch as Map<String, dynamic>)['id'],
                                ),
                                question: branch,
                                isPersonalAccount: widget.isPersonalAccount,
                                participants: [widget.participant],
                                nested: true,
                                onRemove: () => widget.onRemoveFollowUp(
                                  widget.questionId,
                                  widget.participant['id'] as String,
                                  branch['id'] as String,
                                ),
                                onRemoveFollowUp: widget.onRemoveFollowUp,
                                onUpdate: (updated) {
                                  final answer = _copyMap(widget.answer!);
                                  _replaceInQuestions(
                                    answer['follow_ups'] as List,
                                    updated,
                                  );
                                  widget.onUpdate(answer);
                                },
                                makeQuestion: widget.makeQuestion,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SharedGuestGroupsPage extends ConsumerStatefulWidget {
  const SharedGuestGroupsPage({
    super.key,
    this.initialGroupId,
    this.initialEntryId,
  });

  final String? initialGroupId;
  final String? initialEntryId;

  @override
  ConsumerState<SharedGuestGroupsPage> createState() =>
      _SharedGuestGroupsPageState();
}

class _SharedGuestGroupsPageState extends ConsumerState<SharedGuestGroupsPage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _groups = const [];
  List<Map<String, dynamic>> _archivedGroups = const [];
  List<Map<String, dynamic>> _entries = const [];
  List<Map<String, dynamic>> _invitations = const [];
  Map<String, dynamic>? _group;
  String? _groupId;
  bool _busy = false;
  String? _error;
  String? _activeUid;
  int _loadGeneration = 0;
  String _createGroupNameDraft = '';
  String _createGroupDisplayNameDraft = '';
  String _joinTokenDraft = '';
  String _joinDisplayNameDraft = '';
  final Map<String, Map<String, String>> _createKnowledgeDrafts = {};
  final Map<String, Map<String, String>> _entryEditDrafts = {};
  final Set<String> _uncertainArchivedDeletionIds = {};
  bool _archivedDeleteNeedsSafeRefresh = false;
  bool _initialEntryOpened = false;
  bool _groupEditorOpen = false;
  final Set<VoidCallback> _groupDialogClosers = {};

  GuestGroupRepository get _repository =>
      ref.read(guestGroupRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final user = ref.read(firebaseAuthProvider).currentUser;
    _activeUid = isVerifiedRegisteredFirebaseUser(user) ? user!.uid : null;
    if (_activeUid != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadGroups(preferredGroupId: widget.initialGroupId),
      );
    }
  }

  void _identityChanged(User? user) {
    final nextUid = isVerifiedRegisteredFirebaseUser(user) ? user!.uid : null;
    if (nextUid == _activeUid) return;
    _activeUid = nextUid;
    _loadGeneration++;
    _createGroupNameDraft = '';
    _createGroupDisplayNameDraft = '';
    _joinTokenDraft = '';
    _joinDisplayNameDraft = '';
    _createKnowledgeDrafts.clear();
    _entryEditDrafts.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _closeGroupDialogs());
    if (mounted) {
      setState(() {
        _groups = const [];
        _archivedGroups = const [];
        _group = null;
        _groupId = null;
        _entries = const [];
        _invitations = const [];
        _error = null;
        _busy = nextUid != null;
      });
    }
    if (nextUid != null) _loadGroups();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_groupEditorOpen) {
      _loadGroups();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _closeGroupDialogs());
    super.dispose();
  }

  void _closeGroupDialogs() {
    final closers = _groupDialogClosers.toList();
    _groupDialogClosers.clear();
    for (final close in closers.reversed) {
      close();
    }
  }

  Future<T?> _showScopedGroupDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    VoidCallback? close;
    try {
      return await showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (dialogContext) {
          if (close == null) {
            final route = ModalRoute.of(dialogContext);
            final navigator = Navigator.of(dialogContext);
            close = () {
              if (route != null && route.isActive) navigator.removeRoute(route);
            };
            _groupDialogClosers.add(close!);
          }
          return builder(dialogContext);
        },
      );
    } finally {
      if (close != null) _groupDialogClosers.remove(close);
    }
  }

  Future<bool> _loadGroups({String? preferredGroupId}) async {
    if (!mounted) return false;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (!isVerifiedRegisteredFirebaseUser(user) || user!.uid != _activeUid) {
      return false;
    }
    final uid = user.uid;
    final generation = ++_loadGeneration;
    _closeGroupDialogs();
    setState(() {
      _busy = true;
      _error = null;
      _groups = const [];
      _archivedGroups = const [];
      _group = null;
      _entries = const [];
      _invitations = const [];
    });
    try {
      final groups = await _repository.listGroups();
      if (!_isCurrentLoad(uid, generation)) return false;
      final archivedGroups = await _repository.listArchivedGroups();
      if (!_isCurrentLoad(uid, generation)) return false;
      final preferred = preferredGroupId ?? _groupId;
      final selected = groups.any((group) => group['id'] == preferred)
          ? _groupId
          : groups.isEmpty
          ? null
          : groups.first['id'] as String;
      final selectedGroupId = groups.any((group) => group['id'] == preferred)
          ? preferred
          : selected;
      if (!_isCurrentLoad(uid, generation)) return false;
      setState(() {
        _groups = groups;
        _archivedGroups = archivedGroups;
        _uncertainArchivedDeletionIds.clear();
        _archivedDeleteNeedsSafeRefresh = false;
        _groupId = selectedGroupId;
      });
      if (selectedGroupId != null) {
        final loaded = await _loadGroup(
          selectedGroupId,
          uid: uid,
          generation: generation,
        );
        if (loaded && widget.initialEntryId != null && !_initialEntryOpened) {
          for (final entry in _entries) {
            if (entry['id'] == widget.initialEntryId) {
              _initialEntryOpened = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_isCurrentLoad(uid, generation) &&
                    _groupId == selectedGroupId) {
                  _openEntry(entry);
                }
              });
              break;
            }
          }
        }
        return loaded;
      } else {
        if (!mounted) return false;
        setState(() {
          _group = null;
          _entries = const [];
          _invitations = const [];
        });
        return true;
      }
    } on Object catch (error) {
      if (_isCurrentLoad(uid, generation)) {
        setState(() {
          _groups = const [];
          _archivedGroups = const [];
          _group = null;
          _entries = const [];
          _invitations = const [];
          _error = _safeGuestError(error);
        });
      }
      return false;
    } finally {
      if (_isCurrentLoad(uid, generation)) {
        setState(() => _busy = false);
      }
    }
  }

  bool _isCurrentLoad(String uid, int generation) {
    if (!mounted || generation != _loadGeneration || uid != _activeUid) {
      return false;
    }
    final user = ref.read(firebaseAuthProvider).currentUser;
    return user?.uid == uid && isVerifiedRegisteredFirebaseUser(user);
  }

  Future<bool> _loadGroup(
    String groupId, {
    String? uid,
    int? generation,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (!isVerifiedRegisteredFirebaseUser(user) || user!.uid != _activeUid) {
      return false;
    }
    final loadUid = uid ?? user.uid;
    final loadGeneration = generation ?? ++_loadGeneration;
    if (!_isCurrentLoad(loadUid, loadGeneration)) return false;
    setState(() {
      _busy = true;
      _error = null;
      _group = null;
      _entries = const [];
      _invitations = const [];
      _groupId = groupId;
    });
    try {
      final detail = await _repository.getGroup(groupId);
      if (!_isCurrentLoad(loadUid, loadGeneration)) return false;
      final entries = await _repository.searchEntries(
        groupId: groupId,
        query: '',
      );
      if (!_isCurrentLoad(loadUid, loadGeneration)) return false;
      final invitations = detail['role'] == 'admin'
          ? await _repository.listInvitations(groupId)
          : const <Map<String, dynamic>>[];
      if (!_isCurrentLoad(loadUid, loadGeneration)) return false;
      setState(() {
        _groupId = groupId;
        _group = detail;
        _entries = entries;
        _invitations = invitations;
        _error = null;
      });
      return true;
    } on Object catch (error) {
      if (_isCurrentLoad(loadUid, loadGeneration)) {
        setState(() => _error = _safeGuestError(error));
      }
      return false;
    } finally {
      if (_isCurrentLoad(loadUid, loadGeneration)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _archiveGroup() async {
    final groupId = _groupId;
    if (groupId == null || _group?['role'] != 'admin') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive this group?'),
        content: const Text(
          'All members will lose group access and outstanding invitations will '
          'be revoked. Members, content, and revisions are retained. For 30 days, '
          'only the same Firebase account that archives this group can restore it. '
          'A new account does not inherit recovery rights. Restoring does not '
          'reinstate invitations or pending/removed member access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep group active'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive group'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await _repository.archiveGroup(groupId);
      _groupId = null;
      await _loadGroups();
    });
  }

  Future<void> _restoreArchivedGroup(String groupId) async {
    await _run(() async {
      await _repository.restoreGroup(groupId);
      await _loadGroups();
    });
  }

  Future<void> _deleteArchivedGroup(Map<String, dynamic> archived) async {
    if (_busy || archived['can_delete'] != true) return;
    final groupId = archived['id'] as String;
    final groupName = archived['name'] as String? ?? 'Group';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$groupName" permanently?'),
        content: const Text(
          'This permanently deletes the group, its content, and its '
          'memberships for everyone. It cannot be restored. Existing exports '
          'and local copies are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await _run(
      () => _repository.permanentlyDeleteGroup(groupId),
    );
    if (deleted) {
      await _loadGroups();
    } else {
      await _refreshArchivedAfterUncertainDelete(archived);
    }
  }

  Future<void> _refreshArchivedAfterUncertainDelete(
    Map<String, dynamic> archived,
  ) async {
    if (!mounted) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (!isVerifiedRegisteredFirebaseUser(user) || user!.uid != _activeUid) {
      return;
    }
    final uid = user.uid;
    final generation = ++_loadGeneration;
    final groupId = archived['id'] as String;
    final failure = _error ?? 'The request could not be verified.';
    setState(() {
      _busy = true;
      _archivedDeleteNeedsSafeRefresh = true;
    });
    try {
      final groups = await _repository.listArchivedGroups();
      if (!_isCurrentLoad(uid, generation)) return;
      setState(() {
        _archivedGroups = groups;
        _uncertainArchivedDeletionIds.remove(groupId);
        _error =
            '$failure Archived-group status was refreshed. '
            'Review it before retrying.';
      });
    } on Object catch (error) {
      if (!_isCurrentLoad(uid, generation)) return;
      setState(() {
        _uncertainArchivedDeletionIds.add(groupId);
        if (!_archivedGroups.any((group) => group['id'] == groupId)) {
          _archivedGroups = [..._archivedGroups, archived];
        }
        _error =
            'The deletion outcome is uncertain and archived-group status '
            'could not be refreshed. ${_safeGuestError(error)} '
            'The item is retained; refresh status before retrying.';
      });
    } finally {
      if (_isCurrentLoad(uid, generation)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refreshStatus() async {
    if (_archivedDeleteNeedsSafeRefresh ||
        _uncertainArchivedDeletionIds.isNotEmpty) {
      await _refreshArchivedGroups();
    } else {
      await _loadGroups();
    }
  }

  Future<void> _refreshArchivedGroups() async {
    if (!mounted) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (!isVerifiedRegisteredFirebaseUser(user) || user!.uid != _activeUid) {
      return;
    }
    final uid = user.uid;
    final generation = ++_loadGeneration;
    setState(() => _busy = true);
    try {
      final groups = await _repository.listArchivedGroups();
      if (!_isCurrentLoad(uid, generation)) return;
      setState(() {
        _archivedGroups = groups;
        _uncertainArchivedDeletionIds.clear();
        _archivedDeleteNeedsSafeRefresh = false;
        _error = null;
      });
    } on Object catch (error) {
      if (_isCurrentLoad(uid, generation)) {
        setState(
          () => _error =
              'Archived-group status could not be refreshed. '
              '${_safeGuestError(error)} The item is retained; refresh status '
              'before retrying.',
        );
      }
    } finally {
      if (_isCurrentLoad(uid, generation)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _respondToAdminTransfer({
    required String groupId,
    required String transferId,
    required bool accept,
  }) async {
    await _run(() async {
      if (accept) {
        await _repository.acceptAdminTransfer(
          groupId: groupId,
          transferId: transferId,
        );
      } else {
        await _repository.declineAdminTransfer(
          groupId: groupId,
          transferId: transferId,
        );
      }
      await _loadGroup(groupId);
    });
  }

  Future<void> _cancelAdminTransfer({
    required String groupId,
    required String transferId,
  }) async {
    await _run(() async {
      await _repository.cancelAdminTransfer(
        groupId: groupId,
        transferId: transferId,
      );
      await _loadGroup(groupId);
    });
  }

  Widget _adminTransferCard() {
    final value = _group?['pending_admin_transfer'];
    if (value is! Map<String, dynamic> || _groupId == null) {
      return const SizedBox.shrink();
    }
    final groupId = _groupId!;
    final transferId = value['id'] as String;
    if (value['is_target'] == true) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You have been asked to accept group administration. '
                'Accepting makes you an admin and changes the requester to contributor.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _respondToAdminTransfer(
                            groupId: groupId,
                            transferId: transferId,
                            accept: true,
                          ),
                    child: const Text('Accept administration'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _respondToAdminTransfer(
                            groupId: groupId,
                            transferId: transferId,
                            accept: false,
                          ),
                    child: const Text('Decline'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (value['is_requester'] == true) {
      return Card(
        child: ListTile(
          title: Text(
            'Waiting for ${value['target_display_name'] ?? 'the member'} to accept administration.',
          ),
          subtitle: Text('Request expires ${value['expires_at']}'),
          trailing: TextButton(
            onPressed: _busy
                ? null
                : () => _cancelAdminTransfer(
                    groupId: groupId,
                    transferId: transferId,
                  ),
            child: const Text('Cancel request'),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _createGroup() async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => _GuestRequiredTextDialog(
        title: 'Create a group',
        description:
            'Groups require a registered account with a verified email. '
            'Only content you later choose to share is uploaded.',
        submitLabel: 'Create group',
        fields: [
          _GuestRequiredTextField(
            label: 'Group name',
            errorText: 'Enter a group name.',
            initialValue: _createGroupNameDraft,
          ),
          _GuestRequiredTextField(
            label: 'Your display name',
            errorText: 'Enter a display name.',
            initialValue: _createGroupDisplayNameDraft,
          ),
        ],
      ),
    );
    if (values == null) {
      _createGroupNameDraft = '';
      _createGroupDisplayNameDraft = '';
      return;
    }
    if (!mounted) return;
    _createGroupNameDraft = values[0];
    _createGroupDisplayNameDraft = values[1];
    final succeeded = await _run(() async {
      final group = await _repository.createGroup(
        name: values[0],
        displayName: values[1],
      );
      _groupId = group['id'] as String;
      await _loadGroups();
    });
    if (succeeded) {
      _createGroupNameDraft = '';
      _createGroupDisplayNameDraft = '';
    } else {
      await _refreshAfterUncertainWrite();
    }
  }

  Future<void> _joinByInvitation() async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => _GuestRequiredTextDialog(
        title: 'Join a group',
        description:
            'Paste an invitation token. Preview checks validity only and reveals no group content.',
        submitLabel: 'Preview invitation',
        fields: [
          _GuestRequiredTextField(
            label: 'Invitation token',
            errorText: 'Enter an invitation token.',
            initialValue: _joinTokenDraft,
          ),
          _GuestRequiredTextField(
            label: 'Display name',
            errorText: 'Enter a display name.',
            initialValue: _joinDisplayNameDraft,
          ),
        ],
      ),
    );
    if (values == null) {
      _joinTokenDraft = '';
      _joinDisplayNameDraft = '';
      return;
    }
    if (!mounted) return;
    final inviteToken = values[0];
    final memberName = values[1];
    _joinTokenDraft = inviteToken;
    _joinDisplayNameDraft = memberName;
    final succeeded = await _run(() async {
      if (!await _repository.previewInvitation(inviteToken)) {
        throw const ApiException(
          'This invitation is unavailable, expired or revoked.',
        );
      }
      if (!mounted) return;
      final join = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request to join?'),
          content: const Text(
            'A group admin must approve your membership. This request does not grant access to group content, and your display name is not identity verification.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Request access'),
            ),
          ],
        ),
      );
      if (join != true) return;
      final membership = await _repository.joinInvitation(
        token: inviteToken,
        displayName: memberName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              membership['status'] == 'pending'
                  ? 'Join request sent; the host must approve before you can access content.'
                  : 'Group membership confirmed.',
            ),
          ),
        );
      }
      await _loadGroups();
    });
    if (succeeded) {
      _joinTokenDraft = '';
      _joinDisplayNameDraft = '';
    } else {
      await _refreshAfterUncertainWrite();
    }
  }

  Future<void> _createInvitation() async {
    final groupId = _groupId;
    if (groupId == null) return;
    String role = 'contributor';
    final selectedRole = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create invitation'),
          content: DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'New member role'),
            items: const [
              DropdownMenuItem(
                value: 'viewer',
                child: Text('Viewer — read only'),
              ),
              DropdownMenuItem(
                value: 'contributor',
                child: Text('Contributor — own content'),
              ),
              DropdownMenuItem(
                value: 'editor',
                child: Text('Editor — edit group content'),
              ),
            ],
            onChanged: (value) => setDialogState(() => role = value ?? role),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, role),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (selectedRole == null || !mounted) return;
    await _run(() async {
      final invitation = await _repository.createInvitation(
        groupId: groupId,
        role: selectedRole,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invitation created'),
          content: SelectableText(
            'Share this one-time token privately. It expires at ${invitation['expires_at']}. '
            'The token is shown only now; revoke unused invitations from the group controls.\n\n${invitation['token']}',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await Clipboard.setData(
                    ClipboardData(text: invitation['token'] as String),
                  );
                  if (!mounted || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invitation token copied.')),
                  );
                  Navigator.pop(context);
                } on Object {
                  if (!mounted || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to copy the invitation token. Select and copy it from the dialog.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Copy token'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      await _loadGroup(groupId);
    });
  }

  Future<void> _showMembers() async {
    final groupId = _groupId;
    if (groupId == null || _group == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group members'),
        content: SizedBox(
          width: 560,
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: ListView(
            children: [
              for (final item
                  in (_group!['members'] as List? ?? const [])
                      .cast<Map<String, dynamic>>())
                ListTile(
                  title: Text(item['display_name'] as String? ?? 'Guest'),
                  subtitle: Text('${item['role']} · ${item['status']}'),
                  trailing:
                      _group!['role'] == 'admin' && item['status'] == 'pending'
                      ? TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _run(() async {
                              await _repository.approveMember(
                                groupId: groupId,
                                memberId: item['id'] as String,
                              );
                              await _loadGroup(groupId);
                            });
                          },
                          child: const Text('Approve'),
                        )
                      : _group!['role'] == 'admin' &&
                            item['role'] != 'admin' &&
                            item['status'] == 'active'
                      ? PopupMenuButton<String>(
                          onSelected: (action) => _manageMemberAction(
                            groupId,
                            item,
                            action,
                            context,
                          ),
                          itemBuilder: (context) => [
                            for (final role in const [
                              'viewer',
                              'contributor',
                              'editor',
                            ])
                              if (role != item['role'])
                                PopupMenuItem(
                                  value: role,
                                  child: Text('Make $role'),
                                ),
                            const PopupMenuItem(
                              value: 'transfer_admin',
                              child: Text('Request admin transfer'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove member'),
                            ),
                          ],
                        )
                      : null,
                ),
              if (_group!['role'] == 'admin') ...[
                const Divider(),
                const Text('Active invitations'),
                for (final invite in _invitations)
                  ListTile(
                    title: Text('${invite['role']} invitation'),
                    subtitle: Text('Expires ${invite['expires_at']}'),
                    trailing: IconButton(
                      tooltip: 'Revoke invitation',
                      icon: const Icon(Icons.link_off),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _run(() async {
                          await _repository.revokeInvitation(
                            groupId: groupId,
                            invitationId: invite['id'] as String,
                          );
                          await _loadGroup(groupId);
                        });
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          if (_group!['role'] == 'admin')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _createInvitation();
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Invite member'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _manageMemberAction(
    String groupId,
    Map<String, dynamic> member,
    String action,
    BuildContext membersDialogContext,
  ) async {
    if (action == 'transfer_admin' || action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            action == 'transfer_admin'
                ? 'Request group administration?'
                : 'Remove this guest member?',
          ),
          content: Text(
            action == 'transfer_admin'
                ? '${member['display_name']} will be asked to accept administration. '
                      'You remain an administrator unless they accept; then you become a contributor. '
                      'The request expires in seven days. This does not affect organisation roles.'
                : '${member['display_name']} will lose access to this group on their next request. Already exported copies cannot be revoked.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                action == 'transfer_admin' ? 'Send request' : 'Remove member',
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (membersDialogContext.mounted) {
      Navigator.of(membersDialogContext).pop();
    }
    await _run(() async {
      if (action == 'remove') {
        await _repository.removeMember(
          groupId: groupId,
          memberId: member['id'] as String,
        );
      } else if (action == 'transfer_admin') {
        await _repository.transferAdministration(
          groupId: groupId,
          memberId: member['id'] as String,
        );
      } else {
        await _repository.changeMemberRole(
          groupId: groupId,
          memberId: member['id'] as String,
          role: action,
        );
      }
      await _loadGroup(groupId);
    });
  }

  Future<void> _createKnowledge() async {
    final groupId = _groupId;
    if (groupId == null) return;
    final draft = _createKnowledgeDrafts[groupId] ?? const <String, String>{};
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => _GuestRequiredTextDialog(
        title: 'Add shared Knowledge',
        description:
            'This item will be stored online for approved group members.',
        submitLabel: 'Share with group',
        fields: [
          _GuestRequiredTextField(
            label: 'Title',
            hintText: 'e.g. How do we book the meeting room?',
            errorText: 'Enter a title.',
            initialValue: draft['title'] ?? '',
          ),
          _GuestRequiredTextField(
            label: 'Knowledge / answer',
            hintText: 'Write the answer the group should find later.',
            errorText: 'Enter the Knowledge or answer.',
            initialValue: draft['body'] ?? '',
            minLines: 3,
            maxLines: 8,
          ),
        ],
      ),
    );
    if (values == null) {
      _createKnowledgeDrafts.remove(groupId);
      return;
    }
    if (!mounted) return;
    _createKnowledgeDrafts[groupId] = {'title': values[0], 'body': values[1]};
    final succeeded = await _run(() async {
      await _repository.createKnowledge(
        groupId: groupId,
        title: values[0],
        body: values[1],
        answer: values[1],
      );
      await _loadGroup(groupId);
    });
    if (succeeded) {
      _createKnowledgeDrafts.remove(groupId);
    } else {
      await _refreshAfterUncertainWrite(groupId: groupId);
    }
  }

  Future<void> _shareSelectedLocalWork() async {
    final groupId = _groupId;
    if (groupId == null) return;
    await _run(() async {
      final local = await ref.read(guestWorkspaceStoreProvider).load();
      if (!mounted) return;
      final groupName = _group?['name'] as String? ?? 'this group';
      final selection = await showDialog<_GuestImportSelection>(
        context: context,
        builder: (context) => _GuestImportPreview(
          data: local,
          title: 'Preview sharing to $groupName',
          confirmLabel: 'Share selected with group',
          includeTemplates: false,
          shareWithGroup: true,
          groupName: groupName,
        ),
      );
      if (selection == null || !mounted) return;
      await _repository.importSelected(
        groupId: groupId,
        data: local,
        knowledgeIds: selection.knowledgeIds,
        sessionIds: selection.sessionIds,
      );
      final refreshed = await _loadGroup(groupId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              refreshed
                  ? 'Selected copies were shared. Your local work remains on this device.'
                  : 'The share request completed, but the group could not be refreshed. Refresh status before sharing again.',
            ),
          ),
        );
      }
    });
  }

  Future<void> _openEntry(Map<String, dynamic> entry) async {
    final groupId = _groupId;
    final uid = _activeUid;
    final generation = _loadGeneration;
    if (groupId == null || uid == null || !_isCurrentLoad(uid, generation)) {
      return;
    }
    bool current() => _isCurrentLoad(uid, generation) && _groupId == groupId;
    var entryDialogActive = true;
    final entryDialog = _showScopedGroupDialog<void>(
      builder: (entryDialogContext) => AlertDialog(
        title: Text(entry['title'] as String? ?? 'Group entry'),
        content: SizedBox(
          width: 700,
          child: _GuestGroupEntryContent(entry: entry),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Map<String, dynamic>? result;
              await _run(() async {
                result = await _repository.exportEntry(
                  groupId: groupId,
                  entryId: entry['id'] as String,
                );
              });
              if (result != null &&
                  current() &&
                  entryDialogActive &&
                  entryDialogContext.mounted &&
                  (ModalRoute.of(entryDialogContext)?.isCurrent ?? false)) {
                entryDialogActive = false;
                Navigator.pop(entryDialogContext);
                await _exportAuthorizedGroupEntry(
                  result!,
                  groupId: groupId,
                  current: current,
                );
              }
            },
            child: const Text('Download / Share PDF'),
          ),
          TextButton(
            onPressed: () => _run(() async {
              final history = await _repository.entryHistory(
                groupId: groupId,
                entryId: entry['id'] as String,
              );
              if (!current() ||
                  !entryDialogActive ||
                  !entryDialogContext.mounted ||
                  !(ModalRoute.of(entryDialogContext)?.isCurrent ?? false)) {
                return;
              }
              await _showScopedGroupDialog<void>(
                builder: (context) => AlertDialog(
                  title: const Text('Entry revisions'),
                  content: SizedBox(
                    width: 640,
                    height: MediaQuery.sizeOf(context).height * 0.55,
                    child: ListView(
                      children: [
                        for (final revision in history)
                          ListTile(
                            title: Text(
                              'Revision ${revision['revision']} · ${revision['title']}',
                            ),
                            subtitle: const Text('Updated by a group member'),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              );
            }),
            child: const Text('History'),
          ),
          if (_canEdit(entry))
            TextButton(
              onPressed: () {
                if (!current()) return;
                entryDialogActive = false;
                Navigator.pop(entryDialogContext);
                _editEntry(entry);
              },
              child: const Text('Edit'),
            ),
          if (_canEdit(entry))
            TextButton(
              onPressed: () {
                if (!current()) return;
                entryDialogActive = false;
                Navigator.pop(entryDialogContext);
                _deleteEntry(entry);
              },
              child: const Text('Delete'),
            ),
          FilledButton(
            onPressed: () {
              entryDialogActive = false;
              Navigator.pop(entryDialogContext);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
    await entryDialog.whenComplete(() => entryDialogActive = false);
  }

  Future<void> _exportAuthorizedGroupEntry(
    Map<String, dynamic> entry, {
    required String groupId,
    required bool Function() current,
  }) async {
    Future<bool> authorize() async {
      if (!current()) return false;
      try {
        await _repository.exportEntry(
          groupId: groupId,
          entryId: entry['id'] as String,
        );
        return current();
      } on Object {
        if (current()) {
          _closeGroupDialogs();
          setState(() => _error = 'Group export unavailable. Refresh access.');
        }
        return false;
      }
    }

    if (!current()) return;
    final title = entry['title'] as String? ?? 'Group entry';
    final data = entry['data'] is Map
        ? Map<String, dynamic>.from(entry['data'] as Map)
        : <String, dynamic>{};
    if (entry['kind'] == 'interact_session') {
      final participants = (data['participants'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final scope = await _showScopedGroupDialog<String>(
        builder: (context) => SimpleDialog(
          title: const Text('Choose report scope'),
          children: [
            for (final participant in participants)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(context, participant['id'] as String?),
                child: Text(
                  'Selected participant — ${participant['name'] ?? 'Participant'}',
                ),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, '*'),
              child: const Text('All participants'),
            ),
          ],
        ),
      );
      if (scope == null || !await authorize()) return;
      final allParticipants = scope == '*';
      final Object? firstParticipantId = participants.firstOrNull?['id'];
      final String? participantId;
      if (allParticipants) {
        participantId = firstParticipantId is String
            ? firstParticipantId
            : null;
      } else {
        participantId = scope;
      }
      final session = {...data, 'title': title};
      final report = composeGuestReport(
        session: session,
        allParticipants: allParticipants,
        participantId: participantId,
        exportedAt: DateTime.now().toUtc(),
      );
      await _showScopedGroupDialog<void>(
        builder: (context) => _GuestReportPreviewDialog(
          report: report,
          onDownload: () => _downloadAuthorizedReport(
            report,
            session,
            allParticipants,
            participantId,
            authorize,
          ),
          onShare: () => _shareAuthorizedReport(
            report,
            session,
            allParticipants,
            participantId,
            authorize,
          ),
          onPrintFallback: () async {
            if (!await authorize()) return;
            openPrintableReport(
              buildGuestReportDocument(
                session: session,
                allParticipants: allParticipants,
                participantId: participantId,
                generatedAt: report.exportedAt,
              ),
            );
          },
        ),
      );
      return;
    }

    final document = GuestPortableDocument(
      title: title,
      scope: 'Authorized group Knowledge entry',
      exportedAt: DateTime.now().toUtc(),
      sections: [
        if (data['body'] is String)
          GuestPortableSection(
            heading: 'Knowledge',
            body: data['body'] as String,
          ),
        if (data['answer'] is String)
          GuestPortableSection(
            heading: 'Answer',
            body: data['answer'] as String,
          ),
      ],
    );
    if (!await authorize()) return;
    await _showScopedGroupDialog<void>(
      builder: (context) => _GuestPortablePreviewDialog(
        document: document,
        onDownload: () => _downloadPortableDocument(document, authorize),
        onShare: () => _sharePortableDocument(document, authorize),
        onPrintFallback: () async {
          if (!await authorize()) return;
          openPrintableReport(buildGuestPortableHtml(document));
        },
      ),
    );
  }

  Future<void> _downloadAuthorizedReport(
    GuestReportData report,
    Map<String, dynamic> session,
    bool allParticipants,
    String? participantId,
    Future<bool> Function() authorize,
  ) async {
    final document = buildGuestReportDocument(
      session: session,
      allParticipants: allParticipants,
      participantId: participantId,
      generatedAt: report.exportedAt,
    );
    try {
      final bytes = await buildGuestReportPdf(report);
      if (!await authorize()) return;
      final status = await _downloadPdfOrShareFile(
        bytes,
        guestReportFilename(report),
        authorize: authorize,
      );
      if (status == ShareResultStatus.success ||
          status == ShareResultStatus.dismissed) {
        return;
      }
    } on UnsupportedPdfCharactersException {
      if (mounted) _showPdfFontFallbackNotice(context);
    } on Object {
      // Fall through to the print-to-PDF fallback.
    }
    if (kIsWeb && await authorize()) openPrintableReport(document);
  }

  Future<void> _shareAuthorizedReport(
    GuestReportData report,
    Map<String, dynamic> session,
    bool allParticipants,
    String? participantId,
    Future<bool> Function() authorize,
  ) async {
    final confirmed = await _confirmPortableCopy();
    if (confirmed != true || !await authorize()) return;
    try {
      final bytes = await buildGuestReportPdf(report);
      if (!await authorize() || !mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Share Interact PDF',
          text: 'Portable PDF copy. Recipients may retain or forward it.',
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: [guestReportFilename(report)],
          downloadFallbackEnabled: false,
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
      if (result.status == ShareResultStatus.dismissed) return;
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        await _downloadAuthorizedReport(
          report,
          session,
          allParticipants,
          participantId,
          authorize,
        );
      }
    } on Object {
      if (mounted) {
        await _downloadAuthorizedReport(
          report,
          session,
          allParticipants,
          participantId,
          authorize,
        );
      }
    }
  }

  Future<void> _downloadPortableDocument(
    GuestPortableDocument document,
    Future<bool> Function() authorize,
  ) async {
    try {
      final bytes = await buildGuestPortablePdf(document);
      if (!await authorize()) return;
      final status = await _downloadPdfOrShareFile(
        bytes,
        guestPortableFilename(document),
        authorize: authorize,
      );
      if (status == ShareResultStatus.success ||
          status == ShareResultStatus.dismissed) {
        return;
      }
    } on UnsupportedPdfCharactersException {
      if (mounted) _showPdfFontFallbackNotice(context);
    } on Object {
      // Fall through to the print-to-PDF fallback.
    }
    if (kIsWeb && await authorize()) {
      openPrintableReport(buildGuestPortableHtml(document));
    }
  }

  Future<void> _sharePortableDocument(
    GuestPortableDocument document,
    Future<bool> Function() authorize,
  ) async {
    final confirmed = await _confirmPortableCopy();
    if (confirmed != true || !await authorize()) return;
    try {
      final bytes = await buildGuestPortablePdf(document);
      if (!await authorize() || !mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Share PDF',
          text: 'Portable PDF copy. Recipients may retain or forward it.',
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: [guestPortableFilename(document)],
          downloadFallbackEnabled: false,
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
      if (result.status == ShareResultStatus.dismissed) return;
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        await _downloadPortableDocument(document, authorize);
      }
    } on UnsupportedPdfCharactersException {
      if (mounted) await _downloadPortableDocument(document, authorize);
      return;
    } on Object {
      if (mounted) await _downloadPortableDocument(document, authorize);
    }
  }

  Future<bool?> _confirmPortableCopy() => _showScopedGroupDialog<bool>(
    builder: (context) => AlertDialog(
      title: const Text('Share a PDF copy?'),
      content: const Text(
        'Recipients can keep or forward this PDF. Removing their group access later cannot revoke a copy they downloaded.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  bool _canEdit(Map<String, dynamic> entry) {
    final role = _group?['role'];
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    return role == 'admin' ||
        role == 'editor' ||
        (role == 'contributor' && entry['created_by_uid'] == uid);
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final groupId = _groupId;
    if (groupId == null) return;
    if (entry['kind'] == 'interact_session') {
      final uid = _activeUid;
      final generation = _loadGeneration;
      if (uid == null || !_canEdit(entry)) return;
      _groupEditorOpen = true;
      try {
        await _showScopedGroupDialog<void>(
          barrierDismissible: false,
          builder: (_) => _GroupInteractEditor(
            entry: entry,
            groupId: groupId,
            groupName: _group?['name'] as String? ?? 'Group',
            uid: uid,
            isOriginCurrent: () =>
                _isCurrentLoad(uid, generation) && _groupId == groupId,
          ),
        );
      } finally {
        _groupEditorOpen = false;
      }
      if (_isCurrentLoad(uid, generation) && _groupId == groupId) {
        await _loadGroup(groupId);
      }
      return;
    }
    final entryId = entry['id'] as String;
    final uid = _activeUid;
    final generation = _loadGeneration;
    if (uid == null || !_isCurrentLoad(uid, generation)) return;
    final sourceData = entry['data'] is Map
        ? Map<String, dynamic>.from(entry['data'] as Map)
        : <String, dynamic>{};
    final values = await _showScopedGroupDialog<Map<String, String>>(
      builder: (context) => _GuestEntryEditDialog(
        title:
            _entryEditDrafts[entryId]?['title'] ??
            entry['title'] as String? ??
            '',
        body:
            _entryEditDrafts[entryId]?['body'] ??
            sourceData['body'] as String? ??
            '',
        answer:
            _entryEditDrafts[entryId]?['answer'] ??
            sourceData['answer'] as String? ??
            '',
        editKnowledge: entry['kind'] != 'interact_session',
      ),
    );
    if (values == null) {
      if (mounted) _entryEditDrafts.remove(entryId);
      return;
    }
    if (!_isCurrentLoad(uid, generation) || _groupId != groupId) return;
    _entryEditDrafts[entryId] = values;
    final editedTitle = values['title']!;
    final updatedData = entry['kind'] == 'interact_session'
        ? sourceData
        : {...sourceData, 'body': values['body']!, 'answer': values['answer']!};
    final succeeded = await _run(() async {
      if (!_isCurrentLoad(uid, generation) || _groupId != groupId) return;
      await _repository.updateEntry(
        groupId: groupId,
        entryId: entryId,
        expectedRevision: entry['revision'] as int,
        title: editedTitle,
        data: updatedData,
      );
      await _loadGroup(groupId);
    });
    if (succeeded) {
      _entryEditDrafts.remove(entryId);
    } else {
      await _refreshAfterUncertainWrite(groupId: groupId);
    }
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete shared entry?'),
        content: const Text(
          'This removes it from the group for all members. Existing downloads cannot be revoked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await _repository.deleteEntry(
        groupId: groupId,
        entryId: entry['id'] as String,
      );
      await _loadGroup(groupId);
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      return true;
    } on Object catch (error) {
      if (mounted) {
        final safeMessage = _safeGuestError(error);
        setState(() => _error = safeMessage);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(safeMessage)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshAfterUncertainWrite({String? groupId}) async {
    if (!mounted) return;
    final failure = _error;
    final refreshed = groupId == null
        ? await _loadGroups()
        : await _loadGroup(groupId);
    if (!mounted) return;
    final refreshFailure = _error;
    setState(() {
      _error = refreshed
          ? '${failure ?? 'The request could not be verified.'} '
                'Status was refreshed. Review it before retrying.'
          : 'The write outcome is uncertain and status refresh failed. '
                '${refreshFailure ?? 'Group status is unavailable.'} '
                'Your draft is retained; refresh status before retrying.';
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      if (next.isLoading) return;
      _identityChanged(next.hasError ? null : next.value);
    });
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (!isVerifiedRegisteredFirebaseUser(user) || user!.uid != _activeUid) {
      final eligible = isVerifiedRegisteredFirebaseUser(user);
      final needsEmailVerification =
          user != null && !user.isAnonymous && !user.emailVerified;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            needsEmailVerification
                ? 'Verify your email to use Groups'
                : 'Groups',
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  needsEmailVerification
                      ? 'Check your email for the verification link. After '
                            'verifying, sign in again to access Groups. No new '
                            'account is needed.'
                      : eligible
                      ? 'Checking account access…'
                      : 'Groups require a registered account with a verified email.',
                  textAlign: TextAlign.center,
                ),
                if (!eligible) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const SignInPage(),
                      ),
                    ),
                    child: const Text('Already have an account? Sign in'),
                  ),
                  if (!needsEmailVerification)
                    FilledButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => SignInPage(createAccount: true),
                        ),
                      ),
                      child: const Text('Create account'),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return _buildGroupsScaffold();
  }

  Widget _buildGroupsScaffold() => Scaffold(
    appBar: AppBar(
      title: const Text('Groups'),
      actions: [
        IconButton(
          tooltip: 'Manage members and invitations',
          onPressed: _group == null ? null : _showMembers,
          icon: const Icon(Icons.group_outlined),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _busy ? null : _loadGroups,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Groups require a registered account with a verified email, but '
                'do not require organisation membership. Group membership does '
                'not grant organisation, department, or private-session access.',
              ),
            ),
            const _GuestInfoButton(
              tooltip: 'Groups information',
              title: 'About groups',
              content:
                  'Groups require a registered Firebase account with a verified '
                  'email, but do not require organisation membership. Group '
                  'membership does not grant organisation, department, or '
                  'private-session access. Group data remains associated with '
                  'its Firebase UID; another account does not inherit it.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy || !_canCreateOrJoin ? null : _createGroup,
              icon: const Icon(Icons.add),
              label: const Text('Create group'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || !_canCreateOrJoin ? null : _joinByInvitation,
              icon: const Icon(Icons.link),
              label: const Text('Join with invitation'),
            ),
          ],
        ),
        if (!_canCreateOrJoin)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_ineligibleIdentityMessage),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          MaterialBanner(
            content: Text(_error!),
            actions: [
              TextButton(
                onPressed: _busy ? null : _refreshStatus,
                child: const Text('Refresh status'),
              ),
            ],
          ),
        ],
        if (_busy) const LinearProgressIndicator(),
        if (_archivedGroups.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Archived groups',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final archived in _archivedGroups)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      archived['name'] as String? ?? 'Group',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _uncertainArchivedDeletionIds.contains(archived['id'])
                          ? 'Deletion status is uncertain; refresh status before retrying.'
                          : archived['can_restore'] == true
                          ? 'Only this same Firebase account can restore by ${archived['restore_until']}. Invitations stay revoked; removed and pending memberships are not reactivated.'
                          : 'The 30-day restore window ended. This account cannot restore the group.',
                    ),
                    if (!_uncertainArchivedDeletionIds.contains(
                          archived['id'],
                        ) &&
                        (archived['can_restore'] == true ||
                            archived['can_delete'] == true)) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!_uncertainArchivedDeletionIds.contains(
                                archived['id'],
                              ) &&
                              archived['can_restore'] == true)
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _restoreArchivedGroup(
                                      archived['id'] as String,
                                    ),
                              child: const Text('Restore'),
                            ),
                          if (!_uncertainArchivedDeletionIds.contains(
                                archived['id'],
                              ) &&
                              archived['can_delete'] == true)
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _deleteArchivedGroup(archived),
                              icon: const Icon(Icons.delete_forever_outlined),
                              label: const Text('Delete permanently'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
        if (_groups.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _groupId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Your approved groups',
            ),
            items: [
              for (final group in _groups)
                DropdownMenuItem(
                  value: group['id'] as String,
                  child: Text(
                    '${group['name']} · ${group['role']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => value == null ? null : _loadGroup(value),
          ),
        ],
        if (_group != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your group role: ${_group!['role']}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const _GuestInfoButton(
                tooltip: 'Group access information',
                title: 'About Group access',
                content:
                    'Approved Group members can access this content. '
                    'Only Group admins manage membership and invitations. '
                    'Search accessible Group Knowledge from Personal '
                    'workspace Ask & search.',
              ),
            ],
          ),
          _adminTransferCard(),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _canCreate ? _createKnowledge : null,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Add shared Knowledge'),
              ),
              OutlinedButton.icon(
                onPressed: _canCreate ? _shareSelectedLocalWork : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Preview and share local work'),
              ),
              OutlinedButton.icon(
                onPressed: _group?['role'] == 'admin'
                    ? _createInvitation
                    : null,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invite'),
              ),
              OutlinedButton.icon(
                onPressed: _busy || _group?['role'] != 'admin'
                    ? null
                    : _archiveGroup,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive group'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            const Text('No shared Knowledge or Interact items are available.')
          else
            for (final entry in _entries)
              Card(
                child: ListTile(
                  leading: Icon(
                    entry['kind'] == 'interact_session'
                        ? Icons.account_tree_outlined
                        : Icons.menu_book_outlined,
                  ),
                  title: Text(entry['title'] as String? ?? 'Shared content'),
                  subtitle: Text(
                    '${entry['kind']} · revision ${entry['revision']} · updated by a group member',
                  ),
                  onTap: () => _openEntry(entry),
                ),
              ),
        ] else if (_error == null && !_busy && _groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No approved groups are linked to this identity. Create a group or request to join with an invitation. A group admin must approve requests before they can read group content.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    ),
  );

  bool get _canCreate =>
      _group?['role'] == 'admin' ||
      _group?['role'] == 'editor' ||
      _group?['role'] == 'contributor';

  bool get _canCreateOrJoin {
    final user = ref.read(firebaseAuthProvider).currentUser;
    return isVerifiedRegisteredFirebaseUser(user);
  }

  String get _ineligibleIdentityMessage {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      return 'Sign in with a registered account and verify its email before '
          'using Groups.';
    }
    return 'Verify this account’s email before using Groups. Local work '
        'remains available.';
  }
}

String _safeGuestError(Object error) {
  if (error is ApiException) return error.message;
  if (error is DioException) return ApiException.fromDio(error).message;
  return 'The group request could not be verified. Check your sign-in and retry.';
}

Future<ShareResultStatus?> _downloadPdfOrShareFile(
  Uint8List bytes,
  String filename, {
  Future<bool> Function()? authorize,
}) async {
  if (authorize != null && !await authorize()) return null;
  if (await downloadPdf(bytes, filename)) return ShareResultStatus.success;
  if (kIsWeb) return null;
  if (authorize != null && !await authorize()) return null;
  final result = await SharePlus.instance.share(
    ShareParams(
      title: 'Save PDF',
      text: 'Choose a destination to save or share this PDF.',
      files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
      fileNameOverrides: [filename],
      downloadFallbackEnabled: false,
    ),
  );
  return result.status;
}

class _GuestEntryEditDialog extends StatefulWidget {
  const _GuestEntryEditDialog({
    required this.title,
    required this.body,
    required this.answer,
    required this.editKnowledge,
  });

  final String title;
  final String body;
  final String answer;
  final bool editKnowledge;

  @override
  State<_GuestEntryEditDialog> createState() => _GuestEntryEditDialogState();
}

class _GuestEntryEditDialogState extends State<_GuestEntryEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _answer;
  late final FocusNode _titleFocus;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.title);
    _body = TextEditingController(text: widget.body);
    _answer = TextEditingController(text: widget.answer);
    _titleFocus = FocusNode();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _answer.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      _titleFocus.requestFocus();
      return;
    }
    Navigator.pop(context, {
      'title': _title.text.trim(),
      'body': _body.text.trim(),
      'answer': _answer.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit group entry'),
    content: SizedBox(
      width: 640,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              focusNode: _titleFocus,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a title.'
                  : null,
            ),
            if (widget.editKnowledge) ...[
              TextField(
                controller: _body,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Knowledge'),
              ),
              TextField(
                controller: _answer,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Answer'),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Interact questions and answers are unchanged.'),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save revision')),
    ],
  );
}

class _GuestRequiredTextField {
  const _GuestRequiredTextField({
    required this.label,
    required this.errorText,
    this.hintText,
    this.initialValue = '',
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final String errorText;

  /// Example shown only while the field is empty; never saved as a value.
  final String? hintText;
  final String initialValue;
  final int minLines;
  final int maxLines;
}

class _GuestRequiredTextDialog extends StatefulWidget {
  const _GuestRequiredTextDialog({
    required this.title,
    required this.submitLabel,
    required this.fields,
    this.description,
  });

  final String title;
  final String submitLabel;
  final List<_GuestRequiredTextField> fields;
  final String? description;

  @override
  State<_GuestRequiredTextDialog> createState() =>
      _GuestRequiredTextDialogState();
}

class _GuestRequiredTextDialogState extends State<_GuestRequiredTextDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final field in widget.fields)
        TextEditingController(text: field.initialValue),
    ];
    _focusNodes = [for (var i = 0; i < widget.fields.length; i++) FocusNode()];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      final firstEmpty = _controllers.indexWhere(
        (controller) => controller.text.trim().isEmpty,
      );
      if (firstEmpty >= 0) _focusNodes[firstEmpty].requestFocus();
      return;
    }
    Navigator.of(
      context,
    ).pop(_controllers.map((controller) => controller.text.trim()).toList());
  }

  Widget _input(int index) {
    final field = widget.fields[index];
    return TextFormField(
      controller: _controllers[index],
      focusNode: _focusNodes[index],
      autofocus: index == 0,
      minLines: field.minLines,
      maxLines: field.maxLines,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hintText,
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? field.errorText : null,
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.description != null) ...[
              Text(widget.description!),
              const SizedBox(height: 12),
            ],
            for (var i = 0; i < widget.fields.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _input(i),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
    ],
  );
}

class _GuestReportPreviewDialog extends StatelessWidget {
  const _GuestReportPreviewDialog({
    required this.report,
    required this.onDownload,
    required this.onShare,
    required this.onPrintFallback,
  });

  final GuestReportData report;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onPrintFallback;

  Widget _question(
    BuildContext context,
    GuestReportQuestion question,
    int depth,
  ) {
    final indent = (depth * 12).clamp(0, 36).toDouble();
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Question ${question.path}${depth > 0 ? ' · Follow-up' : ''}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          if (question.triggerParticipant != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Triggered by ${question.triggerParticipant}: '
                '${question.triggerAnswer?.trim().isNotEmpty == true ? question.triggerAnswer : 'Unanswered.'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SelectableText(
              question.text,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (question.answers.isEmpty)
            const ListTile(
              title: Text('Answer'),
              subtitle: Text('Unanswered.'),
            ),
          for (final answer in question.answers) ...[
            Card(
              margin: EdgeInsets.only(left: indent, top: 8),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Answer — ${answer.participantName}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      answer.body.trim().isEmpty ? 'Unanswered.' : answer.body,
                    ),
                  ],
                ),
              ),
            ),
            for (final followUp in answer.followUps)
              _question(context, followUp, depth + 1),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Preview PDF'),
    content: SizedBox(
      width: 720,
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Portable copy · ${report.scope}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            'Participants: ${report.participantNames.isEmpty ? 'Not selected' : report.participantNames.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Report prepared: ${report.exportedAt.toLocal()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            _pdfFontPreviewMessage(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Text(
            'Download PDF saves a file directly. Browser print opens a separate report; choose Print → Save as PDF.',
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: report.questions.isEmpty
                  ? const [Text('No questions are available in this report.')]
                  : [
                      for (final question in report.questions)
                        _question(context, question, 0),
                    ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('Close'),
          ),
          TextButton(
            onPressed: onPrintFallback,
            child: const Text('Browser print / Save PDF'),
          ),
          OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share PDF'),
          ),
          FilledButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    ],
  );
}

class _GuestPortablePreviewDialog extends StatelessWidget {
  const _GuestPortablePreviewDialog({
    required this.document,
    required this.onDownload,
    required this.onShare,
    required this.onPrintFallback,
  });

  final GuestPortableDocument document;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onPrintFallback;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Preview PDF'),
    content: SizedBox(
      width: 720,
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: ListView(
        children: [
          Text(document.title, style: Theme.of(context).textTheme.titleLarge),
          Text('Portable copy · ${document.scope}'),
          Text('Report prepared: ${document.exportedAt.toLocal()}'),
          Text(_pdfFontPreviewMessage()),
          const Divider(),
          for (final section in document.sections) ...[
            Text(
              section.heading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SelectableText(
              section.body.trim().isEmpty ? 'Not provided.' : section.body,
            ),
            const SizedBox(height: 16),
          ],
          if (document.sections.isEmpty)
            const Text('No report content is available.'),
        ],
      ),
    ),
    actions: [
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('Close'),
          ),
          TextButton(
            onPressed: onPrintFallback,
            child: const Text('Browser print / Save PDF'),
          ),
          OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share PDF'),
          ),
          FilledButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    ],
  );
}

class _GuestGroupEntryContent extends StatelessWidget {
  const _GuestGroupEntryContent({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final data = entry['data'] is Map
        ? Map<String, dynamic>.from(entry['data'] as Map)
        : <String, dynamic>{};
    if (entry['kind'] != 'interact_session') {
      return ListView(
        shrinkWrap: true,
        children: [
          for (final item in [
            ('Knowledge', data['body']),
            ('Answer', data['answer']),
          ])
            if (item.$2 is String && (item.$2 as String).isNotEmpty) ...[
              Text(item.$1, style: Theme.of(context).textTheme.titleSmall),
              SelectableText(item.$2 as String),
              const SizedBox(height: 12),
            ],
        ],
      );
    }
    final report = composeGuestReport(
      session: {
        ...data,
        'title': entry['title'] as String? ?? 'Interact session',
      },
      allParticipants: true,
      participantId: null,
      exportedAt: DateTime.now().toUtc(),
    );
    return ListView(
      shrinkWrap: true,
      children: [
        Text(
          'All participants · ${report.participantNames.join(', ')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final question in report.questions)
          _GuestEntryQuestionContent(question: question, depth: 0),
      ],
    );
  }
}

class _GuestEntryQuestionContent extends StatelessWidget {
  const _GuestEntryQuestionContent({
    required this.question,
    required this.depth,
  });

  final GuestReportQuestion question;
  final int depth;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: (depth * 12).clamp(0, 36).toDouble(),
      top: 12,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(question.text, style: Theme.of(context).textTheme.titleSmall),
        if (question.triggerParticipant != null)
          Text(
            'Triggered by ${question.triggerParticipant}: '
            '${question.triggerAnswer?.trim().isNotEmpty == true ? question.triggerAnswer : 'Unanswered.'}',
          ),
        if (question.answers.isEmpty) const Text('Unanswered.'),
        for (final answer in question.answers) ...[
          Text('Answer — ${answer.participantName}'),
          SelectableText(
            answer.body.trim().isEmpty ? 'Unanswered.' : answer.body,
          ),
          for (final followUp in answer.followUps)
            _GuestEntryQuestionContent(question: followUp, depth: depth + 1),
        ],
      ],
    ),
  );
}

class _GuestImportSelection {
  const _GuestImportSelection({
    required this.knowledgeIds,
    required this.sessionIds,
    required this.templateIds,
  });

  final Set<String> knowledgeIds;
  final Set<String> sessionIds;
  final Set<String> templateIds;
}

class _GuestImportPreview extends StatefulWidget {
  const _GuestImportPreview({
    required this.data,
    this.title = 'Confirm selected local import',
    this.confirmLabel = 'Import selected locally',
    this.includeTemplates = true,
    this.shareWithGroup = false,
    this.personalAccountImport = false,
    this.groupName,
  });

  final GuestWorkspaceData data;
  final String title;
  final String confirmLabel;
  final bool includeTemplates;
  final bool shareWithGroup;
  final bool personalAccountImport;
  final String? groupName;

  @override
  State<_GuestImportPreview> createState() => _GuestImportPreviewState();
}

class _GuestImportPreviewState extends State<_GuestImportPreview> {
  late final Set<String> _knowledge = widget.shareWithGroup
      ? <String>{}
      : widget.data.knowledge.map((item) => item['id'] as String).toSet();
  late final Set<String> _sessions = widget.shareWithGroup
      ? <String>{}
      : widget.data.sessions.map((item) => item['id'] as String).toSet();
  late final Set<String> _templates = widget.includeTemplates
      ? widget.data.templates.map((item) => item['id'] as String).toSet()
      : <String>{};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 560,
      height: MediaQuery.sizeOf(context).height * 0.65,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.shareWithGroup
                  ? 'Sharing uploads selected copies online to '
                        '${widget.groupName ?? 'this group'}. '
                        'Approved group members may be able to access them. '
                        'Your local originals stay on this device. If an item '
                        'from this identity was already shared to this group, '
                        'its existing group copy is reused without being '
                        'overwritten.'
                  : widget.personalAccountImport
                  ? 'Selected items are copied to your private personal account, available after sign-in on other devices. Your browser-local originals stay on this device. The data is not added to an organisation, group, or shared Knowledge index.'
                  : 'Selected items are added locally. Existing items with matching IDs are kept unchanged.',
            ),
          ),
          for (final item in widget.data.knowledge)
            CheckboxListTile(
              value: _knowledge.contains(item['id']),
              title: Text(item['title'] as String? ?? 'Knowledge'),
              onChanged: (selected) => setState(() {
                _toggle(_knowledge, item['id'] as String, selected);
              }),
            ),
          for (final item in widget.data.sessions)
            CheckboxListTile(
              value: _sessions.contains(item['id']),
              title: Text(item['title'] as String? ?? 'Interact session'),
              subtitle: Text(
                widget.shareWithGroup
                    ? 'Sharing uploads all participants and answer-owned branches'
                    : 'Includes all participants and answer-owned branches',
              ),
              onChanged: (selected) => setState(() {
                _toggle(_sessions, item['id'] as String, selected);
              }),
            ),
          if (!widget.includeTemplates && widget.data.templates.isNotEmpty)
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Local templates remain on this device'),
            ),
          if (widget.includeTemplates)
            for (final item in widget.data.templates)
              CheckboxListTile(
                value: _templates.contains(item['id']),
                title: Text(item['name'] as String? ?? 'Template'),
                onChanged: (selected) => setState(() {
                  _toggle(_templates, item['id'] as String, selected);
                }),
              ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            (widget.shareWithGroup &&
                    _knowledge.isEmpty &&
                    _sessions.isEmpty) ||
                (widget.personalAccountImport &&
                    _knowledge.isEmpty &&
                    _sessions.isEmpty &&
                    _templates.isEmpty)
            ? null
            : () => Navigator.pop(
                context,
                _GuestImportSelection(
                  knowledgeIds: _knowledge,
                  sessionIds: _sessions,
                  templateIds: _templates,
                ),
              ),
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}

void _toggle(Set<String> selection, String id, bool? selected) {
  if (selected == true) {
    selection.add(id);
  } else {
    selection.remove(id);
  }
}

Map<String, dynamic> _copyMap(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>,
    );

void _ensureAnswer(Map<String, dynamic> question, String participantId) {
  final answers = question['answers'] as List;
  if (answers.any(
    (item) => (item as Map<String, dynamic>)['participant_id'] == participantId,
  )) {
    return;
  }
  answers.add({
    'participant_id': participantId,
    'body': '',
    'branches_collapsed': false,
    'follow_ups': <Map<String, dynamic>>[],
  });
}

void _replaceQuestion(
  Map<String, dynamic> session,
  Map<String, dynamic> updated,
  ValueChanged<Map<String, dynamic>> onChange,
) {
  final copy = _copyMap(session);
  final roots = copy['questions'] as List;
  _replaceInQuestions(roots, updated);
  onChange(copy);
}

bool _replaceInQuestions(List questions, Map<String, dynamic> updated) {
  for (var index = 0; index < questions.length; index++) {
    final question = questions[index] as Map<String, dynamic>;
    if (question['id'] == updated['id']) {
      questions[index] = updated;
      return true;
    }
    for (final answer in (question['answers'] as List? ?? const [])) {
      final branches =
          (answer as Map<String, dynamic>)['follow_ups'] as List? ?? const [];
      if (_replaceInQuestions(branches, updated)) return true;
    }
  }
  return false;
}

Map<String, dynamic>? _findGuestQuestion(List questions, String questionId) {
  for (final item in questions) {
    if (item is! Map<String, dynamic>) continue;
    if (item['id'] == questionId) return item;
    for (final answer in (item['answers'] as List? ?? const [])) {
      if (answer is! Map) continue;
      final found = _findGuestQuestion(
        answer['follow_ups'] as List? ?? const [],
        questionId,
      );
      if (found != null) return found;
    }
  }
  return null;
}

Map<String, dynamic>? _guestAnswerFor(
  List questions,
  String questionId,
  String participantId,
) {
  final question = _findGuestQuestion(questions, questionId);
  final answers = question?['answers'] as List?;
  if (answers == null) return null;
  for (final answer in answers) {
    if (answer is Map<String, dynamic> &&
        answer['participant_id'] == participantId) {
      return answer;
    }
  }
  return null;
}
