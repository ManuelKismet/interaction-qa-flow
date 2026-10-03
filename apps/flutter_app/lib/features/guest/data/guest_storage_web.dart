import 'package:web/web.dart' as web;

import 'guest_storage_interface.dart';

const guestWorkspaceStorageKey = 'intqaflow.guest.workspace.v1';

GuestStorage createGuestStorage() => _WebGuestStorage();

class _WebGuestStorage implements GuestStorage {
  @override
  String? read() => web.window.localStorage.getItem(guestWorkspaceStorageKey);

  @override
  void write(String value) {
    web.window.localStorage.setItem(guestWorkspaceStorageKey, value);
  }

  @override
  void remove() {
    web.window.localStorage.removeItem(guestWorkspaceStorageKey);
  }
}
