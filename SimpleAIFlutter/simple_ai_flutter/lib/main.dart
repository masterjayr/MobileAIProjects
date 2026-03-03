import 'package:flutter/material.dart';
import 'package:simple_ai_flutter/inference_service.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: SimpleAIScreen(title: "Test AI App"),
    );
  }
}

class SimpleAIScreen extends StatefulWidget {
  const SimpleAIScreen({super.key, required this.title});

  final String title;

  @override
  State<SimpleAIScreen> createState() => _SimpleAIScreenState();
}

class _SimpleAIScreenState extends State<SimpleAIScreen> {
  final TextEditingController _controller = TextEditingController();
  final InferenceService _inferenceService = InferenceService();

  String _output = "";
  bool _isReady = false;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _inferenceService.initialize();
    setState(() {
      _isReady = true;
    });
  }

  void _runInference() async {
    double value = double.tryParse(_controller.text) ?? 0.0;

    final start = DateTime.now();

    final result = await _inferenceService.run(value);
    debugPrint("Running Inference");
    final end = DateTime.now();

    setState(() {
      _output =
          "Output: $result\nLatency: ${end.difference(start).inMilliseconds} ms.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Enter number"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isReady ? _runInference : null,
              child: const Text("Run Inference"),
            ),
            const SizedBox(height: 20),
            Text(_output, style: const TextStyle(fontSize: 22)),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
