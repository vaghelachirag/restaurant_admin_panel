// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers browser download of QR image (web).
Future<void> saveQrBytesToPlatform(List<int> bytes, String filename) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement()
    ..href = url
    ..download = filename;
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
