import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'my_fridge_page.dart';
import 'search_screen.dart';
import 'login_screen.dart';
import 'recipe_detail_page.dart';
import 'heart_screen.dart';
import 'survey_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 기존 색상 팔레트
const Color kBackgroundColor = Color(0xFFFFFFFF); // 연한 베이지
const Color kCardColor = Color(0xFFFFECD0); // 더 진한 베이지
const Color kPinkButtonColor = Color(0xFFFFC7B9); // 연핑크
const Color kTextColor = Colors.black87; // 문구 색
const double kBorderRadius = 16.0; // 카드 라운딩

/// 메인 화면
class MainScreen extends StatefulWidget {
  final String idToken;
  final String userId;
  final String userEmail; // 이메일 필드 추가

  const MainScreen({
    Key? key,
    required this.idToken,
    required this.userId,
    required this.userEmail, // 생성자에 이메일 파라미터 추가
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  /// PageView에서 사용하는 현재 페이지(단, AI 레시피 슬라이드용)
  int _currentPage = 0;
  final PageController _pageController = PageController();

  /// 서버에서 받아온 레시피 목록 (3개만 사용)
  List<dynamic> _recommendedRecipes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRecommendedRecipes();
  }

  /// 서버와 통신하여 추천 레시피 목록을 가져오는 함수
  Future<void> _fetchRecommendedRecipes() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final uri = Uri.parse("http://192.168.0.254:3000/api/recommend-recipes");
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.idToken}" // 토큰 추가
        },
        body: jsonEncode({
          "userId": widget.userId //실제 사용자 ID 사용
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data["recommendedRecipes"] != null) {
          List<dynamic> recipes = data["recommendedRecipes"];
          // 최대 3개만 사용
          _recommendedRecipes = recipes.take(3).toList();
        }
      } else {
        debugPrint('서버 통신 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('오류 발생: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// 로그아웃 처리
  void _handleLogout() {
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  /// BottomNavigationBar 탭 클릭 시
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // 검색 아이콘(여기서는 바텀바의 세 번째 아이템)을 누르면 SearchScreen으로 이동
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SearchScreen()),
      );
    }

    // 🔹 Heart 버튼을 클릭하면 `HeartScreen`으로 이동
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HeartScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // -------------------- 상단 영역 (Cook it 로고 + 알림아이콘) --------------------
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    // Cook it 로고
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/cookie.png', // 쿠키 로고
                          width: 50,
                          height: 50,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cook it',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: kTextColor,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 알림 아이콘
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      color: kTextColor,
                      onPressed: () {
                        // 알림 기능 등
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      color: Colors.red[300],
                      onPressed: _handleLogout,
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: Colors.black26),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  "${widget.userEmail}님 환영합니다",
                  style: TextStyle(
                    fontSize: 16,
                    color: kTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 구분선
              Container(height: 1, color: Colors.black26),

              // (검색바는 제거함)

              const SizedBox(height: 8),

              // -------------------- 중간: '나만의 냉장고' + 'AI 레시피' (같은 높이) --------------------
              /// 두 위젯의 높이를 동일하게 맞추기 위해 Row 안에 Expanded 위젯을 사용하고,
              /// 내부에서 높이를 고정 혹은 Expanded 처리
              Column(
                children: [
                  // "나만의 냉장고" (크기 증가)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      height: 240, // ✅ 크기 증가
                      child: _buildMyFridgeCard(),
                    ),
                  ),
                  // "AI 레시피" (크기 증가)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      height: 240, // ✅ 크기 증가
                      child: _buildAiRecipeCard(),
                    ),
                  ),
                ],
              ),

              // 구분선
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 1,
                color: Colors.black26,
              ),

              // -------------------- 3) 나의 식습관 좌표 FMBT --------------------
              _buildTasteLabCard(),

              // 구분선
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 1,
                color: Colors.black26,
              ),

              // -------------------- 5) 싫어하거나 피하고 싶은 재료가 있나요? --------------------
              _buildIngredientsCard(),
            ],
          ),
        ),
      ),

      // -------------------- 하단 네비게이션 바 --------------------
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        items: const <BottomNavigationBarItem>[
          // 1) 홈
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          // 2) Category
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Category',
          ),
          // 3) 검색
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          // 4) Heart
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Heart',
          ),
          // 5) Comm
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            label: 'Comm',
          ),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // 아래부터는 동일한 기능 + 수정된 레이아웃, 글자 크기, etc.
  //--------------------------------------------------------------------------

  /// "나만의 냉장고" 카드
  /// "나만의 냉장고" 카드
  Widget _buildMyFridgeCard() {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(kBorderRadius),
        border: Border.all(color: Colors.black87),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.kitchen_outlined,
                      size: 28, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text(
                    "나만의 냉장고",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 냉장고 재료 미리보기
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('user')
                    .doc(widget.userId)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData ||
                      !snapshot.data!.exists ||
                      (snapshot.data!['ingredients'] as List).isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "재료를 추가해보세요!",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    );
                  }

                  List<String> ingredients =
                      List<String>.from(snapshot.data!['ingredients'])
                          .take(10) // 최대 10개만 표시
                          .toList();

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...ingredients.map((ingredient) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: kPinkButtonColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: kPinkButtonColor.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              ingredient,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          )),
                      if ((snapshot.data!['ingredients'] as List).length > 10)
                        Text(
                          "+ ${(snapshot.data!['ingredients'] as List).length - 10}개 더 보기",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text("관리하기"),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPinkButtonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyFridgePage(
                        userId: widget.userId, idToken: widget.idToken),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// "내 취향에 맞는 AI 레시피" 카드
  Widget _buildAiRecipeCard() {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(kBorderRadius),
        border: Border.all(color: Colors.black87),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/cookbook.png',
                      width: 28,
                      height: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "AI 맞춤 레시피",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchRecommendedRecipes,
                      color: Colors.black54,
                      tooltip: '새로고침',
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recommendedRecipes.isEmpty
                      ? const Center(child: Text("추천 레시피가 없습니다."))
                      : PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            // 페이지 변경 시 콜백 추가
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemCount: _recommendedRecipes.length,
                          itemBuilder: (context, index) {
                            final recipe = _recommendedRecipes[index];
                            return _buildRecipeItem(recipe);
                          },
                        ),
            ),
            if (!_isLoading && _recommendedRecipes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _recommendedRecipes.length,
                    (index) => _buildDot(isActive: index == _currentPage),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// AI 레시피 개별 아이템 (이미지 + 이름)
  Widget _buildRecipeItem(dynamic recipe) {
    final String imageUrl = recipe["ATT_FILE_NO_MAIN"] ?? "";
    final String recipeName = recipe["RCP_NM"] ?? "No Name";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailPage(
              recipeData: recipe,
              userId: widget.userId, // 추가
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              height: 128, // 이미지 높이 고정
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.fitWidth,
                ),
              ),
              child: imageUrl.isEmpty
                  ? const Center(child: Text("No Image"))
                  : null,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                recipeName,
                style: const TextStyle(fontSize: 14),
                maxLines: 2, // 최대 2줄 제한
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 페이지 인디케이터용 작은 원
  Widget _buildDot({required bool isActive}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 8 : 6,
      height: isActive ? 8 : 6,
      decoration: BoxDecoration(
        color: isActive ? Colors.black87 : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }

  /// "나만의 입맛 분석소" 큰 박스 위젯
  Widget _buildTasteLabCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 252, 240, 162),
          borderRadius: BorderRadius.circular(kBorderRadius),
          border: Border.all(color: Colors.black87),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16), // 내부 여백 추가
        child: Column(
          children: [
            // 📌 제목 (나만의 입맛 분석소)
            Text(
              "나만의 입맛 분석소",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kTextColor,
              ),
            ),
            const SizedBox(height: 12), // 제목과 카드 사이 간격

            // 📌 두 개의 위젯을 같은 너비로 정렬 + 간격 추가
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // "나의 식습관 좌표 FMBT"
                Expanded(
                  child: _buildCard(
                    title: "나의 식습관 좌표 FMBT",
                    buttonText: "검사하기",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SurveyScreen()),
                      );
                    },
                    backgroundColor:
                        kPinkButtonColor.withOpacity(0.8), // 카드 색 강조
                    isSmall: true, // 크기 줄이기
                  ),
                ),
                const SizedBox(width: 12), // 👉 위젯 사이 간격 추가
                // "취향 탐구 시작!!"
                Expanded(
                  child: _buildCard(
                    title: "맛 취향 분석",
                    buttonText: "검사하기",
                    onPressed: () {},
                    backgroundColor:
                        kPinkButtonColor.withOpacity(0.8), // 연핑크 강조
                    isSmall: true, // 크기 줄이기
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// 카드 위젯 수정 (배경색 추가)
  /// 카드 위젯 (작은 크기 조절 가능)
  Widget _buildCard({
    required String title,
    required String buttonText,
    required VoidCallback onPressed,
    Color? backgroundColor,
    bool isSmall = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? kCardColor, // 기본 색상 유지
        borderRadius: BorderRadius.circular(kBorderRadius),
        border: Border.all(color: Colors.black87),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 10 : 12,
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmall ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8), // 버튼과의 간격 조정
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(197, 170, 10, 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onPressed,
            child: Text(
              buttonText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// "싫어하거나 피하고 싶은 재료가 있나요?" 카드 (5번)
  Widget _buildIngredientsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(kBorderRadius),
          border: Border.all(color: Colors.black87),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              "싫어하거나 피하고 싶은 재료가 있나요?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // 예시: 3가지 칩
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildIngredientChip("알코올"),
                _buildIngredientChip("달걀"),
                _buildIngredientChip("우유"),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPinkButtonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                // 수정하기
              },
              child: const Text("수정하기"),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black45),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }
}
