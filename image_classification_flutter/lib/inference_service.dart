import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:image_classification_flutter/model_runner.dart';

class InferenceService {
  late Isolate _isolate;
  late SendPort _sendPort;

  Future<void> initialize() async {
    final modelData = await rootBundle.load('assets/cifar10_model.tflite');
    final modelBytes = modelData.buffer.asUint8List();

    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(_isolateEntry, [
      receivePort.sendPort,
      modelBytes,
    ]);

    _sendPort = await receivePort.first;
  }

  Future<int> run(Uint8List imageBytes) async {
    final responsePort = ReceivePort();

    _sendPort.send([imageBytes, responsePort.sendPort]);

    return await responsePort.first;
  }

  static void _isolateEntry(List<dynamic> args) async {
    final SendPort sendPort = args[0];
    final Uint8List modelBytes = args[1];

    final port = ReceivePort();

    sendPort.send(port.sendPort);

    final runner = ModelRunner();
    runner.loadModelFromBytes(modelBytes);

    await for (var message in port) {
      final Uint8List imageBytes = message[0];
      final SendPort replyPort = message[1];

      final result = runner.runInference(imageBytes);

      replyPort.send(result);
    }
  }
}
