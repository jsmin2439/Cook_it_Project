import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';

const Color kBackgroundColor = Color(0xFFFFF8EC);

class BookPage extends StatefulWidget {
  final Map<String, dynamic>? recipeData; // 레시피 데이터를 받아옴 (null 가능성 대비)

  const BookPage({super.key, this.recipeData});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCameraActive = false; // 카메라 상태 추적

  static const _cameraChannel = MethodChannel('com.example.mediapipe2/camera');
  static const _gestureChannel =
      MethodChannel('com.example.mediapipe2/gesture');

  List<Map<String, String>> steps = [];

  @override
  void initState() {
    super.initState();
    _setupGestureListener();
    _prepareSteps();
  }

  @override
  void dispose() {
    _stopCamera(); // 페이지 종료 시 카메라 종료
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      await _cameraChannel.invokeMethod('startCamera');
      setState(() => _isCameraActive = true);
    } on PlatformException catch (e) {
      debugPrint("Camera Error: ${e.message}");
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _cameraChannel.invokeMethod('stopCamera');
      setState(() => _isCameraActive = false);
    } on PlatformException catch (e) {
      debugPrint("Camera Stop Error: ${e.message}");
    }
  }

  void _toggleCamera() async {
    if (_isCameraActive) {
      await _stopCamera();
    } else {
      await _initCamera();
    }
  }

  void _setupGestureListener() {
    _gestureChannel.setMethodCallHandler((call) async {
      if (!_isCameraActive) return; // 카메라 비활성화 시 제스처 무시
      if (call.method == 'swipe') {
        final direction = call.arguments as String;
        if (direction == 'left')
          _nextPage();
        else if (direction == 'right') _prevPage();
      }
    });
  }

  /// JSON에서 MANUAL01~20 / MANUAL_IMG01~20을 추출하여
  /// 빈 값("")이 아닌 경우 steps 리스트에 담기
  void _prepareSteps() {
    if (widget.recipeData == null) return;
    final data = widget.recipeData!;
    // 1~20까지 돌면서 단계 텍스트와 이미지 추출
    for (int i = 1; i <= 20; i++) {
      final textKey = "MANUAL${i.toString().padLeft(2, '0')}";
      final imgKey = "MANUAL_IMG${i.toString().padLeft(2, '0')}";

      final stepText = data[textKey] ?? "";
      final stepImg = data[imgKey] ?? "";

      if (stepText.isNotEmpty) {
        steps.add({
          "text": stepText,
          "img": stepImg,
        });
      }
    }
  }

  void _nextPage() {
    if (_currentPage < _getTotalPages() - 1) {
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

  /// 2단계씩 보여줄 것이므로 총 페이지 수 = ceil(steps.length / 2)
  int _getTotalPages() {
    return (steps.length / 2).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.asset('assets/images/cookbook.png', width: 32, height: 32),
            const SizedBox(width: 8),
            Text(
              widget.recipeData?["RCP_NM"] ?? "조리 단계북",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [_buildCameraToggle()],
      ),
      body: _buildBookContent(),
    );
  }

  Widget _buildBookContent() {
    if (steps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "등록된 조리 단계가 없습니다",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _getTotalPages(),
          itemBuilder: (context, index) {
            return _buildRecipeBookPage(index);
          },
        ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: _buildProgressIndicator(),
        ),
      ],
    );
  }

  Widget _buildStepItem(Map<String, String> step, int stepNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Step $stepNumber\n",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextSpan(
                    text: step["text"] ?? "",
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          if (step["img"]?.isNotEmpty ?? false)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Image.network(
                step["img"]!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, size: 50),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraToggle() {
    return IconButton(
      icon: Icon(_isCameraActive ? Icons.videocam : Icons.videocam_off),
      onPressed: _toggleCamera,
    );
  }

  /// 레시피북 한 페이지에 2단계씩 보여주는 위젯
  Widget _buildRecipeBookPage(int pageIndex) {
    final int startIndex = pageIndex * 2;
    final int endIndex = startIndex + 2;
    bool isLastPage = (pageIndex == _getTotalPages() - 1);

    List<Map<String, String>> pageSteps = steps.sublist(
      startIndex,
      endIndex > steps.length ? steps.length : endIndex,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12),
        child: Column(
          children: [
            Text(
              widget.recipeData?["RCP_NM"] ?? "레시피북",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Divider(thickness: 2),
            Expanded(
              child: ListView.builder(
                itemCount: pageSteps.length,
                itemBuilder: (context, i) {
                  return _buildStepItem(pageSteps[i], startIndex + i + 1);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _prevPage,
                  child: const Text("이전 단계"),
                ),
                isLastPage
                    ? ElevatedButton(
                        onPressed: () {
                          _stopCamera(); // 카메라 종료 추가
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        child: const Text("홈으로 돌아가기"))
                    : ElevatedButton(
                        onPressed: _nextPage,
                        child: const Text("다음 단계"),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationControls(bool isLastPage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FloatingActionButton(
            heroTag: 'prev',
            backgroundColor: kPinkButtonColor,
            onPressed: _prevPage,
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          if (isLastPage)
            ElevatedButton.icon(
              icon: const Icon(Icons.home, size: 20),
              label: const Text("홈으로"),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPinkButtonColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                _stopCamera();
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            )
          else
            FloatingActionButton(
              heroTag: 'next',
              backgroundColor: kPinkButtonColor,
              onPressed: _nextPage,
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _getTotalPages(),
        (index) => Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == _currentPage ? kPinkButtonColor : Colors.grey[300],
          ),
        ),
      ),
    );
  }
}
