import 'package:flutter_riverpod/flutter_riverpod.dart';

final personalWorkspaceStatusProvider =
    NotifierProvider<PersonalWorkspaceStatusController, PersonalWorkspaceStatus>(
      PersonalWorkspaceStatusController.new,
    );

class PersonalWorkspaceStatus {
  const PersonalWorkspaceStatus({
    this.owner,
    this.uid,
    this.hasPendingChanges = false,
  });

  final Object? owner;
  final String? uid;
  final bool hasPendingChanges;
}

class PersonalWorkspaceStatusController
    extends Notifier<PersonalWorkspaceStatus> {
  @override
  PersonalWorkspaceStatus build() => const PersonalWorkspaceStatus();

  void publish({
    required Object owner,
    required String? uid,
    required bool hasPendingChanges,
    bool claim = false,
  }) {
    if (!claim && state.owner != owner) return;
    state = PersonalWorkspaceStatus(
      owner: owner,
      uid: uid,
      hasPendingChanges: hasPendingChanges,
    );
  }

  void clear(Object owner) {
    if (state.owner != owner) return;
    state = const PersonalWorkspaceStatus();
  }
}
