import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/device_storage_service.dart';

/// Copies a downloaded file to Movies/Tube Arena or Music/Tube Arena.
Future<void> saveFileToPhone(BuildContext context, String path, {bool? audio}) async {
  final storage = context.read<DeviceStorageService>();
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Saving to phone...'), duration: Duration(seconds: 2)));
  try {
    final collection = await storage.saveToPhone(path, audio: audio);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(savedToPhoneMessage(collection))));
  } on SaveToPhoneException catch (error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error.message)));
  }
}

/// Opens the Android share sheet for a downloaded file.
Future<void> shareFile(BuildContext context, String path, {String? title, bool? audio}) async {
  final messenger = ScaffoldMessenger.of(context);
  final box = context.findRenderObject() as RenderBox?;
  if (!await File(path).exists()) {
    messenger.showSnackBar(const SnackBar(content: Text('The file is no longer on this device.')));
    return;
  }
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: mimeTypeFor(path, audio: audio))],
        title: title,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not share this file.')));
  }
}
