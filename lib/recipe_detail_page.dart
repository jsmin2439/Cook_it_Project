import 'package:flutter/material.dart';
import 'book_page.dart';

// 배경색 예시
const Color kBackgroundColor = Color(0xFFFFF8EC);

class RecipeDetailPage extends StatelessWidget {
  final Map<String, dynamic> recipeData;

  const RecipeDetailPage({super.key, required this.recipeData});

  @override
  Widget build(BuildContext context) {
    // JSON에서 데이터 추출
    final String recipeName = recipeData["RCP_NM"] ?? "No Title";
    final String imageUrl = recipeData["ATT_FILE_NO_MAIN"] ?? "";
    // 재료 문자열 (예: "돼지등심 60g, 밀가루 4g, 달걀 12g, ...")
    final String ingredientsText = recipeData["RCP_PARTS_DTLS"] ?? "";
    // 1인분, 20분 고정
    final String serving = "1인분";
    final String cookingTime = "20분";

    // 재료 문자열을 리스트로 파싱(, 기준)
    List<String> ingredientList = ingredientsText.split(',');

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
            Image.asset(
              'assets/images/cookie.png',
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 8),
            const Text(
              'Cook it',
              style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: const [
          Icon(Icons.star_border, color: Colors.black),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 레시피 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey,
                    alignment: Alignment.center,
                    child: const Text("No Image"),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 레시피명
            Center(
              child: Text(
                recipeName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 16),

            // 인분 / 시간 / 공유 아이콘 등
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people, color: Colors.black87),
                const SizedBox(width: 4),
                Text(serving, style: const TextStyle(color: Colors.black87)),
                const SizedBox(width: 20),
                const Icon(Icons.timer, color: Colors.black87),
                const SizedBox(width: 4),
                Text(cookingTime, style: const TextStyle(color: Colors.black87)),
                const SizedBox(width: 20),
                const Icon(Icons.share, color: Colors.black87),
                const SizedBox(width: 4),
                const Text('공유', style: TextStyle(color: Colors.black87)),
              ],
            ),
            const Divider(height: 32, thickness: 1, color: Colors.black54),

            // 재료
            const Text(
              '재료',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),

            // 재료 목록 (간단히 한 줄씩)
            ...ingredientList.map((ingredient) {
              final trimmed = ingredient.trim(); // 양옆 공백 제거
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text("- $trimmed", style: const TextStyle(fontSize: 16)),
              );
            }).toList(),
            const SizedBox(height: 24),

            // "COOK IT !!" 버튼
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                child: const Text(
                  'COOK IT !!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}