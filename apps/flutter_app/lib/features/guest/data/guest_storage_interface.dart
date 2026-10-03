abstract interface class GuestStorage {
  String? read();

  void write(String value);

  void remove();
}

