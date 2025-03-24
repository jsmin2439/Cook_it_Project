import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'recipe_detail_page.dart';

// 여기서도 MainScreen과 통일된 색상/스타일을 사용
const Color kBackgroundColor = Color(0xFFFFFFFF);
const Color kCardColor = Color(0xFFFFECD0);
const double kBorderRadius = 16.0;

class SearchScreen extends StatefulWidget {
  final String userId;
  final String idToken;

  const SearchScreen({
    Key? key,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

/// AutomaticKeepAliveClientMixin:
/// 탭 이동 시에도 이 화면의 상태를 유지하기 위함
class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  // 검색 결과
  Map<String, dynamic> _searchInfo = {};
  List<dynamic> _recipes = [];

  // AutomaticKeepAliveClientMixin 구현
  @override
  bool get wantKeepAlive => true;

  //----------------------------------------------------------------------------
  // (1) 검색 요청
  //----------------------------------------------------------------------------
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("검색어를 입력해주세요.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _searchInfo = {};
      _recipes = [];
    });

    final url = Uri.parse("http://jsmin2439.iptime.org:3000/api/smart-search");
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.idToken}',
        },
        body: jsonEncode({"searchQuery": query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          // 검색 결과 세팅
          setState(() {
            _searchInfo = data["searchInfo"] ?? {};
            _recipes = data["recipes"] ?? [];
          });
        } else {
          // success: false 인 경우
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("검색 실패: ${data['message']}")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("서버 오류: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("검색 요청 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버 통신 오류: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //----------------------------------------------------------------------------
  // (2) 빌드
  //----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 주의: super.build 호출
    return Container(
      color: kBackgroundColor,
      child: Column(
        children: [
          // 검색어 입력 필드 (suffixIcon에 검색 아이콘)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _performSearch(), // 엔터키로도 검색
              decoration: InputDecoration(
                hintText: "재료나 레시피를 검색해보세요.",
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _performSearch,
                ),
              ),
            ),
          ),

          // 로딩 중이면 로딩 인디케이터 표시
          if (_isLoading) const LinearProgressIndicator(),

          // 검색 정보 + 결과 목록
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  //----------------------------------------------------------------------------
  // (3) 검색 결과 영역
  //----------------------------------------------------------------------------
  Widget _buildSearchResults() {
    // 아직 아무 검색 전
    if (!_isLoading && _recipes.isEmpty && _searchInfo.isEmpty) {
      return const Center(
        child: Text("검색어를 입력해 주세요."),
      );
    }

    // 검색 완료 후 레시피가 없는 경우
    if (!_isLoading && _recipes.isEmpty && _searchInfo.isNotEmpty) {
      return const Center(
        child: Text("검색 결과가 없습니다."),
      );
    }

    // 검색 정보를 보여주는 위젯 (옵션)
    final detectedIngredients =
        List<String>.from(_searchInfo["detectedIngredients"] ?? []);
    final searchTerms = List<String>.from(_searchInfo["searchTerms"] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 검색된 식재료 / 키워드 요약
        if (detectedIngredients.isNotEmpty || searchTerms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...detectedIngredients.map((ing) {
                  return Chip(
                    label: Text(
                      "재료: $ing",
                      style: const TextStyle(color: Colors.black87),
                    ),
                    backgroundColor: Colors.orange[100],
                  );
                }),
                ...searchTerms.map((t) {
                  return Chip(
                    label: Text(
                      "키워드: $t",
                      style: const TextStyle(color: Colors.black87),
                    ),
                    backgroundColor: Colors.lightBlue[100],
                  );
                }),
              ],
            ),
          ),

        // 레시피 그리드
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              itemCount: _recipes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2열 그리드
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75, // 카드 비율
              ),
              itemBuilder: (context, index) {
                final recipeData = _recipes[index];
                return _buildRecipeCard(recipeData);
              },
            ),
          ),
        ),
      ],
    );
  }

  //----------------------------------------------------------------------------
  // (4) 개별 레시피 카드 (HeartScreen 스타일)
  //----------------------------------------------------------------------------
  Widget _buildRecipeCard(Map<String, dynamic> recipeData) {
    final imageUrl = recipeData["ATT_FILE_NO_MAIN"] ?? "";
    final recipeName = recipeData["RCP_NM"] ?? "No Title";

    // 예시로, 요리방법(RCP_WAY2) 혹은 RCP_SEQ 등 간단 정보 표시
    final cookingMethod = recipeData["RCP_WAY2"] ?? "알 수 없음";

    return InkWell(
      onTap: () {
        // 레시피 상세 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailPage(
              recipeData: recipeData,
              userId: widget.userId,
              idToken: widget.idToken,
              showEditIcon: false, // 검색 화면에서 진입 시 편집아이콘 기본 X
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 이미지 영역
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  children: [
                    // 이미지
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.menu_book,
                            size: 40, color: Colors.grey),
                      ),
                    ),
                    // 그라데이션 오버레이
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // 레시피명
                    Positioned(
                      left: 12,
                      bottom: 12,
                      right: 12,
                      child: Text(
                        recipeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 정보: 예) cookingMethod
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_dining, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    cookingMethod,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  // 다른 정보 (예: RCP_SEQ, etc.)
                  const Icon(Icons.star_rate_rounded,
                      size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    recipeData["RCP_SEQ"]?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
