import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/sponsor.dart';
import '../widgets/sponsor_logo_painter.dart';

/// Generates team representative images from sponsor logos using Canvas.
class SponsorImageGenerator {
  /// Renders a sponsor logo to a PNG image as Uint8List.
  ///
  /// [size] determines the output image dimensions (square).
  /// Returns null if rendering fails.
  static Future<Uint8List?> generateImage(
    Sponsor sponsor, {
    int size = 256,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paintSize = Size(size.toDouble(), size.toDouble());

      // Draw background (dark)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, paintSize.width, paintSize.height),
        Paint()..color = const Color(0xFF0F172A),
      );

      // Draw the sponsor logo
      final painter = SponsorLogoPainter(sponsor: sponsor, isSelected: false);
      painter.paint(canvas, paintSize);

      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Failed to generate sponsor image: $e');
      return null;
    }
  }

  /// Generates a base64-encoded data URL for the sponsor logo.
  ///
  /// Returns a data:image/png;base64,... string suitable for storage.
  static Future<String?> generateBase64DataUrl(
    Sponsor sponsor, {
    int size = 256,
  }) async {
    final bytes = await generateImage(sponsor, size: size);
    if (bytes == null) return null;

    final base64 = _bytesToBase64(bytes);
    return 'data:image/png;base64,$base64';
  }

  static String _bytesToBase64(Uint8List bytes) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buffer = StringBuffer();
    final len = bytes.length;

    for (var i = 0; i < len; i += 3) {
      final b1 = bytes[i];
      final b2 = i + 1 < len ? bytes[i + 1] : 0;
      final b3 = i + 2 < len ? bytes[i + 2] : 0;

      buffer.write(chars[(b1 >> 2) & 0x3F]);
      buffer.write(chars[((b1 << 4) | (b2 >> 4)) & 0x3F]);
      buffer.write(i + 1 < len ? chars[((b2 << 2) | (b3 >> 6)) & 0x3F] : '=');
      buffer.write(i + 2 < len ? chars[b3 & 0x3F] : '=');
    }

    return buffer.toString();
  }
}
