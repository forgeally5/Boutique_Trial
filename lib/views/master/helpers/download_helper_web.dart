// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// download_helper_web.dart — Web Browser Blob File Downloader
import 'dart:html' as html;

Future<String?> saveAndDownloadFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return fileName;
  } catch (e) {
    return null;
  }
}
