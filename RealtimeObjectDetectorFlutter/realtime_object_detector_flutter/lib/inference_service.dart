import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:realtime_object_detector_flutter/model_runner.dart';

class InferenceService {
  late Isolate _isolate;
  late SendPort _sendPort;

  Future<void> initialize({
    required Uint8List modelBytes,
    required List<String> labels,
  }) async {
    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(_isolateEntry, [
      receivePort.sendPort,
      modelBytes,
      labels,
    ]);

    _sendPort = await receivePort.first as SendPort;
  }

  Future<List<Map<String, dynamic>>> detect(
    Map<String, dynamic> frameData,
  ) async {
    final responsePort = ReceivePort();

    _sendPort.send({
      'frameData': frameData,
      'replyPort': responsePort.sendPort,
    });

    final result = await responsePort.first;

    return (result as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
  }

  static void _isolateEntry(List<dynamic> args) async {
    final SendPort mainSendPort = args[0] as SendPort;
    final Uint8List modelBytes = args[1] as Uint8List;
    final List<String> labels = (args[2] as List).cast<String>();

    final port = ReceivePort();
    mainSendPort.send(port.sendPort);

    final runner = ModelRunner();
    runner.loadModelFromBytes(modelBytes, labels);

    await for (final message in port) {
      print('MESSAGE TYPE: ${message.runtimeType}');
      print('MESSAGE VALUE: $message');
      final request = (message as Map).cast<String, dynamic>();
      final frameData = (request['frameData'] as Map).cast<String, dynamic>();
      final replyPort = request['replyPort'] as SendPort;

      try {
        final detections = runner.detect(frameData);
        replyPort.send(detections.map((d) => d.toMap()).toList());
      } catch (e, stackTrace) {
        debugPrint('ISOLATE ERROR: $e');
        print("STACKTRACKE --> $stackTrace");

        final errorResult = <Map<String, dynamic>>[
          {
            'label': 'ERROR: $e',
            'confidence': 0.0,
            'left': 0.0,
            'top': 0.0,
            'right': 0.0,
            'bottom': 0.0,
          },
        ];
        replyPort.send(errorResult);
      }
    }
  }
}
