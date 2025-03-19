import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'book_page.dart';
import 'edit_recipe_book.dart';

const Color kBackgroundColor = Color(0xFFFFF8EC);

class RecipeDetailPage extends StatefulWidget {
  final Map<String, dynamic> recipeData;
  final String userId;
  final String idToken;

  // HeartScreen에서 진입할 때만 true로 세팅 -> 편집 아이콘 보이게
  final bool showEditIcon;

  const RecipeDetailPage({
    Key? key,
    required this.recipeData,
    required this.userId,
    required this.idToken,
    this.showEditIcon = false, // 기본값 false
  }) : super(key: key);

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  bool _isFavorited = false; // 즐겨찾기(하트) 상태

  @override
  void initState() {
    super.initState();
    _checkIfFavorited(); // 현재 레시피가 이미 즐겨찾기에 저장되어 있는지 서버에 확인
  }

  //--------------------------------------------------------------------------
  // 1) 이미 즐겨찾기에 등록된 레시피인지 서버로 조회
  //--------------------------------------------------------------------------
  Future<void> _checkIfFavorited() async {
    final recipeId = widget.recipeData["id"]?.toString() ?? "";
    if (recipeId.isEmpty) return; // ID가 없으면 중단

    final url = Uri.parse(
        'http://jsmin2439.iptime.org:3000/api/saved-recipes/$recipeId');
    try {
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.idToken}",
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        bool isSaved = data["isSaved"] == true;
        setState(() => _isFavorited = isSaved);
      } else {
        debugPrint("즐겨찾기 여부 조회 실패: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("오류: $e");
    }
  }

  //--------------------------------------------------------------------------
  // 2) 즐겨찾기 등록(POST)
  //--------------------------------------------------------------------------
  Future<void> _saveRecipeToServer() async {
    final recipeId = widget.recipeData["id"]?.toString() ?? "";
    if (recipeId.isEmpty) return;

    final url = Uri.parse('http://jsmin2439.iptime.org:3000/api/save-recipe');
    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.idToken}",
        },
        body: jsonEncode({"recipeId": recipeId}),
      );
      if (response.statusCode == 200) {
        setState(() => _isFavorited = true);
      } else {
        debugPrint("즐겨찾기 등록 실패: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("서버 오류: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("즐겨찾기 등록 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버 통신 오류: $e")),
      );
    }
  }

  //--------------------------------------------------------------------------
  // 3) 즐겨찾기 해제(DELETE)
  //--------------------------------------------------------------------------
  Future<void> _removeRecipeFromServer() async {
    final recipeId = widget.recipeData["id"]?.toString() ?? "";
    if (recipeId.isEmpty) return;

    final url = Uri.parse(
        'http://jsmin2439.iptime.org:3000/api/saved-recipes/$recipeId');
    try {
      final response = await http.delete(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.idToken}",
        },
      );
      if (response.statusCode == 200) {
        setState(() => _isFavorited = false);
      } else {
        debugPrint("즐겨찾기 해제 실패: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("서버 오류: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("즐겨찾기 해제 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버 통신 오류: $e")),
      );
    }
  }

  //--------------------------------------------------------------------------
  // 4) 하트 아이콘 눌렀을 때 토글
  //--------------------------------------------------------------------------
  void _toggleFavorite() {
    if (_isFavorited) {
      _removeRecipeFromServer();
    } else {
      _saveRecipeToServer();
    }
  }

  //--------------------------------------------------------------------------
  // 편집 아이콘 눌렀을 때 -> EditRecipeBook 페이지로 이동
  //--------------------------------------------------------------------------
  void _goToEditPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditRecipeBook(
          userId: widget.userId,
          idToken: widget.idToken,
          originalRecipe: Map<String, dynamic>.from(widget.recipeData),
        ),
      ),
    ).then((_) {
      // 편집 후 돌아오면 setState로 재빌드(갱신)
      setState(() {});
    });
  }

  //--------------------------------------------------------------------------
  // 빌드
  //--------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.asset('assets/images/cookie.png', width: 40, height: 40),
            const SizedBox(width: 8),
            const Text(
              'Cook it',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // (A) showEditIcon == true 인 경우에만 편집 아이콘
          if (widget.showEditIcon)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              onPressed: _goToEditPage,
            ),
          // (B) 즐겨찾기 아이콘
          IconButton(
            icon: Icon(
              _isFavorited ? Icons.favorite : Icons.favorite_border,
              color: _isFavorited ? Colors.redAccent : Colors.black,
            ),
            onPressed: _toggleFavorite,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('user')
            .doc(widget.userId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // 사용자 냉장고 재료
          final myIngredients = List<String>.from(
            snapshot.data!['ingredients'] ?? [],
          );

          // 레시피 재료 문자열 -> 리스트
          final rawIngredients =
              _processIngredients(widget.recipeData["RCP_PARTS_DTLS"] ?? "");
          final categorized =
              _categorizeIngredients(rawIngredients, myIngredients);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRecipeImage(),
                _buildRecipeHeader(),
                _buildIngredientSection(
                  title: '보유 재료',
                  ingredients: categorized['owned']!,
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
                _buildIngredientSection(
                  title: '필요 재료',
                  ingredients: categorized['needed']!,
                  icon: Icons.cancel,
                  color: Colors.red,
                ),
                _buildCookButton(context),
              ],
            ),
          );
        },
      ),
    );
  }

  //--------------------------------------------------------------------------
  // 레시피 이미지
  //--------------------------------------------------------------------------
  Widget _buildRecipeImage() {
    final imageUrl = widget.recipeData["ATT_FILE_NO_MAIN"] ?? "";
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          color: Colors.grey,
          alignment: Alignment.center,
          child: const Text("No Image", style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // 레시피 헤더(제목, 메타정보)
  //--------------------------------------------------------------------------
  Widget _buildRecipeHeader() {
    final recipeName = widget.recipeData["RCP_NM"] ?? "No Title";
    return Column(
      children: [
        const SizedBox(height: 24),
        Center(
          child: Text(
            recipeName,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
        ),
        const SizedBox(height: 16),
        _buildMetaInfoRow(),
        const Divider(height: 32, thickness: 1, color: Colors.black54),
      ],
    );
  }

  Widget _buildMetaInfoRow() {
    // 임의: 1인분, 20분, 공유
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.people, color: Colors.black87),
        SizedBox(width: 4),
        Text('1인분', style: TextStyle(color: Colors.black87)),
        SizedBox(width: 20),
        Icon(Icons.timer, color: Colors.black87),
        SizedBox(width: 4),
        Text('20분', style: TextStyle(color: Colors.black87)),
        SizedBox(width: 20),
        Icon(Icons.share, color: Colors.black87),
        SizedBox(width: 4),
        Text('공유', style: TextStyle(color: Colors.black87)),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // 재료 섹션
  //--------------------------------------------------------------------------
  Widget _buildIngredientSection({
    required String title,
    required List<String> ingredients,
    required IconData icon,
    required Color color,
  }) {
    if (ingredients.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Text(
                '$title (${ingredients.length}개)',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ingredients.map((ing) {
            return Chip(
              backgroundColor: color.withOpacity(0.15),
              side: BorderSide(color: color.withOpacity(0.3)),
              label: Text(
                ing,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
              avatar: Icon(icon, size: 18, color: color),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // "COOK IT !!" 버튼
  //--------------------------------------------------------------------------
  Widget _buildCookButton(BuildContext context) {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 50),
        ),
        onPressed: () {
          // BookPage로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookPage(recipeData: widget.recipeData),
            ),
          );
        },
        child: const Text(
          'COOK IT !!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // (c) 재료 처리 로직
  //--------------------------------------------------------------------------
  Map<String, List<String>> _categorizeIngredients(
      List<String> recipeIngredients, List<String> myIngredients) {
    final owned = <String>[];
    final needed = <String>[];

    for (final ingredient in recipeIngredients) {
      final normalized = _normalizeIngredient(ingredient);
      final isOwned = myIngredients.any((mine) =>
          _hasCommonComponents(_normalizeIngredient(mine), normalized));

      (isOwned ? owned : needed).add(ingredient);
    }

    return {'owned': owned, 'needed': needed};
  }

  List<String> _processIngredients(String ingredientsText) {
    return ingredientsText.split(',').map((e) => e.trim()).toList();
  }

  String _normalizeIngredient(String ingredient) {
    return ingredient.replaceAll(RegExp(r'\d+[g개]'), '').trim().toLowerCase();
  }

  bool _hasCommonComponents(String userIng, String recipeIng) {
    // 완전 포함 우선
    if (userIng.contains(recipeIng) || recipeIng.contains(userIng)) {
      return true;
    }
    // 형태소 비교
    final userSet = _splitKoreanComponents(userIng).toSet();
    final recipeSet = _splitKoreanComponents(recipeIng).toSet();
    final common = userSet.intersection(recipeSet);
    return common.length >= 2;
  }

  List<String> _splitKoreanComponents(String text) {
    final compoundWords = ['된장', '청국장', '고추장', '간장'];
    for (var w in compoundWords) {
      if (text.contains(w)) {
        return [w, ...text.replaceAll(w, '').split('')];
      }
    }
    return text.split(RegExp(r'(?<=[\uAC00-\uD7AF])'));
  }
}
