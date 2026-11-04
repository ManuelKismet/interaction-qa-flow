import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'nia_hint_storage.dart';

/// One optional teaching slot per account. Only lesson identifiers and the
/// explicit enabled preference are stored locally; no draft or workflow data.
class NiaTeaching extends ChangeNotifier {
  NiaTeaching({
    String? Function(String)? read,
    void Function(String, String)? write,
  }) : _read = read ?? readNiaHintPreference,
       _write = write ?? writeNiaHintPreference;
  final String? Function(String) _read;
  final void Function(String, String) _write;
  String? _subject;
  Object? _owner;
  String? _active;
  bool _remember = true;
  final _seen = <String>{};
  bool enabled = true, ready = false, _disposed = false, _queued = false;
  String get _key => 'intqaflow.nia.guidance.v1.' + (_subject ?? 'unbound');
  bool seen(String id) => _seen.contains(id);
  bool owns(Object owner) => identical(_owner, owner);
  void _changed() {
    if (_queued || _disposed) return;
    _queued = true;
    scheduleMicrotask(() {
      _queued = false;
      if (!_disposed) notifyListeners();
    });
  }

  void bind(String subject) {
    if (_subject == subject) return;
    _subject = subject;
    _owner = null;
    _active = null;
    _seen.clear();
    ready = false;
    enabled = true;
    try {
      final raw = _read(_key);
      if (raw != null && raw.length <= 8192) {
        final data = jsonDecode(raw);
        if (data is Map) {
          enabled = data['enabled'] != false;
          final seen = data['seen'];
          if (seen is List)
            _seen.addAll(
              seen.whereType<String>().where((id) => id.length <= 80).take(64),
            );
        }
      }
      ready = true;
    } on Object {
      /* Optional teaching fails quiet when preferences cannot load. */
    }
    _changed();
  }

  bool claim(Object owner, String id, {bool remember = true}) {
    if (_disposed ||
        !ready ||
        !enabled ||
        (remember && _seen.contains(id)) ||
        id.length > 80 ||
        (_owner != null && !owns(owner)))
      return false;
    _owner = owner;
    _active = id;
    _remember = remember;
    return true;
  }

  void shown(Object owner, String id) {
    if (!owns(owner) || _active != id || !enabled || !ready) return;
    if (!_remember) return;
    if (_seen.length >= 64) _seen.remove(_seen.first);
    _seen.add(id);
    _persist();
  }

  void release(Object owner) {
    if (!owns(owner)) return;
    _owner = null;
    _active = null;
    _changed();
  }

  void withdraw() {
    _owner = null;
    _active = null;
    _changed();
  }

  void setEnabled(bool value) {
    if (!ready || _disposed) return;
    enabled = value;
    withdraw();
    _persist();
  }

  void _persist() {
    try {
      _write(_key, jsonEncode({'enabled': enabled, 'seen': _seen.toList()}));
    } on Object {
      /* Current-session suppression survives a failed local write. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _owner = null;
    super.dispose();
  }
}
