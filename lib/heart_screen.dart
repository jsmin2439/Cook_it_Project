import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'recipe_detail_page.dart'; // 이미 만든 상세 페이지 파일

class HeartScreen extends StatefulWidget {
  final String userId;
  final String idToken;

  const HeartScreen({
    Key? key,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  State<HeartScreen> createState() => _HeartScreenState();
}

class _HeartScreenState extends State<HeartScreen> {
  bool _showDeleteMode = false; // 삭제 모드 on/off

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EC),
      appBar: _buildAppBar(),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('user')
            .doc(widget.userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text("사용자 정보를 찾을 수 없습니다."),
            );
          }

          // savedRecipes 배열 가져오기
          final docData = snapshot.data!.data() as Map<String, dynamic>;
          final savedList = docData["savedRecipes"] ?? [];

          if (savedList.isEmpty) {
            return const Center(
              child: Text("아직 즐겨찾기에 저장된 레시피가 없습니다."),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              itemCount: savedList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) {
                final recipeData = savedList[index];
                return _buildRecipeCard(recipeData, index);
              },
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Image.asset('assets/images/cookie.png', width: 40, height: 40),
          const SizedBox(width: 8),
          const Text(
            'Cook it',
            style: TextStyle(
                color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () {
            setState(() {
              _showDeleteMode = !_showDeleteMode;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipeData, int index) {
    final imageUrl = recipeData["ATT_FILE_NO_MAIN"] ?? "";
    final recipeName = recipeData["RCP_NM"] ?? "No Title";
    final authorName = recipeData["author"] ?? "Unknown Chef"; // 저자 정보 추가 가정

    return Stack(
      children: [
        // 카드 본체
        Container(
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
              // 이미지 영역 (책 커버 스타일)
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
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
                              Colors.black.withOpacity(0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      // 제목 & 저자 정보
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              authorName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 하단 정보 바 (페이지 수 또는 부가 정보)
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
                    Icon(Icons.timer_outlined,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      "${recipeData["cookingTime"] ?? 30}분", // 조리시간 정보 가정
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.star_rate_rounded,
                        size: 16, color: Colors.amber[600]),
                    const SizedBox(width: 4),
                    Text(
                      "${recipeData["rating"] ?? 4.5}", // 평점 정보 가정
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 삭제 버튼 (북마크 리본 스타일)
        if (_showDeleteMode)
          Positioned(
            top: 0,
            right: 12,
            child: GestureDetector(
              onTap: () => _deleteRecipeFromServer(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  '삭제',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

        // 터치 영역
        if (!_showDeleteMode)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailPage(
                        recipeData: recipeData,
                        userId: widget.userId,
                        idToken: widget.idToken,
                        showEditIcon: true, // 이 props로 구분
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // 삭제 요청
  Future<void> _deleteRecipeFromServer(int index) async {
    final url =
        Uri.parse('http://jsmin2439.iptime.org:3000/api/saved-recipe/$index');
    try {
      final response = await http.delete(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.idToken}",
        },
      );
      if (response.statusCode == 200) {
        setState(() {});
      } else {
        debugPrint("삭제 실패: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("삭제 중 오류: $e");
    }
  }
}
