import 'package:flutter/material.dart';
import 'camera_screen.dart';

const Color kBackgroundColor = Color(0xFFFFFFFF);
const Color kCardColor = Color(0xFFFFECD0);
const Color kPinkButtonColor = Color(0xFFFFC7B9);
const Color kTextColor = Colors.black87;
const double kBorderRadius = 16.0;

class MyFridgePage extends StatefulWidget {
  const MyFridgePage({super.key});

  @override
  State<MyFridgePage> createState() => _MyFridgePageState();
}

class _MyFridgePageState extends State<MyFridgePage> {
  /// 예시용 재료 리스트
  List<String> _ingredients = ["달걀", "양파", "소금", "부추"];

  /// 📌 재료를 텍스트로 직접 추가
  void _addIngredientManually() async {
    String? newIng = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text("재료 추가하기"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "추가할 재료를 입력하세요",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text("추가"),
            ),
          ],
        );
      },
    );

    if (newIng != null && newIng.isNotEmpty) {
      setState(() {
        _ingredients.add(newIng);
      });
    }
  }

  /// 📌 **사진 인식 추가 → CameraScreen 실행 후 결과 받아오기**
  void _addIngredientByPhoto() async {
    final detectedIngredient = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );

    if (detectedIngredient != null && detectedIngredient is String) {
      setState(() {
        _ingredients.add(detectedIngredient);
      });
    }
  }

  /// 📌 재료 전체 삭제
  void _deleteAllIngredients() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("재료 삭제하기"),
        content: const Text("정말 모든 재료를 삭제하시겠어요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _ingredients.clear();
              });
            },
            child: const Text("삭제"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kPinkButtonColor,
        title: const Text(
          "나만의 냉장고",
          style: TextStyle(color: Colors.black87),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 📌 현재 보유 중인 재료 목록
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(kBorderRadius),
                border: Border.all(color: Colors.black87),
              ),
              padding: const EdgeInsets.all(16),
              child: Text(
                "현재 보유중인 재료 목록",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 📌 재료 목록 표시
            Expanded(
              child: _ingredients.isEmpty
                  ? const Center(
                      child: Text("등록된 재료가 없습니다."),
                    )
                  : ListView.builder(
                      itemCount: _ingredients.length,
                      itemBuilder: (context, index) {
                        final ingredient = _ingredients[index];
                        return Card(
                          color: kCardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kBorderRadius),
                            side: const BorderSide(color: Colors.black26),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(
                              ingredient,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 30), // 버튼과 바닥 사이 간격 추가

            // 📌 재료 추가/삭제 버튼
            Wrap(
              spacing: 8.0, // gap between adjacent buttons
              runSpacing: 4.0, // gap between lines
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPinkButtonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _addIngredientManually,
                  child: const Text("재료 직접 추가"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPinkButtonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _addIngredientByPhoto, // 📌 CameraScreen 실행
                  child: const Text("사진 인식 추가"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _deleteAllIngredients,
                  child: const Text("재료 삭제하기"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}