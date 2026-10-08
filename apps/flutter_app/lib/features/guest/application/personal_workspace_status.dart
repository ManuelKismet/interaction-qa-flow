import 'package:flutter_riverpod/flutter_riverpod.dart';

final personalWorkspaceStatusProvider =
    NotifierProvider<PersonalWorkspaceStatusController, PersonalWorkspaceStatus>(
      PersonalWorkspaceStatusController.new,
    );

class PersonalWorkspaceStatus {
  const PersonalWorkspaceStatus({this.uid, this.hasPendingChanges = false});

  final String? uid;
  final bool hasPendingChanges;
}

class PersonalWorkspaceStatusController
    extends Notifier<PersonalWorkspaceStatus> {
  @override
  PersonalWorkspaceStatus build() => const PersonalWorkspaceStatus();

  void update({required String? uid, required bool hasPendingChanges}) {
    state = PersonalWorkspaceStatus(
      uid: uid,
      hasPendingChanges: hasPendingChanges,
    );
  }
}
