// lib/community/community_post_create_screen.dart
//
// ────────────────────────────────────────────────────────────────
// • 새   게시물 : 이미지 + 제목 + 내용 + 태그 + 레시피 선택 가능
// • 기존 게시물 : 이미지 + 제목 + 내용 + 태그만 수정   (레시피 고정)
// • 공유 버튼   : preSelectedRecipe 로 진입 → 레시피가 자동 선택됨
// ────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:heif_converter/heif_converter.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class CommunityPostCreateScreen extends StatefulWidget {
  final String userId;
  final String idToken;

  /// `null` → 새 글  |  not-null → 글 수정
  final Map<String, dynamic>? existingPost;

  /// “레시피 공유” 버튼으로 들어올 때 전달됨
  final Map<String, dynamic>? preSelectedRecipe;

  const CommunityPostCreateScreen({
    super.key,
    required this.userId,
    required this.idToken,
    this.existingPost,
    this.preSelectedRecipe,
  });

  @override
  State<CommunityPostCreateScreen> createState() =>
      _CommunityPostCreateScreenState();
}

class _CommunityPostCreateScreenState extends State<CommunityPostCreateScreen> {
  // ───────────────────────── controller & state
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _tags = TextEditingController();

  File? _localImage; // 사용자가 새로 고른 이미지
  String? _networkImageUrl; // 수정모드에서 내려받은 기존 이미지

  int? _recipeIdx; // 서버가 요구하는 recipeIndex
  String? _recipeName;
  String? _recipeImgUrl;

  bool _loading = false;
  bool get _isEdit => widget.existingPost != null;

  // ───────────────────────── init
  @override
  void initState() {
    super.initState();

    if (_isEdit) {
      _loadExistingForEdit();
    } else if (widget.preSelectedRecipe != null) {
      _applyPreSelectedRecipe();
    }
  }

  void _loadExistingForEdit() {
    final p = widget.existingPost!;
    _title.text = p['title'] ?? '';
    _content.text = p['content'] ?? '';
    final t = p['tags'];
    _tags.text = t is List ? t.join(', ') : (t ?? '');

    _networkImageUrl = p['imageUrl'];

    _recipeIdx = _toInt(p['recipeIndex']);
    _recipeName = p['recipeName'];
    _recipeImgUrl = p['recipeImageUrl'];
  }

  void _applyPreSelectedRecipe() {
    final r = widget.preSelectedRecipe!;
    // 사용 환경(백엔드)에 맞게 recipeIndex 또는 seq 로 변환
    // ↓ 예시: 저장된 레시피 배열에서 인덱스를 찾아보는 방식
    _recipeName = r['RCP_NM'] ?? '';
    _recipeImgUrl = r['ATT_FILE_NO_MAIN'] ?? '';
    _recipeIdx = int.tryParse('${r['RCP_SEQ'] ?? -1}'); // 없는 경우 -1

    // 제목·내용·태그 자동 완성(원하면 수정 가능)
    _title.text = '레시피 공유: $_recipeName';
    _content.text = '이 레시피를 공유합니다: $_recipeName';
    _tags.text = '#요리공유';
  }

  int? _toInt(dynamic v) => v == null ? null : int.tryParse('$v');

  // ───────────────────────── 이미지 선택 (+ HEIC → JPG)
  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    File f = File(picked.path);
    if (picked.path.toLowerCase().endsWith('.heic') ||
        picked.path.toLowerCase().endsWith('.heif')) {
      final jpgPath = await HeifConverter.convert(picked.path);
      if (jpgPath != null) f = File(jpgPath);
    }

    final decoded = img.decodeImage(await f.readAsBytes());
    if (decoded == null) return;

    final bytes = img.encodeJpg(decoded, quality: 90);
    final tmp = await getTemporaryDirectory();
    final out =
        await File('${tmp.path}/${DateTime.now().millisecondsSinceEpoch}.jpg')
            .writeAsBytes(bytes);

    setState(() {
      _localImage = out;
      _networkImageUrl = null;
    });
  }

  // ───────────────────────── 레시피 선택(새 글 전용)
  Future<void> _chooseRecipe() async {
    if (_isEdit) return; // 수정 모드에선 레시피 고정

    setState(() => _loading = true);
    final snap = await FirebaseFirestore.instance
        .collection('user')
        .doc(widget.userId)
        .get();
    setState(() => _loading = false);

    final saved = (snap.data()?['savedRecipes'] ?? []) as List<dynamic>;
    if (saved.isEmpty) {
      _snack('저장된 레시피가 없습니다.');
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RecipeModal(
        recipes: saved,
        onPick: (idx, name, img) {
          setState(() {
            _recipeIdx = idx;
            _recipeName = name;
            _recipeImgUrl = img;
          });
        },
      ),
    );
  }

  // ───────────────────────── Submit
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _recipeIdx == null) {
      _snack('레시피를 선택해주세요', true);
      return;
    }

    setState(() => _loading = true);
    try {
      _isEdit ? await _updatePost() : await _createPost();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createPost() async {
    final url = Uri.parse('http://gamdasal.iptime.org:3000/api/community/post');

    final req = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer ${widget.idToken}'
      ..fields['title'] = _title.text.trim()
      ..fields['content'] = _content.text.trim()
      ..fields['tags'] = _tags.text.trim()
      ..fields['recipeIndex'] = _recipeIdx.toString();

    if (_localImage != null) {
      req.files
          .add(await http.MultipartFile.fromPath('image', _localImage!.path));
    }

    final res = await req.send();
    if (res.statusCode ~/ 100 == 2) {
      _snack('게시물이 등록되었습니다.');
      Navigator.pop(context, true);
    } else {
      _snack('등록 실패: ${res.statusCode}', true);
    }
  }

  Future<void> _updatePost() async {
    final url = Uri.parse(
        'http://gamdasal.iptime.org:3000/api/community/post/${widget.existingPost!['id']}');

    final body = jsonEncode({
      'title': _title.text.trim(),
      'content': _content.text.trim(),
      'tags': _tags.text.trim(),
    });

    final res = await http.put(url,
        headers: {
          'Authorization': 'Bearer ${widget.idToken}',
          'Content-Type': 'application/json',
        },
        body: body);

    if (res.statusCode ~/ 100 == 2) {
      if (_localImage != null) await _patchOnlyImage();
      _snack('게시물이 수정되었습니다.');
      Navigator.pop(context, true);
    } else {
      _snack('수정 실패: ${res.statusCode}', true);
    }
  }

  Future<void> _patchOnlyImage() async {
    final url = Uri.parse(
        'http://gamdasal.iptime.org:3000/api/community/post/${widget.existingPost!['id']}/image');

    final m = http.MultipartRequest('PATCH', url)
      ..headers['Authorization'] = 'Bearer ${widget.idToken}'
      ..files
          .add(await http.MultipartFile.fromPath('image', _localImage!.path));

    await m.send();
  }

  // ───────────────────────── UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2E3A59)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEdit ? '게시물 수정' : '새 게시물 작성',
            style: const TextStyle(
                color: Color(0xFF2E3A59),
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // 이미지
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 240,
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                        image: _localImage != null
                            ? DecorationImage(
                                image: FileImage(_localImage!),
                                fit: BoxFit.cover)
                            : (_networkImageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_networkImageUrl!),
                                    fit: BoxFit.cover)
                                : null),
                      ),
                      child: (_localImage == null && _networkImageUrl == null)
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded,
                                      size: 60, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text('이미지 추가하기',
                                      style: TextStyle(
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  _textField(_title, '제목'),
                  const SizedBox(height: 12),
                  _textField(_content, '내용', maxLines: 6),
                  const SizedBox(height: 12),
                  _textField(_tags, '#태그1, #태그2', prefix: Icons.tag),

                  const SizedBox(height: 24),

                  // 레시피(읽기전용 or 선택가능)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      onTap: _chooseRecipe,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF6B8E23).withOpacity(.4)),
                        ),
                        child: _recipeIdx == null
                            ? Row(
                                children: const [
                                  Icon(Icons.menu_book_rounded,
                                      color: Color(0xFF6B8E23)),
                                  SizedBox(width: 8),
                                  Text('레시피 선택하기',
                                      style:
                                          TextStyle(color: Color(0xFF6B8E23))),
                                ],
                              )
                            : Row(
                                children: [
                                  _recipeImgUrl != null &&
                                          _recipeImgUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(_recipeImgUrl!,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover),
                                        )
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.restaurant,
                                              color: Colors.grey),
                                        ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(_recipeName ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  if (!_isEdit)
                                    const Icon(Icons.edit,
                                        size: 18, color: Color(0xFF6B8E23)),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B8E23),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(_isEdit ? '수정 완료' : '게시물 등록하기',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  )
                ],
              ),
            ),
    );
  }

  // ───────────────────────── 작은 위젯들
  Widget _textField(TextEditingController c, String hint,
      {int maxLines = 1, IconData? prefix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        validator: (v) => v == null || v.trim().isEmpty ? '필수 입력란입니다.' : null,
        decoration: InputDecoration(
          prefixIcon: prefix != null
              ? Icon(prefix, color: const Color(0xFF6B8E23))
              : null,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  void _snack(String m, [bool err = false]) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m), backgroundColor: err ? Colors.red : Colors.green));
}

// ─────────────────────────────────── 레시피 선택 모달(새 글 전용)
class _RecipeModal extends StatelessWidget {
  const _RecipeModal({required this.recipes, required this.onPick, super.key});

  final List<dynamic> recipes;
  final void Function(int idx, String name, String img) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * .75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('저장된 레시피',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 0),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recipes.length,
              itemBuilder: (_, i) {
                final r = recipes[i] as Map<String, dynamic>;
                final img = r['ATT_FILE_NO_MAIN'] ?? '';
                return ListTile(
                  leading: img.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(img,
                              width: 50, height: 50, fit: BoxFit.cover))
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade300,
                          child:
                              const Icon(Icons.restaurant, color: Colors.grey)),
                  title: Text(r['RCP_NM'] ?? ''),
                  onTap: () {
                    onPick(i, r['RCP_NM'] ?? '', img);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
