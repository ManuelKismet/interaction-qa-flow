import 'dart:typed_data';

import 'pdf_download_stub.dart'
    if (dart.library.js_interop) 'pdf_download_web.dart' as platform;

Future<bool> downloadPdf(Uint8List bytes, String filename) =>
    platform.downloadPdf(bytes, filename);
