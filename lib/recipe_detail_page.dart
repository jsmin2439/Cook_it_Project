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
  // 4) 북마크 아이콘 눌렀을 때 토글
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
    ).then((result) {
      if (result != null) {
        // result는 수정 후 돌아온 updatedRecipe
        setState(() {
          // widget.recipeData를 새로 갱신
          widget.recipeData.clear();
          widget.recipeData.addAll(result);

          // 필요하면 _checkIfFavorited() 다시 호출 가능
          // _checkIfFavorited();
        });
      }
    });
  }

  //--------------------------------------------------------------------------
  // 빌드
  //--------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipeData;

    // "후식", "밥", "반찬" 등 RCP_PAT2
    final category = recipe["RCP_PAT2"] ?? "카테고리 정보 없음";
    // "기타", "볶기" 등 RCP_WAY2
    final cookingWay = recipe["RCP_WAY2"] ?? "조리방법 정보 없음";
    // 추천 사유
    final recommendReason = recipe["recommendReason"] ?? "";
    // 영양 팁 or 레시피 팁
    final recipeTip = recipe["RCP_NA_TIP"] ?? "";

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 공유 아이콘
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: _handleShare,
          ),
          // (A) showEditIcon == true 인 경우에만 편집 아이콘
          if (widget.showEditIcon)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              onPressed: _goToEditPage,
            ),
          // (B) 즐겨찾기 아이콘
          IconButton(
            icon: Icon(
              _isFavorited ? Icons.bookmark : Icons.bookmark_border,
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
              _processIngredients(recipe["RCP_PARTS_DTLS"] ?? "");
          final categorized =
              _categorizeIngredients(rawIngredients, myIngredients);

          return Column(
            children: [
              // (1) 스크롤되는 콘텐츠
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 레시피 메인 이미지
                      _buildRecipeImage(),
                      const SizedBox(height: 16),

                      // 레시피명
                      _buildRecipeTitle(recipe["RCP_NM"] ?? "No Title"),

                      // 세련된 정보 카드: category, cookingWay, recommendReason
                      _buildMetaSection(category, cookingWay),
                      const SizedBox(height: 24),

                      // AI 추천 이유
                      if (recommendReason.isNotEmpty)
                        _buildInfoCard(
                          icon: Icons.auto_awesome,
                          title: "AI 추천 이유",
                          content: recommendReason,
                          color: Colors.blue[100]!,
                          iconColor: Colors.blue,
                        ),

                      // 레시피 팁 (RCP_NA_TIP)
                      if (recipeTip.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _buildTipCard(recipeTip),
                        ),

                      // 보유 재료 / 필요 재료
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
                    ],
                  ),
                ),
              ),

              // 하단 "COOK IT !!" 버튼
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildCookButton(context),
              ),
            ],
          );
        },
      ),
    );
  }

  //--------------------------------------------------------------------------
  // 공유 아이콘 눌렀을 때
  //--------------------------------------------------------------------------
  void _handleShare() {
    // TODO: 실제 공유 로직 (e.g. Share.share("이 레시피를 공유합니다: ..."))
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("공유 기능은 아직 구현되지 않았습니다.")),
    );
  }

  Widget _buildMetaSection(String category, String CookingWay) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMetaChip('음식 종류: $category', Icons.restaurant),
          _buildMetaChip('조리 방법: $CookingWay', Icons.kitchen),
        ],
      ),
    );
  }

  Widget _buildMetaChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style:
                TextStyle(fontSize: 15, height: 1.4, color: Colors.grey[800]),
          ),
        ],
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
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 220,
          color: Colors.grey,
          alignment: Alignment.center,
          child: const Text("No Image", style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // 레시피 제목
  //--------------------------------------------------------------------------
  Widget _buildRecipeTitle(String name) {
    return Center(
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  //--------------------------------------------------------------------------
  // 레시피 팁 (RCP_NA_TIP)
  //--------------------------------------------------------------------------
  Widget _buildTipCard(String tip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "TIP : " + tip,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              '$title (${ingredients.length}개)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ingredients.map((ing) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                ing,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // "COOK IT !!" 버튼
  //--------------------------------------------------------------------------
  Widget _buildCookButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      child: Image.asset(
        'assets/images/CookIT.png',
        width: 90,
        height: 50,
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
