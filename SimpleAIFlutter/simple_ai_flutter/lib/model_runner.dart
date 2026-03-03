import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class ModelRunner {
  late Interpreter _interpreter;

  void loadModelFromBytes(Uint8List modelBytes) {
    _interpreter = Interpreter.fromBuffer(modelBytes);
  }

  double runInference(double inputValue) {
    var input = [
      [inputValue],
    ];

    var output = List.generate(1, (_) => List.filled(1, 0.0));

    _interpreter.run(input, output);

    return output[0][0];
  }
}
