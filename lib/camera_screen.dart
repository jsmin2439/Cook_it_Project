import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'colors.dart';

class CameraScreen extends StatefulWidget {
  final String userId;
  final String idToken;

  const CameraScreen({
    Key? key,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  bool _isUploading = false;
  bool _isFlashEffectVisible = false;
  List<String> _detectedIngredients = [];
  bool _isDetectionFailed = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  /// 카메라 초기화
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint("❌ 사용할 수 있는 카메라가 없습니다.");
        return;
      }
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;

      setState(() {
        debugPrint("✅ 카메라 초기화 완료");
      });
    } catch (e) {
      debugPrint("❌ 카메라 초기화 오류: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 사진 촬영 후 서버 업로드
  Future<void> _takePictureAndUpload() async {
    if (_controller == null || _initializeControllerFuture == null) {
      debugPrint("❌ 카메라가 초기화되지 않았습니다.");
      return;
    }
    try {
      await _initializeControllerFuture;
      // 화면 깜빡임 효과
      _triggerFlashEffect();

      final file = await _controller!.takePicture();
      final filePath = file.path;
      debugPrint("✅ 사진 촬영 완료: $filePath");

      setState(() {
        _isUploading = true;
        _isDetectionFailed = false;
      });

      final ingredients = await _uploadToServer(filePath);

      setState(() {
        _isUploading = false;
        if (ingredients == null || ingredients.isEmpty) {
          // 서버가 빈 배열 또는 null 반환 시
          _isDetectionFailed = true;
        } else {
          _detectedIngredients = ingredients;
          _showIngredientPopup(); // 팝업창 표시
        }
      });
    } catch (e) {
      debugPrint("❌ 사진 촬영/업로드 오류: $e");
      setState(() {
        _isUploading = false;
        _isDetectionFailed = true;
      });
    }
  }

  /// 서버에 이미지 업로드 (Multipart)
  Future<List<String>?> _uploadToServer(String filePath) async {
    try {
      final uri = Uri.parse("http://192.168.0.254:3000/api/upload-ingredient");
      final imageFile = File(filePath);
      final imageBytes = await imageFile.readAsBytes();

      var request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${widget.idToken}'
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'image.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        if (data['success'] == true && data['detectedIngredients'] != null) {
          // ✅ 여러 재료가 한번에 감지될 경우 배열로 처리
          return List<String>.from(data['detectedIngredients']);
        }
      }
      final errorMessage = _parseErrorMessage(responseBody);
      _showErrorDialog(errorMessage);
      return null;
    } catch (e) {
      debugPrint("❌ 업로드 예외: $e");
      _showErrorDialog("서버 연결에 실패했습니다: ${e.toString()}");
      return null;
    }
  }

  /// 서버 응답 에러메시지 파싱
  String _parseErrorMessage(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      return data['message'] ?? '알 수 없는 오류가 발생했습니다.';
    } catch (e) {
      return '서버 응답을 처리하는 중 오류가 발생했습니다.';
    }
  }

  /// 화면 깜빡임 효과
  void _triggerFlashEffect() {
    setState(() => _isFlashEffectVisible = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() => _isFlashEffectVisible = false);
    });
  }

  /// 에러 메시지 팝업
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("오류"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  /// 인식된 식재료 팝업창
  void _showIngredientPopup() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "인식된 식재료",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _detectedIngredients.map((ingredient) {
                    return _buildIngredientItem(ingredient, setStateDialog);
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("취소"),
                ),
                ElevatedButton(
                  onPressed: () {
                    // "추가하기"를 누르면 인식된 식재료들을 MyFridgePage로 반환
                    Navigator.pop(context, _detectedIngredients);
                    // [추가 요청] MyFridgePage로 바로 이동해 목록 확인
                    // 실제로는 pop() 만으로 MyFridgePage로 돌아감
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPinkButtonColor,
                  ),
                  child:
                      const Text("추가하기", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      // 팝업창이 닫힌 뒤에도 별도 처리가 필요하면 여기서.
      // 예: result가 null이면 취소
      if (result == null) {
        debugPrint("사용자가 팝업에서 취소 버튼 누름");
      } else {
        debugPrint("인식된 식재료 목록 반환: $result");
        Navigator.pop(context, result);
        // => MyFridgePage로 식재료 목록 전송
      }
    });
  }

  /// 식재료 아이템 (팝업 내부)
  Widget _buildIngredientItem(String ingredient, StateSetter setStateDialog) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ingredient,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              // 팝업 내부 setState
              setStateDialog(() {
                _detectedIngredients.remove(ingredient);
              });
            },
            child: const Icon(Icons.close, size: 18, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("식재료 인식"),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kPinkButtonColor, Colors.orangeAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  _controller != null) {
                return CameraPreview(_controller!);
              } else if (snapshot.hasError) {
                return Center(
                  child: Text('카메라 초기화 오류: ${snapshot.error}'),
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          AnimatedOpacity(
            opacity: _isFlashEffectVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 100),
            child: Container(color: Colors.white),
          ),
          if (_isUploading)
            const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _takePictureAndUpload,
        backgroundColor: kPinkButtonColor,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [kPinkButtonColor, Colors.orangeAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.camera_alt, size: 30, color: Colors.white),
        ),
      ),
    );
  }
}
