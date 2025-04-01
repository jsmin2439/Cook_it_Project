import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'recipe_detail_page.dart';

class HeartScreen extends StatefulWidget {
  final String userId;
  final String idToken;

  const HeartScreen({
    Key? key,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  State<HeartScreen> createState() => HeartScreenState();
}

class HeartScreenState extends State<HeartScreen> {
  // 삭제 모드 on/off
  bool _showDeleteMode = false;

  // * 새로고침을 위해 Future를 저장
  late Future<DocumentSnapshot> _future;

  //--------------------------------------------------------------------------
  // initState에서 Future 할당
  //--------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _future = _fetchUserDoc();
  }

  //--------------------------------------------------------------------------
  // 실제 Firestore에서 즐겨찾기 목록(Future) 가져오기
  //--------------------------------------------------------------------------
  Future<DocumentSnapshot> _fetchUserDoc() {
    return FirebaseFirestore.instance
        .collection('user')
        .doc(widget.userId)
        .get();
  }

  //--------------------------------------------------------------------------
  // 다른 탭에서 HeartScreen으로 돌아올 때 새로고침하고 싶으면 이 메서드를 호출
  //--------------------------------------------------------------------------
  void refreshData() {
    setState(() {
      _future = _fetchUserDoc();
    });
  }

  //--------------------------------------------------------------------------
  // MainScreen에서 toggleDeleteMode()와 마찬가지로 노출하는 메서드
  //--------------------------------------------------------------------------
  void toggleDeleteMode() {
    setState(() {
      _showDeleteMode = !_showDeleteMode;
    });
  }

  //--------------------------------------------------------------------------
  // 빌드
  //--------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // ▼ (중요) RefreshIndicator로 감싸기 ▼
    return RefreshIndicator(
      // 당겨서 새로고침 시 실행될 콜백
      onRefresh: () async {
        // FutureBuilder용 Future를 새로고침
        refreshData();
        // _future가 완료될 때까지 대기 (선택사항)
        await _future;
      },
      child: FutureBuilder<DocumentSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          // 로딩 시
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 데이터 없음
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text("사용자 정보를 찾을 수 없습니다."),
            );
          }

          // savedRecipes
          final docData = snapshot.data!.data() as Map<String, dynamic>;
          final savedList = docData["savedRecipes"] ?? [];

          if (savedList.isEmpty) {
            return const Center(
              child: Text("아직 즐겨찾기에 저장된 레시피가 없습니다."),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            // GridView는 이미 스크롤 가능하므로, RefreshIndicator가 동작함
            child: GridView.builder(
              itemCount: savedList.length,
              physics: const AlwaysScrollableScrollPhysics(), // ← 이 줄 추가
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

  //--------------------------------------------------------------------------
  // 카드 빌드
  //--------------------------------------------------------------------------
  Widget _buildRecipeCard(Map<String, dynamic> recipeData, int index) {
    final imageUrl = recipeData["ATT_FILE_NO_MAIN"] ?? "";
    final recipeName = recipeData["RCP_NM"] ?? "No Title";
    final authorName = recipeData["author"] ?? "Unknown Chef";
    final cookingMethod = recipeData["RCP_WAY2"] ?? "알 수 없음";

    return Stack(
      children: [
        // 카드 형태
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
              // 이미지 영역
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
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.menu_book,
                              size: 40, color: Colors.grey),
                        ),
                      ),
                      // 그라데이션
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
              // 하단 정보
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
                    const Icon(Icons.local_dining,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      cookingMethod,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Spacer(),
                    const Icon(Icons.star_rate_rounded,
                        size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      "${recipeData["rating"] ?? 4.5}", // 임의 예시
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 삭제 모드일 때만 '삭제' 리본 아이콘
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

        // 일반 모드일 때 → RecipeDetailPage 진입
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
                        showEditIcon: true,
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

  //--------------------------------------------------------------------------
  // 삭제 요청
  //--------------------------------------------------------------------------
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
        // 서버 쪽 삭제 성공 후, 즉시 새로고침
        refreshData();
      } else {
        debugPrint("삭제 실패: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("삭제 중 오류: $e");
    }
  }
}
