import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Saves QR image bytes to app documents directory (mobile/desktop).
Future<void> saveQrBytesToPlatform(List<int> bytes, String filename) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/$filename';
  final file = File(path);
  await file.writeAsBytes(bytes);
}
