import 'package:flutter/material.dart';
import 'package:realtime_object_detector_flutter/detection.dart';

class DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final int imageWidth;
  final int imageHeight;

  DetectionPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final canvasAspect = size.width / size.height;
    final imageAspect = imageWidth / imageHeight;

    debugPrint(
      'PAINTER size=${size.width}x${size.height} '
      'image=${imageWidth}x$imageHeight',
    );

    double scale;
    double offsetX;
    double offsetY;

    if (imageAspect > canvasAspect) {
      // image is wider
      scale = size.width / imageWidth;
      final scaledHeight = imageHeight * scale;
      offsetX = 0;
      offsetY = (size.height - scaledHeight) / 2;
    } else {
      scale = size.height / imageHeight;
      final scaledWidth = imageWidth * scale;
      offsetX = (size.width - scaledWidth) / 2;
      offsetY = 0;
    }

    final boxPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final detection in detections) {
      final left = detection.left * scale + offsetX;
      final top = detection.top * scale + offsetY;
      final right = detection.right * scale + offsetX;
      final bottom = detection.bottom * scale + offsetY;

      final paddingX = (right - left) * 0.05;
      final paddingY = (bottom - top) * 0.08;

      final rect = Rect.fromLTRB(left - paddingX, top - paddingY, right + paddingX, bottom + paddingY);

      canvas.drawRect(rect, boxPaint);

      textPainter.text = TextSpan(
        text:
            '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.red,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(left, top - 22 < 0 ? top + 4 : top - 22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
