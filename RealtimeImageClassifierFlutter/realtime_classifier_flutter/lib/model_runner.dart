import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

class ModelRunner {
  late Interpreter _interpreter;
  late List<String> _labels;

  void loadModelFromBytes(Uint8List modelBytes, List<String> labels) {
    _interpreter = Interpreter.fromBuffer(modelBytes);
    _labels = labels;
  }

  Map<String, dynamic> runFrameInference(Map<String, dynamic> frameData) {
    final Float32List input = _frameToInputTensor(
      frameData: frameData,
      targetSize: 224,
    );
    final output = List.generate(1, (_) => List.filled(1001, 0.0));

    _interpreter.run(input.reshape([1, 224, 224, 3]), output);

    final scores = output[0];
    int maxIndex = 0;
    double maxScore = scores[0];

    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIndex = i;
      }
    }

    final int labelIndex = _labels.length == 1000 ? maxIndex - 1 : maxIndex;

    final String label = (labelIndex >= 0 && labelIndex < _labels.length)
        ? _labels[labelIndex]
        : "Unknown";
    return {'label': label, 'confidence': maxScore};
  }

  Float32List _frameToInputTensor({
    required Map<String, dynamic> frameData,
    required int targetSize,
  }) {
    final format = frameData['format'];
    final int width = frameData['width'] as int;
    final int height = frameData['height'] as int;

    final Uint8List yBytes = frameData['yBytes'] as Uint8List;
    final Uint8List uBytes = frameData['uBytes'] as Uint8List;
    final Uint8List vBytes = frameData['vBytes'] as Uint8List;

    final int yRowStride = frameData['yRowStride'] as int;
    final int uvRowStride = frameData['uvRowStride'] as int;
    final int uvPixelStride = frameData['uvPixelStride'] as int;
    final int rotation = frameData['rotation'] as int? ?? 0;

    if (format == 'yuv420') {
      return _yuvToInputTensor(
        width: width,
        height: height,
        yBytes: yBytes,
        uBytes: uBytes,
        vBytes: vBytes,
        yRowStride: yRowStride,
        uvRowStride: uvRowStride,
        uvPixelStride: uvPixelStride,
        targetSize: targetSize,
        rotation: rotation,
      );
    } else if (format == 'bgra8888') {
      return _bgraToInputTensor(
        width: width,
        height: height,
        bytes: yBytes,
        rowStride: yRowStride,
        targetSize: targetSize,
        rotation: rotation,
      );
    } else {
      throw Exception('Unsupported format: $format');
    }
  }

  Float32List _bgraToInputTensor({
    required int width,
    required int height,
    required Uint8List bytes,
    required int rowStride,
    required int targetSize,
    required int rotation,
  }) {
    final input = Float32List(targetSize * targetSize * 3);

    int index = 0;

    for (int ty = 0; ty < targetSize; ty++) {
      for (int tx = 0; tx < targetSize; tx++) {
        int srcX, srcY;

        switch (rotation) {
          case 90:
            srcX = (ty * width) ~/ targetSize;
            srcY = height - 1 - ((tx * height) ~/ targetSize);
            break;

          case 270:
            srcX = width - 1 - ((ty * width) ~/ targetSize);
            srcY = (tx * height) ~/ targetSize;
            break;

          default:
            srcX = (tx * width) ~/ targetSize;
            srcY = (ty * height) ~/ targetSize;
        }

        final pixelIndex = srcY * rowStride + srcX * 4;

        final b = bytes[pixelIndex];
        final g = bytes[pixelIndex + 1];
        final r = bytes[pixelIndex + 2];

        input[index++] = r / 255.0;
        input[index++] = g / 255.0;
        input[index++] = b / 255.0;
      }
    }

    return input;
  }

  Float32List _yuvToInputTensor({
    required int width,
    required int height,
    required Uint8List yBytes,
    required Uint8List uBytes,
    required Uint8List vBytes,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
    required int targetSize,
    required int rotation,
  }) {
    final input = Float32List(targetSize * targetSize * 3);

    int index = 0;

    for (int ty = 0; ty < targetSize; ty++) {
      for (int tx = 0; tx < targetSize; tx++) {
        // nearest neighbor sampling from source image
        int srcX, srcY;

        switch (rotation) {
          case 90:
            srcX = (ty * width) ~/ targetSize;
            srcY = height - 1 - ((tx * height) ~/ targetSize);
            break;

          case 270:
            srcX = width - 1 - ((ty * width) ~/ targetSize);
            srcY = (tx * height) ~/ targetSize;
            break;

          default:
            srcX = (tx * width) ~/ targetSize;
            srcY = (ty * height) ~/ targetSize;
        }

        final int yIndex = srcY * yRowStride + srcX;

        final uvX = srcX ~/ 2;
        final uvY = srcY ~/ 2;
        final int uvIndex = uvY * uvRowStride + uvX * uvPixelStride;

        final int yValue = yBytes[yIndex];
        final int uValue = uBytes[uvIndex];
        final int vValue = vBytes[uvIndex];

        int r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        int g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128))
            .clamp(0, 255)
            .toInt();
        int b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        input[index++] = r / 255.0;
        input[index++] = g / 255.0;
        input[index++] = b / 255.0;
      }
    }

    return input;
  }
}
