// lib/ai_recipe/recipe_book_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:turn_page_transition/turn_page_transition.dart';
import '../color/colors.dart';

const Color kBackgroundColor = Color(0xFFFFF8EC);

class BookPage extends StatefulWidget {
  final Map<String, dynamic>? recipeData; // 레시피 데이터를 받아옴 (null 가능성 대비)

  const BookPage({super.key, this.recipeData});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  /// turn_page_transition 패키지에서 제공하는 컨트롤러
  final TurnPageController _turnPageController = TurnPageController();

  // 현재 페이지 인덱스를 추적할 변수
  int _currentPageIndex = 0;

  // 제스처 채널
  static const _cameraChannel = MethodChannel('com.example.mediapipe2/camera');
  static const _gestureChannel =
      MethodChannel('com.example.mediapipe2/gesture');

  bool _isCameraActive = false; // 카메라 상태
  List<Widget> _bookPages = []; // 책처럼 보일 각 페이지(커버, 단계, 마지막 페이지)
  List<Map<String, String>> steps = []; // 레시피 단계 저장

  @override
  void initState() {
    super.initState();
    _setupGestureListener();
    _prepareSteps();
    _buildBookPages();
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  // -----------------------
  // 레시피 단계 관련 로직
  // -----------------------

  /// JSON에서 MANUAL01~20 / MANUAL_IMG01~20을 추출하여
  /// 빈 값("")이 아닌 경우 steps 리스트에 담기
  void _prepareSteps() {
    if (widget.recipeData == null) return;
    final data = widget.recipeData!;
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

  /// 커버 페이지 + 조리 단계 페이지들 + 마지막 페이지
  /// 순서대로 _bookPages 리스트에 담는다
  void _buildBookPages() {
    _bookPages.clear();

    // 0. 표지 페이지
    _bookPages.add(_buildCoverPage());

    // 1. 2단계씩 페이지 구성
    final totalPages = (steps.length / 2).ceil();
    for (int i = 0; i < totalPages; i++) {
      final startIndex = i * 2;
      final endIndex =
          (startIndex + 2 > steps.length) ? steps.length : startIndex + 2;
      final pageSteps = steps.sublist(startIndex, endIndex);

      _bookPages.add(_buildRecipeStepPage(pageSteps, i));
    }

    // 2. 마지막 페이지 (완료 / 홈으로 돌아가기)
    _bookPages.add(_buildFinalPage());
  }

  /// 표지 페이지
  Widget _buildCoverPage() {
    // 첫 페이지 배경으로 사용될 이미지(ATT_FILE_NO_MAIN)
    final coverImageUrl = widget.recipeData?["ATT_FILE_NO_MAIN"] ?? "";

    return Stack(
      children: [
        // 배경 이미지
        SizedBox(
          height: double.infinity,
          width: double.infinity,
          child: coverImageUrl.isNotEmpty
              ? Image.network(
                  coverImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey,
                    alignment: Alignment.center,
                    child: const Text(
                      "No Image",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                )
              : Container(color: kBackgroundColor),
        ),
        // 반투명 오버레이 (시야 개선)
        Container(color: Colors.black.withOpacity(0.3)),
        // 상단 조작 버튼 (뒤로가기, 카메라 토글)
        Positioned(
          top: 40,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBackButton(),
              _buildCameraToggleButton(),
            ],
          ),
        ),
        // 중앙 표지 텍스트
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 요리 이름
              Text(
                widget.recipeData?["RCP_NM"] ?? "나만의 레시피북",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "맛있는 여행을 시작해볼까요?",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 조리 단계가 들어있는 실제 '책 페이지'
  Widget _buildRecipeStepPage(
      List<Map<String, String>> pageSteps, int pageIndex) {
    final startStepNumber = pageIndex * 2 + 1;

    return Container(
      color: kBackgroundColor,
      child: Stack(
        children: [
          // 상단 조작 버튼 (뒤로가기, 카메라 토글)
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBackButton(),
                _buildCameraToggleButton(),
              ],
            ),
          ),
          // 페이지 내용
          Padding(
            padding: const EdgeInsets.only(
                top: 100, left: 16, right: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 단계 목록을 표시
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(pageSteps.length, (index) {
                        final stepNumber = startStepNumber + index;
                        return _buildStepItem(pageSteps[index], stepNumber);
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 마지막 페이지 (완료 / 홈으로 돌아가기)
  Widget _buildFinalPage() {
    // 마지막 페이지도 첫 페이지와 동일한 음식 사진 배경
    final coverImageUrl = widget.recipeData?["ATT_FILE_NO_MAIN"] ?? "";

    return Stack(
      children: [
        // 배경 이미지 (레시피의 메인 요리 사진)
        SizedBox(
          height: double.infinity,
          width: double.infinity,
          child: coverImageUrl.isNotEmpty
              ? Image.network(
                  coverImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey,
                    alignment: Alignment.center,
                    child: const Text(
                      "No Image",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                )
              : Container(color: kBackgroundColor),
        ),
        // 어두운 오버레이
        Container(color: Colors.black.withOpacity(0.3)),
        // 상단 조작 버튼 (뒤로가기, 카메라 토글)
        Positioned(
          top: 40,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBackButton(),
              _buildCameraToggleButton(),
            ],
          ),
        ),
        // 중앙 내용
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "모든 단계가 끝났습니다!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _stopCamera();
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text("홈으로 돌아가기"),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 각 단계 표시(한 페이지 내에 여러 단계가 들어있음)
  Widget _buildStepItem(Map<String, String> step, int stepNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 단계 텍스트
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "STEP $stepNumber\n",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
          // 단계 이미지
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

  // ----------------------
  // TurnPageView 사용
  // ----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: TurnPageView.builder(
        controller: _turnPageController,
        itemCount: _bookPages.length,
        itemBuilder: (context, index) => _bookPages[index],
        overleafColorBuilder: (index) => Colors.grey[200] ?? Colors.grey,
        animationTransitionPoint: 0.5,
      ),
    );
  }

  // ----------------------
  // 제스처 / 카메라 관련 로직
  // ----------------------

  /// 제스처 리스너
  void _setupGestureListener() {
    _gestureChannel.setMethodCallHandler((call) async {
      if (!_isCameraActive) return; // 카메라 비활성화 시 제스처 무시
      if (call.method == 'swipe') {
        final direction = call.arguments as String;
        if (direction == 'left') {
          _nextPage();
        } else if (direction == 'right') {
          _prevPage();
        }
      }
    });
  }

  /// 현재 페이지 + 1
  void _nextPage() {
    if (_currentPageIndex < _bookPages.length - 1) {
      setState(() {
        _currentPageIndex++;
      });
      // (패키지 버전에 따라 nextPage() 없으면 animateToPage() 사용)
      _turnPageController.nextPage();
    }
  }

  /// 현재 페이지 - 1
  void _prevPage() {
    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
      });
      _turnPageController.previousPage();
    }
  }

  /// 카메라 켜기
  Future<void> _initCamera() async {
    try {
      await _cameraChannel.invokeMethod('startCamera');
      // 카메라가 성공적으로 켜졌다면, 상태값 갱신
      setState(() => _isCameraActive = true);
    } on PlatformException catch (e) {
      debugPrint("Camera Error: ${e.message}");
    }
  }

  /// 카메라 끄기
  Future<void> _stopCamera() async {
    try {
      await _cameraChannel.invokeMethod('stopCamera');
      // 카메라가 성공적으로 꺼졌다면, 상태값 갱신
      setState(() => _isCameraActive = false);
    } on PlatformException catch (e) {
      debugPrint("Camera Stop Error: ${e.message}");
    }
  }

  /// 카메라 토글
  void _toggleCamera() async {
    try {
      if (_isCameraActive) {
        await _stopCamera();
      } else {
        await _initCamera();
      }
    } catch (e) {
      debugPrint("Toggle Camera Error: $e");
    }
  }

  // ----------------------
  // 공통으로 쓰는 위젯(상단 버튼)
  // ----------------------

  /// 뒤로가기 버튼
  Widget _buildBackButton() {
    return InkWell(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(2, 2),
            )
          ],
        ),
        child: const Icon(Icons.arrow_back, color: Colors.black),
      ),
    );
  }

  /// 카메라 토글 버튼 (카메라 꺼짐 → 켜짐, 켜짐 → 꺼짐)
  Widget _buildCameraToggleButton() {
    return InkWell(
      onTap: _toggleCamera,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white70,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(2, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(
              // 카메라 상태에 따라 아이콘 변경
              _isCameraActive ? Icons.videocam : Icons.videocam_off,
              color: Colors.black,
            ),
            const SizedBox(width: 4),
            Text(
              _isCameraActive ? '카메라 켜짐' : '카메라 꺼짐',
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
