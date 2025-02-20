import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'colors.dart';

class AddIngredientPage extends StatefulWidget {
  const AddIngredientPage({Key? key}) : super(key: key);

  @override
  State<AddIngredientPage> createState() => _AddIngredientPageState();
}

class _AddIngredientPageState extends State<AddIngredientPage> {
  /// CSV에서 불러온 전체 식재료 목록
  List<String> _allIngredients = [];

  /// 검색어에 따른 필터링된 목록
  List<String> _filteredIngredients = [];

  /// 선택된 재료들 (다중 선택)
  final Set<String> _selectedIngredients = {};

  /// 검색어
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadIngredientsFromCSV();
  }

  Future<void> _loadIngredientsFromCSV() async {
  try {
    final csvString = await rootBundle.loadString('assets/ingredients.csv');
    final lines = const LineSplitter().convert(csvString);

    // 📌 불러온 데이터를 List로 변환 후 한글 기준 정렬
    List<String> tempList = lines.map((e) => e.trim()).toList();
    tempList.sort((a, b) => a.compareTo(b)); // 기본 가나다순 정렬

    setState(() {
      _allIngredients = tempList;
      _filteredIngredients = List.from(_allIngredients);
    });
  } catch (e) {
    debugPrint("CSV 파일 로드 에러: $e");
    setState(() {
      _allIngredients = [];
      _filteredIngredients = [];
    });
  }
}

   // 검색어에 따라 필터링
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
      if (_searchQuery.isEmpty) {
        _filteredIngredients = _allIngredients;
      } else {
        _filteredIngredients = _allIngredients
            .where((item) => item.contains(_searchQuery))
            .toList();
      }
    });
  }

  /// 재료 탭(토글) 시 선택/해제
  void _toggleSelection(String ingredient) {
    setState(() {
      if (_selectedIngredients.contains(ingredient)) {
        _selectedIngredients.remove(ingredient);
      } else {
        _selectedIngredients.add(ingredient);
      }
    });
  }

  /// 선택한 재료들을 MyFridgePage로 전달
  void _onAddSelected() {
    if (_selectedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("재료를 선택해보세요."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    // 선택된 재료를 List로 변환해서 pop
    Navigator.pop(context, _selectedIngredients.toList());
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _selectedIngredients.length;
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "재료 추가하기",
          style: TextStyle(color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: kBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 검색창
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(kBorderRadius),
            ),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "재료명을 검색해보세요.",
                border: InputBorder.none,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          // 검색어 초기화
                          _onSearchChanged("");
                        },
                      )
                    : const Icon(Icons.search),
              ),
            ),
          ),

          // 필터링된 재료 목록 표시 (Grid or Wrap)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _filteredIngredients.isEmpty
                  ? const Center(
                      child: Text("검색 결과가 없습니다."),
                    )
                  : GridView.builder(
                      // 2~3열 정도로 보이는 예시
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,     // 한 행에 4개씩 보여주기 (디자인에 맞게 조절)
                        mainAxisSpacing: 10,   // 수직 간격
                        crossAxisSpacing: 10,  // 수평 간격
                        childAspectRatio: 0.7, // 가로/세로 비율
                      ),
                      itemCount: _filteredIngredients.length,
                      itemBuilder: (context, index) {
                        final ingredient = _filteredIngredients[index];
                        final isSelected = _selectedIngredients.contains(ingredient);

                        return GestureDetector(
                          onTap: () => _toggleSelection(ingredient),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 아이콘(이미지) 부분
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kPinkButtonColor.withOpacity(0.3)
                                      : const Color(0xFFF9F9F9),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.redAccent
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.fastfood, // 실제 앱에서는 Image.asset(...) 사용
                                  color: isSelected
                                      ? Colors.redAccent
                                      : Colors.grey,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // 식재료 이름
                              Text(
                                ingredient,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),

          // 하단 고정 버튼 영역
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: itemCount > 0
                    ? Colors.redAccent
                    : Colors.redAccent.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kBorderRadius),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _onAddSelected,
              child: Text(
                itemCount > 0
                    ? "재료 추가하기 $itemCount개"
                    : "재료를 선택해보세요",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}