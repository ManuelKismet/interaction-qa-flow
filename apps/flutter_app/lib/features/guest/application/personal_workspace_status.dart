import 'package:flutter_riverpod/flutter_riverpod.dart';

final personalWorkspaceStatusProvider =
    NotifierProvider<PersonalWorkspaceStatusController, PersonalWorkspaceStatus>(
      PersonalWorkspaceStatusController.new,
    );

class PersonalWorkspaceStatus {
  const PersonalWorkspaceStatus({
    this.ownerGeneration = 0,
    this.uid,
    this.hasPendingChanges = false,
  });

  final int ownerGeneration;
  final String? uid;
  final bool hasPendingChanges;
}

class PersonalWorkspaceStatusController
    extends Notifier<PersonalWorkspaceStatus> {
  @override
  PersonalWorkspaceStatus build() => const PersonalWorkspaceStatus();

  void publish({
    required int ownerGeneration,
    required String? uid,
    required bool hasPendingChanges,
    bool claim = false,
  }) {
    if (ownerGeneration < state.ownerGeneration ||
        (!claim && state.ownerGeneration != ownerGeneration)) {
      return;
    }
    state = PersonalWorkspaceStatus(
      ownerGeneration: ownerGeneration,
      uid: uid,
      hasPendingChanges: hasPendingChanges,
    );
  }

  void clear(int ownerGeneration) {
    if (state.ownerGeneration != ownerGeneration) return;
    state = const PersonalWorkspaceStatus();
  }
}
