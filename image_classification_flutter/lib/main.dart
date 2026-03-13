import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_classification_flutter/inference_service.dart';
import 'package:image_classification_flutter/labels.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const ImageClassifierScreen(),
    );
  }
}

class ImageClassifierScreen extends StatefulWidget {
  const ImageClassifierScreen({super.key});

  @override
  State<ImageClassifierScreen> createState() => _ImageClassifierScreenState();
}

class _ImageClassifierScreenState extends State<ImageClassifierScreen> {
  final InferenceService _inferenceService = InferenceService();
  String result = "No prediction";
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _inferenceService.initialize();
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();

    final prediction = await _inferenceService.run(bytes);

    setState(() {
      result = classes[prediction];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Flutter Image Classifier")),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(onPressed: pickImage, child: Text("Pick Image")),

            SizedBox(height: 20),

            Text("Prediction: $result", style: TextStyle(fontSize: 22)),
          ],
        ),
      ),
    );
  }
}
