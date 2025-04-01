import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  // 최대 단계
  static const int _maxSteps = 20;

  // 현재 UI에서 표시할 단계 수
  int _currentStepCount = 1;

  // 기본 정보 필드
  late TextEditingController _nameController; // RCP_NM
  late TextEditingController _ingredientController; // RCP_PARTS_DTLS
  // 메인 이미지
  File? _mainImageFile;
  String? _mainImageUrl;

  // 단계별 텍스트/이미지
  final List<TextEditingController> _stepTextControllers = [];
  final List<String?> _stepImageUrls = [];
  final List<File?> _stepLocalFiles = [];

  @override
  void initState() {
    super.initState();
    final r = widget.originalRecipe;

    // (A) 기본 정보
    _nameController = TextEditingController(text: r["RCP_NM"] ?? "");
    _ingredientController =
        TextEditingController(text: r["RCP_PARTS_DTLS"] ?? "");
    _mainImageUrl = r["ATT_FILE_NO_MAIN"] as String? ?? "";

    // (B) 단계별 초기화
    // 최대 20단계
    for (int i = 1; i <= _maxSteps; i++) {
      final stepText =
          r["MANUAL${i.toString().padLeft(2, '0')}"]?.toString() ?? "";
      final stepImg =
          r["MANUAL_IMG${i.toString().padLeft(2, '0')}"]?.toString() ?? "";
      _stepTextControllers.add(TextEditingController(text: stepText));
      _stepImageUrls.add(stepImg.isNotEmpty ? stepImg : null);
      _stepLocalFiles.add(null);
    }

    // (C) 마지막 사용 단계 찾기
    // ex) MANUALxx가 전부 "" 이면 0단계, 하나라도 있으면 그 인덱스까지
    int lastUsedStep = 0; // 0이면 아무 단계도 안 씀
    for (int i = 0; i < _maxSteps; i++) {
      // 텍스트 or 이미지 중 하나라도 있으면 사용된 단계로 본다.
      final txt = _stepTextControllers[i].text.trim();
      final imgUrl = _stepImageUrls[i];
      if (txt.isNotEmpty || (imgUrl != null && imgUrl.isNotEmpty)) {
        lastUsedStep = i + 1;
      }
    }

    // lastUsedStep이 0이면 최소 1단계는 보여주도록
    if (lastUsedStep == 0) {
      lastUsedStep = 1;
    }
    _currentStepCount = lastUsedStep;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ingredientController.dispose();
    for (var c in _stepTextControllers) {
      c.dispose();
    }
    super.dispose();
  }

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
            icon: const Icon(Icons.save, color: Colors.green), // 가독성 있게 초록색
            onPressed: _saveChanges,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // (1) 기본 정보 섹션
            _buildBasicSection(),

            // (2) 단계별 카드: 현재 _currentStepCount까지만 표시
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentStepCount,
              itemBuilder: (ctx, i) {
                final stepIndex = i; // 0-based
                final stepNum = i + 1; // 1-based
                return _buildStepCard(stepIndex, stepNum);
              },
            ),

            // 단계 추가 버튼
            if (_currentStepCount < _maxSteps)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // 가독성있는 파랑
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text("단계 추가 (현재 $_currentStepCount/$_maxSteps)"),
                  onPressed: _addNewStep,
                ),
              ),

            const SizedBox(height: 20),
            // 저장하기 버튼 (하단)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text("저장하기"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // 가독성있는 초록
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //==========================================================================
  // (A) 기본정보
  //==========================================================================
  Widget _buildBasicSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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

            // 메인 이미지
            _buildMainImagePreview(),

            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "레시피 이름 (RCP_NM)",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ingredientController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "재료 (RCP_PARTS_DTLS)",
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainImagePreview() {
    final file = _mainImageFile;
    final url = _mainImageUrl;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: file != null
              ? Image.file(
                  file,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                )
              : (url != null && url.isNotEmpty
                  ? Image.network(
                      url,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[200],
                      child: const Icon(Icons.photo, color: Colors.grey),
                    )),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _pickMainImage,
          icon: const Icon(Icons.image),
          label: const Text("메인 이미지 수정"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
        ),
      ],
    );
  }

  //==========================================================================
  // (B) 단계별 카드
  //==========================================================================
  Widget _buildStepCard(int stepIndex, int stepNum) {
    final textCtrl = _stepTextControllers[stepIndex];
    final stepUrl = _stepImageUrls[stepIndex];
    final stepLocal = _stepLocalFiles[stepIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFECD0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                "STEP $stepNum",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (stepLocal != null || (stepUrl != null && stepUrl.isNotEmpty))
              _buildStepImagePreview(stepIndex, stepLocal, stepUrl)
            else
              _buildStepAddImageBtn(stepIndex),
            if (stepLocal != null || (stepUrl != null && stepUrl.isNotEmpty))
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey, // 이미지 교체 버튼 색상
                    ),
                    onPressed: () => _pickStepImage(stepIndex),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("이미지 교체"),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: textCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "조리 설명 (MANUALxx)",
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepImagePreview(int index, File? file, String? url) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          color: Colors.grey[300],
          child: file != null
              ? Image.file(file, fit: BoxFit.cover)
              : Image.network(url!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                  return const Center(child: Text("이미지 로딩 실패"));
                }),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: InkWell(
            onTap: () {
              setState(() {
                _stepLocalFiles[index] = null;
                _stepImageUrls[index] = null;
              });
            },
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

  Widget _buildStepAddImageBtn(int index) {
    return Container(
      height: 180,
      color: Colors.grey[200],
      child: Center(
        child: IconButton(
          icon: const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
          onPressed: () => _pickStepImage(index),
        ),
      ),
    );
  }

  void _addNewStep() {
    if (_currentStepCount < _maxSteps) {
      setState(() {
        _currentStepCount++;
      });
    }
  }

  //==========================================================================
  // (C) pick Main Image
  //==========================================================================
  Future<void> _pickMainImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    File? converted = await _convertAndEncodeToJpg(File(picked.path));
    if (converted == null) return;

    setState(() {
      _mainImageFile = converted;
      _mainImageUrl = null;
    });
  }

  //==========================================================================
  // (D) pick Step Image
  //==========================================================================
  Future<void> _pickStepImage(int index) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    File? converted = await _convertAndEncodeToJpg(File(picked.path));
    if (converted == null) return;

    setState(() {
      _stepLocalFiles[index] = converted;
      _stepImageUrls[index] = null; // 새로 pick했으므로 기존 url 제거
    });
  }

  //==========================================================================
  // (E) convert & encode
  //==========================================================================
  Future<File?> _convertAndEncodeToJpg(File original) async {
    try {
      // 확장자
      final ext = original.path.split('.').last.toLowerCase();
      File imageFile = original;

      // heic/heif → jpg
      if (ext == 'heic' || ext == 'heif') {
        final jpegPath = await HeifConverter.convert(original.path);
        if (jpegPath == null) throw "HEIF 변환 실패";
        imageFile = File(jpegPath);
      }

      // sRGB 재인코딩
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw "이미지 디코딩 실패";

      final newBytes = img.encodeJpg(decoded, quality: 100);
      final tempPath =
          '${(await getTemporaryDirectory()).path}/converted_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final reEncodedFile = File(tempPath)..writeAsBytesSync(newBytes);

      return reEncodedFile;
    } catch (e) {
      debugPrint("이미지 변환 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("이미지 변환 실패: $e")),
      );
      return null;
    }
  }

  //==========================================================================
  // (F) saveChanges
  //==========================================================================
  Future<void> _saveChanges() async {
    try {
      final updated = Map<String, dynamic>.from(widget.originalRecipe);
      // (1) 기본 필드
      updated["RCP_NM"] = _nameController.text.trim();
      updated["RCP_PARTS_DTLS"] = _ingredientController.text.trim();

      // (1-A) 메인 이미지 업로드
      if (_mainImageFile != null) {
        final url = await _uploadFile(_mainImageFile!, "main");
        updated["ATT_FILE_NO_MAIN"] = url;
      } else {
        updated["ATT_FILE_NO_MAIN"] = _mainImageUrl ?? "";
      }

      // (2) 단계별
      for (int i = 0; i < _maxSteps; i++) {
        final idx = (i + 1).toString().padLeft(2, '0');
        // 텍스트
        updated["MANUAL$idx"] = _stepTextControllers[i].text.trim();
        // 이미지
        final localFile = _stepLocalFiles[i];
        final oldUrl = _stepImageUrls[i];

        if (i < _currentStepCount) {
          // 실제로 사용하는 단계
          if (localFile != null) {
            final stepUrl = await _uploadFile(localFile, "step$idx");
            updated["MANUAL_IMG$idx"] = stepUrl;
          } else {
            updated["MANUAL_IMG$idx"] = oldUrl ?? "";
          }
        } else {
          // 사용 안 하는 단계는 "" 처리
          updated["MANUAL$idx"] = "";
          updated["MANUAL_IMG$idx"] = "";
        }
      }

      // (3) Firestore 저장
      final seq = updated["RCP_SEQ"]?.toString() ?? "";
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
          savedList[i] = updated;
          break;
        }
      }

      await userDocRef.update({"savedRecipes": savedList});

      Navigator.pop(context, updated);
    } catch (e) {
      debugPrint("업데이트 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("저장 실패: $e")),
      );
    }
  }

  //==========================================================================
  // (G) uploadFile
  //==========================================================================
  Future<String> _uploadFile(File file, String prefix) async {
    try {
      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('recipes')
          .child(widget.userId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(file);

      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("이미지 업로드 오류: $e");
      throw "이미지 업로드 실패: $e";
    }
  }
}
