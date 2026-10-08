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

class _GroupInteractEditorState extends ConsumerState<_GroupInteractEditor> {
  final _navigator = GlobalKey<NavigatorState>();
  BuildContext? _editorContext;
  late Map<String, dynamic> _baseline;
  late Map<String, dynamic> _draft;
  bool _busy = false;
  bool _unavailable = false;
  bool _uncertain = false;
  bool _conflict = false;
  bool _closing = false;
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
      data['title'] = session['title'];
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

  bool get _dirty => !_matches(_baseline, _draft);

  @override
  void initState() {
    super.initState();
    _baseline = _copyMap(widget.entry);
    _draft = _session(_baseline);
  }

  void _invalidate() {
    if (!mounted || _closing) return;
    _closing = true;
    _draft = {};
    _baseline = {};
    // All editor dialogs live on the nested navigator and are disposed together.
    Navigator.of(context).pop();
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
    final entries = await _repository.searchEntries(groupId: widget.groupId);
    if (!_current) {
      _invalidate();
      return null;
    }
    final entry = entries
        .where((e) => e['id'] == widget.entry['id'])
        .firstOrNull;
    if (entry == null || !_canEdit(group, entry)) {
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
    setState(() => _busy = true);
    try {
      final remote = await _readAuthorized();
      if (remote == null) return;
      setState(() {
        _uncertain = false;
        if (_matches(remote, _draft)) {
          _baseline = _copyMap(remote);
          _status =
              'Saved Group copy confirmed · revision ${remote['revision']}';
        } else if (remote['revision'] == _baseline['revision'] &&
            _matches(remote, _session(_baseline))) {
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
    setState(() => _busy = true);
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
    setState(() => _busy = true);
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
    return Dialog.fullscreen(
      child: PopScope(
        canPop: _closing,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Navigator(
          key: _navigator,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              _editorContext = context;
              return Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('Edit shared copy'),
                  actions: [
                    IconButton(
                      tooltip: 'Close Group editor',
                      onPressed: _busy ? null : _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                body: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Group: ${widget.groupName} · Shared copy\nEdits affect this Group copy only. Personal/local originals stay separate.',
                        ),
                      ),
                      if (_unavailable)
                        Expanded(child: Center(child: Text(_status)))
                      else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              FilledButton(
                                onPressed:
                                    _busy || _conflict || _uncertain || !_dirty
                                    ? null
                                    : _save,
                                child: const Text('Save Group copy'),
                              ),
                              if (_uncertain)
                                OutlinedButton(
                                  onPressed: _busy ? null : _reconcile,
                                  child: const Text('Check save status'),
                                ),
                              if (_conflict)
                                OutlinedButton(
                                  onPressed: _busy ? null : _review,
                                  child: const Text('Review latest copy'),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: _busy || _uncertain,
                            child: _GuestSessionEditor(
                              key: ValueKey(
                                '${widget.uid}/${widget.groupId}/${widget.entry['id']}',
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
                                    _status = 'Unsaved Group copy draft';
                                  }
                                });
                              },
                              onDelete: () {},
                              onSaveTemplate: () {},
                              onPrint: (_) => _export(),
                              onCopyJson: _export,
                              makeQuestion: _newGuestQuestion,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
