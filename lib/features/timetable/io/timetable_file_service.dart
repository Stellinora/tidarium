import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract final class TimetableFileService {
  static const _channel = MethodChannel(
    'io.github.stellinora.tidarium/files',
  );

  static Future<String?> pickIcsContent() {
    return _channel.invokeMethod<String>('pickIcs');
  }

  static Future<bool> saveIcs({
    required String content,
    required String fileName,
  }) async {
    final saved = await _channel.invokeMethod<bool>('saveIcs', {
      'fileName': fileName,
      'content': content,
    });
    return saved ?? false;
  }

  static Future<void> shareIcs({
    required String content,
    required String fileName,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
    await file.writeAsString(content, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/calendar')],
        subject: 'Tidarium 课表',
      ),
    );
  }
}
