import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cook_it_login.dart';
import 'firebase_options.dart';

void main() {
  runApp(const MyApp());
}

class CookItApp extends StatelessWidget {
  const CookItApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cook It',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CookItLogin(),
    );
  }
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
      setState(() {
        _currentPage++;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutExpo,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
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
            flex: 100,
            child: PageView(
              controller: _pageController,
              children: [
                _buildCoverPage(), // 1. 표지 페이지
                _buildRecipeListPage(), // 2. 레시피 목록 페이지
                _buildRecipeDetailPage(), // 3. 요리 상세 정보 페이지
                _buildCookingStepsPage(), // 4. 조리 단계 페이지
                _buildCompletionPage(), // 5. 완성 페이지
              ],
            ),
          ),
          // 하단 20% 영역: 네이티브 카메라/오버레이
          Expanded(
            flex: 0,
            child: Container(color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  /// 1️⃣ 표지 페이지
  Widget _buildCoverPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "손으로 넘기는 책",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text("시작하기"),
          ),
        ],
      ),
    );
  }

  /// 2️⃣ 레시피 목록 페이지
  Widget _buildRecipeListPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          _recipeCard("매콤한 간장 떡볶이", "tteokbokki.jpg"),
          _recipeCard("부드러운 크림 파스타", "pasta.jpg"),
          _recipeCard("달콤한 팬케이크", "pancake.jpg"),
        ],
      ),
    );
  }

  Widget _recipeCard(String title, String imageName) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Image.asset("assets/images/$imageName",
            width: 60, fit: BoxFit.cover),
        title: Text(title, style: const TextStyle(fontSize: 18)),
        trailing: const Icon(Icons.arrow_forward),
      ),
    );
  }

  /// 3️⃣ 요리 상세 정보 페이지
  Widget _buildRecipeDetailPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 50), // 위 간격 추가
          const Text(
            "매콤한 간장 떡볶이",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Center(
            child: Image.asset("assets/images/tteokbokki.jpg", height: 200),
          ),
          const SizedBox(height: 16),
          const Text(
            "재료",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text("- 떡 400g\n- 물 2컵\n- 대파 1개\n- 오뎅 200g\n- 계란 1개"),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text("다음 단계"),
          ),
        ],
      ),
    );
  }

  /// 4️⃣ 조리 단계 페이지
  Widget _buildCookingStepsPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 50), // 위 간격 추가
          const Text(
            "조리 단계",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text("1. 떡을 찬물에 10분 담가 말랑하게 만듭니다."),
          const Text("2. 오뎅을 먹기 좋은 크기로 썰고, 대파는 송송 썰어 준비합니다."),
          const Text("3. 양념장을 만들고, 떡과 함께 끓입니다."),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _prevPage,
                child: const Text("이전 단계"),
              ),
              ElevatedButton(
                onPressed: _nextPage,
                child: const Text("완료"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 5️⃣ 완성 페이지
  Widget _buildCompletionPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "요리를 완성했습니다!",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _pageController.jumpToPage(0);
            },
            child: const Text("홈으로 돌아가기"),
          ),
        ],
      ),
    );
  }
}