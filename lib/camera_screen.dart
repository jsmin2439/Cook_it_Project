import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  bool _isUploading = false;    // 업로드 중 상태 표시
  bool _isFlashEffectVisible = false; // 화면 깜빡임 효과 플래그

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  /// 카메라 초기화
  Future<void> _initializeCamera() async {
    try {
      // 1) 기기 카메라 목록 가져오기
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        debugPrint("❌ 사용할 수 있는 카메라가 없습니다.");
        return; // 카메라가 없으면 여기서 종료
      }

      // 2) 첫 번째 카메라(필요에 따라 다른 인덱스)로 컨트롤러 생성
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false, // 오디오가 필요 없다면 false
      );

      // 3) 실제 초기화가 끝날 때까지 대기
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;

      // 4) 초기화 성공 시 상태 갱신
      setState(() {
        debugPrint("✅ 카메라 초기화 완료");
      });
    } catch (e) {
      debugPrint("❌ 카메라 초기화 오류: $e");
    }
  }

  @override
  void dispose() {
    // 화면 종료 시 카메라 컨트롤러 dispose
    _controller?.dispose();
    super.dispose();
  }

  /// 사진 촬영 후 서버 업로드
  Future<void> _takePictureAndUpload() async {
    if (_controller == null) {
      debugPrint("❌ 카메라가 초기화되지 않았습니다. (Controller is null)");
      return;
    }

    // 초기화가 끝나지 않았다면 대기
    if (_initializeControllerFuture == null) {
      debugPrint("❌ 카메라 초기화가 시작되지 않았습니다. (Future is null)");
      return;
    }

    try {
      // 초기화 완료까지 대기
      await _initializeControllerFuture;

      // 화면 깜빡임 효과
      _triggerFlashEffect();

      // 사진 촬영
      final file = await _controller!.takePicture();
      final filePath = file.path;
      debugPrint("✅ 사진 촬영 완료: $filePath");

      // 업로드 진행
      setState(() => _isUploading = true);
      final success = await _uploadToServer(filePath);
      setState(() => _isUploading = false);

      if (success) {
        debugPrint("✅ 업로드 성공");
      } else {
        debugPrint("❌ 업로드 실패");
      }
    } catch (e) {
      debugPrint("❌ 사진 촬영/업로드 오류: $e");
    }
  }

  /// 서버에 파일 업로드하는 예시 (MultipartRequest)
  Future<bool> _uploadToServer(String filePath) async {
    try {
      final uri = Uri.parse("http://192.168.23.108:3000/upload-ingredient");
      var request = http.MultipartRequest('POST', uri)
        ..fields['userId'] = "user123" // 예시
        ..files.add(await http.MultipartFile.fromPath('image', filePath));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        debugPrint("✅ 업로드 성공: $responseBody");

        // JSON 파싱 예시
        final data = jsonDecode(responseBody);
        final detectedIngredient = data['detectedIngredient'] ?? "알 수 없음";
        _showDetectedIngredientDialog(detectedIngredient);
        return true;
      } else {
        debugPrint("❌ 업로드 실패(서버 상태): ${response.statusCode}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ 업로드 예외: $e");
      return false;
    }
  }

  /// Vision API 결과 팝업
  void _showDetectedIngredientDialog(String ingredient) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("식재료 인식 결과"),
          content: Text("'$ingredient'을(를) 인식했습니다."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("확인"),
            ),
          ],
        );
      },
    );
  }

  /// 화면 깜빡임 효과
  void _triggerFlashEffect() {
    setState(() {
      _isFlashEffectVisible = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _isFlashEffectVisible = false;
      });
    });
  }

  /// UI 구성
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("카메라 화면"),
      ),
      body: Stack(
        children: [
          // 카메라 초기화가 아직 안 끝났다면 로딩 표시
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

          // 흰색 깜빡임 레이어
          AnimatedOpacity(
            opacity: _isFlashEffectVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 100),
            child: Container(color: Colors.white),
          ),

          // 업로드 중이면 화면에 인디케이터 표시 (예시)
          if (_isUploading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.redAccent,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePictureAndUpload,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}