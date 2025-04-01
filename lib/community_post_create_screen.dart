import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// ★ 추가: HEIC 변환 & sRGB 재인코딩에 필요한 import
import 'package:heif_converter/heif_converter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CommunityPostCreateScreen extends StatefulWidget {
  final String userId;
  final String idToken;

  const CommunityPostCreateScreen({
    Key? key,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  State<CommunityPostCreateScreen> createState() =>
      _CommunityPostCreateScreenState();
}

class _CommunityPostCreateScreenState extends State<CommunityPostCreateScreen> {
  // 제목, 내용, 태그 입력
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  // 첨부 이미지 (글쓰기 시 선택)
  File? _selectedImageFile;

  // 선택된 레시피
  String? _selectedRecipeId; // DB 레시피 ID
  String? _selectedRecipeName; // 레시피 이름
  String? _selectedRecipeImage; // 레시피 메인 이미지 (ATT_FILE_NO_MAIN)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "글 쓰기",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          // 저장 아이콘
          IconButton(
            icon: const Icon(Icons.save, color: Colors.green),
            onPressed: _savePost,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            // (1) 제목
            _buildTitleInput(),
            // (2) 내용
            _buildContentInput(),
            // (3) 이미지 첨부
            _buildImageSection(),
            // (4) 태그
            _buildTagsInput(),
            // (5) 레시피 선택하기
            _buildRecipeSelector(),
            const SizedBox(height: 24),
            // 하단 [저장하기] 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.save),
                label: const Text("저장하기"),
                onPressed: _savePost,
              ),
            )
          ],
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------
  // (A) 제목 입력
  //------------------------------------------------------------------------------
  Widget _buildTitleInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _titleController,
        decoration: const InputDecoration(
          labelText: "게시물 제목",
          border: OutlineInputBorder(),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------
  // (B) 내용 입력
  //------------------------------------------------------------------------------
  Widget _buildContentInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _contentController,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: "게시물 내용",
          border: OutlineInputBorder(),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------
  // (C) 이미지 첨부
  //------------------------------------------------------------------------------
  Widget _buildImageSection() {
    final file = _selectedImageFile;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFECD0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("이미지 첨부", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (file != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(file,
                        width: double.infinity, height: 200, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: () => setState(() => _selectedImageFile = null),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                height: 160,
                color: Colors.grey[200],
                child: IconButton(
                  icon: const Icon(Icons.add_a_photo,
                      size: 40, color: Colors.grey),
                  onPressed: _pickImageFromGallery,
                ),
              ),
            if (file != null)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey),
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text("이미지 교체"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------
  // (D) 태그 입력
  //------------------------------------------------------------------------------
  Widget _buildTagsInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _tagsController,
        decoration: const InputDecoration(
          labelText: "태그 (쉼표 구분)",
          border: OutlineInputBorder(),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------
  // (E) 레시피 선택하기
  //------------------------------------------------------------------------------
  Widget _buildRecipeSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFFECD0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("레시피 선택", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // 현재 선택된 레시피 표시
            if (_selectedRecipeId != null)
              Row(
                children: [
                  // 레시피 이미지 (썸네일)
                  if (_selectedRecipeImage != null &&
                      _selectedRecipeImage!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _selectedRecipeImage!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey,
                          child: const Icon(Icons.photo,
                              color: Colors.white, size: 30),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child: const Icon(Icons.photo, color: Colors.grey),
                    ),
                  const SizedBox(width: 12),
                  // 레시피 이름
                  Expanded(
                    child: Text(
                      _selectedRecipeName ?? "이름 없음",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                    onPressed: _showSavedRecipesDialog,
                    child: const Text("재선택"),
                  ),
                ],
              )
            else
              // 선택 안 된 상태
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showSavedRecipesDialog,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                  child: const Text("저장된 레시피 선택하기"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------
  // 이미지 갤러리에서 선택 (HEIC → JPG 변환)
  //------------------------------------------------------------------------------
  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    File? converted = await _convertAndEncodeToJpg(file);
    if (converted == null) return;

    setState(() => _selectedImageFile = converted);
  }

  //------------------------------------------------------------------------------
  // 레시피 선택 팝업(저장된 레시피 목록)
  //------------------------------------------------------------------------------
  Future<void> _showSavedRecipesDialog() async {
    // Firestore에서 user/{userId}/savedRecipes 가져오기 (예시)
    final userSnap = await FirebaseFirestore.instance
        .collection('user')
        .doc(widget.userId)
        .get();
    final data = userSnap.data() as Map<String, dynamic>?;

    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("사용자 정보가 없습니다.")),
      );
      return;
    }

    final savedList = data["savedRecipes"] ?? [];
    if (savedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("저장된 레시피가 없습니다.")),
      );
      return;
    }

    // Dialog로 표시
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("레시피 선택하기"),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: savedList.length,
              itemBuilder: (context, index) {
                final recipe = savedList[index] as Map<String, dynamic>;
                final rcpName = recipe["RCP_NM"] ?? "No Name";
                final rcpImg = recipe["ATT_FILE_NO_MAIN"] ?? "";
                final rcpSeq = recipe["RCP_SEQ"]?.toString() ?? "???";

                return ListTile(
                  leading: (rcpImg.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            rcpImg,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[200],
                          child: const Icon(Icons.photo,
                              color: Colors.grey, size: 24),
                        ),
                  title: Text(rcpName),
                  onTap: () {
                    setState(() {
                      _selectedRecipeId = rcpSeq; // or recipe's unique ID
                      _selectedRecipeName = rcpName;
                      _selectedRecipeImage = rcpImg;
                    });
                    Navigator.of(ctx).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  //------------------------------------------------------------------------------
  // 저장 버튼 -> 서버로 multipart/form-data 전송
  //------------------------------------------------------------------------------
  Future<void> _savePost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final tags = _tagsController.text.trim(); // 쉼표 구분
    final recipeId = _selectedRecipeId; // 레시피 ID

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("제목과 내용을 입력해주세요.")),
      );
      return;
    }
    if (recipeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("레시피를 선택해주세요.")),
      );
      return;
    }

    // 예: form-data 형식으로 서버 전송
    final url =
        Uri.parse("http://jsmin2439.iptime.org:3000/api/community/posts");

    try {
      final request = http.MultipartRequest("POST", url)
        ..headers["Authorization"] = "Bearer ${widget.idToken}"
        ..fields["title"] = title
        ..fields["content"] = content
        ..fields["recipeId"] = recipeId
        ..fields["tags"] = tags;

      // 이미지 파일 첨부
      if (_selectedImageFile != null) {
        final fileName = _selectedImageFile!.path.split('/').last;
        request.files.add(
          await http.MultipartFile.fromPath("image", _selectedImageFile!.path,
              filename: fileName),
        );
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("업로드 성공!")),
        );
        Navigator.pop(context, true); // 업로드 성공 후 화면 종료
      } else {
        debugPrint("업로드 실패: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("서버 오류: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("업로드 중 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("업로드 실패: $e")),
      );
    }
  }

  //------------------------------------------------------------------------------
  // HEIC → JPG + sRGB 재인코딩 (EditRecipeBook과 동일)
  //------------------------------------------------------------------------------
  Future<File?> _convertAndEncodeToJpg(File original) async {
    try {
      final ext = original.path.split('.').last.toLowerCase();
      File imageFile = original;

      // heic/heif 변환
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
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
}
