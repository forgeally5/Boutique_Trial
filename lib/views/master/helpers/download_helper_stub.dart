// download_helper_stub.dart — Native Desktop / Mobile File Downloader
import 'dart:io';

Future<String?> saveAndDownloadFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  try {
    final userProfile = Platform.environment['USERPROFILE'];
    String dirPath = Directory.current.path;
    if (userProfile != null) {
      final downloads = Directory('$userProfile\\Downloads');
      if (!downloads.existsSync()) downloads.createSync(recursive: true);
      dirPath = downloads.path;
    }
    final filePath = '$dirPath\\$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  } catch (e) {
    return null;
  }
}
