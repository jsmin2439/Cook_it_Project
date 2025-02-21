import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'book_page.dart';

const Color kBackgroundColor = Color(0xFFFFF8EC);

class RecipeDetailPage extends StatelessWidget {
  final Map<String, dynamic> recipeData;
  final String userId;

  const RecipeDetailPage({
    super.key,
    required this.recipeData,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildAppBar(context),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('user').doc(userId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<String> myIngredients =
              List<String>.from(snapshot.data!['ingredients'] ?? []);

          final ingredients =
              _processIngredients(recipeData["RCP_PARTS_DTLS"] ?? "");
          final categorized =
              _categorizeIngredients(ingredients, myIngredients);

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

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
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
          const Text('Cook it',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ],
      ),
      actions: const [
        Icon(Icons.star_border, color: Colors.black),
        SizedBox(width: 16),
      ],
    );
  }

  Widget _buildRecipeImage() {
    final imageUrl = recipeData["ATT_FILE_NO_MAIN"] ?? "";
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 200,
      color: Colors.grey,
      alignment: Alignment.center,
      child: const Text("No Image", style: TextStyle(color: Colors.white)),
    );
  }

  Widget _buildRecipeHeader() {
    final recipeName = recipeData["RCP_NM"] ?? "No Title";
    return Column(
      children: [
        const SizedBox(height: 24),
        Center(
          child: Text(recipeName,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ),
        const SizedBox(height: 16),
        _buildMetaInfoRow(),
        const Divider(height: 32, thickness: 1, color: Colors.black54),
      ],
    );
  }

  Widget _buildMetaInfoRow() {
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
              Text('$title (${ingredients.length}개)',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ingredients
              .map((ing) => _buildIngredientChip(ing, color, icon))
              .toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildIngredientChip(String text, Color color, IconData icon) {
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      side: BorderSide(color: color.withOpacity(0.3)),
      label: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      avatar: Icon(icon, size: 18, color: color),
    );
  }

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
          // 버튼 누르면 BookPage로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookPage(recipeData: recipeData),
            ),
          );
        },
        child: const Text('COOK IT !!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // 재료 처리 및 분류 로직
  Map<String, List<String>> _categorizeIngredients(
      List<String> recipeIngredients, List<String> myIngredients) {
    final owned = <String>[];
    final needed = <String>[];

    for (final ingredient in recipeIngredients) {
      final normalized = _normalizeIngredient(ingredient);
      final isOwned = myIngredients.any(
          (my) => _hasCommonComponents(_normalizeIngredient(my), normalized));

      (isOwned ? owned : needed).add(ingredient);
    }

    return {'owned': owned, 'needed': needed};
  }

  List<String> _processIngredients(String ingredientsText) {
    return ingredientsText.split(',').map((e) => e.trim()).toList();
  }

  String _normalizeIngredient(String ingredient) {
    return ingredient
        .replaceAll(RegExp(r'\d+[g개]'), '') // 숫자+단위 제거
        .trim()
        .toLowerCase();
  }

  bool _hasCommonComponents(String userIngredient, String recipeIngredient) {
    // 1. 정확한 부분 일치 우선 검사
    if (userIngredient.contains(recipeIngredient) ||
        recipeIngredient.contains(userIngredient)) {
      return true;
    }

    // 2. 형태소 분해 후 매칭 규칙 강화
    final userComponents = _splitKoreanComponents(userIngredient);
    final recipeComponents = _splitKoreanComponents(recipeIngredient);

    // 3. 공통 구성 요소 2개 이상 일치 시만 인정
    final common =
        userComponents.toSet().intersection(recipeComponents.toSet());
    return common.length >= 2;
  }

// 개선된 한글 분해 메서드
  List<String> _splitKoreanComponents(String text) {
    // 된장, 청국장 등 복합어 처리
    final compoundWords = ['된장', '청국장', '고추장', '간장'];
    for (var word in compoundWords) {
      if (text.contains(word)) {
        return [word, ...text.replaceAll(word, '').split('')];
      }
    }
    return text.split(RegExp(r'(?<=[\uAC00-\uD7AF])'));
  }
}
