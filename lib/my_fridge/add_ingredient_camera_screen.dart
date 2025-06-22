import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import '../color/colors.dart';

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
      // 카메라 초기화가 완료될 때까지 대기
      await _initializeControllerFuture;

      // 사진 촬영
      final file = await _controller!.takePicture();
      final filePath = file.path;
      debugPrint("✅ 사진 촬영 완료: $filePath");

      setState(() {
        _isUploading = true;
        _isDetectionFailed = false;
      });

      // 서버 업로드
      final ingredients = await _uploadToServer(filePath);

      setState(() {
        _isUploading = false;
      });

      // 식재료 인식 결과 처리
      if (ingredients == null || ingredients.isEmpty) {
        // 하나도 인식하지 못한 경우
        _showNoIngredientDialog();
      } else {
        // 정상적으로 인식된 경우
        _detectedIngredients = ingredients;
        _showIngredientPopup(); // 팝업창 표시
      }
    } catch (e) {
      debugPrint("❌ 사진 촬영/업로드 오류: $e");
      setState(() {
        _isUploading = false;
        _isDetectionFailed = true;
      });
      // 식재료 인식 실패 팝업
      _showNoIngredientDialog();
    }
  }

  /// 서버에 이미지 업로드 (Multipart)
  Future<List<String>?> _uploadToServer(String filePath) async {
    try {
      final uri =
          Uri.parse("http://gamproject.iptime.org:3000/api/upload-ingredient");
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
        // 🔹 success == true 이고 detectedIngredients가 비어있지 않은 경우만 사용
        if (data['success'] == true &&
            data['detectedIngredients'] != null &&
            data['detectedIngredients'].isNotEmpty) {
          return List<String>.from(data['detectedIngredients']);
        }
      }
      // 여기까지 오면 식재료 인식 못함
      return [];
    } catch (e) {
      debugPrint("❌ 업로드 예외: $e");
      return null; // null 반환 시 상위 로직에서 팝업 처리
    }
  }

  /// 식재료 하나도 인식 못했을 때 팝업
  void _showNoIngredientDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("식재료 인식 실패"),
        content: const Text("식재료를 인식하지 못하였습니다."),
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
      if (result == null) {
        debugPrint("사용자가 팝업에서 취소 버튼 누름");
      } else {
        debugPrint("인식된 식재료 목록 반환: $result");
        Navigator.pop(context, result);
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
              // 해당 식재료 팝업상 실시간 삭제
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
          // 카메라 미리보기
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

          // 업로드 중 로딩 인디케이터
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
