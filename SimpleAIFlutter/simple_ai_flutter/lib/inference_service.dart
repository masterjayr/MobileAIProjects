import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:simple_ai_flutter/model_runner.dart';

class InferenceService {
  late Isolate _isolate;
  late SendPort _sendPort;

  Future<void> initialize() async {
    final modelData = await rootBundle.load('assets/simple_model.tflite');
    final modelBytes = modelData.buffer.asUint8List();

    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(_isolateEntry, [
      receivePort.sendPort,
      modelBytes,
    ]);

    _sendPort = await receivePort.first;
  }

  Future<double> run(double value) async {
    final responsePort = ReceivePort();

    _sendPort.send([value, responsePort.sendPort]);
    return await responsePort.first;
  }

  static void _isolateEntry(List<dynamic> args) async {
    final SendPort sendPort = args[0];
    final Uint8List modelBytes = args[1];
    // isolates port
    final port = ReceivePort();

    // send the isolates send port to be saved to _sendPort
    sendPort.send(port.sendPort);

    final runner = ModelRunner();
    runner.loadModelFromBytes(modelBytes);

    await for (var message in port) {
      final double value = message[0];

      final SendPort replyPort = message[1];

      final result = runner.runInference(value);
      replyPort.send(result);
    }
  }
}
