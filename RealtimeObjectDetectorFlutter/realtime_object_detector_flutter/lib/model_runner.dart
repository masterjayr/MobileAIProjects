import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:realtime_object_detector_flutter/detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelRunner {
  late Interpreter _interpreter;
  late List<String> _labels;

  void loadModelFromBytes(Uint8List modelBytes, List<String> labels) {
    _interpreter = Interpreter.fromBuffer(modelBytes);
    _labels = labels;
    _logModelInfo();
  }

  void _logModelInfo() {
    final inputTensor = _interpreter.getInputTensor(0);

    debugPrint("INPUT SHAPE: ${inputTensor.shape}");
    debugPrint('INPUT TYPE: ${inputTensor.type}');

    final outputCount = _interpreter.getOutputTensors().length;

    debugPrint("OUTPUT COUNT: $outputCount");

    for (int i = 0; i < outputCount; i++) {
      final tensor = _interpreter.getOutputTensor(i);

      debugPrint(
        'OUTPUT $i -> '
        'shape=${tensor.shape}'
        'type=${tensor.type}',
      );
    }
  }

  List<Detection> detect(Map<String, dynamic> frameData) {
    final letterbox = _preprocess(frameData);
    final input = letterbox.input;
    final boxes = List.generate(
      1,
      (_) => List.generate(25, (_) => List.filled(4, 0.0)),
    );
    final classes = List.generate(1, (_) => List.filled(25, 0.0));
    final scores = List.generate(1, (_) => List.filled(25, 0.0));
    final count = List.filled(1, 0.0);

    final outputs = {0: boxes, 1: classes, 2: scores, 3: count};
    debugPrint("OUTPUTS -> ${outputs[0]}");
    _interpreter.runForMultipleInputs([input], outputs);

    return _parseDetections(
      boxes,
      classes,
      scores,
      count[0].toInt(),
      letterbox,
    );
  }

  List<Detection> _parseDetections(
    List<List<List<double>>> boxes,
    List<List<double>> classes,
    List<List<double>> scores,
    int detectionCount,
    LetterboxInfo letterbox,
  ) {
    final detections = <Detection>[];
    const double inputSize = 320.0;

    debugPrint('DETECTION COUNT RAW: $detectionCount');

    for (int i = 0; i < detectionCount; i++) {
      final score = scores[0][i];

      if (score < 0.5) continue;

      final classIndex = classes[0][i].toInt() + 1;

      final label = (classIndex >= 0 && classIndex < _labels.length)
          ? _labels[classIndex]
          : 'Unknown';

      final box = boxes[0][i];

      final ymin = box[0].clamp(0.0, 1.0) * inputSize;
      final xmin = box[1].clamp(0.0, 1.0) * inputSize;
      final ymax = box[2].clamp(0.0, 1.0) * inputSize;
      final xmax = box[3].clamp(0.0, 1.0) * inputSize;

      final left = (xmin - letterbox.padX) / letterbox.scale;
      final top = (ymin - letterbox.padY) / letterbox.scale;
      final right = (xmax - letterbox.padX) / letterbox.scale;
      final bottom = (ymax - letterbox.padY) / letterbox.scale;

      print(
        'BOX label=$label score=$score '
        'raw=${boxes[0][i]} '
        'restored=[$left,$top,$right,$bottom]',
      );

      detections.add(
        Detection(
          label: label,
          confidence: score,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
      );
    }
    return detections;
  }

  LetterboxInfo _preprocess(Map<String, dynamic> frameData) {
    final int width = frameData['width'];
    final int height = frameData['height'];

    final List planes = frameData['planes'];
    final String format = frameData['format'];

    if (format == 'yuv420') {
      // Android YUV420
      return _yuv420ToLetterboxTensor(width, height, planes);
    }

    if (format == "bgra888") {
      // Ios BGRA8888
      return _bgra8888ToLetterboxTensor(width, height, planes);
    }

    throw Exception('Unsupported image format: $format');
  }

  LetterboxInfo _yuv420ToLetterboxTensor(int width, int height, List planes) {
    final yPlane = planes[0];
    final uPlane = planes[1];
    final vPlane = planes[2];

    final Uint8List yBytes = yPlane['bytes'] as Uint8List;
    final Uint8List uBytes = uPlane['bytes'] as Uint8List;
    final Uint8List vBytes = vPlane['bytes'] as Uint8List;

    final int yRowStride = yPlane['bytesPerRow'] as int;
    final int uvRowStride = uPlane['bytesPerRow'] as int;
    final int uvPixelStride = uPlane['bytesPerPixel'] as int;

    const int inputSize = 320;

    final double scale = min(inputSize / width, inputSize / height);

    final int scaledWidth = (width * scale).round();
    final int scaledHeight = (height * scale).round();

    final double padX = (inputSize - scaledWidth) / 2.0;
    final double padY = (inputSize - scaledHeight) / 2.0;

    final rgbBytes = Uint8List(inputSize * inputSize * 3);

    int outputIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final double sourceXInScaled = x - padX;
        final double sourceYInScaled = y - padY;

        if (sourceXInScaled < 0 ||
            sourceYInScaled < 0 ||
            sourceXInScaled >= scaledWidth ||
            sourceYInScaled >= scaledHeight) {
          // Padding area: blackpixel
          rgbBytes[outputIndex++] = 0;
          rgbBytes[outputIndex++] = 0;
          rgbBytes[outputIndex++] = 0;
          continue;
        }

        final int srcX = (sourceXInScaled / scale).toInt();
        final int srcY = (sourceYInScaled / scale).toInt();

        final int safeX = srcX.clamp(0, width - 1);
        final int safeY = srcY.clamp(0, height - 1);

        final int yIndex = safeY * yRowStride + safeX;

        final int uvX = safeX ~/ 2;
        final int uvY = safeY ~/ 2;

        final int uvIndex = uvY * uvRowStride + uvX * uvPixelStride;

        final int yValue = yBytes[yIndex];
        final int uValue = uBytes[uvIndex];
        final int vValue = vBytes[uvIndex];

        final double yf = yValue.toDouble();
        final double uf = uValue.toDouble() - 128.0;
        final double vf = vValue.toDouble() - 128.0;

        int r = (yf + 1.402 * vf).round();
        int g = (yf - 0.344136 * uf - 0.714136 * vf).round();
        int b = (yf + 1.772 * uf).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        rgbBytes[outputIndex++] = r;
        rgbBytes[outputIndex++] = g;
        rgbBytes[outputIndex++] = b;
      }
    }
    return LetterboxInfo(input: rgbBytes, scale: scale, padX: padX, padY: padY);
  }

  LetterboxInfo _bgra8888ToLetterboxTensor(int width, int height, List planes) {
    final plane = planes[0];
    final Uint8List bytes = plane['bytes'] as Uint8List;
    final int bytesPerRow = plane['bytesPerRow'] as int;

    const inputSize = 320;

    final double scale = min(inputSize / width, inputSize / height);

    final int scaledWidth = (width * scale).round();
    final int scaledHeight = (height * scale).round();

    final double padX = (inputSize - scaledWidth) / 2.0;
    final double padY = (inputSize - scaledHeight) / 2.0;

    final Uint8List rgbBytes = Uint8List(inputSize * inputSize * 3);

    int pixelIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final double sourceXInScaled = x - padX;
        final double sourceYInScaled = x - padY;

        if (sourceXInScaled < 0 ||
            sourceYInScaled < 0 ||
            sourceXInScaled >= scaledWidth ||
            sourceYInScaled >= scaledHeight) {
          rgbBytes[pixelIndex++] = 0;
          rgbBytes[pixelIndex++] = 0;
          rgbBytes[pixelIndex++] = 0;
          continue;
        }

        final int srcX = (sourceXInScaled / scale).toInt();
        final int srcY = (sourceYInScaled / scale).toInt();

        final int safeX = srcX.clamp(0, width - 1);
        final int safeY = srcY.clamp(0, height - 1);

        final int byteIndex = (safeY * bytesPerRow + safeX) * 4;

        final int b = bytes[byteIndex];
        final int g = bytes[byteIndex + 1];
        final int r = bytes[byteIndex + 2];

        rgbBytes[pixelIndex++] = r;
        rgbBytes[pixelIndex++] = g;
        rgbBytes[pixelIndex++] = b;
      }
    }
    return LetterboxInfo(input: rgbBytes, scale: scale, padX: padX, padY: padY);
  }
}

class LetterboxInfo {
  final Uint8List input;
  final double scale;
  final double padX;
  final double padY;

  LetterboxInfo({
    required this.input,
    required this.scale,
    required this.padX,
    required this.padY,
  });
}
