import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageUtils {
  /// Creates a hexagon path for the given center and radius
  static Path _createHexagonPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      // Start from top point (flat-top hexagon)
      final angle = (i * 60 - 90) * math.pi / 180;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  /// Creates a person icon inside a hexagon for user GPS location marker
  static Future<Uint8List> createHexagonPersonIcon(
    Color teamColor, {
    double size = 140,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final center = Offset(size / 2, size / 2);
    final hexRadius = size / 2 - 10;

    // Outer glow hexagon
    final outerGlowPath = _createHexagonPath(center, hexRadius + 5);
    final outerGlowPaint = Paint()
      ..color = teamColor.withOpacity(0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.0);
    canvas.drawPath(outerGlowPath, outerGlowPaint);

    // Main hexagon fill
    final hexPath = _createHexagonPath(center, hexRadius);
    final fillPaint = Paint()
      ..color = teamColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    canvas.drawPath(hexPath, fillPaint);

    // Hexagon border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawPath(hexPath, borderPaint);

    // Inner hexagon highlight
    final innerHexPath = _createHexagonPath(center, hexRadius * 0.85);
    final innerBorderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(innerHexPath, innerBorderPaint);

    // Draw person icon (head + body)
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Head (circle)
    final headRadius = size / 10;
    final headCenter = Offset(center.dx, center.dy - size / 8);
    canvas.drawCircle(headCenter, headRadius, iconPaint);

    // Body (rounded trapezoid shape)
    final bodyPath = Path();
    final shoulderWidth = size / 5;
    final waistWidth = size / 7;
    final bodyTop = headCenter.dy + headRadius + 3;
    final bodyBottom = center.dy + size / 5;

    bodyPath.moveTo(center.dx - shoulderWidth / 2, bodyTop);
    bodyPath.lineTo(center.dx + shoulderWidth / 2, bodyTop);
    bodyPath.lineTo(center.dx + waistWidth / 2, bodyBottom);
    bodyPath.lineTo(center.dx - waistWidth / 2, bodyBottom);
    bodyPath.close();
    canvas.drawPath(bodyPath, iconPaint);

    // Legs (two rectangles)
    final legWidth = size / 14;
    final legGap = size / 20;
    final legTop = bodyBottom;
    final legBottom = center.dy + size / 3;

    // Left leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          center.dx - legGap / 2 - legWidth,
          legTop,
          center.dx - legGap / 2,
          legBottom,
        ),
        Radius.circular(legWidth / 3),
      ),
      iconPaint,
    );

    // Right leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          center.dx + legGap / 2,
          legTop,
          center.dx + legGap / 2 + legWidth,
          legBottom,
        ),
        Radius.circular(legWidth / 3),
      ),
      iconPaint,
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Creates team-specific location puck icon (person in hexagon)
  static Future<Uint8List> createTeamPuckIcon(
    Color teamColor, {
    double size = 140,
    bool isRedTeam = true,
  }) async {
    return createHexagonPersonIcon(teamColor, size: size);
  }

  /// Legacy: Creates a simple glowing circle puck for location marker
  static Future<Uint8List> createGlowingCirclePuck(
    Color color, {
    double size = 140,
  }) async {
    // Now redirects to hexagon person icon for consistency
    return createHexagonPersonIcon(color, size: size);
  }

  static Future<Uint8List> createLowPolyRunnerImage(
    Color color, {
    double size = 140,
  }) async {
    return createHexagonPersonIcon(color, size: size);
  }

  static Future<Uint8List> createIconImage(
    IconData icon,
    Color color, {
    double size = 96,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final iconStr = String.fromCharCode(icon.codePoint);

    // Draw a background hexagon for visibility
    final center = Offset(size / 2, size / 2);
    final hexPath = _createHexagonPath(center, size / 2 - 4);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(hexPath, paint);

    // Draw the icon
    textPainter.text = TextSpan(
      text: iconStr,
      style: TextStyle(
        letterSpacing: 0.0,
        fontSize: size * 0.6,
        fontFamily: icon.fontFamily,
        color: color,
      ),
    );

    textPainter.layout();

    // Center the icon on the canvas
    final offset = Offset(
      (size - textPainter.width) / 2,
      (size - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }
}
