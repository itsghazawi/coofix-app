import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

/// Documents (order invoice PDF …) are drawn as Flutter widgets on the device,
/// rendered to an image and wrapped in a PDF — nothing is stored on the server.
/// Files live in the app's temporary folder and are cleaned up on the next run.
class Docs {
  static const _ch = MethodChannel('cfx/wa');

  /// Render [w] (laid out at [size] logical px, RTL) to PNG bytes.
  static Future<Uint8List> png(Widget w, Size size, {double ratio = 2.5}) {
    return ScreenshotController().captureFromWidget(
      MediaQuery(
        data: MediaQueryData(size: size, devicePixelRatio: ratio),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'Plex', color: Color(0xFF15181D), decoration: TextDecoration.none),
            child: SizedBox(width: size.width, height: size.height, child: w),
          ),
        ),
      ),
      pixelRatio: ratio,
      targetSize: size,
      delay: const Duration(milliseconds: 450),
    );
  }

  /// One A4 page holding the image edge to edge.
  static Future<Uint8List> pdfFromPng(Uint8List image) async {
    final doc = pw.Document(title: 'Coofix', author: 'Coofix Syria', creator: 'Coofix app');
    final img = pw.MemoryImage(image);
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, build: (_) => pw.FullPage(ignoreMargins: true, child: pw.Image(img, fit: pw.BoxFit.cover))));
    return doc.save();
  }

  static Future<File> _tmp(String name, Uint8List bytes) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/cfx_docs');
    if (await dir.exists()) {
      // Old documents from earlier sends: remove them.
      for (final f in dir.listSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    } else {
      await dir.create(recursive: true);
    }
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  /// Send a file to WhatsApp. On Android it opens the chat of [phone] directly
  /// (digits, with country code). Elsewhere (or if that fails) the share sheet opens.
  static Future<void> sendToWhatsApp(Uint8List bytes, String fileName, {required String mime, String phone = '', String text = '', Rect? origin}) async {
    final f = await _tmp(fileName, bytes);
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final ok = await _ch.invokeMethod<bool>('send', {'path': f.path, 'mime': mime, 'phone': phone.replaceAll(RegExp(r'\D'), ''), 'text': text});
        if (ok == true) return;
      } catch (_) {}
    }
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: mime)], text: text.isEmpty ? null : text, sharePositionOrigin: origin));
  }
}
