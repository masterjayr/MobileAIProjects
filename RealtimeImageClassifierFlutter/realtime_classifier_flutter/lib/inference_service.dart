import 'dart:isolate';
import 'dart:typed_data';

import 'package:realtime_classifier_flutter/model_runner.dart';

class InferenceService {
  late Isolate _isolate;
  late SendPort _sendPort;

  Future<void> initialize(Uint8List modelBytes, List<String> labels) async {
    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(_isolateEntry, [
      receivePort.sendPort,
      modelBytes,
      labels,
    ]);
    _sendPort = await receivePort.first as SendPort;
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
  }

  Future<Map<String, dynamic>> runInference(
    Map<String, dynamic> frameData,
  ) async {
    final responsePort = ReceivePort();
    _sendPort.send([frameData, responsePort.sendPort]);
    final result = await responsePort.first as Map<String, dynamic>;
    return result;
  }

  static void _isolateEntry(List<dynamic> args) async {
    final SendPort mainSendPort = args[0];
    final Uint8List modelBytes = args[1];
    final List<String> labels = (args[2] as List).cast<String>();

    final port = ReceivePort();

    mainSendPort.send(port.sendPort);

    final runner = ModelRunner();
    runner.loadModelFromBytes(modelBytes, labels);
    await for (final message in port) {
      final Map<String, dynamic> frameData = (message[0] as Map)
          .cast<String, dynamic>();
      final SendPort replyPort = message[1] as SendPort;

      try {
        final result = runner.runFrameInference(frameData);
        replyPort.send(result);
      } catch (e) {
        replyPort.send({
          'label': 'Error',
          'confidence': 0.0,
          'error': e.toString(),
        });
      }
    }
  }
}
