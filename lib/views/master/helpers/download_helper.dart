// download_helper.dart — Conditional export for Web & Native
export 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';
