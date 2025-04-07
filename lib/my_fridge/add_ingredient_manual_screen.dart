import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../color/colors.dart';

class AddIngredientPage extends StatefulWidget {
  final List<String> currentFridgeIngredients; // 현재 냉장고 재료 목록

  const AddIngredientPage({Key? key, required this.currentFridgeIngredients})
      : super(key: key);

  @override
  State<AddIngredientPage> createState() => _AddIngredientPageState();
}

class _AddIngredientPageState extends State<AddIngredientPage> {
  /// Firestore에서 불러온 전체 식재료 목록 (중복 제거)
  List<String> _allIngredients = [];

  /// 현재 냉장고에 없는 식재료 목록 (필터링된 결과)
  List<String> _filteredIngredients = [];

  /// 검색어에 따른 필터링된 목록
  List<String> _searchResults = [];

  /// 선택된 재료들 (다중 선택)
  final Set<String> _selectedIngredients = {};

  /// 검색어
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadIngredientsFromFirestore();
  }

  /// **📌 Firestore에서 `ingredients` 컬렉션 데이터를 불러오면서 중복 제거**
  Future<void> _loadIngredientsFromFirestore() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('ingredients').get();

      // ✅ 중복된 식재료 제거 후 리스트 변환
      List<String> tempList = querySnapshot.docs
          .map((doc) => doc['식재료'] as String)
          .toSet() // 중복 제거
          .toList();

      // ✅ 현재 냉장고(my_fridge)에 있는 재료들을 제거한 새로운 목록 생성
      tempList.removeWhere(
          (ingredient) => widget.currentFridgeIngredients.contains(ingredient));

      tempList.sort(); // 가나다순 정렬

      setState(() {
        _allIngredients = tempList;
        _filteredIngredients = List.from(_allIngredients);
        _searchResults = List.from(_filteredIngredients);
      });
    } catch (e) {
      debugPrint("Firestore 데이터 로드 오류: $e");
      setState(() {
        _allIngredients = [];
        _filteredIngredients = [];
      });
    }
  }

  /// **검색어에 따라 필터링**
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
      if (_searchQuery.isEmpty) {
        _searchResults = _filteredIngredients;
      } else {
        _searchResults = _filteredIngredients
            .where((item) => item.contains(_searchQuery))
            .toList();
      }
    });
  }

  /// **재료 탭(토글) 시 선택/해제**
  void _toggleSelection(String ingredient) {
    setState(() {
      if (_selectedIngredients.contains(ingredient)) {
        _selectedIngredients.remove(ingredient);
      } else {
        _selectedIngredients.add(ingredient);
      }
    });
  }

  /// **선택한 재료들을 MyFridgePage로 전달하고 목록에서 삭제**
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

    List<String> addedIngredients = _selectedIngredients.toList();

    setState(() {
      // ✅ 선택한 재료는 필터링된 목록에서도 삭제
      _filteredIngredients
          .removeWhere((ingredient) => addedIngredients.contains(ingredient));
      _searchResults
          .removeWhere((ingredient) => addedIngredients.contains(ingredient));
      _selectedIngredients.clear();
    });

    Navigator.pop(context, addedIngredients);
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
                          _onSearchChanged("");
                        },
                      )
                    : const Icon(Icons.search),
              ),
            ),
          ),

          // 필터링된 재료 목록 표시
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _searchResults.isEmpty
                  ? const Center(
                      child: Text("추가 가능한 재료가 없습니다."),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final ingredient = _searchResults[index];
                        final isSelected =
                            _selectedIngredients.contains(ingredient);

                        return ListTile(
                          title: Text(
                            ingredient,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.redAccent
                                  : Colors.black87,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Colors.redAccent)
                              : null,
                          onTap: () => _toggleSelection(ingredient),
                        );
                      },
                    ),
            ),
          ),

          // 하단 추가 버튼
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
                itemCount > 0 ? "재료 추가하기 $itemCount개" : "재료를 선택해보세요",
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
