import 'dart:io'; // File
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:heif_converter/heif_converter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class EditRecipeBook extends StatefulWidget {
  final String userId;
  final String idToken;
  final Map<String, dynamic> originalRecipe;

  const EditRecipeBook({
    Key? key,
    required this.userId,
    required this.idToken,
    required this.originalRecipe,
  }) : super(key: key);

  @override
  State<EditRecipeBook> createState() => _EditRecipeBookState();
}

class _EditRecipeBookState extends State<EditRecipeBook> {
  // 기본 정보 필드
  late TextEditingController _nameController;
  late TextEditingController _imageController;
  late TextEditingController _ingredientController;

  // 단계별 텍스트/이미지
  final int _maxSteps = 20;
  List<TextEditingController> _manualControllers = [];
  List<TextEditingController> _manualImgControllers = [];

  @override
  void initState() {
    super.initState();

    final r = widget.originalRecipe;
    // (A) 기본 정보
    _nameController = TextEditingController(text: r["RCP_NM"] ?? "");
    _imageController = TextEditingController(text: r["ATT_FILE_NO_MAIN"] ?? "");
    _ingredientController =
        TextEditingController(text: r["RCP_PARTS_DTLS"] ?? "");

    // (B) 단계별 컨트롤러 초기화
    for (int i = 1; i <= _maxSteps; i++) {
      final stepText = r["MANUAL${i.toString().padLeft(2, '0')}"] ?? "";
      final stepImg = r["MANUAL_IMG${i.toString().padLeft(2, '0')}"] ?? "";
      _manualControllers.add(TextEditingController(text: stepText));
      _manualImgControllers.add(TextEditingController(text: stepImg));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageController.dispose();
    _ingredientController.dispose();

    for (var c in _manualControllers) {
      c.dispose();
    }
    for (var c in _manualImgControllers) {
      c.dispose();
    }
    super.dispose();
  }

  //--------------------------------------------------------------------------
  // 1) Firestore에 최종 저장
  //--------------------------------------------------------------------------
  Future<void> _saveChanges() async {
    try {
      // (1) 변경된 데이터 구성
      final updatedRecipe = Map<String, dynamic>.from(widget.originalRecipe);
      updatedRecipe["RCP_NM"] = _nameController.text.trim();
      updatedRecipe["ATT_FILE_NO_MAIN"] = _imageController.text.trim();
      updatedRecipe["RCP_PARTS_DTLS"] = _ingredientController.text.trim();

      // MANUALxx / MANUAL_IMGxx 갱신
      for (int i = 0; i < _maxSteps; i++) {
        final index = (i + 1).toString().padLeft(2, '0');
        updatedRecipe["MANUAL$index"] = _manualControllers[i].text.trim();
        updatedRecipe["MANUAL_IMG$index"] =
            _manualImgControllers[i].text.trim();
      }

      // (2) Firestore savedRecipes에서 해당 레시피 찾아 업데이트
      final seq = updatedRecipe["RCP_SEQ"]?.toString() ?? "";
      if (seq.isEmpty) {
        throw "RCP_SEQ가 없어 업데이트 불가";
      }

      final userDocRef =
          FirebaseFirestore.instance.collection('user').doc(widget.userId);
      final snap = await userDocRef.get();
      if (!snap.exists) throw "사용자 문서가 없습니다.";

      final data = snap.data() as Map<String, dynamic>;
      List<dynamic> savedList = data["savedRecipes"] ?? [];

      for (int i = 0; i < savedList.length; i++) {
        final item = savedList[i];
        if (item["RCP_SEQ"]?.toString() == seq) {
          // 레시피 교체
          savedList[i] = updatedRecipe;
          break;
        }
      }

      await userDocRef.update({"savedRecipes": savedList});
      Navigator.pop(context);
    } catch (e) {
      debugPrint("업데이트 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("저장 실패: $e")),
      );
    }
  }

  //--------------------------------------------------------------------------
  // 2) 이미지를 제거
  //--------------------------------------------------------------------------
  void _removeStepImage(int stepIndex) {
    setState(() {
      _manualImgControllers[stepIndex].text = ""; // URL 제거
    });
  }

  //--------------------------------------------------------------------------
  // 3) 앨범에서 새 이미지를 가져와 **Firebase Storage 업로드 후** URL 저장
  //--------------------------------------------------------------------------
  // HEIF → JPEG 변환 함수
  Future<void> _pickImageFromGallery(int stepIndex) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // 원본 파일
    final File originalFile = File(picked.path);
    File imageFile = originalFile;

    // 확장자 확인
    final String extension = picked.path.split('.').last.toLowerCase();

    // HEIF/HEIC → JPEG 변환
    if (extension == 'heic' || extension == 'heif') {
      try {
        final String? jpegPath = await HeifConverter.convert(picked.path);
        if (jpegPath != null) {
          imageFile = File(jpegPath);
        } else {
          throw "HEIF/HEIC 변환 실패";
        }
      } catch (e) {
        debugPrint("HEIF 변환 오류: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("이미지 변환 실패: $e")),
        );
        return;
      }
    }

    // ****************************************************
    // 1) image 라이브러리로 다시 sRGB JPEG로 인코딩
    // ****************************************************
    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage != null) {
        final sRgbBytes = img.encodeJpg(decodedImage, quality: 100);
        // 임시 경로 예: /tmp/converted_1691234567890.jpg
        final tempPath =
            '${(await getTemporaryDirectory()).path}/converted_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final reEncodedFile = File(tempPath)..writeAsBytesSync(sRgbBytes);
        imageFile = reEncodedFile; // 업데이트된 sRGB JPEG 파일
      }
    } catch (e) {
      debugPrint("sRGB 재인코딩 오류: $e");
    }

    // ****************************************************
    // 2) Firebase Storage 업로드
    // ****************************************************
    try {
      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('recipes')
          .child(widget.userId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(imageFile);

      final downloadUrl = await storageRef.getDownloadURL();
      setState(() {
        _manualImgControllers[stepIndex].text = downloadUrl;
      });

      // 임시 파일 정리
      if (imageFile.path != originalFile.path) {
        try {
          await imageFile.delete();
        } catch (e) {
          debugPrint("임시 파일 삭제 오류: $e");
        }
      }
    } catch (e) {
      debugPrint("이미지 업로드 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("이미지 업로드 실패: $e")),
      );
    }
  }

  //--------------------------------------------------------------------------
  // UI
  //--------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EC),
      appBar: AppBar(
        title: const Text("레시피 수정", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.blueAccent),
            onPressed: _saveChanges,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // (A) 레시피 기본정보
            _buildBasicSection(),

            // (B) 단계별 카드
            _buildAllSteps(),

            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text("저장하기"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // 레시피 기본정보 (메인 이미지, 이름, 재료)
  //--------------------------------------------------------------------------
  Widget _buildBasicSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFECD0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("기본 정보",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "레시피 이름"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _imageController,
              decoration: const InputDecoration(labelText: "메인 이미지 URL"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ingredientController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "재료(쉼표 구분)"),
            ),
          ],
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // 단계별 카드
  //--------------------------------------------------------------------------
  Widget _buildAllSteps() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _maxSteps,
      itemBuilder: (context, i) {
        final stepNumber = i + 1;
        return _buildStepCard(i, stepNumber);
      },
    );
  }

  Widget _buildStepCard(int index, int stepNum) {
    final stepTextCtrl = _manualControllers[index];
    final stepImgCtrl = _manualImgControllers[index];
    final stepImgPath = stepImgCtrl.text; // Firebase Storage의 URL (또는 빈 값)

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFECD0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STEP 번호
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                "STEP $stepNum",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // 이미지 표시
            if (stepImgPath.isNotEmpty)
              _buildImagePreview(index, stepImgPath)
            else
              _buildImageAddButton(index),

            // "이미지 교체" 버튼 (이미지 있을 때만)
            if (stepImgPath.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    ),
                    onPressed: () => _pickImageFromGallery(index),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("이미지 교체"),
                  ),
                ),
              ),

            // 단계 텍스트
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: stepTextCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "조리 설명",
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // (1) 이미지가 있을 때: 미리보기 + 삭제 버튼
  //--------------------------------------------------------------------------
  Widget _buildImagePreview(int index, String url) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          color: Colors.grey[300],
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Text("이미지 로딩 실패"),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: InkWell(
            onTap: () => _removeStepImage(index),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // (2) 이미지가 없을 때: "추가" 버튼
  //--------------------------------------------------------------------------
  Widget _buildImageAddButton(int index) {
    return Container(
      height: 180,
      color: Colors.grey[200],
      child: Center(
        child: IconButton(
          icon: const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
          onPressed: () => _pickImageFromGallery(index),
        ),
      ),
    );
  }
}
