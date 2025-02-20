import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'colors.dart';
import 'camera_screen.dart';
import 'add_ingredient_page.dart';

class MyFridgePage extends StatefulWidget {
  const MyFridgePage({Key? key}) : super(key: key);

  @override
  State<MyFridgePage> createState() => _MyFridgePageState();
}

class _MyFridgePageState extends State<MyFridgePage> with SingleTickerProviderStateMixin {
  List<String> _ingredients = [];
  bool _isDeleteMode = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this, // ✅ SingleTickerProviderStateMixin을 추가했으므로 정상 작동
    )..repeat(reverse: true);
  }

  Future<void> _addIngredientByPhoto() async {
    final detectedIngredient = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (detectedIngredient != null && detectedIngredient is String) {
      setState(() {
        _ingredients.add(detectedIngredient);
      });
    }
  }

  /// 📌 재료 추가 페이지로 이동
  Future<void> _goToAddIngredientPage() async {
    final List<String>? selectedItems = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddIngredientPage()),
    );
    if (selectedItems != null && selectedItems.isNotEmpty) {
      setState(() {
        _ingredients.addAll(selectedItems);
      });
    }
  }

  /// 📌 개별 재료 삭제 (삭제 버튼 클릭 시)
  void _deleteIngredient(String ingredient) {
    setState(() {
      _ingredients.remove(ingredient);
    });
  }

  /// 📌 전체 삭제 확인 다이얼로그
  void _confirmDeleteAllIngredients() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("전체 삭제"),
        content: const Text("정말 모든 재료를 삭제하시겠어요?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          TextButton(
            onPressed: () {
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

  /// 📌 재료 아이템 UI (삭제 모드 시 애니메이션 적용)
  Widget _buildIngredientItem(String ingredient, int index) {
    return AnimatedBuilder(
      animation: _isDeleteMode ? _shakeController : AlwaysStoppedAnimation(0),
      builder: (context, child) {
        final angle = _isDeleteMode ? _shakeController.value * 0.1 * (index.isEven ? 1 : -1) : 0.0;
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
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          deleteIcon: const Icon(Icons.close, size: 18),
          onDeleted: _isDeleteMode ? () => _deleteIngredient(ingredient) : null,
          backgroundColor: Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: kPinkButtonColor.withOpacity(0.3))),
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
        title: Column(
          children: [
            const Text(
              "나만의 냉장고",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                shadows: [
                  Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                ],
              ),
            ),
            if (_isDeleteMode)
              const Text(
                "삭제할 재료를 선택해주세요",
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isDeleteMode
                  ? const Icon(Icons.delete_forever, key: Key('delete'))
                  : const Icon(Icons.delete_outline, key: Key('no-delete')),
            ),
            onPressed: () {
              setState(() => _isDeleteMode = !_isDeleteMode);
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
                        Image.asset('assets/images/empty_fridge.png', width: 200),
                        const SizedBox(height: 20),
                        Text(
                          "냉장고가 비었어요!",
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 10),
                        const Text("아래 버튼을 눌러 재료를 추가해보세요", style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.5,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: _ingredients.length,
                      itemBuilder: (context, index) => _buildIngredientItem(_ingredients[index], index),
                    ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'camera',
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text("사진 추가"),
                  backgroundColor: kPinkButtonColor,
                  onPressed: _addIngredientByPhoto,
                  elevation: 4,
                ),
                FloatingActionButton.extended(
                  heroTag: 'add',
                  icon: const Icon(Icons.add_circle, color: Colors.white),
                  label: const Text("직접 추가"),
                  backgroundColor: Colors.orangeAccent,
                  onPressed: _goToAddIngredientPage,
                  elevation: 4,
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: _ingredients.isNotEmpty && !_isDeleteMode
          ? FloatingActionButton(
              child: const Icon(Icons.delete_sweep),
              backgroundColor: Colors.redAccent,
              onPressed: _confirmDeleteAllIngredients,
            )
          : null,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }
}