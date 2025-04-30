import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heif_converter/heif_converter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CommunityPostCreateScreen extends StatefulWidget {
  final String userId;
  final String idToken;
  final Map<String, dynamic>? preSelectedRecipe;

  const CommunityPostCreateScreen({
    Key? key,
    required this.userId,
    required this.idToken,
    this.preSelectedRecipe,
  }) : super(key: key);

  @override
  State<CommunityPostCreateScreen> createState() =>
      _CommunityPostCreateScreenState();
}

class _CommunityPostCreateScreenState extends State<CommunityPostCreateScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  File? _selectedImageFile;
  int? _selectedRecipeIndex;
  String? _selectedRecipeName;
  String? _selectedRecipeImageUrl;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "새 게시물 작성",
          style: TextStyle(
            color: Color(0xFF2E3A59),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2E3A59)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6B8E23),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _savePost,
                  child: const Text(
                    "게시",
                    style: TextStyle(
                      color: Color(0xFF6B8E23),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B8E23)))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _buildImagePicker(),
                  _buildInputFields(),
                  _buildRecipeSelector(),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  @override
  void initState() {
    super.initState();

    // 기존에 있던 코드가 있다면 유지

    // 레시피가 미리 선택되었다면 초기화
    if (widget.preSelectedRecipe != null) {
      _setupPreSelectedRecipe();
    }
  }

  void _setupPreSelectedRecipe() async {
    try {
      setState(() => _isLoading = true);

      final userSnap = await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .get();

      final data = userSnap.data() as Map<String, dynamic>?;
      if (data == null) {
        setState(() => _isLoading = false);
        return;
      }

      final savedRecipes = data["savedRecipes"] as List<dynamic>? ?? [];
      if (savedRecipes.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final preSeq = widget.preSelectedRecipe?["RCP_SEQ"]?.toString() ?? "";

      int? foundIndex;
      for (int i = 0; i < savedRecipes.length; i++) {
        final recipe = savedRecipes[i] as Map<String, dynamic>;
        if (recipe["RCP_SEQ"]?.toString() == preSeq) {
          foundIndex = i;
          break;
        }
      }

      setState(() {
        _isLoading = false;

        if (foundIndex != null) {
          _selectedRecipeIndex = foundIndex;
          final recipe = savedRecipes[foundIndex] as Map<String, dynamic>;
          _selectedRecipeName = recipe["RCP_NM"] ?? "No Name";
          _selectedRecipeImageUrl = recipe["ATT_FILE_NO_MAIN"] ?? "";

          // 제목과 내용 자동 채우기
          _titleController.text = "레시피 공유: $_selectedRecipeName";
          _contentController.text = "이 레시피를 공유합니다: $_selectedRecipeName";

          // 태그 자동 추가
          final category = recipe["RCP_PAT2"] ?? "";
          final way = recipe["RCP_WAY2"] ?? "";
          if (category.isNotEmpty || way.isNotEmpty) {
            final tags = <String>[];
            if (category.isNotEmpty) tags.add("#$category");
            if (way.isNotEmpty) tags.add("#$way");
            tags.add("#요리공유");
            _tagsController.text = tags.join(", ");
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("사전 선택 레시피 설정 오류: $e");
    }
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImageFromGallery,
      child: Container(
        height: 240,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _selectedImageFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _selectedImageFile!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImageFile = null),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _pickImageFromGallery,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B8E23),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              "변경",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "이미지 추가하기",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "완성한 요리 사진을 공유해보세요",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInputFields() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Input
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: "제목을 입력하세요",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2E3A59),
            ),
            validator: (value) => value?.isEmpty ?? true ? "제목을 입력해주세요" : null,
          ),
          const SizedBox(height: 16),

          // Content Input
          TextFormField(
            controller: _contentController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: "나만의 요리 이야기를 공유해보세요...",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF2E3A59),
              height: 1.5,
            ),
            validator: (value) => value?.isEmpty ?? true ? "내용을 입력해주세요" : null,
          ),
          const SizedBox(height: 16),

          // Tags Input
          TextFormField(
            controller: _tagsController,
            decoration: InputDecoration(
              hintText: "#태그1, #태그2, #태그3",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: const Icon(
                Icons.tag,
                color: Color(0xFF6B8E23),
                size: 20,
              ),
            ),
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF2E3A59),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF6B8E23),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                "레시피 선택",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E3A59),
                ),
              ),
              const Spacer(),
              if (_selectedRecipeIndex != null)
                TextButton(
                  onPressed: _showSavedRecipesDialog,
                  child: const Text(
                    "변경",
                    style: TextStyle(
                      color: Color(0xFF6B8E23),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedRecipeIndex != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _selectedRecipeImageUrl != null &&
                            _selectedRecipeImageUrl!.isNotEmpty
                        ? Image.network(
                            _selectedRecipeImageUrl!,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 70,
                              height: 70,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.restaurant,
                                  color: Colors.grey),
                            ),
                          )
                        : Container(
                            width: 70,
                            height: 70,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.restaurant,
                                color: Colors.grey),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedRecipeName ?? "이름 없음",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E3A59),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B8E23).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "선택됨",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B8E23),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: _showSavedRecipesDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6B8E23).withOpacity(0.3),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 32,
                      color: const Color(0xFF6B8E23).withOpacity(0.8),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "레시피 선택하기",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B8E23),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _savePost,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6B8E23),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          "게시물 등록하기",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (picked == null) return;

    final file = File(picked.path);
    File? converted = await _convertAndEncodeToJpg(file);
    if (converted == null) return;

    setState(() => _selectedImageFile = converted);
  }

  Future<void> _showSavedRecipesDialog() async {
    setState(() => _isLoading = true);

    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .get();

      setState(() => _isLoading = false);

      final data = userSnap.data() as Map<String, dynamic>?;

      if (data == null) {
        _showErrorSnackBar("사용자 정보를 불러올 수 없습니다.");
        return;
      }

      final savedList = data["savedRecipes"] ?? [];
      if (savedList.isEmpty) {
        _showErrorSnackBar("저장된 레시피가 없습니다.");
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        "저장된 레시피",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E3A59),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: savedList.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final recipe = savedList[index] as Map<String, dynamic>;
                      final rcpName = recipe["RCP_NM"] ?? "No Name";
                      final rcpImg = recipe["ATT_FILE_NO_MAIN"] ?? "";

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRecipeIndex = index;
                            _selectedRecipeName = rcpName;
                            _selectedRecipeImageUrl = rcpImg;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _selectedRecipeIndex == index
                                ? const Color(0xFF6B8E23).withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedRecipeIndex == index
                                  ? const Color(0xFF6B8E23)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: rcpImg.isNotEmpty
                                    ? Image.network(
                                        rcpImg,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.restaurant,
                                              color: Colors.grey),
                                        ),
                                      )
                                    : Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.restaurant,
                                            color: Colors.grey),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  rcpName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: _selectedRecipeIndex == index
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: const Color(0xFF2E3A59),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedRecipeIndex == index)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF6B8E23),
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("레시피를 불러오는 중 오류가 발생했습니다: $e");
    }
  }

  Future<void> _savePost() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final tags = _tagsController.text.trim();
    final recipeIndex = _selectedRecipeIndex;

    if (recipeIndex == null) {
      _showErrorSnackBar("레시피를 선택해주세요");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url =
          Uri.parse("http://jsmin2439.iptime.org:3000/api/community/post");
      final request = http.MultipartRequest("POST", url)
        ..headers["Authorization"] = "Bearer ${widget.idToken}"
        ..fields["title"] = title
        ..fields["content"] = content
        ..fields["recipeIndex"] = recipeIndex.toString()
        ..fields["tags"] = tags;

      if (_selectedImageFile != null) {
        final fileName = _selectedImageFile!.path.split('/').last;
        request.files.add(
          await http.MultipartFile.fromPath("image", _selectedImageFile!.path,
              filename: fileName),
        );
      }

      final response = await request.send();

      setState(() => _isLoading = false);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSuccessSnackBar("게시물이 성공적으로 등록되었습니다");
        Navigator.pop(context, true);
      } else {
        _showErrorSnackBar("서버 오류: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("업로드 실패: $e");
    }
  }

  Future<File?> _convertAndEncodeToJpg(File original) async {
    try {
      final ext = original.path.split('.').last.toLowerCase();
      File imageFile = original;

      if (ext == 'heic' || ext == 'heif') {
        final jpegPath = await HeifConverter.convert(original.path);
        if (jpegPath == null) throw "HEIF 변환 실패";
        imageFile = File(jpegPath);
      }

      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw "이미지 디코딩 실패";

      final newBytes = img.encodeJpg(decoded, quality: 90);
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final reEncodedFile = File(tempPath)..writeAsBytesSync(newBytes);

      return reEncodedFile;
    } catch (e) {
      _showErrorSnackBar("이미지 변환 실패: $e");
      return null;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6B8E23),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
