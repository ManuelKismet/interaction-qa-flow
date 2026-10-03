import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';

final guestStorageProvider = Provider<GuestStorage>((ref) {
  return createGuestStorage();
});

final guestWorkspaceStoreProvider = Provider<GuestWorkspaceStore>((ref) {
  return GuestWorkspaceStore(ref.watch(guestStorageProvider));
});

class GuestWorkspaceStore {
  const GuestWorkspaceStore(this._storage);

  final GuestStorage _storage;

  Future<GuestWorkspaceData> load() async {
    final raw = _storage.read();
    if (raw == null || raw.isEmpty) return const GuestWorkspaceData();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Stored guest data is not a JSON object.');
    }
    return GuestWorkspaceData.fromJson(decoded);
  }

  Future<void> save(GuestWorkspaceData data) async {
    _storage.write(jsonEncode(data.toJson()));
  }

  Future<void> clear() async {
    _storage.remove();
  }

  Future<GuestWorkspaceData> importSelected({
    required GuestWorkspaceData imported,
    required Set<String> knowledgeIds,
    required Set<String> sessionIds,
    required Set<String> templateIds,
  }) async {
    final existing = await load();
    final result = GuestWorkspaceData(
      knowledge: mergeSelectedGuestItems(
        existing: existing.knowledge,
        imported: imported.knowledge,
        selectedIds: knowledgeIds,
      ),
      sessions: mergeSelectedGuestItems(
        existing: existing.sessions,
        imported: imported.sessions,
        selectedIds: sessionIds,
      ),
      templates: mergeSelectedGuestItems(
        existing: existing.templates,
        imported: imported.templates,
        selectedIds: templateIds,
      ),
    );
    await save(result);
    return result;
  }
}
