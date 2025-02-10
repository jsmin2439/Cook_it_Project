import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const _gestureChannel = MethodChannel('com.example.mediapipe2/gesture');

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
        if (direction == 'left') _nextPage();
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
    if (steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Recipe Book"),
          actions: [_buildCameraToggle()], // 카메라 토글 버튼 추가
        ),
        body: const Center(child: Text("조리 단계가 없습니다.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Recipe Book"),
        actions: [_buildCameraToggle()], // 카메라 토글 버튼 추가
      ),
      body: Column(
        children: [
          Expanded(
            flex: 80,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _getTotalPages(),
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return _buildRecipeBookPage(index);
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
              child: const Text("홈으로 돌아가기")
              )
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


  /// 각 단계별 위젯
  Widget _buildStepItem(Map<String, String> step, int stepNumber) {
    final text = step["text"] ?? "";
    final imgUrl = step["img"] ?? "";

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("STEP $stepNumber", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (imgUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imgUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[300],
                    alignment: Alignment.center,
                    child: const Text("No Image"),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}