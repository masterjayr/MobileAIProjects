import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:realtime_classifier_flutter/inference_service.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: CameraScreen());
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  final InferenceService _inferenceService = InferenceService();

  bool _isReady = false;
  bool _isProcessing = false;

  String _prediction = 'Detecting...';
  String _lastLabel = '';
  int _sameCount = 0;
  int requiredConsistency = 3;
  @override
  void initState() {
    super.initState();
    _initializeEverything();
  }

  Future<void> _initializeEverything() async {
    final modelData = await rootBundle.load(
      'assets/mobilenet_v1_1.0_224.tflite',
    );
    final modelBytes = modelData.buffer.asUint8List();

    final labelsText = await rootBundle.loadString('assets/labels.txt');
    final labels = labelsText
        .split('\n')
        .map((e) => e.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    await _inferenceService.initialize(modelBytes, labels);

    controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );
    await controller!.initialize();

    await controller!.startImageStream((CameraImage image) async {
      if (_isProcessing) return;
      _isProcessing = true;
      try {
        final frameData = {
          'width': image.width,
          'height': image.height,
          'format': image.format.group.name, // 🔥 key change

          'yBytes': image.planes[0].bytes,
          'uBytes': image.planes.length > 1 ? image.planes[1].bytes : null,
          'vBytes': image.planes.length > 2 ? image.planes[2].bytes : null,

          'yRowStride': image.planes[0].bytesPerRow,
          'uvRowStride': image.planes.length > 1
              ? image.planes[1].bytesPerRow
              : 0,
          'uvPixelStride': image.planes.length > 1
              ? image.planes[1].bytesPerPixel ?? 1
              : 0,

          'rotation':
              controller!.description.sensorOrientation, // Pass rotation info
        };
        final result = await _inferenceService.runInference(frameData);
        if (!mounted) return;
        final label = result['label'] as String;
        final confidence = result['confidence'] as double;
        const double threshold = 0.5;

        if (label == _lastLabel) {
          _sameCount++;
        } else {
          _sameCount = 1;
          _lastLabel = label;
        }

        if (_sameCount >= requiredConsistency && confidence > threshold) {
          setState(() {
            _prediction = '$label (${confidence.toStringAsFixed(2)})';
          });
        }
      } finally {
        _isProcessing = false;
      }
    });

    setState(() {
      _isReady = true;
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    _inferenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || controller == null || !controller!.value.isInitialized) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(controller!)),
          Positioned(
            left: 16,
            right: 16,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Text(
                _prediction,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
