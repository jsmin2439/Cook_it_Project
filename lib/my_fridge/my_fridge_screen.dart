//lib/my_fridge/my_fridge_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import '../color/colors.dart';
import 'add_ingredient_camera_screen.dart';
import 'add_ingredient_manual_screen.dart';

class MyFridgePage extends StatefulWidget {
  final String userId;
  final String idToken;

  const MyFridgePage({Key? key, required this.userId, required this.idToken})
      : super(key: key);

  @override
  State<MyFridgePage> createState() => _MyFridgePageState();
}

class _MyFridgePageState extends State<MyFridgePage>
    with SingleTickerProviderStateMixin {
  List<String> _ingredients = [];
  bool _isDeleteMode = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _loadUserIngredients();
  }

  /// Firestore에서 재료 배열 불러오기
  Future<void> _loadUserIngredients() async {
    try {
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .get();

      if (docSnapshot.exists) {
        List<dynamic> ingredients = docSnapshot['ingredients'] ?? [];
        setState(() {
          // 중복 제거 및 문자열 리스트로 변환
          _ingredients = List<String>.from(Set<String>.from(ingredients));
        });
      }
    } catch (e) {
      debugPrint("Firestore에서 데이터를 불러오는 중 오류 발생: $e");
    }
  }

  /// 여러 개의 재료를 한 번에 Firestore에 추가
  Future<void> _addIngredientToFirestore(List<String> ingredients) async {
    DocumentReference userDoc =
        FirebaseFirestore.instance.collection('user').doc(widget.userId);

    try {
      await userDoc.update({
        "ingredients": FieldValue.arrayUnion(ingredients)
      }).catchError((error) async {
        // 문서가 없으면 새로 생성
        await userDoc.set({"ingredients": ingredients});
      });

      // Firestore 저장 후 다시 불러와서 UI 갱신
      await _loadUserIngredients();
    } catch (e) {
      debugPrint("재료 추가 오류: $e");
    }
  }

  /// 특정 재료 삭제
  Future<void> _removeIngredientFromFirestore(String ingredient) async {
    DocumentReference userDoc =
        FirebaseFirestore.instance.collection('user').doc(widget.userId);

    await userDoc.update({
      "ingredients": FieldValue.arrayRemove([ingredient])
    });
  }

  /// 📌 사진을 이용한 재료 추가
  Future<void> _addIngredientByPhoto() async {
    final detectedIngredients = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          userId: widget.userId,
          idToken: widget.idToken,
        ),
      ),
    );

    /// [★핵심★] CameraScreen에서 "추가하기" 버튼을 누르면 인식된 식재료 리스트를 반환
    if (detectedIngredients != null && detectedIngredients is List<String>) {
      if (detectedIngredients.isNotEmpty) {
        // 여러 개 재료를 한 번에 추가
        await _addIngredientToFirestore(detectedIngredients);
        // UI 갱신
        setState(() {});
      }
    }
  }

  /// 재료 추가 페이지 이동
  Future<void> _goToAddIngredientPage() async {
    final List<String>? selectedItems = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddIngredientPage(
          currentFridgeIngredients: List.from(_ingredients),
        ),
      ),
    );

    if (selectedItems != null && selectedItems.isNotEmpty) {
      await _addIngredientToFirestore(selectedItems);
      setState(() {});
    }
  }

  /// 개별 재료 삭제
  void _deleteIngredient(String ingredient) {
    setState(() {
      _ingredients.remove(ingredient);
    });
    _removeIngredientFromFirestore(ingredient);
  }

  /// 전체 삭제 확인 다이얼로그
  void _confirmDeleteAllIngredients() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("전체 삭제"),
        content: const Text("정말 모든 재료를 삭제하시겠어요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () async {
              for (String ingredient in _ingredients) {
                await _removeIngredientFromFirestore(ingredient);
              }
              setState(() {
                _ingredients.clear();
                _isDeleteMode = false;
              });
              Navigator.pop(context);
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 재료 아이템 UI
  Widget _buildIngredientItem(String ingredient, int index) {
    return AnimatedBuilder(
      animation:
          _isDeleteMode ? _shakeController : const AlwaysStoppedAnimation(0),
      builder: (context, child) {
        final angle = _isDeleteMode
            ? _shakeController.value * 0.1 * (index.isEven ? 1 : -1)
            : 0.0;
        return Transform.rotate(
          angle: angle,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kPinkButtonColor.withOpacity(0.8), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Chip(
          label: Text(
            ingredient,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          deleteIcon: _isDeleteMode
              ? const Icon(Icons.close, size: 18, color: Colors.redAccent)
              : null,
          onDeleted: _isDeleteMode ? () => _deleteIngredient(ingredient) : null,
          backgroundColor: Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(color: kPinkButtonColor.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kPinkButtonColor, Colors.orangeAccent.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "나만의 냉장고",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: _isDeleteMode
                ? const Icon(Icons.delete_forever, color: Colors.white)
                : const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_isDeleteMode) {
                  _shakeController
                      .animateTo(0.0,
                          duration: const Duration(milliseconds: 200))
                      .then((_) {
                    setState(() {
                      _isDeleteMode = false;
                    });
                  });
                } else {
                  _isDeleteMode = true;
                  _shakeController.repeat(reverse: true);
                }
              });
            },
          ),
          if (_isDeleteMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: () {
                _confirmDeleteAllIngredients();
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: _ingredients.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/empty_fridge.png',
                          width: 200,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "냉장고가 비었어요!",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.5,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: _ingredients.length,
                      itemBuilder: (context, index) {
                        return _buildIngredientItem(_ingredients[index], index);
                      },
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton.extended(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("사진 추가"),
                  backgroundColor: kPinkButtonColor,
                  onPressed: _addIngredientByPhoto,
                ),
                FloatingActionButton.extended(
                  icon: const Icon(Icons.add_circle),
                  label: const Text("재료 추가"),
                  backgroundColor: Colors.orangeAccent,
                  onPressed: _goToAddIngredientPage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }
}
