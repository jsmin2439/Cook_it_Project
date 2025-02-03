import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gesture Book',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BookPage(),
    );
  }
}

class BookPage extends StatefulWidget {
  const BookPage({super.key});

  @override
  _BookPageState createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _cameraChannel = MethodChannel('com.example.mediapipe2/camera');
  static const _gestureChannel =
      MethodChannel('com.example.mediapipe2/gesture');

  @override
  void initState() {
    super.initState();
    _initCamera();
    _setupGestureListener();
  }

  Future<void> _initCamera() async {
    try {
      await _cameraChannel.invokeMethod('startCamera');
    } on PlatformException catch (e) {
      debugPrint("Camera Error: ${e.message}");
    }
  }

  void _setupGestureListener() {
    _gestureChannel.setMethodCallHandler((call) async {
      if (call.method == 'swipe') {
        final direction = call.arguments as String;
        if (direction == 'left') {
          _nextPage();
        } else if (direction == 'right') {
          _prevPage();
        }
      }
      return;
    });
  }

  void _nextPage() {
    if (_currentPage < 4) {
      // 0~4 = 5페이지
      _currentPage++;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutExpo,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _currentPage--;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutExpo,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 상단 80% 영역: Flutter Book UI (5페이지)
          Expanded(
            flex: 5,
            child: PageView.builder(
              controller: _pageController,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  color: Colors.white,
                  child: Center(
                    child: Text(
                      'Page ${index + 1}',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                );
              },
            ),
          ),
          // 하단 20% 영역: 네이티브 카메라/오버레이 (AppDelegate에서 붙여짐)
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
