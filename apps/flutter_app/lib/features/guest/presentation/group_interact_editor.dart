part of 'guest_workspace_page.dart';

class _GroupInteractEditor extends ConsumerStatefulWidget {
  const _GroupInteractEditor({
    required this.entry,
    required this.groupId,
    required this.groupName,
    required this.uid,
    required this.isOriginCurrent,
  });

  final Map<String, dynamic> entry;
  final String groupId;
  final String groupName;
  final String uid;
  final bool Function() isOriginCurrent;

  @override
  ConsumerState<_GroupInteractEditor> createState() =>
      _GroupInteractEditorState();
}

class _GroupInteractEditorState extends ConsumerState<_GroupInteractEditor>
    with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  BuildContext? _editorContext;
  late Map<String, dynamic> _baseline;
  late Map<String, dynamic> _draft;
  bool _busy = false;
  bool _unavailable = false;
  bool _uncertain = false;
  bool _conflict = false;
  bool _closing = false;
  int _editorGeneration = 0;
  String _status = 'Saved Group copy';

  GuestGroupRepository get _repository =>
      ref.read(guestGroupRepositoryProvider);
  bool get _current {
    if (!mounted || !widget.isOriginCurrent()) return false;
    final user = ref.read(firebaseAuthProvider).currentUser;
    return isVerifiedRegisteredFirebaseUser(user) && user!.uid == widget.uid;
  }

  Map<String, dynamic> _session(Map<String, dynamic> entry) => {
    ..._copyMap(Map<String, dynamic>.from(entry['data'] as Map)),
    'title': entry['title'],
  };
  Map<String, dynamic> _data(Map<String, dynamic> session) {
    final data = _copyMap(session);
    // Entry title is authoritative; retain the payload's existing title field.
    if ((_baseline['data'] as Map).containsKey('title')) {
      data['title'] = (_baseline['data'] as Map)['title'];
    } else {
      data.remove('title');
    }
    return data;
  }

  bool _matches(Map<String, dynamic> entry, Map<String, dynamic> session) =>
      entry['title'] == session['title'] &&
      _sameValue(entry['data'], _data(session));
  bool _sameValue(Object? left, Object? right) {
    if (left is Map && right is Map) {
      return left.length == right.length &&
          left.keys.every(
            (key) =>
                right.containsKey(key) && _sameValue(left[key], right[key]),
          );
    }
    if (left is List && right is List) {
      return left.length == right.length &&
          List.generate(
            left.length,
            (index) => index,
          ).every((index) => _sameValue(left[index], right[index]));
    }
    return left == right;
  }

  bool get _dirty => !_closing && !_unavailable && !_matches(_baseline, _draft);

  @override
  void initState() {
    super.initState();
    _baseline = _copyMap(widget.entry);
    _draft = _session(_baseline);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAccess());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccess();
  }

  Future<void> _refreshAccess() async {
    if (_busy || _unavailable || !_current) return;
    _beginBusy();
    try {
      final remote = await _readAuthorized();
      if (remote == null) return;
      if (remote['revision'] != _baseline['revision']) {
        setState(() {
          if (_dirty || _uncertain || _conflict) {
            _conflict = true;
            _status = 'Conflict: draft kept. Review the latest Group copy.';
          } else {
            _baseline = _copyMap(remote);
            _draft = _session(remote);
            _editorGeneration++;
            _status = 'Saved Group copy · revision ${remote['revision']}';
          }
        });
      }
    } on Object catch (error) {
      if (!_current) {
        _invalidate();
      } else if (_denied(error)) {
        _unavailableNow();
      } else {
        setState(
          () => _status =
              'Access could not be refreshed. Saving requires a fresh permission check.',
        );
      }
    } finally {
      if (_current && !_closing) setState(() => _busy = false);
    }
  }

  void _invalidate() {
    if (!mounted || _closing) return;
    _closing = true;
    _draft = {};
    _baseline = {};
    // All editor dialogs live on the nested navigator and are disposed together.
    Navigator.of(context).pop();
  }

  void _beginBusy() {
    final editorContext = _editorContext;
    if (editorContext != null) FocusScope.of(editorContext).unfocus();
    setState(() => _busy = true);
  }

  void _unavailableNow() {
    if (!_current) {
      _invalidate();
      return;
    }
    setState(() {
      _unavailable = true;
      _draft = {};
      _baseline = {};
      _status =
          'Group copy unavailable. Access changed or the copy was removed.';
    });
    _navigator.currentState?.popUntil((route) => route.isFirst);
  }

  bool _canEdit(Map<String, dynamic> group, Map<String, dynamic> entry) =>
      group['archived_at'] == null &&
      (group['role'] == 'admin' ||
          group['role'] == 'editor' ||
          (group['role'] == 'contributor' &&
              entry['created_by_uid'] == widget.uid));

  Future<Map<String, dynamic>?> _readAuthorized() async {
    if (!_current) {
      _invalidate();
      return null;
    }
    final group = await _repository.getGroup(widget.groupId);
    if (!_current) {
      _invalidate();
      return null;
    }
    final entry = await _repository.getEntry(
      groupId: widget.groupId,
      entryId: widget.entry['id'] as String,
    );
    if (!_current) {
      _invalidate();
      return null;
    }
    if (entry['id'] != widget.entry['id'] || !_canEdit(group, entry)) {
      _unavailableNow();
      return null;
    }
    return entry;
  }

  bool _denied(Object error) =>
      error is ApiException &&
      (error.statusCode == 403 || error.statusCode == 404);

  Future<bool> _save() async {
    if (_busy || _unavailable || _conflict || _uncertain || !_current) {
      return false;
    }
    final attempted = _copyMap(_draft);
    final editorContext = _editorContext;
    if (editorContext != null) FocusScope.of(editorContext).unfocus();
    setState(() {
      _busy = true;
      _status = 'Saving Group copy…';
    });
    var wrote = false;
    try {
      final remote = await _readAuthorized();
      if (remote == null) return false;
      if (remote['revision'] != _baseline['revision'] ||
          !_matches(remote, _session(_baseline))) {
        setState(() {
          _conflict = true;
          _status = 'Conflict: draft kept. Review the latest Group copy.';
        });
        return false;
      }
      if (!_current) return false;
      wrote = true;
      final saved = await _repository.updateEntry(
        groupId: widget.groupId,
        entryId: widget.entry['id'] as String,
        title: attempted['title'] as String,
        data: _data(attempted),
        expectedRevision: _baseline['revision'] as int,
      );
      if (!_current) {
        _invalidate();
        return false;
      }
      if (saved['id'] != widget.entry['id'] ||
          saved['revision'] != (_baseline['revision'] as int) + 1 ||
          !_matches(saved, attempted)) {
        throw const ApiException('The save response could not be confirmed.');
      }
      setState(() {
        _baseline = _copyMap(saved);
        _draft = _session(saved);
        _status = 'Saved Group copy · revision ${saved['revision']}';
      });
      return true;
    } on Object catch (error) {
      if (!_current) {
        _invalidate();
      } else if (_denied(error)) {
        _unavailableNow();
      } else {
        setState(() {
          _conflict = error is ApiException && error.statusCode == 409;
          _uncertain = wrote && !_conflict;
          _status = _conflict
              ? 'Conflict: draft kept. Review the latest Group copy.'
              : 'Save unconfirmed. Draft kept. ${wrote ? 'Check save status before retrying.' : 'Retry when available.'}';
        });
      }
      return false;
    } finally {
      if (_current && !_closing) setState(() => _busy = false);
    }
  }

  Future<void> _reconcile() async {
    if (_busy || !_current || _unavailable) return;
    _beginBusy();
    try {
      final remote = await _readAuthorized();
      if (remote == null) return;
      setState(() {
        _uncertain = false;
        if (_matches(remote, _draft)) {
          _conflict = false;
          _baseline = _copyMap(remote);
          _status =
              'Saved Group copy confirmed · revision ${remote['revision']}';
        } else if (remote['revision'] == _baseline['revision'] &&
            _matches(remote, _session(_baseline))) {
          _conflict = false;
          _status = 'Not saved. Draft kept; safe to retry Save Group copy.';
        } else {
          _conflict = true;
          _status = 'Conflict: draft kept. Review the latest Group copy.';
        }
      });
    } on Object catch (error) {
      if (!_current) {
        _invalidate();
      } else if (_denied(error)) {
        _unavailableNow();
      } else {
        setState(() => _status = 'Save still unconfirmed. Draft kept.');
      }
    } finally {
      if (_current && !_closing) setState(() => _busy = false);
    }
  }

  BuildContext? get _dialogContext => _editorContext;

  Future<void> _review() async {
    if (_busy || !_current || _unavailable) return;
    _beginBusy();
    try {
      final remote = await _readAuthorized();
      final dialogContext = _dialogContext;
      if (remote == null || dialogContext == null || !dialogContext.mounted) {
        return;
      }
      final discard = await showDialog<bool>(
        context: dialogContext,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          title: const Text('Review competing Group edit'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your unsaved draft is kept unless you explicitly discard it. No overwrite or automatic retry.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Your draft:\n${const JsonEncoder.withIndent('  ').convert(_draft)}',
                ),
                const SizedBox(height: 12),
                Text(
                  'Latest revision ${remote['revision']}:\n${const JsonEncoder.withIndent('  ').convert(_session(remote))}',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep draft'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard draft and load latest'),
            ),
          ],
        ),
      );
      if (discard == true && _current) {
        setState(() {
          _baseline = _copyMap(remote);
          _draft = _session(remote);
          _editorGeneration++;
          _conflict = false;
          _uncertain = false;
          _status = 'Latest Group copy loaded · revision ${remote['revision']}';
        });
      }
    } on Object catch (error) {
      if (!_current) {
        _invalidate();
      } else if (_denied(error)) {
        _unavailableNow();
      } else {
        setState(() => _status = 'Latest copy could not be read. Draft kept.');
      }
    } finally {
      if (_current && !_closing) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy || _closing) return;
    if (!_current) {
      _invalidate();
      return;
    }
    if (!_unavailable && (_dirty || _uncertain || _conflict)) {
      final dialogContext = _dialogContext;
      if (dialogContext == null) return;
      final choice = await showDialog<String>(
        context: dialogContext,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          title: const Text('Leave Group copy editor?'),
          content: Text(
            _uncertain
                ? 'The last save is unconfirmed and may have applied. Discard closes only this draft; it cannot undo a remote write.'
                : 'This Group copy has unsaved edits. The original is unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Discard draft'),
            ),
            if (!_conflict && !_uncertain)
              FilledButton(
                onPressed: () => Navigator.pop(context, 'save'),
                child: const Text('Save and close'),
              ),
          ],
        ),
      );
      if (!_current || choice == null || choice == 'cancel') return;
      if (choice == 'save' && !await _save()) return;
    }
    if (_current && mounted) {
      _closing = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _export() async {
    if (_busy || !_current || _unavailable) return;
    _beginBusy();
    try {
      // Export only an authorised persisted revision, never an unconfirmed draft.
      final remote = await _readAuthorized();
      if (remote == null) return;
      final exported = await _repository.exportEntry(
        groupId: widget.groupId,
        entryId: widget.entry['id'] as String,
      );
      final dialogContext = _dialogContext;
      if (!_current || dialogContext == null || !dialogContext.mounted) return;
      final confirmed = await showDialog<bool>(
        context: dialogContext,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          title: const Text('Copy saved Group session JSON?'),
          content: const Text(
            'This exports the saved Group copy, not unsaved edits or the original. Recipients may retain it after access is removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Copy saved JSON'),
            ),
          ],
        ),
      );
      if (confirmed != true || !_current) return;
      // Membership may have changed while the confirmation was open.
      if (await _readAuthorized() == null || !_current) return;
      await Clipboard.setData(ClipboardData(text: jsonEncode(exported)));
    } on Object catch (error) {
      if (!_current) {
        _invalidate();
      } else if (_denied(error)) {
        _unavailableNow();
      } else {
        setState(() => _status = 'Export unavailable. No copy confirmed.');
      }
    } finally {
      if (_current && !_closing) setState(() => _busy = false);
    }
  }

  Future<void> _history() async {
    if (_busy || !_current || _unavailable) return;
    _beginBusy();
    try {
      if (await _readAuthorized() == null) return;
      final history = await _repository.entryHistory(
        groupId: widget.groupId,
        entryId: widget.entry['id'] as String,
      );
      final dialogContext = _dialogContext;
      if (!_current || dialogContext == null || !dialogContext.mounted) return;
      await showDialog<void>(
        context: dialogContext,
        useRootNavigator: false,
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      if (!_current) {
        _invalidate();
      } else if (_denied(error)) {
        _unavailableNow();
      } else {
        setState(() => _status = 'History unavailable. Draft kept.');
      }
    } finally {
      if (_current && !_closing) setState(() => _busy = false);
    }
  }

  Future<void> _report(String? participantId) async {
    if (_busy || !_current || _unavailable) return;
    _beginBusy();
    try {
      if (await _readAuthorized() == null) return;
      final exported = await _repository.exportEntry(
        groupId: widget.groupId,
        entryId: widget.entry['id'] as String,
      );
      var dialogContext = _dialogContext;
      if (!_current || dialogContext == null || !dialogContext.mounted) return;
      final scope = await showDialog<String>(
        context: dialogContext,
        useRootNavigator: false,
        builder: (context) => SimpleDialog(
          title: const Text('Saved Group copy report scope'),
          children: [
            if (participantId != null)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, participantId),
                child: const Text('Selected participant'),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, '*'),
              child: const Text('All participants'),
            ),
          ],
        ),
      );
      dialogContext = _dialogContext;
      if (scope == null ||
          !_current ||
          dialogContext == null ||
          !dialogContext.mounted) {
        return;
      }
      final session = _session(exported);
      final allParticipants = scope == '*';
      final selected = allParticipants ? null : scope;
      final report = composeGuestReport(
        session: session,
        allParticipants: allParticipants,
        participantId: selected,
        exportedAt: DateTime.now().toUtc(),
      );
      Future<bool> authorize() async {
        if (!_current) return false;
        try {
          return await _readAuthorized() != null && _current;
        } on Object catch (error) {
          if (!_current) {
            _invalidate();
          } else if (_denied(error)) {
            _unavailableNow();
          } else {
            setState(
              () => _status =
                  'Export authorization unconfirmed. No copy created.',
            );
          }
          return false;
        }
      }

      Future<void> printCopy() async {
        if (!await authorize()) return;
        openPrintableReport(
          buildGuestReportDocument(
            session: session,
            allParticipants: allParticipants,
            participantId: selected,
            generatedAt: report.exportedAt,
          ),
        );
      }

      Future<void> pdfCopy({required bool share}) async {
        final confirmationContext = _dialogContext;
        if (!_current ||
            confirmationContext == null ||
            !confirmationContext.mounted) {
          return;
        }
        final confirmed = await showDialog<bool>(
          context: confirmationContext,
          useRootNavigator: false,
          builder: (context) => AlertDialog(
            title: const Text('Export a saved Group PDF copy?'),
            content: const Text(
              'Unsaved edits are excluded. Recipients may keep or forward this copy after Group access is removed.',
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
        if (confirmed != true || !await authorize()) return;
        try {
          final bytes = await buildGuestReportPdf(report);
          if (!_current || !await authorize()) return;
          if (!share && await downloadPdf(bytes, guestReportFilename(report))) {
            return;
          }
          if (!_current || !await authorize()) return;
          if (kIsWeb && !share) {
            await printCopy();
            return;
          }
          if (!mounted) return;
          final box = context.findRenderObject() as RenderBox?;
          await SharePlus.instance.share(
            ShareParams(
              title: 'Share Interact PDF',
              text: 'Portable saved Group copy. Recipients may retain it.',
              files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
              fileNameOverrides: [guestReportFilename(report)],
              downloadFallbackEnabled: false,
              sharePositionOrigin: box == null
                  ? null
                  : box.localToGlobal(Offset.zero) & box.size,
            ),
          );
        } on UnsupportedPdfCharactersException {
          if (_current && mounted) {
            _showPdfFontFallbackNotice(context);
            await printCopy();
          }
        } on Object {
          if (_current) {
            setState(
              () => _status = 'PDF export unconfirmed. Try browser print.',
            );
          }
        }
      }

      await showDialog<void>(
        context: dialogContext,
        useRootNavigator: false,
        builder: (context) => _GuestReportPreviewDialog(
          report: report,
          onDownload: () => pdfCopy(share: false),
          onShare: () => pdfCopy(share: true),
          onPrintFallback: printCopy,
        ),
      );
    } on Object catch (error) {
      if (!_current) {
        _invalidate();
      } else if (_denied(error)) {
        _unavailableNow();
      } else {
        setState(() => _status = 'Report unavailable. No copy confirmed.');
      }
    } finally {
      if (_current && !_closing) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      final user = next.value;
      if (next.hasValue &&
          (!isVerifiedRegisteredFirebaseUser(user) ||
              user!.uid != widget.uid)) {
        _invalidate();
      }
    });
    if (_closing) return const SizedBox.shrink();
    return Dialog.fullscreen(
      child: PopScope(
        canPop: _closing,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: ScaffoldMessenger(
          child: Navigator(
            key: _navigator,
            onDidRemovePage: (_) {},
            pages: [
              MaterialPage<void>(
                child: Builder(
                  builder: (context) {
                    if (_closing || !_current) return const SizedBox.shrink();
                    _editorContext = context;
                    return Scaffold(
                      appBar: AppBar(
                        automaticallyImplyLeading: false,
                        toolbarHeight: 48,
                        title: Text(
                          'Edit shared copy',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        actions: [
                          _GuestInfoButton(
                            tooltip: 'Group copy information',
                            title: 'About this Group copy',
                            content:
                                'Group: ${widget.groupName} · Shared copy\n\n'
                                'Edits affect this Group copy only. Personal/local '
                                'originals stay separate. Use Save Group copy to '
                                'confirm changes; closing an unsaved draft requires '
                                'your choice. Revision history shows saved copies.',
                          ),
                          IconButton(
                            tooltip: 'Group copy revision history',
                            onPressed: _busy || _unavailable ? null : _history,
                            icon: const Icon(Icons.history),
                          ),
                          IconButton(
                            tooltip: 'Close Group editor',
                            onPressed: _busy ? null : _close,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      body: SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: constraints.maxHeight * 0.4,
                                ),
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (!_unavailable)
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              FilledButton(
                                                onPressed:
                                                    _busy ||
                                                        _conflict ||
                                                        _uncertain ||
                                                        !_dirty
                                                    ? null
                                                    : _save,
                                                child: const Text(
                                                  'Save Group copy',
                                                ),
                                              ),
                                              Semantics(
                                                liveRegion: true,
                                                child: Text(_status),
                                              ),
                                              if (_uncertain)
                                                OutlinedButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : _reconcile,
                                                  child: const Text(
                                                    'Check save status',
                                                  ),
                                                ),
                                              if (_conflict)
                                                OutlinedButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : _review,
                                                  child: const Text(
                                                    'Review latest copy',
                                                  ),
                                                ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_unavailable)
                                Expanded(
                                  child: Center(
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(_status),
                                    ),
                                  ),
                                )
                              else ...[
                                Expanded(
                                  child: AbsorbPointer(
                                    absorbing: _busy || _uncertain,
                                    child: _GuestSessionEditor(
                                      key: ValueKey(
                                        '${widget.uid}/${widget.groupId}/${widget.entry['id']}/$_editorGeneration',
                                      ),
                                      session: _draft,
                                      storageStatus: _status,
                                      isPersonalAccount: false,
                                      privateWorkspace: false,
                                      groupName: widget.groupName,
                                      onBack: _close,
                                      onChange: (session) {
                                        if (!_current ||
                                            _busy ||
                                            _uncertain ||
                                            _unavailable) {
                                          return;
                                        }
                                        setState(() {
                                          _draft = _copyMap(session);
                                          if (!_conflict) {
                                            _status =
                                                'Unsaved Group copy draft';
                                          }
                                        });
                                      },
                                      onDelete: () {},
                                      onSaveTemplate: () {},
                                      onPrint: _report,
                                      onCopyJson: _export,
                                      makeQuestion: _newGuestQuestion,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
