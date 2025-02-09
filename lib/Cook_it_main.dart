import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'Cook_it_login.dart';
import 'Cook_it_splash.dart';
import 'recipe_detail_page.dart';
import 'book_page.dart';

// 색상 팔레트 (예시)
const Color kBackgroundColor = Color(0xFFFFF8EC); // 연한 베이지
const Color kCardColor = Color(0xFFFFECD0);       // 더 진한 베이지
const Color kPinkButtonColor = Color(0xFFFFC7B9); // 연핑크
const Color kTextColor = Colors.black87;          // 문구 색
const double kBorderRadius = 16.0;                // 카드 라운딩

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  /// 서버에서 받아온 레시피 목록 (3개만 사용한다고 가정)
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
      // 예시: POST로 userId 넘기는 구조
      final uri = Uri.parse("https://api-lij5rc3veq-uc.a.run.app/recommend-recipes");
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": "user123"}),  // raw 데이터 예시
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CookItLogin()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 영역 (Cook it 로고 + 알림아이콘)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // 구분선
            Container(height: 1, color: Colors.black26),

            // 상단 검색바
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black26),
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "맛있는 요리 하실 준비 되셨나요??",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: Icon(Icons.search, color: Colors.black45),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            // 스크롤 가능 영역
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 1) 내 취향에 맞는 AI 레시피
                    _buildAiRecipeCard(),

                    // 구분선
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      height: 1,
                      color: Colors.black26,
                    ),
                    // 2) 나의 냉장고로 만들 수 있는 음식은?
                    _buildCard(
                      title: "나의 냉장고로 만들 수 있는 음식은 ?",
                      buttonText: "찾아보기",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BookPage()),
                        );
                      },
                    ),
                    // 구분선
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      height: 1,
                      color: Colors.black26,
                    ),
                    // 3) 나의 식습관 좌표 FMBT
                    _buildCard(
                      title: "나의 식습관 좌표 FMBT",
                      buttonText: "검사하기",
                      onPressed: () {},
                    ),
                    // 구분선
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      height: 1,
                      color: Colors.black26,
                    ),
                    // 4) 취향 탐구 시작!!
                    _buildCard(
                      title: "취향 탐구 시작!!",
                      buttonText: "검사하기",
                      onPressed: () {},
                    ),
                    // 구분선
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      height: 1,
                      color: Colors.black26,
                    ),
                    // 5) 싫어하거나 피하고 싶은 재료가 있나요?
                    _buildIngredientsCard(),
                    const SizedBox(height: 80), // 하단여백 (BottomNavigationBar 공간)
                  ],
                ),
              ),
            ),

            // 로그인 버튼
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _navigateToLogin,
                child: const Text('로그인 화면으로 이동'),
              ),
            ),
          ],
        ),
      ),

      // 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Category',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Heart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            label: 'Comm',
          ),
        ],
      ),
    );
  }

  /// "내 취향에 맞는 AI 레시피" 카드
  Widget _buildAiRecipeCard() {
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
            const SizedBox(height: 16),
            const Text(
              "내 취향에 맞는 AI 레시피",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 로딩 상태 표시
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else if (_recommendedRecipes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("추천 레시피가 없습니다."),
              )
            else
              // PageView
              SizedBox(
                height: 180,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: _recommendedRecipes.map((recipe) {
                    return _buildRecipeItem(recipe);
                  }).toList(),
                ),
              ),

            const SizedBox(height: 12),

            // 페이지 인디케이터
            if (_recommendedRecipes.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _recommendedRecipes.length,
                  (index) => _buildDot(isActive: index == _currentPage),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// AI 레시피 개별 아이템 (이미지 + 이름)
  Widget _buildRecipeItem(dynamic recipe) {
    final String imageUrl = recipe["ATT_FILE_NO_MAIN"] ?? ""; // 대표 이미지
    final String recipeName = recipe["RCP_NM"] ?? "No Name";   // 레시피명

    return GestureDetector(
      onTap: () {
        // 탭하면 RecipeDetailPage로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailPage(recipeData: recipe),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 대표 이미지
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: 160,
              height: 110,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 160,
                  height: 110,
                  color: Colors.grey,
                  alignment: Alignment.center,
                  child: const Text("No Image"),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // 레시피 이름
          Text(recipeName, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  /// 페이지 인디케이터용 작은 원
  Widget _buildDot({required bool isActive}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 10 : 8,
      height: isActive ? 10 : 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.black87 : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }

  /// 단순 카드 구조
  Widget _buildCard({
    required String title,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
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
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPinkButtonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onPressed,
              child: Text(buttonText),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// "싫어하거나 피하고 싶은 재료가 있나요?" 카드
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
            const SizedBox(height: 16),
            const Text(
              "싫어하거나 피하고 싶은 재료가 있나요?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildIngredientChip("알코올"),
                _buildIngredientChip("달걀"),
                _buildIngredientChip("우유"),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPinkButtonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                // TODO: 수정하기 등
              },
              child: const Text("수정하기"),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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