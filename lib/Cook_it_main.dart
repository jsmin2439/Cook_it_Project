import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'Cook_it_login.dart';
import 'Cook_it_splash.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'book_page.dart'; 
import 'firebase_options.dart';
import 'recipe_detail_page.dart';

// 색상 팔레트 (예시)
const Color kBackgroundColor = Color(0xFFFFF8EC); // 연한 베이지
const Color kCardColor = Color(0xFFFFECD0); // 더 진한 베이지
const Color kPinkButtonColor = Color(0xFFFFC7B9); // 연핑크
const Color kTextColor = Colors.black87; // 문구 색
const double kBorderRadius = 16.0; // 카드 라운딩


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _currentPage = 0;
  final PageController _pageController = PageController();

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
            // 상단 영역 (Cook it 로고 + 검색바)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  // 왼쪽 Cook it 로고 (이미지+텍스트)
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/cookie.png', // 쿠키 로고 예시
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
                  // 벨 아이콘
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    color: kTextColor,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // 구분선
            Container(
              height: 1,
              color: Colors.black26,
            ),
            // 상단 검색바
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black26),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "맛있는 요리 하실 준비 되셨나요??",
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    suffixIcon: const Icon(Icons.search, color: Colors.black45),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 스크롤 가능한 영역
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
                    const SizedBox(
                        height: 80), // 맨 아래 여백 (BottomNavigationBar 공간)
                  ],
                ),
              ),
            ),
            // 로그인 버튼 추가
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

  // "내 취향에 맞는 AI 레시피" 카드
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // PageView 추가
            SizedBox(
              height: 150,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildRecipeImage(
                      'assets/images/매콤한_간장_떡볶이.jpg', "매콤한 간장 떡볶이"),
                  _buildRecipeImage('assets/images/부드러운_크림_파스타.jpg', "부드러운 크림 파스타"),
                  _buildRecipeImage('assets/images/달콤한_팬케이크.jpg', "달콤한 팬케이크"),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 페이지 인디케이터 (원 3개 예시)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  3, (index) => _buildDot(isActive: index == _currentPage)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  
// 기존 _buildRecipeImage 수정
Widget _buildRecipeImage(String imagePath, String title) {
  // 1. 명시적 타입 선언 추가
  final Map<String, List<Map<String, String>>> recipeData = {
    '매콤한 간장 떡볶이': [
      {'name': '떡', 'quantity': '400g'},
      {'name': '설탕', 'quantity': '4T'},
      {'name': '물', 'quantity': '2컵'},
      {'name': '간장', 'quantity': '2T'},
      {'name': '대파', 'quantity': '1컵'},
      {'name': '고추장', 'quantity': '1T'},
      {'name': '오뎅', 'quantity': '200g'},
      {'name': '고춧가루', 'quantity': '1T'},
      {'name': '계란', 'quantity': '1개'},
    ],
    '부드러운 크림 파스타': [ // 3. 빈 리스트 대체
      {'name': '파스타면', 'quantity': '200g'},
      {'name': '생크림', 'quantity': '1컵'},
    ],
    '달콤한 팬케이크': [ // 3. 빈 리스트 대체
      {'name': '밀가루', 'quantity': '1.5컵'},
      {'name': '우유', 'quantity': '1컵'},
    ],
  };

  return GestureDetector(
    onTap: () {
      // 2. null 체크 추가 (! 연산자 사용)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailPage(
            title: title,
            ingredients: recipeData[title]!,
          ),
        ),
      );
    },
    child: Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            imagePath,
            width: 180,
            height: 120,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 8),
        Text(title),
      ],
    ),
  );
}

  // 페이지 인디케이터용 작은 원
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

  // 단순 카드 구조
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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

  // "싫어하거나 피하고 싶은 재료가 있나요?" 카드
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
                // 수정하기 등
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

class CookItMain extends StatefulWidget {
  const CookItMain({Key? key}) : super(key: key);

  @override
  _CookItMainState createState() => _CookItMainState();
}

class _CookItMainState extends State<CookItMain> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 로그아웃
  Future<void> _signOut() async {
    await _auth.signOut();
    // 로그아웃 후 로그인 화면으로
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const CookItLogin()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 현재 로그인된 유저
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cook It - Main'),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Center(
        child: user == null
            ? const Text('로그인 정보가 없습니다')
            : Text('반갑습니다, ${user.email ?? user.uid} 님!'),
      ),
    );
  }
}
