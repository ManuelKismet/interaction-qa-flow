import 'guest_storage_interface.dart';

GuestStorage createGuestStorage() => _MemoryGuestStorage();

class _MemoryGuestStorage implements GuestStorage {
  static String? _value;

  @override
  String? read() => _value;

  @override
  void write(String value) => _value = value;

  @override
  void remove() => _value = null;
}
