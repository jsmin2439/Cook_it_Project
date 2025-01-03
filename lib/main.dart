import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('com.example.flutter/mediapipe');

  String _detectedGesture = 'No gesture detected';

  Future<void> detectGesture() async {
    String gesture;
    try {
      final String result = await platform.invokeMethod('detectGesture');
      gesture = 'Detected gesture: $result';
    } on PlatformException catch (e) {
      gesture = "Failed to detect gesture: '${e.message}'.";
    }
    setState(() {
      _detectedGesture = gesture;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('MediaPipe Gesture Recognition'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(_detectedGesture),
              ElevatedButton(
                onPressed: detectGesture,
                child: Text('Detect Gesture'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
