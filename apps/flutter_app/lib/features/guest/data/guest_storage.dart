import 'guest_storage_interface.dart';
import 'guest_storage_stub.dart'
    if (dart.library.js_interop) 'guest_storage_web.dart' as platform;

export 'guest_storage_interface.dart';

GuestStorage createGuestStorage() => platform.createGuestStorage();

