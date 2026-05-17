import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:realtime_object_detector_flutter/detection.dart';
import 'package:realtime_object_detector_flutter/detection_painter.dart';
import 'package:realtime_object_detector_flutter/inference_service.dart';

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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ObjectDetectionScreen(),
    );
  }
}

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  CameraController? _controller;

  final InferenceService _inferenceService = InferenceService();

  bool _isReady = false;
  bool _isProcessing = false;

  List<Detection> _detections = [];

  int _imageWidth = 1;
  int _imageHeight = 1;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final modelData = await rootBundle.load('assets/efficientdet_lite0.tflite');

    final labelsText = await rootBundle.loadString('assets/labels.txt');
    debugPrint("Loaded Labels Text");

    final labels = labelsText
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    await _inferenceService.initialize(
      modelBytes: modelData.buffer.asUint8List(),
      labels: labels,
    );

    final imageFormatGroup = Platform.isAndroid
        ? ImageFormatGroup.yuv420
        : ImageFormatGroup.bgra8888;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: imageFormatGroup,
    );

    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);

    if (!mounted) return;

    setState(() {
      _isReady = true;
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    debugPrint(
      'FRAME ${image.width}x${image.height} format=${image.format.group.name} planes=${image.planes.length}',
    );
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      final frameData = {
        'width': image.width,
        'height': image.height,
        'format': image.format.group.name,
        'planes': image.planes.map((plane) {
          return {
            'bytes': plane.bytes,
            'bytesPerRow': plane.bytesPerRow,
            'bytesPerPixel': plane.bytesPerPixel ?? 1,
          };
        }).toList(),
      };

      final rawResults = await _inferenceService.detect(frameData);
      debugPrint('RAW RESULTS COUNT: ${rawResults.length}');
      debugPrint('RAW RESULTS: $rawResults');

      final detections = rawResults.map((e) => Detection.fromMap(e)).toList();

      if (!mounted) return;

      final rotatedDetections = detections.map((d) {
        final newLeft = image.height - d.bottom;
        final newTop = d.left;
        final newRight = image.height - d.top;
        final newBottom = d.right;

        return Detection(
          label: d.label,
          confidence: d.confidence,
          left: newLeft,
          top: newTop,
          right: newRight,
          bottom: newBottom,
        );
      }).toList();

      setState(() {
        _detections = rotatedDetections;
        _imageWidth = image.height;
        _imageHeight = image.width;
      });
    } catch (e) {
      debugPrint('Frame processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _inferenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          CustomPaint(
            painter: DetectionPainter(
              detections: _detections,
              imageWidth: _imageWidth,
              imageHeight: _imageHeight,
            ),
          ),
        ],
      ),
    );
  }
}
