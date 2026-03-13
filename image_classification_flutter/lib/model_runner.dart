import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelRunner {
  late Interpreter _interpreter;

  void loadModelFromBytes(Uint8List modelBytes) {
    _interpreter = Interpreter.fromBuffer(modelBytes);
  }

  int runInference(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes)!;
    final resized = img.copyResize(image, width: 32, height: 32);

    final input = Float32List(1 * 32 * 32 * 3);

    int index = 0;

    for (int y = 0; y < 32; y++) {
      for (int x = 0; x < 32; x++) {
        final pixel = resized.getPixel(x, y);

        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        input[index++] = r;
        input[index++] = g;
        input[index++] = b;
      }
    }
    final output = List.generate(1, (_) => List.filled(10, 0.0));

    _interpreter.run(input.reshape([1, 32, 32, 3]), output);

    final scores = output[0];

    int maxIndex = 0;
    double maxScore = scores[0];

    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIndex = i;
      }
    }

    return maxIndex;
  }
}
